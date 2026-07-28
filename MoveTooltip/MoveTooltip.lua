-- MoveTooltip
-- Lets you reposition the default GameTooltip by dragging a small anchor box.
-- The anchor can be locked (hidden, click-through) or unlocked (visible, draggable).
-- Position and lock state are stored in MoveTooltipDB, which is declared as a
-- plain "SavedVariables" (not "SavedVariablesPerCharacter") in the .toc file,
-- so it is written to the Account-level SavedVariables folder and shared by
-- every character on the account.

MoveTooltipDB = MoveTooltipDB or {}

local DEFAULT_X, DEFAULT_Y = 0, 200 -- default offset from the center of the screen

-- ---------------------------------------------------------------------
-- Position saving / restoring
-- ---------------------------------------------------------------------

local function MoveTooltip_SavePosition()
    local point, _, relPoint, x, y = MoveTooltipAnchor:GetPoint()
    MoveTooltipDB.point = point
    MoveTooltipDB.relPoint = relPoint
    MoveTooltipDB.x = x
    MoveTooltipDB.y = y
end

local function MoveTooltip_ApplySavedPosition()
    MoveTooltipAnchor:ClearAllPoints()
    if MoveTooltipDB.point then
        MoveTooltipAnchor:SetPoint(
            MoveTooltipDB.point,
            UIParent,
            MoveTooltipDB.relPoint or MoveTooltipDB.point,
            MoveTooltipDB.x or 0,
            MoveTooltipDB.y or 0
        )
    else
        MoveTooltipAnchor:SetPoint("CENTER", UIParent, "CENTER", DEFAULT_X, DEFAULT_Y)
    end
end

-- ---------------------------------------------------------------------
-- The draggable anchor frame
-- ---------------------------------------------------------------------

local anchor = CreateFrame("Frame", "MoveTooltipAnchor", UIParent)
anchor:SetWidth(160)
anchor:SetHeight(36)
anchor:SetFrameStrata("TOOLTIP")
anchor:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
anchor:SetBackdropColor(0, 0, 0, 0.85)
anchor:SetMovable(true)
anchor:EnableMouse(false)
anchor:RegisterForDrag("LeftButton")
anchor:Hide()

anchor:SetScript("OnDragStart", function()
    this:StartMoving()
end)

anchor:SetScript("OnDragStop", function()
    this:StopMovingOrSizing()
    MoveTooltip_SavePosition()
end)

local label = anchor:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
label:SetPoint("CENTER", anchor, "CENTER", 0, 0)
label:SetText("Tooltip Anchor")

-- ---------------------------------------------------------------------
-- Hook the tooltip so it always follows the anchor
-- ---------------------------------------------------------------------
-- Some tooltips (bag/inventory items especially) don't just rely on the
-- anchor set by SetOwner - they also make a second, explicit SetPoint
-- call afterwards (e.g. a BOTTOMRIGHT point) to control text wrapping.
-- If we only override SetOwner, that second point still lands on the
-- tooltip's *original* on-screen location, and the tooltip stretches
-- to span the gap between our anchor and that leftover point - which
-- looks like the tooltip "growing" the further you drag the anchor.
--
-- To stop that, we also hijack SetPoint itself so no code path can ever
-- attach a second anchor point: every SetPoint call gets redirected to
-- a single point on our anchor. The tooltip still sizes itself normally
-- from its own content - only its position is fixed.

local Orig_SetOwner = GameTooltip.SetOwner
local Orig_SetPoint = GameTooltip.SetPoint

local function MoveTooltip_Anchor(self)
    Orig_SetPoint(self, "BOTTOMRIGHT", MoveTooltipAnchor, "BOTTOMRIGHT", 0, 0)
end

GameTooltip.SetOwner = function(self, owner, anchorType)
    Orig_SetOwner(self, owner, anchorType)
    MoveTooltip_Anchor(self)
end

GameTooltip.SetPoint = function(self, ...)
    -- Ignore whatever point the caller asked for; always pin to our anchor.
    MoveTooltip_Anchor(self)
end

-- ---------------------------------------------------------------------
-- Lock / unlock / reset
-- ---------------------------------------------------------------------

local function MoveTooltip_Lock()
    MoveTooltipDB.locked = true
    anchor:EnableMouse(false)
    anchor:Hide()
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99MoveTooltip|r: locked.")
end

local function MoveTooltip_Unlock()
    MoveTooltipDB.locked = false
    anchor:EnableMouse(true)
    anchor:Show()
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99MoveTooltip|r: unlocked - drag the box to reposition the tooltip, then /tam lock when done.")
end

local function MoveTooltip_Reset()
    MoveTooltipDB.point = nil
    MoveTooltipDB.relPoint = nil
    MoveTooltipDB.x = nil
    MoveTooltipDB.y = nil
    MoveTooltip_ApplySavedPosition()
    MoveTooltip_SavePosition()
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99MoveTooltip|r: position reset to default.")
end

local function MoveTooltip_PrintHelp()
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99MoveTooltip|r commands:")
    DEFAULT_CHAT_FRAME:AddMessage("  /mt unlock OR /movetooltip unlock - Show and unlock the draggable anchor")
    DEFAULT_CHAT_FRAME:AddMessage("  /mt lock OR /movetooltip lock - Hide and lock the anchor in place")
    DEFAULT_CHAT_FRAME:AddMessage("  /mt reset OR /movetooltip reset - Reset the anchor to the default position")
end

-- ---------------------------------------------------------------------
-- Restore saved state on login
-- ---------------------------------------------------------------------

local f = CreateFrame("Frame")
f:RegisterEvent("VARIABLES_LOADED")
f:SetScript("OnEvent", function()
    MoveTooltip_ApplySavedPosition()

    if MoveTooltipDB.locked == nil then
        MoveTooltipDB.locked = true -- locked by default until the player unlocks it
    end

    if MoveTooltipDB.locked then
        anchor:EnableMouse(false)
        anchor:Hide()
    else
        anchor:EnableMouse(true)
        anchor:Show()
    end
end)

-- ---------------------------------------------------------------------
-- Slash commands
-- ---------------------------------------------------------------------

SLASH_MOVETOOLTIP1 = "/mt"
SLASH_MOVETOOLTIP2 = "/movetooltip"
SlashCmdList["MOVETOOLTIP"] = function(msg)
    msg = string.lower(msg or "")
    if msg == "lock" then
        MoveTooltip_Lock()
    elseif msg == "unlock" then
        MoveTooltip_Unlock()
    elseif msg == "reset" then
        MoveTooltip_Reset()
    else
        MoveTooltip_PrintHelp()
    end
end
