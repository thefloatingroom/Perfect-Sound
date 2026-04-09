dofile(reaper.GetResourcePath() .. "/Scripts/Perfect-Sound/Core/license.lua")

local ctx = reaper.ImGui_CreateContext('Perfect Sound License')

local user = ""
local pass = ""
local status = "Not activated"
local message = ""

local function loop()

  reaper.ImGui_SetNextWindowSize(ctx, 420, 220, reaper.ImGui_Cond_FirstUseEver())

  local visible, open = reaper.ImGui_Begin(ctx, 'Perfect Sound License', true)

  if visible then

    user = reaper.ImGui_InputText(ctx, 'User', user)
    pass = reaper.ImGui_InputText(ctx, 'Password', pass, reaper.ImGui_InputTextFlags_Password())

    reaper.ImGui_Text(ctx, "HWID: " .. getHWID())

    if reaper.ImGui_Button(ctx, 'ACTIVATE') then

      local response = login(user, pass)

      if hasAccess(response) then
        local token = response:match('"token":"(.-)"')
        saveToken(token)
        status = "Activated"
        message = "License OK"
      else
        status = "Failed"
        message = "Invalid credentials"
      end

    end

    reaper.ImGui_Separator(ctx)

    reaper.ImGui_Text(ctx, "Status: " .. status)
    reaper.ImGui_Text(ctx, message)

    reaper.ImGui_End(ctx)
  end

  if open then
    reaper.defer(loop)
  end
end

reaper.defer(loop)
