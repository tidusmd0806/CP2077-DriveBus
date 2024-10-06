local Utils = require("Tools/utils.lua")
local UI = {}
UI.__index = UI

function UI:New()
	-- instance --
    local obj = {}
    obj.log_obj = Log:New()
    obj.log_obj:SetLevel(LogLevel.Info, "UI")
	-- static --
	-- record name
    obj.dummy_vehicle_record = "Vehicle.av_dav_dummy"
	obj.delay_updating_native_settings = 0.1
	-- dynamic --
	-- common
	obj.av_obj = nil
	obj.dummy_av_record = nil
	obj.av_record_list = {}
	-- auto pilot setting
	obj.selected_auto_pilot_history_index = 1
	obj.selected_auto_pilot_history_name = ""
	obj.history_list = {}
	-- autopilot setting popup
	obj.ui_game_menu_controller = nil
	obj.autopilot_popup_obj = nil
	obj.current_position_name = ""
	-- native settings page
	obj.option_table_list = {}
	obj.is_activate_vehicle_switch = false
	obj.selected_flight_mode_index = 1
    return setmetatable(obj, self)
end

function UI:Init()
	if BTM.is_valid_native_settings then
		self:CreateNativeSettingsBasePage()
	end
end

function UI:CreateNativeSettingsBasePage()

	if not BTM.is_valid_native_settings then
		return
	end
	BTM.NativeSettings.addTab("/BTM", BTM.core_obj:GetTranslationText("native_settings_top_title"))
	BTM.NativeSettings.registerRestoreDefaultsCallback("/BTM", true, function()
		print('[BTM][Info] Restore All Settings')
		self:ResetParameters()
		Cron.After(self.delay_updating_native_settings, function()
			self:UpdateNativeSettingsPage()
		end)
	end)
	self:CreateNativeSettingsSubCategory()
	self:CreateNativeSettingsPage()

end

function UI:CreateNativeSettingsSubCategory()

	if not BTM.is_valid_native_settings then
		return
	end
	BTM.NativeSettings.addSubcategory("/BTM/general", BTM.core_obj:GetTranslationText("native_settings_general_subtitle"))
	if self.is_activate_vehicle_switch then
		BTM.NativeSettings.addSubcategory("/BTM/activation", BTM.core_obj:GetTranslationText("native_settings_activation_subtitle"))
	end
	BTM.NativeSettings.addSubcategory("/BTM/keybinds", BTM.core_obj:GetTranslationText("native_settings_keybinds_subtitle"))
	BTM.NativeSettings.addSubcategory("/BTM/controller", BTM.core_obj:GetTranslationText("native_settings_controller_subtitle"))

end

function UI:ClearAllNativeSettingsSubCategory()

	if not BTM.is_valid_native_settings then
		return
	end
	BTM.NativeSettings.removeSubcategory("/BTM/general")
	BTM.NativeSettings.removeSubcategory("/BTM/activation")
	BTM.NativeSettings.removeSubcategory("/BTM/keybinds")
	BTM.NativeSettings.removeSubcategory("/BTM/controller")

end

