local Sound = {}
Sound.__index = Sound

function Sound:New()
    -- instance --
    local obj = {}
    obj.log_obj = Log:New()
    obj.log_obj:SetLevel(LogLevel.Info, "Sound")
    -- static --
    obj.bus_audio_metadata_name = "v_car_kaukaz_bratsk"
    obj.bus_default_enter_sound = "v_car_kaukaz_bratsk_enter"
    obj.bus_default_exit_sound = "v_car_kaukaz_bratsk_exit"
    obj.bus_defalut_close_sound = "v_car_kaukaz_bratsk_door_close"
    obj.bus_default_open_sound = "v_car_kaukaz_bratsk_door_open"
    -- dynamic --
    obj.bus_audio_metadata = nil
    return setmetatable(obj, self)
end

function Sound:ToggleEnterExitSound(on)

    local depot = Game.GetResourceDepot()
    local token = depot:LoadResource("base\\sound\\metadata\\cooked_metadata.audio_metadata")
    local metadata_list = token:GetResource()
    for _, metadata in pairs(metadata_list.entries) do
        if metadata.name.value == self.bus_audio_metadata_name then
            self.bus_audio_metadata = metadata
            break
        end
    end

    local veh_door_settings = audioVehicleDoorsSettings.new()

    local general_data = self.bus_audio_metadata.generalData
    local veh_door_settings_metadata = general_data.vehicleDoorsSettings
    if on then
        general_data.enterVehicleEvent = CName.new(self.bus_default_enter_sound)
        general_data.exitVehicleEvent = CName.new(self.bus_default_exit_sound)
        veh_door_settings.closeEvent = CName.new(self.bus_defalut_close_sound)
        veh_door_settings.openEvent = CName.new(self.bus_default_open_sound)
    else
        general_data.enterVehicleEvent = CName.new("None")
        general_data.exitVehicleEvent = CName.new("None")
        veh_door_settings.closeEvent = CName.new("None")
        veh_door_settings.openEvent = CName.new("None")
    end

    veh_door_settings_metadata.door = veh_door_settings
    general_data.vehicleDoorsSettings = veh_door_settings_metadata
    self.bus_audio_metadata.generalData = general_data

end

return Sound