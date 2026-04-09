dofile("Core/license.lua")

if not checkLicense() then
  return
end

dofile("Scripts/PerfectSound_Main.lua")

local token = loadToken()

if not token or token == "" then
  dofile("UI/license_ui.lua")
  return
end
