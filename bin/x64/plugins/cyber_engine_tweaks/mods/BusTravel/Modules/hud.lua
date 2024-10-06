local HUD = {}
HUD.__index = HUD

function HUD:New()
    -- instance --
    local obj = {}
    obj.log_obj = Log:New()
    obj.log_obj:SetLevel(LogLevel.Info, "HUD")
    -- static --
    obj.choice_title = "LocKey#77041"
    obj.choice_num = 0
    obj.seat_front_left_choice_contents = {icon = "ChoiceCaptionParts.SitIcon", text_1 = "LocKey#522", text_2 = "LocKey#40664"}
    obj.seat_front_right_choice_contents = {icon = "ChoiceCaptionParts.CourierIcon", text_1 = "LocKey#84764", text_2 = "LocKey#40665"}
    obj.seat_back_left_contents = {icon = "ChoiceCaptionParts.SitIcon", text_1 = "LocKey#522", text_2 = "LocKey#40664"}
    obj.seat_back_right_contents = {icon = "ChoiceCaptionParts.CourierIcon", text_1 = "LocKey#84764", text_2 = "LocKey#40665"}
    -- dynamic --
    obj.show_stand_hint_event = nil
    obj.hide_stand_hint_event = nil
    obj.show_sit_hint_event = nil
    obj.hide_sit_hint_event = nil
    obj.interaction_hub = nil
    obj.selected_choice_index = 0
    return setmetatable(obj, self)
end

function HUD:ShowStandHint()
    Game.GetUISystem():QueueEvent(self.show_stand_hint_event)
end

function HUD:HideStandHint()
    Game.GetUISystem():QueueEvent(self.hide_stand_hint_event)
end

function HUD:ShowSitHint()
    Game.GetUISystem():QueueEvent(self.show_sit_hint_event)
end

function HUD:HideSitHint()
    Game.GetUISystem():QueueEvent(self.hide_sit_hint_event)
end

function HUD:SetChoice(variation)

    local tmp_list = {}

    local hub = gameinteractionsvisListChoiceHubData.new()
    hub.title = GetLocalizedText(self.choice_title)
    hub.activityState = gameinteractionsvisEVisualizerActivityState.Active
    hub.hubPriority = 1
    hub.id = 77777 + math.random(99999)

    local choice_contents = {}
    if variation == Def.ChoiceVariation.FrontBoth then
        table.insert(choice_contents, self.seat_front_left_choice_contents)
        table.insert(choice_contents, self.seat_front_right_choice_contents)
    elseif variation == Def.ChoiceVariation.FrontLeft then
        table.insert(choice_contents, self.seat_front_left_choice_contents)
    elseif variation == Def.ChoiceVariation.FrontRight then
        table.insert(choice_contents, self.seat_front_right_choice_contents)
    elseif variation == Def.ChoiceVariation.BackBoth then
        table.insert(choice_contents, self.seat_back_left_contents)
        table.insert(choice_contents, self.seat_back_right_contents)
    elseif variation == Def.ChoiceVariation.BackLeft then
        table.insert(choice_contents, self.seat_back_left_contents)
    elseif variation == Def.ChoiceVariation.BackRight then
        table.insert(choice_contents, self.seat_back_right_contents)
    end

    self.choice_num = #choice_contents
    for _, v in ipairs(choice_contents) do
        local icon = TweakDBInterface.GetChoiceCaptionIconPartRecord(v.icon)
        local caption_part = gameinteractionsChoiceCaption.new()
        local choice_type = gameinteractionsChoiceTypeWrapper.new()
        caption_part:AddPartFromRecord(icon)
        choice_type:SetType(gameinteractionsChoiceType.Selected)

        local choice = gameinteractionsvisListChoiceData.new()

        local text_1 = GetLocalizedText(v.text_1)
        local text_2 = GetLocalizedText(v.text_2)
        choice.localizedName = text_1 .. " [" .. text_2 .. "]"
        choice.inputActionName = CName.new("None")
        choice.captionParts = caption_part
        choice.type = choice_type
        table.insert(tmp_list, choice)
    end

    hub.choices = tmp_list

    self.interaction_hub = hub
end

function HUD:ShowChoice(variation)

    self:SetChoice(variation)

    if self.choice_num <= self.selected_choice_index then
        self.selected_choice_index = self.choice_num - 1
    end

    local ui_interaction_define = GetAllBlackboardDefs().UIInteractions
    local interaction_blackboard = Game.GetBlackboardSystem():Get(ui_interaction_define)

    interaction_blackboard:SetInt(ui_interaction_define.ActiveChoiceHubID, self.interaction_hub.id)
    local data = interaction_blackboard:GetVariant(ui_interaction_define.DialogChoiceHubs)
    self.interaction_ui_base:OnDialogsSelectIndex(self.selected_choice_index)
    self.interaction_ui_base:OnDialogsData(data)
    self.interaction_ui_base:OnInteractionsChanged()
    self.interaction_ui_base:UpdateListBlackboard()
    self.interaction_ui_base:OnDialogsActivateHub(self.interaction_hub.id)

end

function HUD:HideChoice()

    self.interaction_hub = nil
    self.choice_num = 0

    local ui_interaction_define = GetAllBlackboardDefs().UIInteractions;
    local interaction_blackboard = Game.GetBlackboardSystem():Get(ui_interaction_define)

    local data = interaction_blackboard:GetVariant(ui_interaction_define.DialogChoiceHubs)
    if self.interaction_ui_base == nil then
        return
    end
    self.interaction_ui_base:OnDialogsData(data)

end

return HUD