dofile(reaper.GetResourcePath() .. "/Scripts/Core/loader.lua")

local token = PS_GetToken()

if token == "" then
    token = PS_Login()

    if token == "LICENSE_IN_USE" then
        local confirm = reaper.MB("Licencia activa en otro equipo.\n¿Mover aquí?", "Perfect Sound", 1)
        if confirm == 1 then
            -- aquí luego haremos transfer
        end
        return
    end

    if not token then return end
end

local status = PS_Validate(token)

if status == "OK" then
    PS_RunScript("PerfectSound_Main", token)
elseif status == "DEVICE_REVOKED" then
    reaper.MB("Licencia usada en otro equipo", "Error", 0)
end
