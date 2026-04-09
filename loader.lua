local script_path = debug.getinfo(1, "S").source:match("@(.*[\\|/])")

dofile(script_path .. "Core/license.lua")

if not checkLicense() then
  dofile(script_path .. "UI/license_ui.lua")
  return
end

dofile(script_path .. "Scripts/PerfectSound_Main.lua")
