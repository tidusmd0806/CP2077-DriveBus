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

DAB = {
	description = "Drive Bus",
	version = "1.1.3",
    -- system
    is_ready = false,
    time_resolution = 0.01,
    is_debug_mode = false,
    -- common
    user_setting_path = "Data/user_setting.json",
    language_path = "Language",
    -- vehicle record
    bus_record = "Vehicle.cs_savable_mahir_mt28_coach_dab",
    bus_appearance = "mahir_mt28_basic_coach_01_dab",
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
        {name = "auto_drive", key = "IK_Z", pad = "IK_Pad_X_SQUARE", is_hold = false},
        {name = "window_toggle", key = "IK_Y", pad = "IK_Pad_DigitLeft", is_hold = false},
    },
    -- other mods
    is_auto_drive_mod = false,
}

-- initial settings
DAB.user_setting_table = {
    version = DAB.version,
    -- general
    language_index = 1,
    ride_npc_num = -1,
    ride_special_npc_rate = 5,
    -- keybind
    keybind_table = DAB.default_keybind_table,
}

registerForEvent("onHook", function()

    -- refer to Kiroshi Night Vision (https://www.nexusmods.com/cyberpunk2077/mods/8326)
    DAB.input_key_listener = NewProxy({
        OnKeyInput = {
            args = {'handle:KeyInputEvent'},
            callback = function(event)
                local key = event:GetKey().value
                local action = event:GetAction().value
                if key:find("IK_Pad") then
                    DAB.is_keyboard_input = false
                else
                    DAB.is_keyboard_input = true
                end
                if DAB.listening_keybind_widget and key:find("IK_Pad") and action == "IACT_Release" then -- OnKeyBindingEvent has to be called manually for gamepad inputs, while there is a keybind widget listening for input
                    DAB.listening_keybind_widget:OnKeyBindingEvent(KeyBindingEvent.new({keyName = key}))
                    DAB.listening_keybind_widget = nil
                elseif DAB.listening_keybind_widget and action == "IACT_Release" then -- Key was bound, by keyboard
                    DAB.listening_keybind_widget = nil
                end
                local current_status = DAB.core_obj.available_event_obj:GetStatus() or Def.VehicleStatus.NoExistance
                if current_status == Def.VehicleStatus.Mounted then
                    if action == "IACT_Press" then
                        DAB.core_obj:ConvertPressButtonAction(key)
                    end
                end
            end
        }
    })
    Game.GetCallbackSystem():RegisterCallback('Input/Key', DAB.input_key_listener:Target(), DAB.input_key_listener:Function("OnKeyInput"), true)

    Observe("SettingsSelectorControllerKeyBinding", "ListenForInput", function(this)
        DAB.listening_keybind_widget = this
    end)

    DAB.input_axis_listener = NewProxy({
        OnAxisInput = {
            args = {'handle:AxisInputEvent'},
            callback = function(event)
                local key = event:GetKey().value
                local value = event:GetValue()
                if key:find("IK_Pad") and math.abs(value) > DAB.axis_dead_zone then
                    DAB.is_keyboard_input = false
                else
                    DAB.is_keyboard_input = true
                end
            end
        }
    })
    Game.GetCallbackSystem():RegisterCallback('Input/Axis', DAB.input_axis_listener:Target(), DAB.input_axis_listener:Function("OnAxisInput"), true)

end)

registerForEvent('onInit', function()

    if not DAB:CheckDependencies() then
        print('[DAB][Error] Drive Bus Mod failed to load due to missing dependencies.')
        return
    end

    DAB:CheckNativeSettings()
    DAB:CheckAutoDriveMod()

    DAB.core_obj = Core:New()
    DAB.debug_obj = Debug:New()

    DAB.core_obj:Init()

    DAB.is_ready = true

    print('[DAB][Info] Finished initializing Drive Bus Mod.')

end)

registerForEvent("onDraw", function()
    if DAB.is_debug_mode then
        DAB.debug_obj:ImGuiMain()
    end
end)

registerForEvent('onUpdate', function(delta)
    Cron.Update(delta)
end)

registerForEvent('onShutdown', function()
    Game.GetCallbackSystem():UnregisterCallback('Input/Key', DAB.input_key_listener:Target(), DAB.input_key_listener:Function("OnKeyInput"))
    Game.GetCallbackSystem():UnregisterCallback('Input/Axis', DAB.input_axis_listener:Target(), DAB.input_axis_listener:Function("OnAxisInput"))
end)

function DAB:CheckDependencies()

    -- Check Cyber Engine Tweaks Version
    local cet_version_str = GetVersion()
    local cet_version_major, cet_version_minor = cet_version_str:match("1.(%d+)%.*(%d*)")
    DAB.cet_version_num = tonumber(cet_version_major .. "." .. cet_version_minor)

    -- Check CodeWare Version
    local code_version_str = Codeware.Version()
    local code_version_major, code_version_minor = code_version_str:match("1.(%d+)%.*(%d*)")
    DAB.codeware_version_num = tonumber(code_version_major .. "." .. code_version_minor)

    if DAB.cet_version_num < DAB.cet_required_version then
        print("[DAB][Error] requires Cyber Engine Tweaks version 1." .. DAB.cet_required_version .. " or higher.")
        return false
    elseif DAB.codeware_version_num < DAB.codeware_required_version then
        print("[DAB][Error] requires CodeWare version 1." .. DAB.codeware_required_version .. " or higher.")
        return false
    end

    return true

end

function DAB:CheckNativeSettings()

    DAB.NativeSettings = GetMod("nativeSettings")
    if DAB.NativeSettings == nil then
		DAB.is_valid_native_settings = false
        return
	end
    DAB.native_settings_version_num = DAB.NativeSettings.version
    if DAB.NativeSettings.version < DAB.native_settings_required_version then
        DAB.is_valid_native_settings = false
        print("[DAB][Error] requires Native Settings version " .. DAB.native_settings_required_version .. " or higher.")
        return
    end
    DAB.is_valid_native_settings = true

end

function DAB:CheckAutoDriveMod()
    if AutoDriveMod_AutoDriveComponent ~= nil then
        DAB.is_auto_drive_mod = true
    end
end

function DAB:Version()
    return DAB.version
end

return DAB