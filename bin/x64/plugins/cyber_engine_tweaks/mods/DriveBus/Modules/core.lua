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
    -- common
    obj.available_bus_obj = nil
    obj.available_event_obj = nil
    -- choice action
    obj.is_locked_choice_action = false
    -- auto drive
    obj.is_running_auto_drive = false
    -- npc
    obj.npc_id_list = {}
    obj.npc_default_tweak_id_list = {}
    obj.npc_special_tweak_id_list = {}
    -- user setting table
    obj.initial_user_setting_table = {}
    -- language table
    obj.language_file_list = {}
    obj.language_name_list = {}
    obj.translation_table_list = {}

    return setmetatable(obj, self)
end

function Core:Init()

    if DAB.is_ready then
        self.log_obj:Record(LogLevel.Warning, "DAB is already prepared.")
        return
    end

    -- set initial user setting
    self.initial_user_setting_table = Utils:DeepCopy(DAB.user_setting_table)
    self:LoadSetting()
    self:SetTranslationNameList()
    self:StoreTranslationtableList()

    self.bus_obj = Bus:New()
    self.available_bus_obj = self.bus_obj

    self.event_obj = Event:New()
    self.event_obj:Init(self.bus_obj)
    self.available_event_obj = self.event_obj

    self.community_bus_obj = Bus:New()

    self.community_event_obj = Event:New()
    self.community_event_obj:Init(self.community_bus_obj)

    self:SetObserve()
    self:SetOverride()

    self.ui_obj = UI:New()
    self.ui_obj:Init()

    self:CheckCommunityBus()

end

function Core:SetObserve()

    Observe("VehicleMinimapMappinComponent", "OnInitialize", function(this, minimapPOIMappinController, vehicleMappin)
        local vehicle = vehicleMappin:GetVehicle()
        local veh_id = vehicle:GetTDBID()
        local bus_id = TweakDBID.new(DAB.bus_record)
        if veh_id == bus_id then
            self.log_obj:Record(LogLevel.Info, "Bus vehicle detected.")
            self.bus_obj:SetEntity(vehicle)
        end
    end)

    local exception_in_choice_list = Utils:ReadJson("Data/exception_in_choice.json")
    local exception_in_mount_list = Utils:ReadJson("Data/exception_in_mount.json")
    Observe("PlayerPuppet", "OnAction", function(this, action, consumer)
        local action_name = action:GetName(action).value
		local action_type = action:GetType(action).value
        local action_value = action:GetValue(action)

        self.log_obj:Record(LogLevel.Debug, "Action Name: " .. action_name .. " Type: " .. action_type .. " Value: " .. action_value)

        local veh_status = self.available_event_obj:GetStatus()
        local is_in_front_of_seat = self.available_event_obj:IsInFrontOfSeat()
        if veh_status == Def.VehicleStatus.PlayerIn and is_in_front_of_seat then
            for _, exception in pairs(exception_in_choice_list) do
                if action_name == exception then
                    consumer:Consume()
                    break
                end
            end
            self:ChoiceAction(action_name, action_type, action_value)
        end
        if veh_status == Def.VehicleStatus.Mounted then
            for _, exception in pairs(exception_in_mount_list) do
                if action_name == exception then
                    consumer:Consume()
                    break
                end
            end
        end
    end)

    Observe("WorkspotGameSystem", "UnmountFromVehicle", function(this, parent, child, instant, posDelta, orientDelta, exitSlotName)
        if parent ~= nil and parent:GetCurrentAppearanceName().value == DAB.bus_appearance then
            if child:IsPlayer() then
                Cron.Every(0.5, {tick=1}, function(timer)
                    timer.tick = timer.tick + 1
                    if self.available_bus_obj:GetDoorState() == Def.DoorEvent.Close then
                        self.available_bus_obj:ControlDoor(Def.DoorEvent.Open)
                    elseif timer.tick > 10 then
                        timer:Halt()
                    end
                end)
                if self:IsAutoDrive() then
                    self:StopAutoDrive()
                end
                local blink_time = 0.8
                if child:IsInCombat() and self.available_bus_obj.player_seat == "seat_front_left" then
                    blink_time = 0.2
                end
                Cron.After(blink_time, function()
                    GameObjectEffectHelper.StartEffectEvent(Game.GetPlayer(), "eyes_closed_loop", true, worldEffectBlackboard.new())
                    Cron.After(blink_time, function()
                        GameObjectEffectHelper.StopEffectEvent(Game.GetPlayer(), "eyes_closed_loop")
                        GameObjectEffectHelper.StartEffectEvent(Game.GetPlayer(), "eyes_opening_05s", true, worldEffectBlackboard.new())
                    end)
                end)
            end
        end
    end)

    Observe("VehicleSystem", "SpawnPlayerVehicle", function(this, vehicle_type)
        local record_id = this:GetActivePlayerVehicle(vehicle_type).recordID
        local bus_record_id = TweakDBID.new(DAB.bus_record)
        if record_id.hash == bus_record_id.hash then
            Cron.Every(0.1, {tick=1}, function(timer)
                timer.tick = timer.tick + 1
                if self.bus_obj:IsInWorld() then
                    self:SetNPC(true, true)
                    timer:Halt()
                elseif timer.tick > 50 then
                    timer:Halt()
                end
            end)
            local is_coming = false
            Cron.Every(0.1, {tick=1}, function(timer)
                timer.tick = timer.tick + 1
                if self.bus_obj:GetSpeed() == 0 and is_coming then
                    self.bus_obj:SendAutoDriveToHereEvent()
                    timer:Halt()
                elseif  self.bus_obj:GetSpeed() > 0 and not is_coming then
                    is_coming = true
                elseif timer.tick > 100 then
                    timer:Halt()
                end
            end)
        end
    end)

