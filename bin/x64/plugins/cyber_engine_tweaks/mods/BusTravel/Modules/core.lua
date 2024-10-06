local Bus = require("Modules/bus.lua")
local Event = require("Modules/event.lua")
local UI = require("Modules/ui.lua")
local Utils = require("Tools/utils.lua")

local Core = {}
Core.__index = Core

function Core:New()
    -- instance --
    local obj = {}
    obj.log_obj = Log:New()
    obj.log_obj:SetLevel(LogLevel.Info, "Core")
    obj.event_obj = nil
    obj.bus_obj = nil
    obj.ui_obj = nil
    -- dynamic --
    -- choice action
    obj.is_locked_choice_action = false
    -- auto drive
    obj.is_running_auto_drive = false
    -- npc
    obj.npc_id_list = {}
    obj.npc_tweak_id_list = {}
    -- user setting table
    obj.initial_user_setting_table = {}
    -- language table
    obj.language_file_list = {}
    obj.language_name_list = {}
    obj.translation_table_list = {}

    return setmetatable(obj, self)
end

function Core:Init()

    if BTM.is_ready then
        self.log_obj:Record(LogLevel.Warning, "BTM is already prepared.")
        return
    end

    -- set initial user setting
    self.initial_user_setting_table = Utils:DeepCopy(BTM.user_setting_table)
    self:LoadSetting()
    self:SetTranslationNameList()
    self:StoreTranslationtableList()

    self.bus_obj = Bus:New()

    self.event_obj = Event:New()
    self.event_obj:Init(self.bus_obj)

    self:LoadNPCTweakID()

    self:SetObserve()
    self:SetOverride()

    self.ui_obj = UI:New()
    self.ui_obj:Init()

end

function Core:SetObserve()

    Observe("VehicleMinimapMappinComponent", "OnInitialize", function(this, minimapPOIMappinController, vehicleMappin)
        local vehicle = vehicleMappin:GetVehicle()
        local veh_id = vehicle:GetTDBID()
        local bus_id = TweakDBID.new(BTM.bus_record)
        if veh_id == bus_id then
            self.log_obj:Record(LogLevel.Info, "Bus vehicle detected.")
            self.bus_obj:SetEntity(vehicle)
        end
    end)

    local exception_in_choice_list = Utils:ReadJson("Data/exception_in_choice.json")
    Observe("PlayerPuppet", "OnAction", function(this, action, consumer)
        local action_name = action:GetName(action).value
		local action_type = action:GetType(action).value
        local action_value = action:GetValue(action)

        self.log_obj:Record(LogLevel.Debug, "Action Name: " .. action_name .. " Type: " .. action_type .. " Value: " .. action_value)

        if self.event_obj:GetStatus() == Def.VehicleStatus.PlayerIn and self.event_obj:IsInFrontOfSeat() then
            for _, exception in pairs(exception_in_choice_list) do
                if action_name == exception then
                    consumer:Consume()
                    break
                end
            end
            self:ChoiceAction(action_name, action_type, action_value)
        end
    end)

    Observe("WorkspotGameSystem", "UnmountFromVehicle", function(this, parent, child, instant, posDelta, orientDelta, exitSlotName)
        if parent:GetTDBID() == TweakDBID.new(BTM.bus_record) then
            if child:IsPlayer() then
                Cron.Every(0.5, {tick=1}, function(timer)
                    timer.tick = timer.tick + 1
                    if self.bus_obj:GetDoorState() == Def.DoorEvent.Close then
                        self.bus_obj:ControlDoor(Def.DoorEvent.Open)
                    elseif timer.tick > 10 then
                        timer:Halt()
                    end
                end)
                if self:IsAutoDrive() then
                    self:StopAutoDrive()
                end
            end
        end
    end)

    Observe("VehicleSystem", "SpawnPlayerVehicle", function(this, vehicle_type)
        local record_id = this:GetActivePlayerVehicle(vehicle_type).recordID
        local bus_record_id = TweakDBID.new(BTM.bus_record)
        if record_id.hash == bus_record_id.hash then
            Cron.Every(0.1, {tick=1}, function(timer)
                timer.tick = timer.tick + 1
                if self.bus_obj:IsInWorld() then
                    self:SetNPC()
                    timer:Halt()
                elseif timer.tick > 50 then
                    timer:Halt()
                end
            end)
        end
    end)

end

function Core:SetOverride()

    Override("VehicleObject", "CanUnmount", function(this, isPlayer, mountedObject, checkSpecificDirection, wrapped_method)

        if self.event_obj:GetStatus() == Def.VehicleStatus.Mounted then
            local veh_unmount_pos = vehicleUnmountPosition.new()
            local seat = self.bus_obj:GetPlayerSeat()
            if string.find(seat, "left") then
                veh_unmount_pos.direction = vehicleExitDirection.Left
            elseif string.find(seat, "right") then
                veh_unmount_pos.direction = vehicleExitDirection.Right
            else
                veh_unmount_pos.direction = vehicleExitDirection.NoDirection
            end
            return veh_unmount_pos
        else
            return wrapped_method(this, isPlayer, mountedObject, checkSpecificDirection)
        end
    end)

