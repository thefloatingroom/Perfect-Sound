-- @description FloatingRoom
-- @version 1.0.0
-- @author FloatingRoom
-- @about
--   FloatingRoom licensed tools loader

local function askEmail()
    local retval, email = reaper.GetUserInputs("FloatingRoom Login", 1, "Email:", "")
    if not retval or email == "" then return nil end
    return email
end

local email = askEmail()
if not email then return end

local url = "http://127.0.0.1:5000/auth?email=" .. email

local response = reaper.CF_GetClipboard("") -- placeholder temporal
reaper.ShowMessageBox("Connecting to FloatingRoom server for: "..email, "FloatingRoom", 0)
