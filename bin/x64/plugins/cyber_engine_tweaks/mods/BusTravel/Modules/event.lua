local GameUI = require('External/GameUI.lua')
local HUD = require("Modules/hud.lua")
local Sound = require("Modules/sound.lua")

local Event = {}
Event.__index = Event

function Event:New()
    -- instance --
    local obj = {}
    obj.log_obj = Log:New()
    obj.log_obj:SetLevel(LogLevel.Info, "Event")
    obj.bus_obj = nil
    obj.sound_obj = nil
    obj.hud_obj = nil
    -- static --
    obj.bus_size = { max_x = 1.2, min_x = -1.2, max_y = 5.0, min_y = -3.0, max_z = 1.8, min_z = 0 }
    obj.seat_entry_area_list = {
        { max_x = 0.5, min_x = -0.5, max_y = 4.2, min_y = 3.5, max_z = 1.8, min_z = 0 },
        { max_x = 0.5, min_x = -0.5, max_y = 3.5, min_y = 2.4, max_z = 1.8, min_z = 0 },
        { max_x = 0.5, min_x = -0.5, max_y = -0.2, min_y = -1.2, max_z = 1.8, min_z = 0 }}
    obj.choice_both_angle_large_min = 140
    obj.choice_both_angle_small_max = 40
    obj.door_control_distance = 10
    -- dynamic --
    obj.veh_status = Def.VehicleStatus.NoExistance
    obj.is_in_front_of_seat = false
    obj.choice_variation = Def.ChoiceVariation.None

    return setmetatable(obj, self)

end

function Event:Init(bus_obj)

    if BTM.is_ready then
        self.log_obj:Record(LogLevel.Warning, "BTM is already prepared.")
        return
    end

    self.bus_obj = bus_obj
    self.sound_obj = Sound:New()
    self.hud_obj = HUD:New()

    self:SetObserve()
    self:SetOverride()

    Cron.Every(0.1, {tick=1}, function(timer)
        self:CheckAllEvents()
    end)

end

function Event:SetObserve()

    GameUI.Observe("SessionStart", function()
        self.veh_status = Def.VehicleStatus.NoExistance
    end)

    GameUI.Observe("SessionEnd", function()
        self.sound_obj:ToggleEnterExitSound(true)
    end)

    Observe("InteractionUIBase", "OnInitialize", function(this)
        self.hud_obj.interaction_ui_base = this
    end)

    Observe("InteractionUIBase", "OnDialogsData", function(this)
        self.hud_obj.interaction_ui_base = this
    end)

end

