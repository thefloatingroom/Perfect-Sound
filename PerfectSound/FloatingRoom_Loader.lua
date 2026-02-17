-- @description FloatingRoom
-- @version 1.0.0
-- @author TheFloatingRoom
-- @about
--   FloatingRoom licensed tools loader

local function msg(t)
    reaper.ShowMessageBox(t, "FloatingRoom", 0)
end

local function askEmail()
    local retval, email = reaper.GetUserInputs("FloatingRoom Login", 1, "Email:", "")
    if not retval or email == "" then return nil end
    return email
end

local email = askEmail()
if not email then return end

msg("FloatingRoom Loader installed correctly!\nUser: "..email)