function UI:CreateNativeSettingsPage()

	if not BTM.is_valid_native_settings then
		return
	end
	self.option_table_list = {}
	local option_table

	-- general
    option_table = BTM.NativeSettings.addSelectorString("/BTM/general", BTM.core_obj:GetTranslationText("native_settings_general_language"), BTM.core_obj:GetTranslationText("native_settings_general_language_description"), BTM.core_obj.language_name_list, BTM.user_setting_table.language_index, 1, function(index)
		BTM.user_setting_table.language_index = index
		Utils:WriteJson(BTM.user_setting_path, BTM.user_setting_table)
		Cron.After(self.delay_updating_native_settings, function()
			self:UpdateNativeSettingsPage()
		end)
	end)
	table.insert(self.option_table_list, option_table)

	option_table = BTM.NativeSettings.addRangeInt("/BTM/general", BTM.core_obj:GetTranslationText("native_settings_general_ride_npc_num"), BTM.core_obj:GetTranslationText("native_settings_general_ride_npc_num_description"), -1, 12, 1, BTM.user_setting_table.ride_npc_num, 12, function(value)
		BTM.user_setting_table.ride_npc_num = value
		Utils:WriteJson(BTM.user_setting_path, BTM.user_setting_table)
		Cron.After(self.delay_updating_native_settings, function()
			self:UpdateNativeSettingsPage()
		end)
	end)
	table.insert(self.option_table_list, option_table)

	option_table = BTM.NativeSettings.addSwitch("/BTM/general", BTM.core_obj:GetTranslationText("native_settings_general_activation"), BTM.core_obj:GetTranslationText("native_settings_general_activation_description"), self.is_activate_vehicle_switch, false, function(state)
		self.is_activate_vehicle_switch = state
		Cron.After(self.delay_updating_native_settings, function()
			self:UpdateNativeSettingsPage()
		end)
	end)
	table.insert(self.option_table_list, option_table)

	-- activation
	if self.is_activate_vehicle_switch then
		local is_activated_bus = Game.GetVehicleSystem():IsVehiclePlayerUnlocked(TweakDBID.new(BTM.bus_record))
		option_table = BTM.NativeSettings.addSwitch("/BTM/activation", BTM.core_obj:GetTranslationText("native_settings_activation_bus"), BTM.core_obj:GetTranslationText("native_settings_activation_bus_description"), is_activated_bus, is_activated_bus, function(state)
			Game.GetVehicleSystem():EnablePlayerVehicle(BTM.bus_record, state, true)
			Cron.After(self.delay_updating_native_settings, function()
				self:UpdateNativeSettingsPage()
			end)
		end)
		table.insert(self.option_table_list, option_table)
	end

	-- keybinds
	local keybind_table = BTM.user_setting_table.keybind_table
	local default_table = BTM.default_keybind_table
	for index, keybind_list in ipairs(keybind_table) do
		if keybind_list.key ~= nil then
			option_table = BTM.NativeSettings.addKeyBinding("/BTM/keybinds", BTM.core_obj:GetTranslationText("native_settings_keybinds_" .. keybind_list.name), BTM.core_obj:GetTranslationText("native_settings_keybinds_" .. keybind_list.name .. "_description"), keybind_list.key, default_table[index].key, keybind_table[index].is_hold, function(key)
				if string.find(key, "IK_Pad") then
					self.log_obj:Record(LogLevel.Warning, "Invalid keybind (no keyboard): " .. key)
				else
					keybind_table[index].key = key
					Utils:WriteJson(BTM.user_setting_path, BTM.user_setting_table)
				end
				Cron.After(self.delay_updating_native_settings, function()
					self:UpdateNativeSettingsPage()
				end)
			end)
			table.insert(self.option_table_list, option_table)
		end
	end

	for index, keybind_list in ipairs(keybind_table) do
		if keybind_list.pad ~= nil then
			option_table = BTM.NativeSettings.addKeyBinding("/BTM/controller", BTM.core_obj:GetTranslationText("native_settings_keybinds_" .. keybind_list.name), BTM.core_obj:GetTranslationText("native_settings_keybinds_" .. keybind_list.name .. "_description"), keybind_list.pad, keybind_table[index].pad, keybind_table[index].is_hold, function(pad)
				if not string.find(pad, "IK_Pad") then
					self.log_obj:Record(LogLevel.Warning, "Invalid keybind (no controller): " .. pad)
				else
					keybind_table[index].pad = pad
					Utils:WriteJson(BTM.user_setting_path, BTM.user_setting_table)
				end
				Cron.After(self.delay_updating_native_settings, function()
					self:UpdateNativeSettingsPage()
				end)
			end)
			table.insert(self.option_table_list, option_table)
		end
	end

end

function UI:ClearNativeSettingsPage()

	if not BTM.is_valid_native_settings then
		return
	end
	for _, option_table in ipairs(self.option_table_list) do
		BTM.NativeSettings.removeOption(option_table)
	end
	self.option_table_list = {}

	self:ClearAllNativeSettingsSubCategory()

end

function UI:UpdateNativeSettingsPage()

	if BTM.core_obj.event_obj.current_situation == -1 then
		self.is_activate_vehicle_switch = false
	end
	self:ClearNativeSettingsPage()
	self:CreateNativeSettingsSubCategory()
	self:CreateNativeSettingsPage()

end

function UI:ResetParameters()

	if not BTM.is_valid_native_settings then
		return
	end
	local favorite_location_list = BTM.user_setting_table.favorite_location_list
	BTM.user_setting_table = Utils:DeepCopy(BTM.core_obj.initial_user_setting_table)
	BTM.user_setting_table.favorite_location_list = favorite_location_list
    Utils:WriteJson(BTM.user_setting_path, BTM.user_setting_table)

end

return UI