end

function Core:SetOverride()

    Override("VehicleObject", "CanUnmount", function(this, isPlayer, mountedObject, checkSpecificDirection, wrapped_method)

        if self.available_event_obj:GetStatus() == Def.VehicleStatus.Mounted then
            local veh_unmount_pos = vehicleUnmountPosition.new()
            local seat = self.available_bus_obj:GetPlayerSeat()
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

    Override("VehicleObject", "TriggerDrivingPanicBehavior", function(this, threatPosition, wrapped_method)
        local veh_id = this:GetTDBID()
        local veh_app = this:GetCurrentAppearanceName().value
        -- if veh_id == TweakDBID.new(DAB.bus_record) then
        if veh_app == DAB.bus_appearance then
            self.log_obj:Record(LogLevel.Trace, "Panic Driving is disabled.")
            return false
        else
            return wrapped_method(threatPosition)
        end
    end)

    -- This is Method added Auto Drive Mod(https://www.nexusmods.com/cyberpunk2077/mods/14680)
    if DAB.is_auto_drive_mod then
        Override("VehicleObject", "CanAutoDrive", function(this, wrapped_method)
            if self:IsAutoDrive() then
                return false
            else
                return wrapped_method()
            end
        end)
    end

    Override("ExitFromVehicle", "Activate", function(this, context, wrapped_method)
        local puppet = context:GetOwner()
        local puppet_id = puppet:GetEntityID()
        local tag_persist_entity_list = Game.GetDynamicEntitySystem():GetTaggedIDs("BusNPC_persist")
        if #tag_persist_entity_list ~= 0 then
            for _, entity_id in ipairs(tag_persist_entity_list) do
                if entity_id.hash == puppet_id.hash then
                    return
                end
            end
        end
        local tag_temp_entity_list = Game.GetDynamicEntitySystem():GetTaggedIDs("BusNPC_temp")
        if #tag_temp_entity_list ~= 0 then
            for _, entity_id in ipairs(tag_temp_entity_list) do
                if entity_id.hash == puppet_id.hash then
                    return
                end
            end
        end
        wrapped_method(context)
    end)

end

function Core:SetTranslationNameList()

    self.language_file_list = {}
    self.language_name_list = {}

    local files = dir(DAB.language_path)
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
        local default_language_table = Utils:ReadJson(DAB.language_path .. "/" .. default_file.name)
        if default_language_table and default_language_table.language then
            table.insert(self.language_file_list, default_file)
            table.insert(self.language_name_list, default_language_table.language)
        end
    else
        self.log_obj:Record(LogLevel.Critical, "Default Language File is not found")
        return
    end

    for _, file in ipairs(other_files) do
        local language_table = Utils:ReadJson(DAB.language_path .. "/" .. file.name)
        if language_table and language_table.language then
            table.insert(self.language_file_list, file)
            table.insert(self.language_name_list, language_table.language)
        end
    end

end

function Core:StoreTranslationtableList()

    self.translation_table_list = {}
    for _, file in ipairs(self.language_file_list) do
        local language_table = Utils:ReadJson(DAB.language_path .. "/" .. file.name)
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
    local translated_text = self.translation_table_list[DAB.user_setting_table.language_index][text]
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

    local setting_data = Utils:ReadJson(DAB.user_setting_path)
    if setting_data == nil then
        self.log_obj:Record(LogLevel.Info, "Failed to load setting data. Restore default setting")
        Utils:WriteJson(DAB.user_setting_path, DAB.user_setting_table)
        return
    end
    if setting_data.version == DAB.version then
        DAB.user_setting_table = setting_data
    end

end

function Core:LoadNPCTweakID()
    self.npc_default_tweak_id_list = Utils:ReadJson("Data/npc_default.json")
    self.npc_special_tweak_id_list = Utils:ReadJson("Data/npc_special.json")
end

function Core:IsAutoDrive()
    return self.is_running_auto_drive
end

-- This is Method added Auto Drive Mod(https://www.nexusmods.com/cyberpunk2077/mods/14680)
function Core:IsAutoDriveByOtherMod()
    if DAB.is_auto_drive_mod and self.available_bus_obj:IsInWorld() then
        local auto_drive_component = self.available_bus_obj.entity:GetAutoDriveComponent()
        return auto_drive_component:IsAutoDriving()
    end
    return false
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

    local choice_num = self.available_event_obj.hud_obj.choice_num

    if command == 0 then
        local choice_vari = self.available_event_obj:GetChoiceVariation()
        if choice_vari == Def.ChoiceVariation.FrontBoth then
            if self.available_event_obj.hud_obj.selected_choice_index == 0 then
                self.available_bus_obj:MountPlayer(self.available_bus_obj.player_seat_name_list["front_left"])
            elseif self.available_event_obj.hud_obj.selected_choice_index == 1 then
                self.available_bus_obj:MountPlayer(self.available_bus_obj.player_seat_name_list["front_right"])
            end
        elseif choice_vari == Def.ChoiceVariation.FrontLeft then
            self.available_bus_obj:MountPlayer(self.available_bus_obj.player_seat_name_list["front_left"])
        elseif choice_vari == Def.ChoiceVariation.FrontRight then
            self.available_bus_obj:MountPlayer(self.available_bus_obj.player_seat_name_list["front_right"])
        elseif choice_vari == Def.ChoiceVariation.BackBoth then
            if self.available_event_obj.hud_obj.selected_choice_index == 0 then
                self.available_bus_obj:MountPlayer(self.available_bus_obj.player_seat_name_list["back_left"])
            elseif self.available_event_obj.hud_obj.selected_choice_index == 1 then
                self.available_bus_obj:MountPlayer(self.available_bus_obj.player_seat_name_list["back_right"])
            end
        elseif choice_vari == Def.ChoiceVariation.BackLeft then
            self.available_bus_obj:MountPlayer(self.available_bus_obj.player_seat_name_list["back_left"])
        elseif choice_vari == Def.ChoiceVariation.BackRight then
            self.available_bus_obj:MountPlayer(self.available_bus_obj.player_seat_name_list["back_right"])
        end
    elseif command > 0 then
        self.available_event_obj.hud_obj.selected_choice_index = self.available_event_obj.hud_obj.selected_choice_index + 1
    elseif command < 0 then
        self.available_event_obj.hud_obj.selected_choice_index = self.available_event_obj.hud_obj.selected_choice_index - 1
    end
    if self.available_event_obj.hud_obj.selected_choice_index < 0 then
        self.available_event_obj.hud_obj.selected_choice_index = choice_num - 1
    elseif self.available_event_obj.hud_obj.selected_choice_index >= choice_num then
        self.available_event_obj.hud_obj.selected_choice_index = 0
    end

    self.available_event_obj.hud_obj:ShowChoice(self.available_event_obj:GetChoiceVariation())

end

function Core:ConvertPressButtonAction(key)

    local keybind_name = ""
    for _, keybind in ipairs(DAB.user_setting_table.keybind_table) do
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
    elseif keybind_name == "window_toggle" then
        self.available_bus_obj:ControlWindow(Def.WindowEvent.Change)
    end

end

function Core:RunAutoDrive()

    if self:IsAutoDrive() then
        self.log_obj:Record(LogLevel.Warning, "Auto drive is already running.")
        return
    end

    if self:IsAutoDriveByOtherMod() then
        self.log_obj:Record(LogLevel.Info, "Auto drive is already running by other mod.")
        return
    end

    if self.available_event_obj:GetStatus() == Def.VehicleStatus.Mounted then
        self.is_running_auto_drive = true
        self.available_bus_obj:SoundHorn(0.2)
        self.available_bus_obj:SendAutoDriveInTrafficEvent()
        Cron.Every(0.1, {tick=1}, function(timer)
            timer.tick = timer.tick + 1
            local veh_speed = self.available_bus_obj:GetSpeed()
            if veh_speed == 0 then
                self.available_bus_obj:SendAutoDriveInTrafficEvent()
            elseif not self:IsAutoDrive() then
                self.available_bus_obj:StopAutoDrive()
                timer:Halt()
            end
        end)
    end
end

function Core:StopAutoDrive()
    self.log_obj:Record(LogLevel.Info, "Auto drive is stopped.")
    self.is_running_auto_drive = false
end

function Core:CreateNPC(npc_id, is_persist)

    if not self.available_bus_obj:IsInWorld() then
        self.log_obj:Record(LogLevel.Warning, "Bus is not in the world.")
        return
    end

    local random_value = math.random(1, 100)
    local main_character_spawn_rate = DAB.user_setting_table.ride_special_npc_rate

    local npc_tweak_id_num = #self.npc_default_tweak_id_list
    local random_index = math.random(1, npc_tweak_id_num)
    local npc_record_id = self.npc_default_tweak_id_list[random_index]
    local npc_special_tweak_id_info = {id = npc_record_id, appearance = {"random"}}

    if random_value <= main_character_spawn_rate and #self.npc_special_tweak_id_list ~= 0 then
        local npc_tweak_id_num = #self.npc_special_tweak_id_list
        local random_index = math.random(1, npc_tweak_id_num)
        npc_special_tweak_id_info = self.npc_special_tweak_id_list[random_index]
        table.remove(self.npc_special_tweak_id_list, random_index)
    end

    self.log_obj:Record(LogLevel.Trace, "Spawn NPC: " .. npc_record_id .. "/ id: " .. npc_id)

    local npc_spec = DynamicEntitySpec.new()
    local pos = self.available_bus_obj:GetEntity():GetWorldPosition()
    pos.z = pos.z - 5.5
    npc_spec.recordID = npc_special_tweak_id_info.id
    local random_value_for_app = math.random(1, #npc_special_tweak_id_info.appearance)
    npc_spec.appearanceName = npc_special_tweak_id_info.appearance[random_value_for_app]
    npc_spec.position = pos
    npc_spec.persistState = is_persist
    npc_spec.persistSpawn = is_persist
    npc_spec.alwaysSpawned = true
    if is_persist then
        npc_spec.tags = {"BusNPC_persist"}
    else
        npc_spec.tags = {"BusNPC_temp"}
    end
    self.npc_id_list[npc_id] = Game.GetDynamicEntitySystem():CreateEntity(npc_spec)
end

function Core:SetNPC(is_persist, is_unset)

    self:LoadNPCTweakID()

    if is_unset then
        self:UnsetNPC(is_persist)
    end
    local total_npc_num = 12
    local create_npc_num = DAB.user_setting_table.ride_npc_num
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
        self:CreateNPC(index, is_persist)
        Cron.Every(0.1, {tick=1}, function(timer)
            local npc_entity = Game.FindEntityByID(self.npc_id_list[index])
            timer.tick = timer.tick + 1
            if npc_entity ~= nil then
                self.available_bus_obj:MountNPC(npc_entity, index)
                timer:Halt()
            elseif timer.tick > 20 then
                timer:Halt()
            end
        end)
    end

end

function Core:UnsetNPC(is_persist)

    local tag_entity_list = {}
    if is_persist then
        tag_entity_list = Game.GetDynamicEntitySystem():GetTaggedIDs("BusNPC_persist")
    else
        tag_entity_list = Game.GetDynamicEntitySystem():GetTaggedIDs("BusNPC_temp")
    end

    if #tag_entity_list == 0 then
        return
    end
    for _, entity_id in ipairs(tag_entity_list) do
        Game.GetDynamicEntitySystem():DeleteEntity(entity_id)
    end

end

function Core:CheckCommunityBus()

    Cron.Every(0.1, {tick=1}, function(timer)
        timer.tick = timer.tick + 1
        self:SetLookAtCommunityBus()
        if self.community_bus_obj:GetEntity() ~= nil then
            if self.community_bus_obj:GetDoorState() == Def.DoorEvent.Open and self.community_event_obj:GetStatus() < Def.VehicleStatus.Mounted then
                self.community_bus_obj:GetEntity():ForceBrakesUntilStoppedOrFor(0.1)
            elseif self.community_bus_obj:GetSpeed() == 0 and self.community_event_obj:GetStatus() < Def.VehicleStatus.PlayerIn then
                self.community_bus_obj:SendAutoDriveInTrafficEvent()
            end
        end
    end)

end

function Core:SetLookAtCommunityBus()

    if self.community_event_obj:GetStatus() == Def.VehicleStatus.Mounted then
        return true
    end
    local player = Game.GetPlayer()
    if player == nil then
        return false
    end
    local look_at_obj = Game.GetTargetingSystem():GetLookAtObject(player)
    if look_at_obj ~= nil and look_at_obj:GetCurrentAppearanceName().value == DAB.bus_appearance then
        local player_bus = self.bus_obj:GetEntity()
        if player_bus ~= nil and player_bus:GetEntityID().hash ~= look_at_obj:GetEntityID().hash or player_bus == nil then
            self.community_bus_obj:SetEntity(look_at_obj)
            self.available_bus_obj =  self.community_bus_obj
            self.available_event_obj = self.community_event_obj
            local driver = VehicleComponent.GetDriverMounted(self.community_bus_obj:GetEntity():GetEntityID())
            if driver ~= nil then
                self.community_bus_obj:UnmountNPC(driver, 1)
                self:SetNPC(false, false)
            end
            return true
        else
            self.available_bus_obj =  self.bus_obj
            self.available_event_obj = self.event_obj
            return true
        end
    else
        self.available_bus_obj =  self.bus_obj
        self.available_event_obj = self.event_obj
        return false
    end

end

return Core