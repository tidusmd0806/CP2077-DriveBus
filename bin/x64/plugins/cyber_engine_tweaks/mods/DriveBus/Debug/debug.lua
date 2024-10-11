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

    ImGui.Begin("DAB DEBUG WINDOW")
    ImGui.Text("Version : " .. DAB.version)

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
        if DAB.is_keyboard_input then
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
        if DAB.core_obj.bus_obj.entity == nil then
            return
        end
        local bus_local_pos = DAB.core_obj.bus_obj:GetPlayerLocalPosition()
        local local_x = string.format("%.2f", bus_local_pos.x)
        local local_y = string.format("%.2f", bus_local_pos.y)
        local local_z = string.format("%.2f", bus_local_pos.z)
        ImGui.Text("[local]X:" .. local_x .. ", Y:" .. local_y .. ", Z:" .. local_z)
        local bus_angle = DAB.core_obj.bus_obj:GetPlayerLookAngle()
        local bus_yaw = string.format("%.2f", bus_angle)
        ImGui.Text("[local]Yaw:" .. bus_yaw)
    end
end

function Debug:ImGuiBusPosition()
    self.is_im_gui_bus_position = ImGui.Checkbox("[ImGui] Bus Position Angle", self.is_im_gui_bus_position)
    if self.is_im_gui_bus_position then
        if DAB.core_obj.bus_obj.entity == nil then
            ImGui.Text("Bus is not exist.")
            return
        end
        local pos = DAB.core_obj.bus_obj.entity:GetWorldPosition()
        local angle = DAB.core_obj.bus_obj.entity:GetWorldOrientation():ToEulerAngles()
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
        if DAB.core_obj.bus_obj.entity == nil then
            ImGui.Text("Bus is not exist.")
            return
        end
        ImGui.Text("Current Status : " .. DAB.core_obj.event_obj:GetStatus())
        local is_front = DAB.core_obj.event_obj:IsInFrontOfSeat()
        if is_front then
            ImGui.Text("In front of seat")
        else
            ImGui.Text("Not in front of seat")
        end
        local speed = string.format("%.2f", DAB.core_obj.bus_obj:GetSpeed())
        ImGui.Text("Speed : " .. speed)
        local is_auto_drive = DAB.core_obj:IsAutoDrive()
        if is_auto_drive then
            ImGui.Text("Auto Drive : On")
        else
            ImGui.Text("Auto Drive : Off")
        end
        ImGui.Text("Player Seat : " .. DAB.core_obj.bus_obj:GetPlayerSeat())
    end
end

function Debug:ImGuiMeasurement()
    self.is_im_gui_measurement = ImGui.Checkbox("[ImGui] Measurement", self.is_im_gui_measurement)
    if self.is_im_gui_measurement then
        local look_at_pos = Game.GetTargetingSystem():GetLookAtPosition(Game.GetPlayer())
        if DAB.core_obj.bus_obj.entity == nil then
            return
        end
        local origin = DAB.core_obj.bus_obj.entity:GetWorldPosition()
        local right = DAB.core_obj.bus_obj.entity:GetWorldRight()
        local forward = DAB.core_obj.bus_obj.entity:GetWorldForward()
        local up = DAB.core_obj.bus_obj.entity:GetWorldUp()
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
        DAB.core_obj.bus_obj:ControlDoor(Def.DoorEvent.Open)
        print("Excute Test Function 1")
    end
    ImGui.SameLine()
    if ImGui.Button("TF2") then
        DAB.core_obj.bus_obj:ControlWindow(Def.WindowEvent.Change)
        print("Excute Test Function 2")
    end
    ImGui.SameLine()
    if ImGui.Button("TF3") then
        local evt = AICommandEvent.new()
        local cmd = AIVehicleDriveToPointAutonomousCommand.new()
        local player_pos = Game.GetPlayer():GetWorldPosition()
        cmd.targetPosition = Vector4.Vector4To3(player_pos)
        cmd.driveDownTheRoadIndefinitely = false
        cmd.clearTrafficOnPath = true
        cmd.minimumDistanceToTarget = 10
        cmd.maxSpeed = 5
        cmd.minSpeed = 1
        evt.command = cmd
    
        DAB.core_obj.bus_obj.entity:QueueEvent(evt)
        print("Excute Test Function 3")
    end
end

return Debug