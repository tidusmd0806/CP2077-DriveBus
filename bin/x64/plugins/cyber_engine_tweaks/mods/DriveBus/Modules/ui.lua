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
	if DAB.is_valid_native_settings then
		self:CreateNativeSettingsBasePage()
	end
end

function UI:CreateNativeSettingsBasePage()

	if not DAB.is_valid_native_settings then
		return
	end
	DAB.NativeSettings.addTab("/DAB", DAB.core_obj:GetTranslationText("native_settings_top_title"))
	DAB.NativeSettings.registerRestoreDefaultsCallback("/DAB", true, function()
		print('[DAB][Info] Restore All Settings')
		self:ResetParameters()
		Cron.After(self.delay_updating_native_settings, function()
			self:UpdateNativeSettingsPage()
		end)
	end)
	self:CreateNativeSettingsSubCategory()
	self:CreateNativeSettingsPage()

end

function UI:CreateNativeSettingsSubCategory()

	if not DAB.is_valid_native_settings then
		return
	end
	DAB.NativeSettings.addSubcategory("/DAB/general", DAB.core_obj:GetTranslationText("native_settings_general_subtitle"))
	if self.is_activate_vehicle_switch then
		DAB.NativeSettings.addSubcategory("/DAB/activation", DAB.core_obj:GetTranslationText("native_settings_activation_subtitle"))
	end
	DAB.NativeSettings.addSubcategory("/DAB/keybinds", DAB.core_obj:GetTranslationText("native_settings_keybinds_subtitle"))
	DAB.NativeSettings.addSubcategory("/DAB/controller", DAB.core_obj:GetTranslationText("native_settings_controller_subtitle"))

end

function UI:ClearAllNativeSettingsSubCategory()

	if not DAB.is_valid_native_settings then
		return
	end
	DAB.NativeSettings.removeSubcategory("/DAB/general")
	DAB.NativeSettings.removeSubcategory("/DAB/activation")
	DAB.NativeSettings.removeSubcategory("/DAB/keybinds")
	DAB.NativeSettings.removeSubcategory("/DAB/controller")

end

