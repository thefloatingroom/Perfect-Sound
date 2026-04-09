dofile("Core/license.lua")

if not checkLicense() then
  return
end

dofile("Scripts/PerfectSound_Main.lua")
