local BASE_URL = "http://localhost:3000"

function PS_GetMachineID()
    local user = os.getenv("USERNAME") or os.getenv("USER") or "unknown"
    local os_name = reaper.GetOS()
    return user .. "_" .. os_name
end

function PS_GetToken()
    return reaper.GetExtState("PerfectSound", "token")
end

function PS_SaveToken(token)
    reaper.SetExtState("PerfectSound", "token", token, true)
end

function PS_Login()
    local ok, input = reaper.GetUserInputs("Perfect Sound Login", 2, "Email,Password", "")
    if not ok then return nil end

    local email, pass = input:match("([^,]+),([^,]+)")
    local machine = PS_GetMachineID()

    local cmd = 'curl -s -X POST '..BASE_URL..'/login -d "email='..email..'&pass='..pass..'&machine='..machine..'"'
    local f = io.popen(cmd)
    local res = f:read("*a")
    f:close()

    if res ~= "" and res ~= "LICENSE_IN_USE" then
        PS_SaveToken(res)
        return res
    end

    return res
end

function PS_Validate(token)
    local machine = PS_GetMachineID()

    local cmd = 'curl -s "'..BASE_URL..'/validate?token='..token..'&machine='..machine..'"'
    local f = io.popen(cmd)
    local res = f:read("*a")
    f:close()

    return res
end

function PS_RunScript(name, token)
    local cmd = 'curl -s "'..BASE_URL..'/script?name='..name..'&token='..token..'"'
    local f = io.popen(cmd)
    local code = f:read("*a")
    f:close()

    local func, err = load(code)
    if func then func() else reaper.MB(err, "Error", 0) end
end