function UI:CreateNativeSettingsPage()

	if not DAB.is_valid_native_settings then
		return
	end
	self.option_table_list = {}
	local option_table

	-- general
    option_table = DAB.NativeSettings.addSelectorString("/DAB/general", DAB.core_obj:GetTranslationText("native_settings_general_language"), DAB.core_obj:GetTranslationText("native_settings_general_language_description"), DAB.core_obj.language_name_list, DAB.user_setting_table.language_index, 1, function(index)
		DAB.user_setting_table.language_index = index
		Utils:WriteJson(DAB.user_setting_path, DAB.user_setting_table)
		Cron.After(self.delay_updating_native_settings, function()
			self:UpdateNativeSettingsPage()
		end)
	end)
	table.insert(self.option_table_list, option_table)

	option_table = DAB.NativeSettings.addRangeInt("/DAB/general", DAB.core_obj:GetTranslationText("native_settings_general_ride_npc_num"), DAB.core_obj:GetTranslationText("native_settings_general_ride_npc_num_description"), -1, 12, 1, DAB.user_setting_table.ride_npc_num, -1, function(value)
		DAB.user_setting_table.ride_npc_num = value
		Utils:WriteJson(DAB.user_setting_path, DAB.user_setting_table)
		Cron.After(self.delay_updating_native_settings, function()
			self:UpdateNativeSettingsPage()
		end)
	end)
	table.insert(self.option_table_list, option_table)

	option_table = DAB.NativeSettings.addRangeInt("/DAB/general", DAB.core_obj:GetTranslationText("native_settings_general_ride_special_npc_rate"), DAB.core_obj:GetTranslationText("native_settings_general_ride_special_npc_rate_description"), 0, 100, 1, DAB.user_setting_table.ride_special_npc_rate, 5, function(value)
		DAB.user_setting_table.ride_special_npc_rate = value
		Utils:WriteJson(DAB.user_setting_path, DAB.user_setting_table)
		Cron.After(self.delay_updating_native_settings, function()
			self:UpdateNativeSettingsPage()
		end)
	end)
	table.insert(self.option_table_list, option_table)

	option_table = DAB.NativeSettings.addSwitch("/DAB/general", DAB.core_obj:GetTranslationText("native_settings_general_activation"), DAB.core_obj:GetTranslationText("native_settings_general_activation_description"), self.is_activate_vehicle_switch, false, function(state)
		self.is_activate_vehicle_switch = state
		Cron.After(self.delay_updating_native_settings, function()
			self:UpdateNativeSettingsPage()
		end)
	end)
	table.insert(self.option_table_list, option_table)

	-- activation
	if self.is_activate_vehicle_switch then
		local is_activated_bus = Game.GetVehicleSystem():IsVehiclePlayerUnlocked(TweakDBID.new(DAB.bus_record))
		option_table = DAB.NativeSettings.addSwitch("/DAB/activation", DAB.core_obj:GetTranslationText("native_settings_activation_bus"), DAB.core_obj:GetTranslationText("native_settings_activation_bus_description"), is_activated_bus, is_activated_bus, function(state)
			Game.GetVehicleSystem():EnablePlayerVehicle(DAB.bus_record, state, true)
			Cron.After(self.delay_updating_native_settings, function()
				self:UpdateNativeSettingsPage()
			end)
		end)
		table.insert(self.option_table_list, option_table)
	end

	-- keybinds
	local keybind_table = DAB.user_setting_table.keybind_table
	local default_table = DAB.default_keybind_table
	for index, keybind_list in ipairs(keybind_table) do
		if keybind_list.key ~= nil then
			option_table = DAB.NativeSettings.addKeyBinding("/DAB/keybinds", DAB.core_obj:GetTranslationText("native_settings_keybinds_" .. keybind_list.name), DAB.core_obj:GetTranslationText("native_settings_keybinds_" .. keybind_list.name .. "_description"), keybind_list.key, default_table[index].key, keybind_table[index].is_hold, function(key)
				if string.find(key, "IK_Pad") then
					self.log_obj:Record(LogLevel.Warning, "Invalid keybind (no keyboard): " .. key)
				else
					keybind_table[index].key = key
					Utils:WriteJson(DAB.user_setting_path, DAB.user_setting_table)
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
			option_table = DAB.NativeSettings.addKeyBinding("/DAB/controller", DAB.core_obj:GetTranslationText("native_settings_keybinds_" .. keybind_list.name), DAB.core_obj:GetTranslationText("native_settings_keybinds_" .. keybind_list.name .. "_description"), keybind_list.pad, keybind_table[index].pad, keybind_table[index].is_hold, function(pad)
				if not string.find(pad, "IK_Pad") then
					self.log_obj:Record(LogLevel.Warning, "Invalid keybind (no controller): " .. pad)
				else
					keybind_table[index].pad = pad
					Utils:WriteJson(DAB.user_setting_path, DAB.user_setting_table)
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

	if not DAB.is_valid_native_settings then
		return
	end
	for _, option_table in ipairs(self.option_table_list) do
		DAB.NativeSettings.removeOption(option_table)
	end
	self.option_table_list = {}

	self:ClearAllNativeSettingsSubCategory()

end

function UI:UpdateNativeSettingsPage()

	if DAB.core_obj.event_obj.current_situation == -1 then
		self.is_activate_vehicle_switch = false
	end
	self:ClearNativeSettingsPage()
	self:CreateNativeSettingsSubCategory()
	self:CreateNativeSettingsPage()

end

function UI:ResetParameters()

	if not DAB.is_valid_native_settings then
		return
	end
	local favorite_location_list = DAB.user_setting_table.favorite_location_list
	DAB.user_setting_table = Utils:DeepCopy(DAB.core_obj.initial_user_setting_table)
	DAB.user_setting_table.favorite_location_list = favorite_location_list
    Utils:WriteJson(DAB.user_setting_path, DAB.user_setting_table)

end

return UI