end

function Core:SetTranslationNameList()

    self.language_file_list = {}
    self.language_name_list = {}

    local files = dir(BTM.language_path)
    local default_file
    local other_files = {}

    for _, file in ipairs(files) do
        if string.match(file.name, 'default.json') then
            default_file = file
        elseif string.match(file.name, '%a%a%-%a%a.json') then
            table.insert(other_files, file)
        end
    end

    if default_file then
        local default_language_table = Utils:ReadJson(BTM.language_path .. "/" .. default_file.name)
        if default_language_table and default_language_table.language then
            table.insert(self.language_file_list, default_file)
            table.insert(self.language_name_list, default_language_table.language)
        end
    else
        self.log_obj:Record(LogLevel.Critical, "Default Language File is not found")
        return
    end

    for _, file in ipairs(other_files) do
        local language_table = Utils:ReadJson(BTM.language_path .. "/" .. file.name)
        if language_table and language_table.language then
            table.insert(self.language_file_list, file)
            table.insert(self.language_name_list, language_table.language)
        end
    end

end

function Core:StoreTranslationtableList()

    self.translation_table_list = {}
    for _, file in ipairs(self.language_file_list) do
        local language_table = Utils:ReadJson(BTM.language_path .. "/" .. file.name)
        if language_table then
            table.insert(self.translation_table_list, language_table)
        end
    end

end

function Core:GetTranslationText(text)

    if self.translation_table_list == {} then
        self.log_obj:Record(LogLevel.Critical, "Language File is invalid")
        return nil
    end
    local translated_text = self.translation_table_list[BTM.user_setting_table.language_index][text]
    if translated_text == nil then
        self.log_obj:Record(LogLevel.Warning, "Translation is not found")
        translated_text = self.translation_table_list[1][text]
        if translated_text == nil then
            self.log_obj:Record(LogLevel.Error, "Translation is not found in default language")
            translated_text = "???"
        end
        return translated_text
    end

    return translated_text

end

function Core:LoadSetting()

    local setting_data = Utils:ReadJson(BTM.user_setting_path)
    if setting_data == nil then
        self.log_obj:Record(LogLevel.Info, "Failed to load setting data. Restore default setting")
        Utils:WriteJson(BTM.user_setting_path, BTM.user_setting_table)
        return
    end
    if setting_data.version == BTM.version then
        BTM.user_setting_table = setting_data
    end

end

function Core:LoadNPCTweakID()
    self.npc_tweak_id_list = Utils:ReadJson("Data/npc_default.json")
end

function Core:IsAutoDrive()
    return self.is_running_auto_drive
end

function Core:ChoiceAction(action_name, action_type, action_value)

    if action_name == "ChoiceApply" and action_type == "BUTTON_PRESSED" and action_value > 0 then
        if self.is_locked_choice_action then
            return
        end
        self.is_locked_choice_action = true
        self:ChoiceSelect(0)
        Cron.After(0.1, function()
            self.is_locked_choice_action = false
        end)

    elseif action_name == "ChoiceScrollUp" and action_type == "BUTTON_PRESSED" and action_value > 0 then
        if self.is_locked_choice_action then
            return
        end
        self.is_locked_choice_action = true
        self:ChoiceSelect(1)
        Cron.After(0.1, function()
            self.is_locked_choice_action = false
        end)

    elseif action_name == "ChoiceScrollDown" and action_type == "BUTTON_PRESSED" and action_value > 0 then
        if self.is_locked_choice_action then
            return
        end
        self.is_locked_choice_action = true
        self:ChoiceSelect(-1)
        Cron.After(0.1, function()
            self.is_locked_choice_action = false
        end)

    end
end

