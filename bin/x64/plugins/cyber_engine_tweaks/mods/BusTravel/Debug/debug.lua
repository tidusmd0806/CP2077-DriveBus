local Utils = require("Tools/utils.lua")
local Debug = {}
Debug.__index = Debug

function Debug:New(core_obj)
    local obj = {}
    obj.core_obj = core_obj

    -- set parameters
    obj.is_set_observer = false
    obj.is_im_gui_rw_count = false
    obj.is_im_gui_input_check = false
    obj.is_im_gui_player_position = false
    obj.is_im_gui_bus_position = false
    obj.is_im_gui_bus_info = false
    obj.is_im_gui_measurement = false

    return setmetatable(obj, self)
end

function Debug:ImGuiMain()

    ImGui.Begin("BTM DEBUG WINDOW")
    ImGui.Text("Version : " .. BTM.version)

    self:SetObserver()
    self:SetLogLevel()
    self:SelectPrintDebug()
    self:ImGuiShowRWCount()
    self:ImGuiInputCheck()
    self:ImGuiPlayerPosition()
    self:ImGuiBusPosition()
    self:BusInfo()
    self:ImGuiMeasurement()
    self:ImGuiExcuteFunction()

    ImGui.End()

end

function Debug:SetObserver()

    if not self.is_set_observer then
        -- reserved
    end
    self.is_set_observer = true

    if self.is_set_observer then
        ImGui.Text("Observer : On")
    end

end

function Debug:SetLogLevel()
    local selected = false
    if ImGui.BeginCombo("LogLevel", Utils:GetKeyFromValue(LogLevel, MasterLogLevel)) then
		for _, key in ipairs(Utils:GetKeys(LogLevel)) do
			if Utils:GetKeyFromValue(LogLevel, MasterLogLevel) == key then
				selected = true
			else
				selected = false
			end
			if(ImGui.Selectable(key, selected)) then
				MasterLogLevel = LogLevel[key]
			end
		end
		ImGui.EndCombo()
	end
end

function Debug:SelectPrintDebug()
    PrintDebugMode = ImGui.Checkbox("Print Debug Mode", PrintDebugMode)
end

function Debug:ImGuiShowRWCount()
    self.is_im_gui_rw_count = ImGui.Checkbox("[ImGui] R/W Count", self.is_im_gui_rw_count)
    if self.is_im_gui_rw_count then
        ImGui.Text("Read : " .. READ_COUNT .. ", Write : " .. WRITE_COUNT)
    end
end

function Debug:ImGuiInputCheck()
    self.is_im_gui_input_check = ImGui.Checkbox("[ImGui] Input Check", self.is_im_gui_input_check)
    if self.is_im_gui_input_check then
        if BTM.is_keyboard_input then
            ImGui.Text("Keyboard : On")
        else
            ImGui.Text("Keyboard : Off")
        end
    end
end

function Debug:ImGuiPlayerPosition()
    self.is_im_gui_player_position = ImGui.Checkbox("[ImGui] Player Position Angle", self.is_im_gui_player_position)
    if self.is_im_gui_player_position then
        local pos = Game.GetPlayer():GetWorldPosition()
        local x = string.format("%.2f", pos.x)
        local y = string.format("%.2f", pos.y)
        local z = string.format("%.2f", pos.z)
        ImGui.Text("[world]X:" .. x .. ", Y:" .. y .. ", Z:" .. z)
        local angle = Game.GetPlayer():GetWorldOrientation():ToEulerAngles()
        local roll = string.format("%.2f", angle.roll)
        local pitch = string.format("%.2f", angle.pitch)
        local yaw = string.format("%.2f", angle.yaw)
        ImGui.Text("[world]Roll:" .. roll .. ", Pitch:" .. pitch .. ", Yaw:" .. yaw)
        if BTM.core_obj.bus_obj.entity == nil then
            return
        end
        local bus_local_pos = BTM.core_obj.bus_obj:GetPlayerLocalPosition()
        local local_x = string.format("%.2f", bus_local_pos.x)
        local local_y = string.format("%.2f", bus_local_pos.y)
        local local_z = string.format("%.2f", bus_local_pos.z)
        ImGui.Text("[local]X:" .. local_x .. ", Y:" .. local_y .. ", Z:" .. local_z)
        local bus_angle = BTM.core_obj.bus_obj:GetPlayerLookAngle()
        local bus_yaw = string.format("%.2f", bus_angle)
        ImGui.Text("[local]Yaw:" .. bus_yaw)
    end
