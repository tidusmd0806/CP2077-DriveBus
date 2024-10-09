--------------------------------------------------------
-- CopyRight (C) 2024, tidusmd. All rights reserved.
-- This mod is under the MIT License.
-- https://opensource.org/licenses/mit-license.php
--------------------------------------------------------

Cron = require("External/Cron.lua")
Def = require("Tools/def.lua")
Log = require("Tools/log.lua")

local Core = require("Modules/core.lua")
local Debug = require("Debug/debug.lua")

BTM = {
	description = "Bus Travel",
	version = "1.0.0",
    -- system
    is_ready = false,
    time_resolution = 0.01,
    is_debug_mode = true,
    -- common
    user_setting_path = "Data/user_setting.json",
    language_path = "Language",
    -- vehicle record
    bus_record = "Vehicle.cs_savable_mahir_mt28_coach_btm",
    -- version check
    cet_required_version = 32.1, -- 1.32.1
    cet_recommended_version = 32.3, -- 1.32.3
    codeware_required_version = 8.2, -- 1.8.2
    codeware_recommended_version = 9.2, -- 1.9.2
    native_settings_required_version = 1.96,
    cet_version_num = 0,
    codeware_version_num = 0,
    native_settings_version_num = 0,
    -- setting
    is_valid_native_settings = false,
    NativeSettings = nil,
    -- input
    axis_dead_zone = 0.1,
    input_key_listener = nil,
    input_axis_listener = nil,
    is_keyboard_input = true,
    listening_keybind_widget = nil,
    default_keybind_table = {
        {name = "auto_drive", key = "IK_G", pad = "IK_Pad_X_SQUARE", is_hold = false},
    }
}

-- initial settings
BTM.user_setting_table = {
    version = BTM.version,
    -- general
    language_index = 1,
    ride_npc_num = -1,
    ride_special_npc_rate = 5,
    -- keybind
    keybind_table = BTM.default_keybind_table,
}

registerForEvent("onHook", function()

    -- refer to Kiroshi Night Vision (https://www.nexusmods.com/cyberpunk2077/mods/8326)
    BTM.input_key_listener = NewProxy({
        OnKeyInput = {
            args = {'handle:KeyInputEvent'},
            callback = function(event)
                local key = event:GetKey().value
                local action = event:GetAction().value
                if key:find("IK_Pad") then
                    BTM.is_keyboard_input = false
                else
                    BTM.is_keyboard_input = true
                end
                if BTM.listening_keybind_widget and key:find("IK_Pad") and action == "IACT_Release" then -- OnKeyBindingEvent has to be called manually for gamepad inputs, while there is a keybind widget listening for input
                    BTM.listening_keybind_widget:OnKeyBindingEvent(KeyBindingEvent.new({keyName = key}))
                    BTM.listening_keybind_widget = nil
                elseif BTM.listening_keybind_widget and action == "IACT_Release" then -- Key was bound, by keyboard
                    BTM.listening_keybind_widget = nil
                end
                local current_status = BTM.core_obj.event_obj:GetStatus() or Def.VehicleStatus.NoExistance
                if current_status == Def.VehicleStatus.Mounted then
                    if action == "IACT_Press" then
                        BTM.core_obj:ConvertPressButtonAction(key)
                    end
                end
            end
        }
    })
    Game.GetCallbackSystem():RegisterCallback('Input/Key', BTM.input_key_listener:Target(), BTM.input_key_listener:Function("OnKeyInput"), true)

    Observe("SettingsSelectorControllerKeyBinding", "ListenForInput", function(this)
        BTM.listening_keybind_widget = this
    end)

    BTM.input_axis_listener = NewProxy({
        OnAxisInput = {
            args = {'handle:AxisInputEvent'},
            callback = function(event)
                local key = event:GetKey().value
                local value = event:GetValue()
                if key:find("IK_Pad") and math.abs(value) > BTM.axis_dead_zone then
                    BTM.is_keyboard_input = false
                else
                    BTM.is_keyboard_input = true
                end
            end
        }
    })
    Game.GetCallbackSystem():RegisterCallback('Input/Axis', BTM.input_axis_listener:Target(), BTM.input_axis_listener:Function("OnAxisInput"), true)

end)

registerForEvent('onInit', function()

    if not BTM:CheckDependencies() then
        print('[BTM][Error] Drive an Aerial Vehicle Mod failed to load due to missing dependencies.')
        return
    end

    BTM:CheckNativeSettings()

    BTM.core_obj = Core:New()
    BTM.debug_obj = Debug:New(nil)

    BTM.core_obj:Init()

    BTM.is_ready = true

    print('[BTM][Info] Finished initializing Drive an Aerial Vehicle Mod.')

end)

registerForEvent("onDraw", function()
    if BTM.is_debug_mode then
        BTM.debug_obj:ImGuiMain()
    end
end)

registerForEvent('onUpdate', function(delta)
    Cron.Update(delta)
end)

registerForEvent('onShutdown', function()
    Game.GetCallbackSystem():UnregisterCallback('Input/Key', BTM.input_key_listener:Target(), BTM.input_key_listener:Function("OnKeyInput"))
    Game.GetCallbackSystem():UnregisterCallback('Input/Axis', BTM.input_axis_listener:Target(), BTM.input_axis_listener:Function("OnAxisInput"))
end)

function BTM:CheckDependencies()

    -- Check Cyber Engine Tweaks Version
    local cet_version_str = GetVersion()
    local cet_version_major, cet_version_minor = cet_version_str:match("1.(%d+)%.*(%d*)")
    BTM.cet_version_num = tonumber(cet_version_major .. "." .. cet_version_minor)

    -- Check CodeWare Version
    local code_version_str = Codeware.Version()
    local code_version_major, code_version_minor = code_version_str:match("1.(%d+)%.*(%d*)")
    BTM.codeware_version_num = tonumber(code_version_major .. "." .. code_version_minor)

    if BTM.cet_version_num < BTM.cet_required_version then
        print("[BTM][Error] requires Cyber Engine Tweaks version 1." .. BTM.cet_required_version .. " or higher.")
        return false
    elseif BTM.codeware_version_num < BTM.codeware_required_version then
        print("[BTM][Error] requires CodeWare version 1." .. BTM.codeware_required_version .. " or higher.")
        return false
    end

    return true

end

function BTM:CheckNativeSettings()

    BTM.NativeSettings = GetMod("nativeSettings")
    if BTM.NativeSettings == nil then
		BTM.is_valid_native_settings = false
        return
	end
    BTM.native_settings_version_num = BTM.NativeSettings.version
    if BTM.NativeSettings.version < BTM.native_settings_required_version then
        BTM.is_valid_native_settings = false
        print("[BTM][Error] requires Native Settings version " .. BTM.native_settings_required_version .. " or higher.")
        return
    end
    BTM.is_valid_native_settings = true

end

function BTM:Version()
    return BTM.version
end

return BTM