local _, ns = ...

-- A bar over the bag search box that shows the progress of a long bag operation (the restore of the
-- reserved slots, the own sort). The bar is a child of the search box, so it follows the box between
-- the bag frames and closes with the bags, while the operation goes on. Created on first use.
local Progress = {}
ns.Progress = Progress

local TEXTURE = "Interface\\TargetingFrame\\UI-StatusBar"
local PULSE_DURATION = 0.6
local PULSE_MIN_ALPHA = 0.35

local bar, label, pulse

local function Create()
    bar = CreateFrame("StatusBar", nil, BagItemSearchBox)
    bar:SetAllPoints()
    bar:SetStatusBarTexture(TEXTURE)
    bar:SetStatusBarColor(0.2, 0.6, 1)
    bar:Hide()

    -- Opaque, so the text of the search box does not show through.
    local background = bar:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0, 0, 0)

    label = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("CENTER")

    pulse = bar:GetStatusBarTexture():CreateAnimationGroup()
    pulse:SetLooping("BOUNCE")
    local fade = pulse:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(PULSE_MIN_ALPHA)
    fade:SetDuration(PULSE_DURATION)
end

-- A full, pulsing bar for an operation without a known length.
function Progress:Pulse(text)
    if not bar then
        Create()
    end
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(1)
    label:SetText(text)
    pulse:Play()
    bar:Show()
end

-- A bar that counts done of total steps.
function Progress:Set(text, done, total)
    if not bar then
        Create()
    end
    pulse:Stop()
    bar:SetMinMaxValues(0, total)
    bar:SetValue(done)
    label:SetText(text)
    bar:Show()
end

function Progress:Hide()
    if bar then
        pulse:Stop()
        bar:Hide()
    end
end
