local LICENSE_URL = "https://perfect-sound-licensing.khonnorsound.workers.dev"

function getHWID()
  return reaper.GetOS() .. "_" .. reaper.GetAppVersion()
end

local function saveToken(token)
  reaper.SetExtState("PerfectSound", "token", token, true)
end

local function loadToken()
  return reaper.GetExtState("PerfectSound", "token")
end

local function login(user, password)
  local hwid = reaper.GetOS() .. "_" .. reaper.GetAppVersion()

  local json = string.format(
    '{"user":"%s","password":"%s","hwid":"%s"}',
    user, password, hwid
  )

  local cmd = string.format(
    "curl -s -X POST %s/login -H \"Content-Type: application/json\" -d '%s'",
    LICENSE_URL,
    json
  )

  local handle = io.popen(cmd)
  local result = handle:read("*a")
  handle:close()

  return result
end

local function hasAccess(response)
  return response and response:find('"ok":true') ~= nil
end

local function checkLicense()

  local token = loadToken()

  -- si ya existe token
  if token and token ~= "" then
    return true
  end

  -- si no hay token → pedir login
  local user = "demo"       -- luego lo cambiamos a UI
  local pass = "1234"

  local response = login(user, pass)

  if hasAccess(response) then

    local token = response:match('"token":"(.-)"')
    saveToken(token)

    reaper.ShowMessageBox("License activated", "Perfect Sound", 0)
    return true

  else
    reaper.ShowMessageBox("Invalid license", "Perfect Sound", 0)
    return false
  end
end

