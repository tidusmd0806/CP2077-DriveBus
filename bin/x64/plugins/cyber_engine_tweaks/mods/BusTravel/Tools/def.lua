---@class Def
Def = {}
Def.__index = Def

---@enum Def.VehicleStatus
Def.VehicleStatus = {
    NoExistance = 0,
    Summoned = 1,
    PlayerIn = 2,
    Mounted = 3,
}

Def.ChoiceVariation = {
    None = 0,
    FrontBoth = 1,
    FrontLeft = 2,
    FrontRight = 3,
    BackBoth = 4,
    BackLeft = 5,
    BackRight = 6,
}

Def.BusSeat = {
    FrontLeft = 1,
    FrontRight = 2,
    BackLeft = 3,
    BackRight = 4,
}

Def.DoorEvent = {
    Unknown = 0,
    Open = 1,
    Close = 2,
}

return Def