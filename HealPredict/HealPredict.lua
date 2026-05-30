-- HealPredict.lua
-- Incoming heal prediction + overheal display on default UI unit frames
-- WotLK 3.3.5 / Ascension compatible
-- No C_Timer, no WeakAuras dependency

------------------------------------------------------------------------
-- Config
------------------------------------------------------------------------
local CFG = {
    healColor     = { r = 0.2,  g = 0.85, b = 0.2,  a = 0.55 },
    overhealColor = { r = 1.0,  g = 1.0,  b = 1.0,  a = 0.60 },
    updateRate    = 0.05,
    minBarWidth   = 2,
    -- Inset the bars vertically by this many pixels top+bottom
    -- Gives a slightly inset look that reads as "rounded" against the bar border
    vertInset     = 1,
}

------------------------------------------------------------------------
-- Frame registry
------------------------------------------------------------------------
local trackedFrames = {}

------------------------------------------------------------------------
-- Create a plain coloured bar texture
------------------------------------------------------------------------
local function CreateBarTexture(parent, r, g, b, a, drawLayer, sublevel)
    local t = parent:CreateTexture(nil, drawLayer or "ARTWORK", nil, sublevel or 0)
    t:SetTexture("Interface\\Buttons\\WHITE8X8")
    t:SetVertexColor(r, g, b, a)
    t:Hide()
    return t
end

------------------------------------------------------------------------
-- Update
------------------------------------------------------------------------
local function UpdateEntry(e)
    local unitID    = e.unitID
    local healthBar = e.healthBar

    if not UnitExists(unitID) or not healthBar:IsVisible() then
        e.healBar:Hide()
        e.overhealBar:Hide()
        return
    end

    local hp    = UnitHealth(unitID)
    local maxHP = UnitHealthMax(unitID)
    if maxHP <= 0 then return end

    local incoming = UnitGetIncomingHeals(unitID) or 0

    if incoming <= 0 then
        e.healBar:Hide()
        e.overhealBar:Hide()
        return
    end

    local missing    = maxHP - hp
    local actualHeal = math.min(incoming, missing)
    local overheal   = incoming - actualHeal

    local barWidth  = healthBar:GetWidth()
    local barHeight = healthBar:GetHeight()
    local hpPixel   = (hp / maxHP) * barWidth
    local inset     = CFG.vertInset
    local innerH    = barHeight - inset * 2

    -- ---- Green heal bar: inside health bar, from HP edge rightward ----
    local healPixel = (actualHeal / maxHP) * barWidth
    if healPixel >= CFG.minBarWidth then
        e.healBar:ClearAllPoints()
        e.healBar:SetPoint("TOPLEFT",    healthBar, "TOPLEFT",    hpPixel,  -inset)
        e.healBar:SetPoint("BOTTOMLEFT", healthBar, "BOTTOMLEFT", hpPixel,   inset)
        e.healBar:SetWidth(healPixel)
        e.healBar:Show()
    else
        e.healBar:Hide()
    end

    -- ---- White overheal bar: extends past right edge of health bar ----
    if overheal > 0 then
        local ovPixel = (overheal / maxHP) * barWidth
        if ovPixel >= CFG.minBarWidth then
            e.overhealBar:ClearAllPoints()
            e.overhealBar:SetPoint("LEFT", healthBar, "RIGHT", 0, 0)
            e.overhealBar:SetSize(ovPixel, innerH)
            e.overhealBar:Show()
        else
            e.overhealBar:Hide()
        end
    else
        e.overhealBar:Hide()
    end
end

------------------------------------------------------------------------
-- Register
------------------------------------------------------------------------
local function RegisterFrame(unitID, healthBar, unitFrame)
    if not healthBar then return end

    local c = CFG

    local healBar = CreateBarTexture(healthBar,
        c.healColor.r, c.healColor.g, c.healColor.b, c.healColor.a,
        "ARTWORK", 1)

    local ovParent = unitFrame or healthBar:GetParent() or healthBar
    local overhealBar = CreateBarTexture(ovParent,
        c.overhealColor.r, c.overhealColor.g, c.overhealColor.b, c.overhealColor.a,
        "OVERLAY", 1)

    trackedFrames[#trackedFrames + 1] = {
        unitID      = unitID,
        healthBar   = healthBar,
        healBar     = healBar,
        overhealBar = overhealBar,
    }
end

------------------------------------------------------------------------
-- OnUpdate driver
------------------------------------------------------------------------
local ticker  = CreateFrame("Frame")
local elapsed = 0
ticker:SetScript("OnUpdate", function(self, dt)
    elapsed = elapsed + dt
    if elapsed < CFG.updateRate then return end
    elapsed = 0
    for i = 1, #trackedFrames do
        UpdateEntry(trackedFrames[i])
    end
end)

------------------------------------------------------------------------
-- Init
------------------------------------------------------------------------
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self, event)
    if event ~= "PLAYER_LOGIN" then return end

    RegisterFrame("player", PlayerFrameHealthBar, PlayerFrame)
    RegisterFrame("target", TargetFrameHealthBar, TargetFrame)
    RegisterFrame("focus",  FocusFrameHealthBar,  FocusFrame)
    RegisterFrame("pet",    PetFrameHealthBar,     PetFrame)

    for i = 1, 4 do
        local f   = _G["PartyMemberFrame" .. i]
        local bar = f and _G["PartyMemberFrame" .. i .. "HealthBar"]
        if bar then
            RegisterFrame("party" .. i, bar, f)
        end
    end

    self:UnregisterAllEvents()
    DEFAULT_CHAT_FRAME:AddMessage("|cff66ff66HealPredict|r loaded.")
end)

------------------------------------------------------------------------
-- Event-driven refresh
------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("UNIT_HEALTH")
eventFrame:RegisterEvent("UNIT_MAXHEALTH")
eventFrame:RegisterEvent("UNIT_HEAL_PREDICTION")
eventFrame:SetScript("OnEvent", function(self, event, unitArg)
    for i = 1, #trackedFrames do
        local e = trackedFrames[i]
        if e.unitID == unitArg then
            UpdateEntry(e)
        end
    end
end)
