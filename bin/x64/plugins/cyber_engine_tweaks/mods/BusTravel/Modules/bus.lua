local Bus = {}
Bus.__index = Bus

function Bus:New()
    -- instance --
    local obj = {}
    obj.log_obj = Log:New()
    obj.log_obj:SetLevel(LogLevel.Info, "Bus")
    -- static --
    obj.player_seat_name_list = {front_left = "seat_front_right", front_right = "seat_front_left", back_left = "seat_back_left", back_right = "seat_back_right"}
    obj.npc_seat_name_list = {"seat_back_left_a", "seat_back_left_b", "seat_back_left_c", "seat_back_left_d",
                          "seat_back_left_e", "seat_back_left_f", "seat_back_left_g", "seat_back_right_a",
                          "seat_back_right_b", "seat_front_right_a", "seat_front_right_b", "seat_front_right_c"}
    -- dynamic --
    obj.entity = nil
    obj.player_seat = "None"

    return setmetatable(obj, self)
end

function Bus:GetEntity()
    return self.entity
end

function Bus:SetEntity(entity)
    self.entity = entity
end

function Bus:IsInWorld()

    if self.entity ~= nil then
        return true
    else
        return false
    end

end

function Bus:GetPlayerLocalPosition()

    if self.entity == nil then
        return Vector4.new(999, 999, 999, 1)
    end

    local bus_world_pos = self.entity:GetWorldPosition()
    local bus_forward_vec = self.entity:GetWorldForward()
    local bus_right_vec = self.entity:GetWorldRight()
    local bus_up_vec = self.entity:GetWorldUp()
    local bus_forward_pos = Vector4.new(bus_world_pos.x + bus_forward_vec.x, bus_world_pos.y + bus_forward_vec.y, bus_world_pos.z + bus_forward_vec.z, bus_world_pos.w)
    local bus_right_pos = Vector4.new(bus_world_pos.x + bus_right_vec.x, bus_world_pos.y + bus_right_vec.y, bus_world_pos.z + bus_right_vec.z, bus_world_pos.w)
    local bus_up_pos = Vector4.new(bus_world_pos.x + bus_up_vec.x, bus_world_pos.y + bus_up_vec.y, bus_world_pos.z + bus_up_vec.z, bus_world_pos.w)
    local player_world_pos = Game.GetPlayer():GetWorldPosition()
    local project_yz_pos = Vector4.ProjectPointToPlane(bus_world_pos, bus_forward_pos, bus_up_pos, player_world_pos)
    local project_xz_pos = Vector4.ProjectPointToPlane(bus_world_pos, bus_right_pos, bus_up_pos, player_world_pos)
    local project_xy_pos = Vector4.ProjectPointToPlane(bus_world_pos, bus_forward_pos, bus_right_pos, player_world_pos)
    local project_local_x_vec = Vector4.new(player_world_pos.x - project_yz_pos.x, player_world_pos.y - project_yz_pos.y, player_world_pos.z - project_yz_pos.z, 1)
    local project_local_y_vec = Vector4.new(player_world_pos.x - project_xz_pos.x, player_world_pos.y - project_xz_pos.y, player_world_pos.z - project_xz_pos.z, 1)
    local project_local_z_vec = Vector4.new(player_world_pos.x - project_xy_pos.x, player_world_pos.y - project_xy_pos.y, player_world_pos.z - project_xy_pos.z, 1)
    local local_x = Vector4.Length(project_local_x_vec)
    local local_y = Vector4.Length(project_local_y_vec)
    local local_z = Vector4.Length(project_local_z_vec)
    if Vector4.Dot(project_local_x_vec, bus_right_vec) < 0 then
        local_x = -local_x
    end
    if Vector4.Dot(project_local_y_vec, bus_forward_vec) < 0 then
        local_y = -local_y
    end
    if Vector4.Dot(project_local_z_vec, bus_up_vec) < 0 then
        local_z = -local_z
    end
    return Vector4.new(local_x, local_y, local_z, 1)

end

function Bus:GetPlayerLookAngle()

    if self.entity == nil then
        return 0
    end

    local bus_world_angle = self.entity:GetWorldOrientation():ToEulerAngles()
    local player_world_angle = Game.GetPlayer():GetWorldOrientation():ToEulerAngles()
    local angle_diff = player_world_angle.yaw - bus_world_angle.yaw
    if angle_diff > 180 then
        angle_diff = angle_diff - 360
    elseif angle_diff < -180 then
        angle_diff = angle_diff + 360
    end

    return angle_diff

end

function Bus:GetPlayerSeat()
    return self.player_seat
end

function Bus:GetDoorState()
    if self.entity == nil then
        return Def.DoorEvent.Unknown
    end
    local vehicle_ps = self.entity:GetVehiclePS()
    local veh_door_state = vehicle_ps:GetDoorState(EVehicleDoor.seat_front_right)
    if veh_door_state == VehicleDoorState.Closed then
        return Def.DoorEvent.Close
    elseif veh_door_state == VehicleDoorState.Open then
        return Def.DoorEvent.Open
    else
        return Def.DoorEvent.Unknown
    end
