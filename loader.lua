-- =========================================================================
-- Perfect Sound — Loader (v2)
-- =========================================================================
-- This is the ONLY file shipped via ReaPack. It does not contain any of
-- the paid logic. Its job is:
--   1. Detect a stable hardware ID
--   2. Prompt for email + password (once; cached encrypted at rest)
--   3. Log in to the licensing server
--   4. Fetch encrypted bundles for the scripts the user owns
--   5. Verify HMAC, decrypt with HMAC-keystream, run with load() in memory
--
-- Crypto: SHA-256 + HMAC-SHA256 in pure Lua. Bundles are encrypted with
-- HMAC-keystream + HMAC-SHA256 (encrypt-then-MAC) using per-session keys.
-- =========================================================================

local API_BASE = "https://perfect-sound-api.khonnorsound.workers.dev"
local DATA_DIR = reaper.GetResourcePath() .. "/Scripts/PerfectSound"
local CRED_FILE = DATA_DIR .. "/creds.dat"
local SESS_KEY  = "PerfectSound_session"   -- ExtState key (volatile, in-memory)

-- =========================================================================
-- 1. SHA-256 (RFC 6234) — pure Lua, requires Lua 5.3+ bitwise ops
-- =========================================================================

local mask32 = 0xFFFFFFFF
local function rotr(x, n) return ((x >> n) | (x << (32 - n))) & mask32 end

local K_SHA = {
  0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
  0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
  0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
  0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
  0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
  0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
  0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
  0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2,
}