function Event:SetOverride()
    -- Overside choice ui (refer to https://www.nexusmods.com/cyberpunk2077/mods/7299)
    Override("InteractionUIBase", "OnDialogsData", function(_, value, wrapped_method)
        if self:GetStatus() >= Def.VehicleStatus.PlayerIn then
            local data = FromVariant(value)
            local hubs = data.choiceHubs
            table.insert(hubs, self.hud_obj.interaction_hub)
            data.choiceHubs = hubs
            wrapped_method(ToVariant(data))
        else
            wrapped_method(value)
        end
    end)

    Override("InteractionUIBase", "OnDialogsSelectIndex", function(_, index, wrapped_method)
        if self:GetStatus() >= Def.VehicleStatus.PlayerIn then
            wrapped_method(self.hud_obj.selected_choice_index - 1)
        else
            self.hud_obj.selected_choice_index = index + 1
            wrapped_method(index)
        end
    end)

    Override("dialogWidgetGameController", "OnDialogsActivateHub", function(_, id, wrapped_metthod) -- Avoid interaction getting overriden by game
        if self:GetStatus() >= Def.VehicleStatus.PlayerIn then
            local id_
            if self.hud_obj.interaction_hub == nil then
                id_ = id
            else
                id_ = self.hud_obj.interaction_hub.id
            end
            return wrapped_metthod(id_)
        else
            return wrapped_metthod(id)
        end
    end)
end

function Event:CheckAllEvents()

    if self.veh_status == Def.VehicleStatus.NoExistance then
        self:CheckSummonedBus()
    elseif self.veh_status == Def.VehicleStatus.Summoned then
        if not self:CheckSummonedBus() then
            return
        end
        if self:CheckPlayerInBus() then
            return
        end
        self:CheckDoorOpenDistance()
    elseif self.veh_status == Def.VehicleStatus.PlayerIn then
        if not self:CheckPlayerInBus() then
            return
        end
        if self:CheckMountedBus() then
            self.hud_obj:HideChoice()
            return
        end
        self:CheckInFrontOfUserSeat()
    elseif self.veh_status == Def.VehicleStatus.Mounted then
        if not self:CheckMountedBus() then
            return
        end
    end

end

function Event:UpdateVehicleStatus(status)

    if self.veh_status == status then
        self.log_obj:Record(LogLevel.Debug, "Status is not changed.")
    elseif self.veh_status == Def.VehicleStatus.NoExistance then
        if status == Def.VehicleStatus.Summoned then
            self.log_obj:Record(LogLevel.Info, "Status: NoExistance -> Summoned")
            self.veh_status = Def.VehicleStatus.Summoned
        else
            self.log_obj:Record(LogLevel.Critical, "Invalid status in NoExistance.")
        end
    elseif self.veh_status == Def.VehicleStatus.Summoned then
        if status == Def.VehicleStatus.NoExistance then
            self.log_obj:Record(LogLevel.Info, "Status: Summoned -> NoExistance")
            self.veh_status = Def.VehicleStatus.NoExistance
        elseif status == Def.VehicleStatus.PlayerIn then
            self.log_obj:Record(LogLevel.Info, "Status: Summoned -> PlayerIn")
            self.sound_obj:ToggleEnterExitSound(false)
            self.veh_status = Def.VehicleStatus.PlayerIn
        else
            self.log_obj:Record(LogLevel.Critical, "Invalid status in Summoned.")
        end
    elseif self.veh_status == Def.VehicleStatus.PlayerIn then
        if status == Def.VehicleStatus.NoExistance then
            self.log_obj:Record(LogLevel.Info, "Status: PlayerIn -> NoExistance")
            self.veh_status = Def.VehicleStatus.NoExistance
        elseif status == Def.VehicleStatus.Summoned then
            self.log_obj:Record(LogLevel.Info, "Status: PlayerIn -> Summoned")
            self.sound_obj:ToggleEnterExitSound(true)
            self.veh_status = Def.VehicleStatus.Summoned
        elseif status == Def.VehicleStatus.Mounted then
            self.log_obj:Record(LogLevel.Info, "Status: PlayerIn -> Mounted")
            self.veh_status = Def.VehicleStatus.Mounted
        else
            self.log_obj:Record(LogLevel.Critical, "Invalid status in PlayerIn.")
        end
    elseif self.veh_status == Def.VehicleStatus.Mounted then
        if status == Def.VehicleStatus.NoExistance then
            self.log_obj:Record(LogLevel.Info, "Status: Mounted -> NoExistance")
            self.veh_status = Def.VehicleStatus.NoExistance
        elseif status == Def.VehicleStatus.PlayerIn then
            self.log_obj:Record(LogLevel.Info, "Status: Mounted -> PlayerIn")
            self.veh_status = Def.VehicleStatus.PlayerIn
        else
            self.log_obj:Record(LogLevel.Critical, "Invalid status in Mounted.")
        end
    else
        self.log_obj:Record(LogLevel.Critical, "Invalid status.")
    end

end

function Event:GetStatus()
    return self.veh_status
end

function Event:IsInFrontOfSeat()
    return self.is_in_front_of_seat
end

function Event:GetChoiceVariation()
    return self.choice_variation
end

function Event:CheckSummonedBus()

    if self.bus_obj:IsInWorld() then
        self:UpdateVehicleStatus(Def.VehicleStatus.Summoned)
        return true
    else
        self:UpdateVehicleStatus(Def.VehicleStatus.NoExistance)
        return false
    end

end

function Event:CheckPlayerInBus()

    local player_local_pos = self.bus_obj:GetPlayerLocalPosition()
    if player_local_pos.x < self.bus_size.max_x and player_local_pos.x > self.bus_size.min_x
        and player_local_pos.y < self.bus_size.max_y and player_local_pos.y > self.bus_size.min_y
            and player_local_pos.z < self.bus_size.max_z and player_local_pos.z > self.bus_size.min_z then
        self:UpdateVehicleStatus(Def.VehicleStatus.PlayerIn)
        return true
    else
        self:UpdateVehicleStatus(Def.VehicleStatus.Summoned)
        return false
    end

end

function Event:CheckMountedBus()

    local mounted_vehicle = Game.GetPlayer():GetMountedVehicle()
    if mounted_vehicle ~=nil and mounted_vehicle:GetTDBID() == TweakDBID.new(BTM.bus_record) then
        self:UpdateVehicleStatus(Def.VehicleStatus.Mounted)
        return true
    else
        self:UpdateVehicleStatus(Def.VehicleStatus.PlayerIn)
        return false
    end

end

function Event:CheckInFrontOfUserSeat()

    local player_local_pos = self.bus_obj:GetPlayerLocalPosition()
    for index, seat_area in ipairs(self.seat_entry_area_list) do
        if player_local_pos.x < seat_area.max_x and player_local_pos.x > seat_area.min_x
            and player_local_pos.y < seat_area.max_y and player_local_pos.y > seat_area.min_y
                and player_local_pos.z < seat_area.max_z and player_local_pos.z > seat_area.min_z then
            local local_angle = self.bus_obj:GetPlayerLookAngle()
            -- front left seat
            if index == 1 then
                if local_angle > 0 then
                    if self.choice_variation ~= Def.ChoiceVariation.FrontLeft then
                        self.hud_obj:ShowChoice(Def.ChoiceVariation.FrontLeft)
                    end
                    self.choice_variation = Def.ChoiceVariation.FrontLeft
                else
                    self.choice_variation = Def.ChoiceVariation.None
                    self.hud_obj:HideChoice()
                end
            -- front right seat
            elseif index == 2 then
                if local_angle < 0 then
                    if self.choice_variation ~= Def.ChoiceVariation.FrontRight then
                        self.hud_obj:ShowChoice(Def.ChoiceVariation.FrontRight)
                    end
                    self.choice_variation = Def.ChoiceVariation.FrontRight
                else
                    self.choice_variation = Def.ChoiceVariation.None
                    self.hud_obj:HideChoice()
                end
            -- back seats
            elseif index == 3 then
                if math.abs(local_angle) < self.choice_both_angle_small_max or math.abs(local_angle) > self.choice_both_angle_large_min then
                    if self.choice_variation ~= Def.ChoiceVariation.BackBoth then
                        self.hud_obj:ShowChoice(Def.ChoiceVariation.BackBoth)
                    end
                    self.choice_variation = Def.ChoiceVariation.BackBoth
                elseif local_angle > 0 then
                    if self.choice_variation ~= Def.ChoiceVariation.BackLeft then
                        self.hud_obj:ShowChoice(Def.ChoiceVariation.BackLeft)
                    end
                    self.choice_variation = Def.ChoiceVariation.BackLeft
                elseif local_angle < 0 then
                    if self.choice_variation ~= Def.ChoiceVariation.BackRight then
                        self.hud_obj:ShowChoice(Def.ChoiceVariation.BackRight)
                    end
                    self.choice_variation = Def.ChoiceVariation.BackRight
                end
            end
            self.is_in_front_of_seat = true
            return true
        end
    end
    if self.is_in_front_of_seat then
        self.choice_variation = Def.ChoiceVariation.None
        self.hud_obj:HideChoice()
    end
    self.is_in_front_of_seat = false
    return false

end

function Event:CheckDoorOpenDistance()

    local player_world_pos = Game.GetPlayer():GetWorldPosition()
    local bus_world_pos = self.bus_obj.entity:GetWorldPosition()
    local disatnce = Vector4.Distance(player_world_pos, bus_world_pos)
    if disatnce < self.door_control_distance then
        if self.bus_obj:GetDoorState() == Def.DoorEvent.Close then
            self.bus_obj:ControlDoor(Def.DoorEvent.Open)
        end
    else
        if self.bus_obj:GetDoorState() == Def.DoorEvent.Open then
            self.bus_obj:ControlDoor(Def.DoorEvent.Close)
        end
    end

end

return Event