end

function Debug:ImGuiBusPosition()
    self.is_im_gui_bus_position = ImGui.Checkbox("[ImGui] Bus Position Angle", self.is_im_gui_bus_position)
    if self.is_im_gui_bus_position then
        if BTM.core_obj.bus_obj.entity == nil then
            ImGui.Text("Bus is not exist.")
            return
        end
        local pos = BTM.core_obj.bus_obj.entity:GetWorldPosition()
        local angle = BTM.core_obj.bus_obj.entity:GetWorldOrientation():ToEulerAngles()
        local x = string.format("%.2f", pos.x)
        local y = string.format("%.2f", pos.y)
        local z = string.format("%.2f", pos.z)
        local roll = string.format("%.2f", angle.roll)
        local pitch = string.format("%.2f", angle.pitch)
        local yaw = string.format("%.2f", angle.yaw)
        ImGui.Text("X: " .. x .. ", Y: " .. y .. ", Z: " .. z)
        ImGui.Text("Roll:" .. roll .. ", Pitch:" .. pitch .. ", Yaw:" .. yaw)
    end
end

function Debug:BusInfo()
    self.is_im_gui_bus_info = ImGui.Checkbox("[ImGui] Bus Info", self.is_im_gui_bus_info)
    if self.is_im_gui_bus_info then
        if BTM.core_obj.bus_obj.entity == nil then
            ImGui.Text("Bus is not exist.")
            return
        end
        ImGui.Text("Current Status : " .. BTM.core_obj.event_obj:GetStatus())
        local is_front = BTM.core_obj.event_obj:IsInFrontOfSeat()
        if is_front then
            ImGui.Text("In front of seat")
        else
            ImGui.Text("Not in front of seat")
        end
        local speed = string.format("%.2f", BTM.core_obj.bus_obj:GetSpeed())
        ImGui.Text("Speed : " .. speed)
        local is_auto_drive = BTM.core_obj:IsAutoDrive()
        if is_auto_drive then
            ImGui.Text("Auto Drive : On")
        else
            ImGui.Text("Auto Drive : Off")
        end
    end
end

function Debug:ImGuiMeasurement()
    self.is_im_gui_measurement = ImGui.Checkbox("[ImGui] Measurement", self.is_im_gui_measurement)
    if self.is_im_gui_measurement then
        local look_at_pos = Game.GetTargetingSystem():GetLookAtPosition(Game.GetPlayer())
        if BTM.core_obj.bus_obj.entity == nil then
            return
        end
        local origin = BTM.core_obj.bus_obj.entity:GetWorldPosition()
        local right = BTM.core_obj.bus_obj.entity:GetWorldRight()
        local forward = BTM.core_obj.bus_obj.entity:GetWorldForward()
        local up = BTM.core_obj.bus_obj.entity:GetWorldUp()
        local relative = Vector4.new(look_at_pos.x - origin.x, look_at_pos.y - origin.y, look_at_pos.z - origin.z, 1)
        local x = Vector4.Dot(relative, right)
        local y = Vector4.Dot(relative, forward)
        local z = Vector4.Dot(relative, up)
        local absolute_position_x = string.format("%.2f", x)
        local absolute_position_y = string.format("%.2f", y)
        local absolute_position_z = string.format("%.2f", z)
        ImGui.Text("[LookAt]X:" .. absolute_position_x .. ", Y:" .. absolute_position_y .. ", Z:" .. absolute_position_z)
    end
end