end

function Bus:GetSpeed()
    if self.entity == nil then
        return 0
    end
    return self.entity:GetCurrentSpeed()
end

function Bus:ControlDoor(door_event)

    if self.entity == nil then
        self.log_obj:Record(LogLevel.Error, "ControlDoor: entity is nil.")
        return false
    end

    local veh_door_event = nil
    if door_event == Def.DoorEvent.Open then
        self.log_obj:Record(LogLevel.Info, "ControlDoor: open door.")
        veh_door_event = VehicleDoorOpen.new()
    elseif door_event == Def.DoorEvent.Close then
        self.log_obj:Record(LogLevel.Info, "ControlDoor: close door.")
        veh_door_event = VehicleDoorClose.new()
    else
        self.log_obj:Record(LogLevel.Error, "ControlDoor: invalid door event.")
        return false
    end

    local vehicle_ps = self.entity:GetVehiclePS()
    veh_door_event.slotID = CName.new("seat_front_right")
    veh_door_event.forceScene = false
    vehicle_ps:QueuePSEvent(vehicle_ps, veh_door_event)

    return true

end

function Bus:MountPlayer(seat)

    if self.entity == nil then
        self.log_obj:Record(LogLevel.Error, "MountPlayer: entity is nil.")
        return
    end

    local player = Game.GetPlayer()
    local ent_id = self.entity:GetEntityID()

    self.player_seat = seat

    local data = MountEventData.new()
    data.isInstant = false
    data.slotName = seat
    data.mountParentEntityId = ent_id

    local slot_id = MountingSlotId.new()
    slot_id.id = seat

    local mounting_info = MountingInfo.new()
    mounting_info.childId = player:GetEntityID()
    mounting_info.parentId = ent_id
    mounting_info.slotId = slot_id

    local mounting_request = MountingRequest.new()
    mounting_request.lowLevelMountingInfo = mounting_info
    mounting_request.mountData = data

    Game.GetMountingFacility():Mount(mounting_request)

end

function Bus:SendAutoDriveInTrafficEvent()

    if self.entity == nil then
        self.log_obj:Record(LogLevel.Error, "SendAutoDriveInTrafficEvent: entity is nil.")
        return
    end

    local evt = vehicleJoinTrafficVehicleEvent.new()
    self.entity:QueueEvent(evt)

end

function Bus:StopAutoDrive()

    if self.entity == nil then
        self.log_obj:Record(LogLevel.Error, "StopAutoDrive: entity is nil.")
        return
    end

    local evt = AICommandEvent.new()
    local cmd = AIVehicleDriveToPointAutonomousCommand.new()
    local player_pos = Game.GetPlayer():GetWorldPosition()
    cmd.targetPosition = Vector4.Vector4To3(player_pos)
    cmd.driveDownTheRoadIndefinitely = false
    cmd.clearTrafficOnPath = true
    cmd.minimumDistanceToTarget = 0
    cmd.maxSpeed = 5
    cmd.minSpeed = 1
    evt.command = cmd

    self.entity:QueueEvent(evt)
    self.entity:ForceBrakesUntilStoppedOrFor(3)

    self:SoundHorn(0.5)

end

function Bus:SoundHorn(time)

    if self.entity == nil then
        self.log_obj:Record(LogLevel.Error, "SoundHorn: entity is nil.")
        return
    end

    local horn_event = VehicleQuestDelayedHornEvent.new()
    horn_event.honkTime = time
    horn_event.delayTime = 0
    self.entity:QueueEvent(horn_event)

end

function Bus:MountNPC(npc_entity, seat_id)

    if self.entity == nil then
        self.log_obj:Record(LogLevel.Error, "MountNPC: entity is nil.")
        return
    elseif npc_entity == nil then
        self.log_obj:Record(LogLevel.Error, "MountNPC: npc_entity is nil.")
        return
    end

    local mount_data = MountEventData.new()
    local mount_event_options = MountEventOptions.new()
    mount_event_options.silentUnmount = false
    mount_event_options.entityID = self.entity:GetEntityID()
    mount_event_options.alive = true
    mount_event_options.occupiedByNeutral = true

    mount_data.mountParentEntityId = self.entity:GetEntityID()
    mount_data.isInstant = true
    mount_data.setEntityVisibleWhenMountFinish = true
    mount_data.removePitchRollRotationOnDismount = false
    mount_data.ignoreHLS = false
    mount_data.mountEventOptions = mount_event_options
    mount_data.slotName = self.npc_seat_name_list[seat_id]
    local cmd = AIMountCommand.new()
    cmd.mountData = mount_data
    npc_entity:GetAIControllerComponent():SendCommand(cmd)

end

return Bus