function Core:ChoiceSelect(command)

    local choice_num = self.event_obj.hud_obj.choice_num

    if command == 0 then
        local choice_vari = self.event_obj:GetChoiceVariation()
        if choice_vari == Def.ChoiceVariation.FrontBoth then
            if self.event_obj.hud_obj.selected_choice_index == 0 then
                self.bus_obj:MountPlayer("seat_front_right")
            elseif self.event_obj.hud_obj.selected_choice_index == 1 then
                self.bus_obj:MountPlayer("seat_front_left")
            end
        elseif choice_vari == Def.ChoiceVariation.FrontLeft then
            self.bus_obj:MountPlayer("seat_front_right")
        elseif choice_vari == Def.ChoiceVariation.FrontRight then
            self.bus_obj:MountPlayer("seat_front_left")
        elseif choice_vari == Def.ChoiceVariation.BackBoth then
            if self.event_obj.hud_obj.selected_choice_index == 0 then
                self.bus_obj:MountPlayer("seat_back_left")
            elseif self.event_obj.hud_obj.selected_choice_index == 1 then
                self.bus_obj:MountPlayer("seat_back_right")
            end
        elseif choice_vari == Def.ChoiceVariation.BackLeft then
            self.bus_obj:MountPlayer("seat_back_left")
        elseif choice_vari == Def.ChoiceVariation.BackRight then
            self.bus_obj:MountPlayer("seat_back_right")
        end
    elseif command > 0 then
        if self.event_obj.hud_obj.selected_choice_index < choice_num - 1 then
            self.event_obj.hud_obj.selected_choice_index = self.event_obj.hud_obj.selected_choice_index + 1
        else
            self.event_obj.hud_obj.selected_choice_index = 0
        end
    elseif command < 0 then
        if self.event_obj.hud_obj.selected_choice_index > 0 then
            self.event_obj.hud_obj.selected_choice_index = self.event_obj.hud_obj.selected_choice_index - 1
        else
            self.event_obj.hud_obj.selected_choice_index = choice_num - 1
        end
    end

    self.event_obj.hud_obj:ShowChoice(self.event_obj:GetChoiceVariation())

end

function Core:ConvertPressButtonAction(key)

    local keybind_name = ""
    for _, keybind in ipairs(BTM.user_setting_table.keybind_table) do
        if key == keybind.key or key == keybind.pad then
            keybind_name = keybind.name
            self:ActionKeybind(keybind_name)
            return
        end
    end

end

function Core:ActionKeybind(keybind_name)

    if keybind_name == "auto_drive" then
        if self:IsAutoDrive() then
            self:StopAutoDrive()
        else
            self:RunAutoDrive()
        end
    end

end

function Core:RunAutoDrive()

    if self:IsAutoDrive() then
        self.log_obj:Record(LogLevel.Warning, "Auto drive is already running.")
        return
    end

    if self.event_obj:GetStatus() == Def.VehicleStatus.Mounted then
        self.is_running_auto_drive = true
        self.bus_obj:SoundHorn(0.2)
        self.bus_obj:SendAutoDriveInTrafficEvent()
        Cron.Every(0.1, {tick=1}, function(timer)
            timer.tick = timer.tick + 1
            local veh_speed = self.bus_obj:GetSpeed()
            if veh_speed == 0 then
                self.bus_obj:SendAutoDriveInTrafficEvent()
            elseif not self:IsAutoDrive() then
                self.bus_obj:StopAutoDrive()
                timer:Halt()
            end
        end)
    end
end

function Core:StopAutoDrive()
    self.is_running_auto_drive = false
end

function Core:CreateNPC(npc_id)

    if not self.bus_obj:IsInWorld() then
        self.log_obj:Record(LogLevel.Warning, "Bus is not in the world.")
        return
    end

    local npc_tweak_id_num = #self.npc_tweak_id_list
    local random_index = math.random(1, npc_tweak_id_num)

    local npc_spec = DynamicEntitySpec.new()
    local pos = self.bus_obj:GetEntity():GetWorldPosition()
    pos.z = pos.z + 0.5
    npc_spec.recordID = self.npc_tweak_id_list[random_index]
    npc_spec.appearanceName = "random"
    npc_spec.position = pos
    npc_spec.persistState = true
    npc_spec.persistSpawn = true
    npc_spec.alwaysSpawned = true
    npc_spec.tags = {"BusNPC"}
    self.npc_id_list[npc_id] = Game.GetDynamicEntitySystem():CreateEntity(npc_spec)
end

function Core:SetNPC()

    self:UnsetNPC()
    local total_npc_num = 12
    local create_npc_num = BTM.user_setting_table.ride_npc_num
    if create_npc_num < 0 then
        create_npc_num = math.random(0, total_npc_num)
    end
    local indices = {}

     for i = 1, total_npc_num do
        table.insert(indices, i)
    end

    for i = total_npc_num, 2, -1 do
        local j = math.random(i)
        indices[i], indices[j] = indices[j], indices[i]
    end

    for i = 1, create_npc_num do
        local index = indices[i]
        self:CreateNPC(index)
        Cron.Every(0.1, {tick=1}, function(timer)
            local npc_entity = Game.FindEntityByID(self.npc_id_list[index])
            timer.tick = timer.tick + 1
            if npc_entity ~= nil then
                self.bus_obj:MountNPC(npc_entity, index)
                timer:Halt()
            elseif timer.tick > 20 then
                timer:Halt()
            end
        end)
    end

end

function Core:UnsetNPC()

    local tag_entity_list = Game.GetDynamicEntitySystem():GetTaggedIDs("BusNPC")
    if tag_entity_list == nil then
        return
    end
    for _, entity_id in ipairs(tag_entity_list) do
        Game.GetDynamicEntitySystem():DeleteEntity(entity_id)
    end

end

return Core