local function sha256(msg)
  local H = {0x6a09e667,0xbb67ae85,0x3c6ef372,0xa54ff53a,
             0x510e527f,0x9b05688c,0x1f83d9ab,0x5be0cd19}

  local len = #msg
  local bytes = {}
  for i = 1, len do bytes[i] = msg:byte(i) end
  bytes[#bytes+1] = 0x80
  while (#bytes % 64) ~= 56 do bytes[#bytes+1] = 0 end
  local bitlen = len * 8
  for i = 7, 0, -1 do bytes[#bytes+1] = (bitlen >> (i*8)) & 0xFF end

  for chunk = 0, (#bytes / 64) - 1 do
    local W = {}
    for i = 0, 15 do
      local p = chunk * 64 + i * 4 + 1
      W[i] = (bytes[p]<<24) | (bytes[p+1]<<16) | (bytes[p+2]<<8) | bytes[p+3]
    end
    for i = 16, 63 do
      local w15 = W[i-15]; local w2 = W[i-2]
      local s0 = rotr(w15,7) ~ rotr(w15,18) ~ (w15 >> 3)
      local s1 = rotr(w2,17) ~ rotr(w2,19) ~ (w2 >> 10)
      W[i] = (W[i-16] + s0 + W[i-7] + s1) & mask32
    end

    local a,b,c,d,e,f,g,h = H[1],H[2],H[3],H[4],H[5],H[6],H[7],H[8]

    for i = 0, 63 do
      local S1  = rotr(e,6) ~ rotr(e,11) ~ rotr(e,25)
      local ch  = (e & f) ~ ((~e) & g)
      local t1  = (h + S1 + ch + K_SHA[i+1] + W[i]) & mask32
      local S0  = rotr(a,2) ~ rotr(a,13) ~ rotr(a,22)
      local mj  = (a & b) ~ (a & c) ~ (b & c)
      local t2  = (S0 + mj) & mask32
      h = g; g = f; f = e
      e = (d + t1) & mask32
      d = c; c = b; b = a
      a = (t1 + t2) & mask32
    end

    H[1]=(H[1]+a)&mask32; H[2]=(H[2]+b)&mask32; H[3]=(H[3]+c)&mask32; H[4]=(H[4]+d)&mask32
    H[5]=(H[5]+e)&mask32; H[6]=(H[6]+f)&mask32; H[7]=(H[7]+g)&mask32; H[8]=(H[8]+h)&mask32
  end

  local out = {}
  for i = 1, 8 do
    local v = H[i]
    out[#out+1] = string.char((v>>24)&0xFF)
    out[#out+1] = string.char((v>>16)&0xFF)
    out[#out+1] = string.char((v>>8)&0xFF)
    out[#out+1] = string.char(v&0xFF)
  end
  return table.concat(out)
end

local function sha256_hex(msg)
  local s = sha256(msg)
  local h = {}
  for i = 1, #s do h[i] = string.format("%02x", s:byte(i)) end
  return table.concat(h)
end

-- =========================================================================
-- 2. HMAC-SHA256 (RFC 2104)
-- =========================================================================

local function hmac_sha256(key, msg)
  if #key > 64 then key = sha256(key) end
  if #key < 64 then key = key .. string.rep("\0", 64 - #key) end

  local opad, ipad = {}, {}
  for i = 1, 64 do
    local k = key:byte(i)
    ipad[i] = string.char(k ~ 0x36)
    opad[i] = string.char(k ~ 0x5c)
  end
  local inner = sha256(table.concat(ipad) .. msg)
  return sha256(table.concat(opad) .. inner)
end

-- =========================================================================
-- 3. Self-test (runs once on load — guards against 32/64-bit bugs)
-- =========================================================================

do
  local got = sha256_hex("abc")
  local exp = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
  if got ~= exp then
    reaper.ShowMessageBox(
      "Crypto self-test failed.\nExpected: "..exp.."\nGot: "..got..
      "\n\nThis means your REAPER's Lua doesn't support 64-bit bitwise ops correctly. " ..
      "Please update REAPER.",
      "Perfect Sound — fatal", 0
    )
    return
  end
end

-- =========================================================================
-- 4. Base64 decode
-- =========================================================================

local b64_alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local b64_lookup = {}
for i = 1, #b64_alphabet do b64_lookup[b64_alphabet:byte(i)] = i - 1 end

local function b64decode(s)
  s = s:gsub("[^A-Za-z0-9+/=]", "")
  local out = {}
  for i = 1, #s, 4 do
    local c1 = b64_lookup[s:byte(i)]   or 0
    local c2 = b64_lookup[s:byte(i+1)] or 0
    local c3 = b64_lookup[s:byte(i+2)]
    local c4 = b64_lookup[s:byte(i+3)]
    local n = (c1 << 18) | (c2 << 12) | ((c3 or 0) << 6) | (c4 or 0)
    out[#out+1] = string.char((n >> 16) & 0xFF)
    if c3 then out[#out+1] = string.char((n >> 8) & 0xFF) end
    if c4 then out[#out+1] = string.char(n & 0xFF) end
  end
  return table.concat(out)
end

-- =========================================================================
-- 5. Constant-time byte-string compare
-- =========================================================================

local function ct_eq(a, b)
  if #a ~= #b then return false end
  local r = 0
  for i = 1, #a do r = r | (a:byte(i) ~ b:byte(i)) end
  return r == 0
end

-- =========================================================================
-- 6. Safe JSON parser (NO load/eval — recursive descent)
-- =========================================================================

local function json_decode(s)
  local pos = 1
  local parse_value

  local function skip_ws()
    while pos <= #s do
      local c = s:byte(pos)
      if c == 32 or c == 9 or c == 10 or c == 13 then pos = pos + 1
      else break end
    end
  end

  local function parse_string()
    pos = pos + 1   -- skip opening "
    local out = {}
    while pos <= #s do
      local c = s:sub(pos, pos)
      if c == '"' then pos = pos + 1; return table.concat(out) end
      if c == "\\" then
        local n = s:sub(pos+1, pos+1)
        if     n == '"' then out[#out+1] = '"'
        elseif n == "\\" then out[#out+1] = "\\"
        elseif n == "/" then out[#out+1] = "/"
        elseif n == "n" then out[#out+1] = "\n"
        elseif n == "r" then out[#out+1] = "\r"
        elseif n == "t" then out[#out+1] = "\t"
        elseif n == "b" then out[#out+1] = "\b"
        elseif n == "f" then out[#out+1] = "\f"
        elseif n == "u" then out[#out+1] = "?"; pos = pos + 4
        else out[#out+1] = n end
        pos = pos + 2
      else
        out[#out+1] = c
        pos = pos + 1
      end
    end
    error("unterminated string")
  end

  local function parse_number()
    local start = pos
    while pos <= #s do
      local c = s:byte(pos)
      if (c >= 48 and c <= 57) or c == 45 or c == 46 or c == 43 or c == 101 or c == 69 then
        pos = pos + 1
      else break end
    end
    return tonumber(s:sub(start, pos - 1))
  end

  local function parse_array()
    pos = pos + 1; skip_ws()
    local arr = {}
    if s:sub(pos, pos) == "]" then pos = pos + 1; return arr end
    while true do
      arr[#arr+1] = parse_value(); skip_ws()
      local c = s:sub(pos, pos)
      if c == "," then pos = pos + 1; skip_ws()
      elseif c == "]" then pos = pos + 1; return arr
      else error("expected , or ] (array) at "..pos) end
    end
  end

  local function parse_object()
    pos = pos + 1; skip_ws()
    local obj = {}
    if s:sub(pos, pos) == "}" then pos = pos + 1; return obj end
    while true do
      skip_ws()
      if s:sub(pos, pos) ~= '"' then error("expected key at "..pos) end
      local key = parse_string(); skip_ws()
      if s:sub(pos, pos) ~= ":" then error("expected : at "..pos) end
      pos = pos + 1; skip_ws()
      obj[key] = parse_value(); skip_ws()
      local c = s:sub(pos, pos)
      if c == "," then pos = pos + 1
      elseif c == "}" then pos = pos + 1; return obj
      else error("expected , or } (obj) at "..pos) end
    end
  end

  parse_value = function()
    skip_ws()
    local c = s:sub(pos, pos)
    if c == "{" then return parse_object() end
    if c == "[" then return parse_array() end
    if c == '"' then return parse_string() end
    if c == "t" then pos = pos + 4; return true end
    if c == "f" then pos = pos + 5; return false end
    if c == "n" then pos = pos + 4; return nil end
    return parse_number()
  end

  local ok, result = pcall(parse_value)
  if not ok then return nil end
  return result
end

local function json_encode_string(str)
  local s = str:gsub("\\", "\\\\")
                :gsub('"', '\\"')
                :gsub("\n", "\\n")
                :gsub("\r", "\\r")
                :gsub("\t", "\\t")
  return '"' .. s .. '"'
end

local function json_encode(v)
  local t = type(v)
  if t == "string"  then return json_encode_string(v) end
  if t == "number"  then return tostring(v) end
  if t == "boolean" then return v and "true" or "false" end
  if t == "nil"     then return "null" end
  if t == "table" then
    local parts = {}
    for k, val in pairs(v) do
      parts[#parts+1] = json_encode_string(tostring(k)) .. ":" .. json_encode(val)
    end
    return "{" .. table.concat(parts, ",") .. "}"
  end
  return "null"
end

-- =========================================================================
-- 7. File I/O + cross-platform mkdir
-- =========================================================================

local function file_read(path)
  local f = io.open(path, "rb")
  if not f then return nil end
  local data = f:read("*a"); f:close(); return data
end

local function file_write(path, data)
  local f = io.open(path, "wb")
  if not f then return false end
  f:write(data); f:close(); return true
end

local function ensure_dir(path)
  if reaper.RecursiveCreateDirectory then
    reaper.RecursiveCreateDirectory(path, 0)
  end
end

ensure_dir(DATA_DIR)

-- =========================================================================
-- 8. Hardware ID — real, stable, OS-bound
-- =========================================================================

local function trim(s) return (s or ""):gsub("^%s+", ""):gsub("%s+$", "") end

local function detect_hwid()
  local os_str = reaper.GetOS() or ""
  local raw

  if os_str:find("OSX") or os_str:find("macOS") then
    local p = io.popen([[ioreg -d2 -c IOPlatformExpertDevice 2>/dev/null | awk -F'"' '/IOPlatformUUID/{print $(NF-1)}']])
    if p then raw = trim(p:read("*l")); p:close() end

  elseif os_str:find("Win") then
    -- wmic is being deprecated in newer Windows, so try PowerShell as fallback.
    local p = io.popen('wmic csproduct get UUID 2>nul')
    if p then
      for line in p:lines() do
        local t = trim(line)
        if t ~= "" and not t:match("UUID") then raw = t; break end
      end
      p:close()
    end
    if not raw or raw == "" then
      local p2 = io.popen('powershell -NoProfile -Command "(Get-CimInstance -ClassName Win32_ComputerSystemProduct).UUID" 2>nul')
      if p2 then raw = trim(p2:read("*l")); p2:close() end
    end

  else
    raw = trim(file_read("/etc/machine-id"))
    if not raw or raw == "" then raw = trim(file_read("/var/lib/dbus/machine-id")) end
  end

  if not raw or raw == "" then
    -- Last-ditch fallback: hostname + REAPER resource path. Stable per user
    -- but not great. We mark it so the server-side analytics can flag it.
    local p = io.popen("hostname")
    local host = p and trim(p:read("*l")) or "unknown"
    if p then p:close() end
    raw = "fallback:" .. host .. ":" .. reaper.GetResourcePath()
  end

  -- Hash for normalization (always 64 hex chars, no special chars).
  return sha256_hex("PSv2-hwid:" .. raw)
end

-- =========================================================================
-- 9. At-rest credential encryption (XOR with HWID-derived keystream)
-- =========================================================================
-- Defense in depth: if creds.dat is copied to another machine, the attacker
-- needs that machine's UUID to decrypt. Not strong crypto; just enough to
-- make casual file-sharing useless.

local function obfuscate(data, hwid)
  local out = {}
  local n_blocks = math.ceil(#data / 32)
  for blk = 0, n_blocks - 1 do
    local key = sha256(hwid .. ":at-rest:" .. tostring(blk))
    for i = 1, 32 do
      local pos = blk * 32 + i
      if pos > #data then break end
      out[pos] = string.char(data:byte(pos) ~ key:byte(i))
    end
  end
  return table.concat(out)
end

local deobfuscate = obfuscate   -- XOR is symmetric

-- Base64 encode for storing binary on disk as text
local function b64encode(data)
  local out = {}
  for i = 1, #data, 3 do
    local b1 = data:byte(i)
    local b2 = data:byte(i+1) or 0
    local b3 = data:byte(i+2) or 0
    local n = (b1 << 16) | (b2 << 8) | b3
    out[#out+1] = b64_alphabet:sub(((n >> 18) & 63) + 1, ((n >> 18) & 63) + 1)
    out[#out+1] = b64_alphabet:sub(((n >> 12) & 63) + 1, ((n >> 12) & 63) + 1)
    if i + 1 <= #data then
      out[#out+1] = b64_alphabet:sub(((n >> 6) & 63) + 1, ((n >> 6) & 63) + 1)
    else out[#out+1] = "=" end
    if i + 2 <= #data then
      out[#out+1] = b64_alphabet:sub((n & 63) + 1, (n & 63) + 1)
    else out[#out+1] = "=" end
  end
  return table.concat(out)
end

-- =========================================================================
-- 10. HTTP — curl with body in temp file
-- =========================================================================

local function is_windows()
  local s = reaper.GetOS() or ""
  return s:find("Win") ~= nil
end

-- Cross-platform tempfile path. os.tmpname() in Windows returns a relative
-- path like "\sNNN" that lands at the root of the current drive (C:\sNNN),
-- which is unwritable for non-admin users. We build a proper absolute path
-- inside the user's temp directory.
local function make_tempfile_path()
  if is_windows() then
    local tmpdir = os.getenv("TEMP") or os.getenv("TMP")
    if not tmpdir or tmpdir == "" then
      -- Last resort: REAPER's own resource path (always writable)
      tmpdir = reaper.GetResourcePath()
    end
    -- math.random gives us enough uniqueness for short-lived files
    return string.format("%s\\ps_%d_%d.tmp",
      tmpdir, os.time(), math.random(100000, 999999))
  end
  -- On macOS / Linux, os.tmpname() works correctly (returns absolute paths)
  return os.tmpname()
end

-- Shell-quote a path or URL for the current OS.
-- POSIX (mac/linux) uses single quotes.
-- Windows cmd.exe uses double quotes; backslashes don't need escaping inside
-- them (paths like C:\Users\... are fine), but a literal " has to be doubled.
local function shell_quote(s)
  if is_windows() then
    return '"' .. s:gsub('"', '""') .. '"'
  end
  return "'" .. s:gsub("'", "'\\''") .. "'"
end

local function http_post_json(url, body_table)
  local body_path = make_tempfile_path()
  local resp_path = make_tempfile_path()

  if not file_write(body_path, json_encode(body_table)) then
    return nil, "tempfile_write_failed"
  end

  -- URL is a hardcoded constant we trust; quoting it anyway.
  local cmd = string.format(
    'curl -s -L -X POST -H "Content-Type: application/json" --data-binary @%s -o %s %s',
    shell_quote(body_path), shell_quote(resp_path), shell_quote(url)
  )
  local ok = os.execute(cmd)
  local raw = file_read(resp_path)
  os.remove(body_path); os.remove(resp_path)

  if not raw or raw == "" then return nil, "no_response" end
  local parsed = json_decode(raw)
  if not parsed then return nil, "bad_json:" .. raw:sub(1, 200) end
  return parsed
end

-- =========================================================================
-- 11. Credential storage — load/save email+password obfuscated with HWID
-- =========================================================================

local function load_creds(hwid)
  local raw = file_read(CRED_FILE)
  if not raw then return nil end
  local cipher = b64decode(raw)
  local plain  = deobfuscate(cipher, hwid)
  local parsed = json_decode(plain)
  if not parsed or not parsed.email or not parsed.password then return nil end
  return parsed
end

local function save_creds(creds, hwid)
  local plain  = json_encode(creds)
  local cipher = obfuscate(plain, hwid)
  return file_write(CRED_FILE, b64encode(cipher))
end

local function clear_creds() os.remove(CRED_FILE) end

-- =========================================================================
-- 12. Session cache — stored in REAPER ExtState (in-memory, volatile)
-- =========================================================================
-- We never write the session token to disk. It lives only in REAPER's
-- in-memory state for the current REAPER session. If REAPER is restarted,
-- we re-login (silent, since creds are cached on disk).

local function load_session()
  local s = reaper.GetExtState("PerfectSound", SESS_KEY)
  if s == "" then return nil end
  local p = json_decode(s)
  if not p or not p.session_token or not p.expires_at then return nil end
  if os.time() > p.expires_at - 60 then return nil end  -- 60s grace
  return p
end

local function save_session(sess)
  reaper.SetExtState("PerfectSound", SESS_KEY, json_encode(sess), false) -- persist=false
end

local function clear_session()
  reaper.DeleteExtState("PerfectSound", SESS_KEY, false)
end

-- =========================================================================
-- 13. Decrypt + verify a package payload
-- =========================================================================
-- Inverse of the server's streamEncrypt:
--   block_i  = HMAC-SHA256(k_enc, iv || u32be(i))
--   ks       = block_0 || block_1 || ...
--   pt       = ct XOR ks[0..len(ct)-1]
--   verify mac == HMAC-SHA256(k_mac, iv || ct)

local function u32be(n)
  return string.char((n >> 24) & 0xFF, (n >> 16) & 0xFF, (n >> 8) & 0xFF, n & 0xFF)
end

local function decrypt_bundle(payload, k_enc, k_mac)
  local iv  = b64decode(payload.iv)
  local ct  = b64decode(payload.ct)
  local mac = b64decode(payload.mac)

  -- 1) Verify MAC FIRST (encrypt-then-MAC).
  local expected = hmac_sha256(k_mac, iv .. ct)
  if not ct_eq(expected, mac) then return nil, "mac_mismatch" end

  -- 2) Decrypt.
  local pt = {}
  local ctr = 0
  local off = 1
  while off <= #ct do
    local block = hmac_sha256(k_enc, iv .. u32be(ctr))
    local take = math.min(32, #ct - off + 1)
    for i = 1, take do
      pt[off + i - 1] = string.char(ct:byte(off + i - 1) ~ block:byte(i))
    end
    off = off + take
    ctr = ctr + 1
  end
  return table.concat(pt)
end

-- =========================================================================
-- 14. Login flow
-- =========================================================================

local function prompt_creds()
  local ok1, email = reaper.GetUserInputs("Perfect Sound — Sign in", 1, "Email:,extrawidth=200", "")
  if not ok1 or email == "" then return nil end
  local ok2, password = reaper.GetUserInputs("Perfect Sound — Sign in", 1, "Password:,extrawidth=200", "")
  if not ok2 or password == "" then return nil end
  return { email = email, password = password }
end

local function do_login(creds, hwid)
  local body = { email = creds.email, password = creds.password, machine_id = hwid }
  local resp, err = http_post_json(API_BASE .. "/api/login", body)
  if not resp then return nil, err or "network" end
  if not resp.ok then return nil, resp.error or "login_failed" end

  local sess = {
    session_token = resp.session_token,
    k_enc         = resp.k_enc,    -- base64
    k_mac         = resp.k_mac,    -- base64
    expires_at    = resp.expires_at,
    scripts       = resp.scripts or {},
  }
  save_session(sess)
  return sess
end

-- Deactivate this device on the server. Tries with the cached session first;
-- falls back to email + password if there is no session (e.g. customer
-- already lost it).
local function do_deactivate()
  local sess = load_session()
  local body = {}
  if sess and sess.session_token then
    body.session_token = sess.session_token
  else
    -- Need email + password to authenticate the deactivate request.
    local hwid = detect_hwid()
    local creds = load_creds(hwid)
    if not creds then
      creds = prompt_creds()
      if not creds then return nil, "user_cancelled" end
    end
    body.email = creds.email
    body.password = creds.password
  end

  local resp, err = http_post_json(API_BASE .. "/api/deactivate", body)
  if not resp then return nil, err or "network" end
  if not resp.ok then return nil, resp.error or "deactivate_failed" end

  -- Server confirmed: clear local state too, so this machine truly stops
  -- having a working install until the customer logs in again.
  clear_session()
  clear_creds()
  return true
end

-- Returns a valid session, prompting for creds if needed. Handles cred
-- rotation transparently.
local function get_or_create_session(hwid)
  local sess = load_session()
  if sess then return sess end

  -- Try cached creds.
  local creds = load_creds(hwid)
  if creds then
    local s, err = do_login(creds, hwid)
    if s then return s end
    -- Cached creds invalid (password changed, license revoked, etc).
    if err ~= "network" then clear_creds() end
  end

  -- Prompt user.
  creds = prompt_creds()
  if not creds then return nil, "user_cancelled" end
  local s, err = do_login(creds, hwid)
  if not s then return nil, err end
  save_creds(creds, hwid)
  return s
end

-- =========================================================================
-- 15. Fetch + run a bundle
-- =========================================================================

-- Returns the display name of a known REAPER extension that is NOT
-- installed, or nil if all known extensions are present.
-- Used to translate cryptic "attempt to call a nil value" errors from
-- obfuscated bundles into helpful messages.
local function detect_missing_extension()
  -- ReaImGui: provides reaper.ImGui_*
  if not reaper.ImGui_CreateContext then
    return "ReaImGui"
  end
  -- SWS / S&M Extension: provides reaper.CF_*, reaper.BR_*, reaper.NF_*
  if not reaper.CF_GetCommandText then
    return "SWS"
  end
  -- js_ReaScriptAPI: provides reaper.JS_*
  -- (Optional - some scripts use it, some don't. Only flag if the bundle
  -- likely needs it, but since we don't know what the bundle uses, we only
  -- check the two most common dependencies above.)
  return nil
end

local function fetch_and_run(slug, sess)
  local resp, err = http_post_json(API_BASE .. "/api/package", {
    session_token = sess.session_token,
    slug          = slug,
  })
  if not resp then return false, err end
  if not resp.ok then return false, resp.error end

  local k_enc = b64decode(sess.k_enc)
  local k_mac = b64decode(sess.k_mac)
  local source, derr = decrypt_bundle(resp, k_enc, k_mac)
  if not source then return false, derr end

  -- Optional: verify against server-stored hash.
  if resp.bundle_hash and resp.bundle_hash ~= sha256_hex(source) then
    return false, "hash_mismatch"
  end

  -- Run in-memory. We use a clean environment so the bundle cannot easily
  -- mess with the loader's internals (it still has access to _G via reaper.*).
  local fn, lerr = load(source, "=psbundle:" .. slug, "t")
  if not fn then return false, "load_error: " .. tostring(lerr) end

  local ok, rerr = pcall(fn)
  if not ok then
    -- "attempt to call a nil value" almost always means the script tried
    -- to use a REAPER extension (ReaImGui, SWS, js_ReaScriptAPI) that the
    -- customer hasn't installed. Detect which one and return a better code
    -- so friendly_error can show a useful message instead of the cryptic
    -- "nil value W" that comes from obfuscated bundles.
    local err_str = tostring(rerr)
    if err_str:find("attempt to call a nil value", 1, true) then
      local missing = detect_missing_extension()
      if missing then
        return false, "missing_extension:" .. missing
      end
    end
    return false, "runtime_error: " .. err_str
  end
  return true
end

-- =========================================================================
-- 16. Friendly error mapping
-- =========================================================================
-- The server returns short machine-readable codes (e.g. "license_inactive").
-- Customers see this loader, not the API, so we translate codes into clear
-- messages and trigger any side effects that should happen when a given
-- error appears.

local SUPPORT_EMAIL = "pconesa@perfectsound.es"

local function friendly_error(code)
  if not code then code = "unknown" end
  code = tostring(code)

  if code == "license_inactive" then
    return "Your Perfect Sound license is currently paused.\n\n" ..
           "Please contact support to reactivate it:\n" ..
           SUPPORT_EMAIL
  end
  if code == "license_revoked" then
    return "Your Perfect Sound license has been revoked.\n\n" ..
           "Please contact support if you believe this is a mistake:\n" ..
           SUPPORT_EMAIL
  end
  if code == "device_mismatch" then
    return "This license is currently active on a different computer.\n\n" ..
           "Run any Perfect Sound script and sign in again to move your " ..
           "license to this machine. The previous device will be released " ..
           "automatically.\n\n" ..
           "If you would prefer to release the previous device explicitly, " ..
           "use the action \"Perfect Sound: Deactivate this device\" on " ..
           "that computer first.\n\n" ..
           "Need help? " .. SUPPORT_EMAIL
  end
  if code == "not_authorized" then
    return "Your license does not include this script.\n\n" ..
           "Contact support to add it to your plan:\n" .. SUPPORT_EMAIL
  end
  if code == "invalid_credentials" then
    return "Invalid email or password.\n\n" ..
           "Please double-check the credentials sent to your email when " ..
           "you purchased your license. If you have lost them, contact " ..
           "support:\n" .. SUPPORT_EMAIL
  end
  if code == "invalid_session" or code == "mac_mismatch" or code == "hash_mismatch" then
    return "Your session has expired or is invalid.\n\n" ..
           "Please run the script again - you will be asked to sign in."
  end
  if code == "bundle_unavailable" then
    return "This script is temporarily unavailable.\n\n" ..
           "Please try again in a few minutes. If the issue persists, " ..
           "contact support:\n" .. SUPPORT_EMAIL
  end
  if code == "network" or code == "no_response" or code == "tempfile_write_failed" then
    return "Could not reach the Perfect Sound server.\n\n" ..
           "Please check your internet connection and try again. If the " ..
           "problem persists, contact support:\n" .. SUPPORT_EMAIL
  end
  if code:sub(1, 9) == "bad_json:" or code:sub(1, 11) == "load_error:" or
     code:sub(1, 14) == "runtime_error:" then
    return "An unexpected error occurred running this script:\n\n" .. code ..
           "\n\nPlease contact support:\n" .. SUPPORT_EMAIL
  end

  -- Fallback: include the raw code so support can diagnose.
  return "An unexpected error occurred:\n\n" .. code ..
         "\n\nPlease contact support:\n" .. SUPPORT_EMAIL
end

-- Some error codes imply that local state is now stale and should be
-- cleaned up before the next run.
local function handle_error_side_effects(code)
  if code == "license_revoked" then
    -- License is dead: cached credentials and session are useless. Clearing
    -- credentials means the next run won't auto-relogin with a dead account.
    clear_creds()
    clear_session()
  elseif code == "license_inactive" then
    -- Pause is reversible (admin can re-activate). Clear only the session
    -- so the next run does a fresh login that picks up the new status.
    clear_session()
  elseif code == "device_mismatch" then
    -- The license was rebound elsewhere; our session is now inconsistent.
    clear_session()
  elseif code == "invalid_credentials" then
    -- The cached credentials no longer match (password reset, account gone).
    clear_creds()
    clear_session()
  end
end

-- =========================================================================
-- 17. Main
-- =========================================================================
--
-- This loader is meant to be invoked by per-script stubs. Each stub that
-- the user triggers (an action in REAPER) calls into this loader with a
-- specific slug. For now, we expose a global table the stubs can read.
--
-- Usage from a stub script (1-line entry point installed by ReaPack):
--
--    PERFECT_SOUND_RUN = "specs"
--    dofile(reaper.GetResourcePath() .. "/Scripts/PerfectSound/Core/loader.lua")
--
-- If PERFECT_SOUND_RUN is not set, the loader logs in and lists available
-- scripts (handy for first install).

local function main()
  -- Branch 1: Deactivate this device. Triggered by a stub setting
  -- PERFECT_SOUND_ACTION = "deactivate". This does NOT need a working
  -- session: if cached creds exist they're used, otherwise the user is
  -- prompted for email/password.
  if PERFECT_SOUND_ACTION == "deactivate" then
    local confirm = reaper.ShowMessageBox(
      "Release this computer from your Perfect Sound license?\n\n" ..
      "After deactivating, you will not be able to run Perfect Sound " ..
      "scripts on this machine until you sign in again. You will then " ..
      "be free to activate the license on a different computer.",
      "Perfect Sound - Deactivate device",
      1   -- 1 = OK / Cancel
    )
    if confirm ~= 1 then return end   -- 1 = OK pressed

    local ok, err = do_deactivate()
    if not ok then
      if err == "user_cancelled" then return end
      handle_error_side_effects(err)
      reaper.ShowMessageBox(friendly_error(err), "Perfect Sound", 0)
      return
    end
    reaper.ShowMessageBox(
      "This computer has been released.\n\n" ..
      "You can now sign in on another machine.",
      "Perfect Sound", 0
    )
    return
  end

  -- Dependency check. Only runs when actually launching a script (not for
  -- Deactivate, which doesn't need these extensions). Lists every missing
  -- extension in one go so the user can install them all in a single trip
  -- to ReaPack instead of getting hit one at a time.
  local missing = {}
  if not reaper.ImGui_CreateContext then
    missing[#missing+1] = "ReaImGui"
  end
  if not reaper.CF_GetCommandText then
    missing[#missing+1] = "SWS Extension"
  end
  if not reaper.JS_Dialog_BrowseForSaveFile then
    missing[#missing+1] = "js_ReaScriptAPI"
  end

  if #missing > 0 then
    local lines = {
      "Perfect Sound scripts require the following extension(s) which are",
      "not installed on this machine:",
      "",
    }
    for _, name in ipairs(missing) do
      lines[#lines+1] = "  - " .. name
    end
    lines[#lines+1] = ""
    lines[#lines+1] = "How to install:"
    lines[#lines+1] = ""
    if table.concat(missing, ","):find("SWS") then
      lines[#lines+1] = "  SWS Extension: download from https://www.sws-extension.org"
      lines[#lines+1] = "  and run the installer."
      lines[#lines+1] = ""
    end
    if table.concat(missing, ","):find("ReaImGui") or table.concat(missing, ","):find("js_ReaScriptAPI") then
      lines[#lines+1] = "  ReaImGui / js_ReaScriptAPI: in REAPER, go to"
      lines[#lines+1] = "  Extensions > ReaPack > Browse packages, search the name,"
      lines[#lines+1] = "  right-click > Install, then Apply."
      lines[#lines+1] = ""
    end
    lines[#lines+1] = "After installing, restart REAPER and try again."
    lines[#lines+1] = ""
    lines[#lines+1] = "Need help? " .. SUPPORT_EMAIL

    reaper.ShowMessageBox(
      table.concat(lines, "\n"),
      "Perfect Sound - missing extensions",
      0
    )
    return
  end

  local hwid = detect_hwid()
  local sess, err = get_or_create_session(hwid)
  if not sess then
    if err == "user_cancelled" then return end
    handle_error_side_effects(err)
    reaper.ShowMessageBox(friendly_error(err), "Perfect Sound", 0)
    return
  end

  local slug = PERFECT_SOUND_RUN
  if not slug or slug == "" then
    -- No specific script requested → show what's available.
    local names = {}
    for _, s in ipairs(sess.scripts or {}) do
      names[#names+1] = "  • " .. s.name .. " (" .. s.slug .. ") v" .. (s.version or "?")
    end
    if #names == 0 then
      reaper.ShowMessageBox(
        "Signed in as " .. (load_creds(hwid) or {}).email ..
        ".\n\nNo scripts assigned to your license yet.",
        "Perfect Sound", 0
      )
    else
      reaper.ShowMessageBox(
        "Signed in.\n\nAvailable scripts:\n\n" .. table.concat(names, "\n"),
        "Perfect Sound", 0
      )
    end
    return
  end

  local ok, err2 = fetch_and_run(slug, sess)
  if not ok then
    -- Session may have expired between cache check and call; retry once.
    if err2 == "invalid_session" then
      clear_session()
      sess, err = get_or_create_session(hwid)
      if sess then ok, err2 = fetch_and_run(slug, sess) end
    end
    if not ok then
      handle_error_side_effects(err2)
      reaper.ShowMessageBox(friendly_error(err2), "Perfect Sound", 0)
    end
  end
end

main()