function Debug:ImGuiExcuteFunction()
    if ImGui.Button("TF1") then
        BTM.core_obj.bus_obj:ControlDoor(Def.DoorEvent.Open)
        print("Excute Test Function 1")
    end
    ImGui.SameLine()
    if ImGui.Button("TF2") then
        -- local entity = Game.FindEntityByID(self.entity_id)
        local entity = self.entity
        local player = Game.GetPlayer()
        local ent_id = entity:GetEntityID()
        local seat = "seat_front_left"

        local data = NewObject('handle:gameMountEventData')
        data.isInstant = false
        data.slotName = seat
        data.mountParentEntityId = ent_id
        data.entryAnimName = "forcedTransition"


        local slot_id = NewObject('gamemountingMountingSlotId')
        slot_id.id = seat

        local mounting_info = NewObject('gamemountingMountingInfo')
        mounting_info.childId = player:GetEntityID()
        mounting_info.parentId = ent_id
        mounting_info.slotId = slot_id

        local mounting_request = NewObject('handle:gamemountingMountingRequest')
        mounting_request.lowLevelMountingInfo = mounting_info
        mounting_request.mountData = data

        Game.GetMountingFacility():Mount(mounting_request)
        print("Excute Test Function 2")
    end
    ImGui.SameLine()
    if ImGui.Button("TF3") then
        local slot = gamemountingMountingSlotId.new()
        slot.id = "seat_front_left"
        local mountingInfo = Game.GetMountingFacility():GetMountingInfoSingleWithObjects(Game.GetPlayer(), self.entity, slot)
        local cmd  = UnmountingRequest.new()
        cmd.lowLevelMountingInfo = mountingInfo;
        -- Game.GetWorkspotSystem():UnmountFromVehicle(Game.GetPlayer():GetMountedVehicle(), Game.GetPlayer(), false, Vector4.new(0, 0, 1, 1), Quaternion.new(0, 0, 0, 1) ,"default")
        -- Cron.After(1.5, function()
            Game.GetMountingFacility():Unmount(cmd)
        -- end)
        -- local evt = VehicleStartedMountingEvent.new()
        -- evt.slotID = "seat_front_left"
        -- evt.isMounting = false
        -- evt.character = Game.GetPlayer()
        -- Game.GetPlayer():GetMountedVehicle():QueueEvent(evt)
        -- Game.GetPlayer():QueueEvent(evt)
        print("Excute Test Function 3")
    end
    ImGui.SameLine()
    if ImGui.Button("TF4-0") then
        local player = Game.GetPlayer()
        local npc = Game.FindEntityByID(self.man_id)
        local currentRole = npc:GetAIControllerComponent():GetAIRole()
        -- if currentRole then
        --     if npc:IsCrowd() and currentRole:IsA('AIFollowerRole') then
        --         print("AIFollowerRole")
        --     end

        --     currentRole:OnRoleCleared(npc)
        -- end
        print(npc:IsCrowd())
        print("Excute Test Function 4")
    end
    ImGui.SameLine()
    if ImGui.Button("TF4") then
        local entity_system = Game.GetDynamicEntitySystem()
        local entity_spec = DynamicEntitySpec.new()
        local pos = Game.GetPlayer():GetWorldPosition()
        pos.x = pos.x + 5
        local rot = Game.GetPlayer():GetWorldOrientation()

        -- entity_spec.recordID = "Vehicle.v_mahir_mt28_coach"
        entity_spec.recordID = "Vehicle.cs_savable_mahir_mt28_coach"
        entity_spec.appearanceName = "mahir_mt28_basic_coach_01"
        entity_spec.position = pos
        entity_spec.orientation = rot
        entity_spec.persistState = false
        entity_spec.persistSpawn = false
        self.entity_id = entity_system:CreateEntity(entity_spec)
        print("Excute Test Function 4")
    end

    ImGui.SameLine()
    if ImGui.Button("TF5") then
        local entity = Game.FindEntityByID(self.entity_id)
        local player = Game.GetPlayer()
        local ent_id = entity:GetEntityID()
        local seat = "seat_front_right"

        local data = NewObject('handle:gameMountEventData')
        data.isInstant = false
        data.slotName = seat
        data.mountParentEntityId = ent_id
        data.entryAnimName = "forcedTransition"


        local slot_id = NewObject('gamemountingMountingSlotId')
        slot_id.id = seat

        local mounting_info = NewObject('gamemountingMountingInfo')
        mounting_info.childId = player:GetEntityID()
        mounting_info.parentId = ent_id
        mounting_info.slotId = slot_id

        local mounting_request = NewObject('handle:gamemountingMountingRequest')
        mounting_request.lowLevelMountingInfo = mounting_info
        mounting_request.mountData = data

        Game.GetMountingFacility():Mount(mounting_request)

        print("Excute Test Function 5")
    end
    ImGui.SameLine()
    if ImGui.Button("TF5-2") then
        -- local entity = Game.FindEntityByID(self.entity_id)
        local player = Game.GetPlayer()
        local vehicle = player:GetMountedVehicle()
        local ent_id = vehicle:GetEntityID()
        -- local ent_id = player:GetMountedVehicle():GetEntityID()
        local seat = "seat_front_right"

        local data = gameMountEventData.new()
        data.isInstant = false
        data.slotName = seat
        data.mountParentEntityId = ent_id
        -- data.entryAnimName = "forcedTransition"
        data.mountEventOptions = NewObject('handle:gameMountEventOptions')
        data.mountEventOptions.silentUnmount = false
        data.mountEventOptions.entityID = ent_id
        data.mountEventOptions.alive = true
        data.mountEventOptions.occupiedByNeutral = true
        data.setEntityVisibleWhenMountFinish = true
        data.removePitchRollRotationOnDismount = false
        data.ignoreHLS = false

        local slot_id = NewObject('gamemountingMountingSlotId')
        slot_id.id = seat

        local mounting_info = NewObject('gamemountingMountingInfo')
        mounting_info.childId = player:GetEntityID()
        mounting_info.parentId = ent_id
        mounting_info.slotId = slot_id

        local mounting_request = NewObject('handle:gamemountingUnmountingRequest')
        mounting_request.lowLevelMountingInfo = mounting_info
        mounting_request.mountData = data

        Game.GetMountingFacility():Unmount(mounting_request)
        -- Game.GetWorkspotSystem():UnmountFromVehicle(vehicle, player, false, "default")
        -- Game.GetWorkspotSystem():SendFastExitSignal(player, true, true)
        -- local evt = VehicleStartedMountingEvent.new()
        -- evt.slotID = seat
        -- evt.isMounting = false
        -- evt.character = player
        -- vehicle:QueueEvent(evt)
        -- local door = VehicleExternalDoorRequestEvent.new()
        -- door.slotName = vehicle:GetBoneNameFromSlot(seat)
        -- door.autoClose = true
        -- vehicle:QueueEvent(door)

        print("Excute Test Function 5")
    end
    ImGui.SameLine()
    if ImGui.Button("TF5-3") then
        BTM.core_obj:SetNPC()
        print("Excute Test Function 5")
    end
    ImGui.SameLine()
    if ImGui.Button("TF5-4") then
        BTM.core_obj:StopAutoDrive()
        print("Excute Test Function 5")
    end
    ImGui.SameLine()
    if ImGui.Button("TF6") then
        BTM.core_obj:RunAutoDrive()

        print("Excute Test Function 6")
    end
    if ImGui.Button("TF7") then
        local player = Game.GetPlayer()
        local player_pos = player:GetWorldPosition()
        -- local npcs = player:GetNPCsAroundObject()
        local moveCmd = AIMoveToCommand.new()
        local positionSpec = AIPositionSpec.new()
        local worldPosition = WorldPosition.new()
	    worldPosition:SetVector4(player_pos)
        positionSpec:SetWorldPosition(worldPosition)
        local movementType = moveMovementType.Run
        local targetDistance = 1.0
        moveCmd.movementTarget = positionSpec
        moveCmd.movementType = movementType
        moveCmd.desiredDistanceFromTarget = targetDistance
        moveCmd.finishWhenDestinationReached = true
        moveCmd.ignoreNavigation = true
        moveCmd.useStart = true
        moveCmd.useStop = false
        -- if #npcs > 0 then
        --     local min_distance = 100
        --     local min_index = 0
        --     for index, npc in ipairs(npcs) do
        --         local npc_pos = npc:GetWorldPosition()
        --         local distnce = Vector4.Distance(player_pos, npc_pos)
        --         if distnce < min_distance then
        --             min_distance = distnce
        --             min_index = index
        --         end
        --     end
        --     print("Distance : " .. min_distance)
        --     print("Index : " .. min_index)
        --     print(npcs[min_index]:GetAIControllerComponent():SendCommand(moveCmd))
        -- end
        local npc = Game.FindEntityByID(self.man_id)
        npc:GetAIControllerComponent():SendCommand(moveCmd)

        print("Excute Test Function 7")
    end
    ImGui.SameLine()
    if ImGui.Button("TF8") then
        local entitySystem = Game.GetDynamicEntitySystem()
        local npcSpec = DynamicEntitySpec.new()
        local pos = Game.GetPlayer():GetWorldPosition()
        pos.x = pos.x + 3
        npcSpec.recordID = "Character.DefaultNCResidentMale"
        npcSpec.appearanceName = "random"
        npcSpec.position = pos
        npcSpec.persistState = true
        npcSpec.persistSpawn = true
        npcSpec.alwaysSpawned = true
        self.man_id = entitySystem:CreateEntity(npcSpec)
        print("Excute Test Function 8")
    end
    ImGui.SameLine()
    if ImGui.Button("TF9") then
        -- local entity = Game.FindEntityByID(self.entity_id)
        -- local comp = entity:GetVehicleComponent()
        -- comp:MountEntityToSlot(self.entity_id, self.man_id, "seat_back_right")
        local entity = self.entity
        local player = Game.FindEntityByID(self.man_id)
        local ent_id = entity:GetEntityID()
        local seat = "seat_back_right_a"

        local mountData = MountEventData.new()
        mountData.mountParentEntityId = entity:GetEntityID()
        mountData.isInstant = false
        mountData.setEntityVisibleWhenMountFinish = true
        mountData.removePitchRollRotationOnDismount = false
        mountData.ignoreHLS = false
        mountData.mountEventOptions = NewObject('handle:gameMountEventOptions')
        mountData.mountEventOptions.silentUnmount = false
        mountData.mountEventOptions.entityID = entity:GetEntityID()
        mountData.mountEventOptions.alive = true
        mountData.mountEventOptions.occupiedByNeutral = true
        mountData.slotName = seat
        local cmd = AIMountCommand.new()
        cmd.mountData = mountData
        player:GetAIControllerComponent():SendCommand(cmd)
        print("Excute Test Function 9")
    end
    ImGui.SameLine()
    if ImGui.Button("TF9-2") then
        -- local entity = Game.FindEntityByID(self.entity_id)
        -- local comp = entity:GetVehicleComponent()
        -- comp:MountEntityToSlot(self.entity_id, self.man_id, "seat_back_right")
        local entity = self.entity
        local player = Game.FindEntityByID(self.man_id)
        local ent_id = entity:GetEntityID()
        local seat = "seat_back_right_a"

        local mountData = MountEventData.new()
        mountData.mountParentEntityId = entity:GetEntityID()
        mountData.isInstant = false
        mountData.setEntityVisibleWhenMountFinish = true
        mountData.removePitchRollRotationOnDismount = false
        mountData.ignoreHLS = false
        mountData.mountEventOptions = NewObject('handle:gameMountEventOptions')
        mountData.mountEventOptions.silentUnmount = false
        mountData.mountEventOptions.entityID = entity:GetEntityID()
        mountData.mountEventOptions.alive = true
        mountData.mountEventOptions.occupiedByNeutral = true
        mountData.slotName = seat
        local cmd = AIUnmountCommand.new()
        cmd.mountData = mountData
        player:GetAIControllerComponent():SendCommand(cmd)
        Cron.After(1.5, function()
            local pos = entity:GetWorldPosition()
            pos.z = pos.z + 1
            local teleportCmd = AITeleportCommand.new()
            teleportCmd.position = pos
            teleportCmd.rotation = 0
            teleportCmd.doNavTest = false
            player:GetAIControllerComponent():SendCommand(teleportCmd)
        end)
        print("Excute Test Function 9")
    end
    ImGui.SameLine()
    if ImGui.Button("TF10") then
        local entity = Game.FindEntityByID(self.entity_id)
        local player = Game.FindEntityByID(self.man_id)
        local ent_id = entity:GetEntityID()
        local seat = "seat_back_right"

        local data = NewObject('handle:gameMountEventData')
        data.isInstant = true
        data.slotName = seat
        data.mountParentEntityId = ent_id
        data.entryAnimName = "UpdateWorkspot"

        local slotID = NewObject('gamemountingMountingSlotId')
        slotID.id = seat

        local mounting_info = NewObject('gamemountingMountingInfo')
        mounting_info.childId = player:GetEntityID()
        mounting_info.parentId = ent_id
        mounting_info.slotId = slotID

        local mount_event = NewObject('handle:gamemountingUnmountingRequest')
        mount_event.lowLevelMountingInfo = mounting_info
        mount_event.mountData = data

		Game.GetMountingFacility():Unmount(mount_event)
        print("Excute Test Function 10")
    end
end

return Debug