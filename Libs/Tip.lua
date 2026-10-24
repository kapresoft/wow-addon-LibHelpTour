--[[-----------------------------------------------------------------------------
Tip: the help tip view; the controller decides what it shows.

Built in Lua with unnamed frames, so embedded copies share no global or XML
template name. Arrow points down from below the tip; ArrowUp points up from
above it and is shown instead when the tip flips below its target. Both are
anchored in PlaceAt, on the side nearer the target's screen edge, so the tip
opens away from that edge.
-------------------------------------------------------------------------------]]
local lib = LibStub('LibHelpTour-1.0')
-- Set by this copy's LibHelpTour.lua only if it registered
if not lib.loadTip then return end
lib.loadTip = nil

-- Arrow's inset from the tip's side edge.
local ARROW_INSET = 8
-- ArrowUp on the right clears the close button in that corner.
local ARROW_UP_RIGHT_INSET = 40
-- Half the GlowBox arrow art; centers the arrow over the target.
local ARROW_HALF_WIDTH = 26
-- How far the arrow overlaps into the tip's edge.
local ARROW_OVERLAP = 4
-- Tip edge to target edge; leaves room for the arrow.
local ARROW_GAP = 19
-- Text's left inset plus room for the close button.
local TEXT_PAD_X = 44
local TEXT_PAD_Y = 32
local TEXT_INSET = 16
local TEXT_MAX_WIDTH = 188

--- @class LibHelpTour_Tip : Frame
--- @field Text FontString
--- @field Counter FontString @Step position, e.g. 1/3; hidden on one-step tours
--- @field CloseButton Button
--- @field Arrow Frame        @Points down; shown while the tip is above its target
--- @field ArrowUp Frame      @Points up; shown while the tip is below its target
--- @field onClose fun()?     @Set by the controller; runs on the close button
local TipMixin = {}

--[[-----------------------------------------------------------------------------
Support Functions
-------------------------------------------------------------------------------]]
--- @param tip LibHelpTour_Tip
local function CreateTexts(tip)
  tip.Text = tip:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightLeft')
  tip.Text:SetJustifyV('TOP')
  tip.Text:SetPoint('TOPLEFT', TEXT_INSET, -TEXT_INSET)
  tip.Counter = tip:CreateFontString(nil, 'OVERLAY', 'GameFontDisableSmall')
  tip.Counter:SetPoint('BOTTOMRIGHT', -10, 6)
  tip.Counter:Hide()
end

--- @param tip LibHelpTour_Tip
local function CreateCloseButton(tip)
  local button = CreateFrame('Button', nil, tip, 'UIPanelCloseButton' --[[@as Template]])
  button:SetPoint('TOPRIGHT', 6, 6)
  -- Replaces the template's OnClick, which hides the parent
  button:SetScript('OnClick', function()
    if tip.onClose then tip.onClose() end
  end)
  tip.CloseButton = button
end

--- GlowBoxArrowTemplate only points down; this mirrors it upward.
--- @param tip LibHelpTour_Tip
--- @return Frame
local function CreateArrowUp(tip)
  local down = tip.Arrow
  local up = CreateFrame('Frame', nil, tip)
  up:SetSize(down:GetSize())
  up:Hide()
  up.Arrow = up:CreateTexture(nil, 'ARTWORK', 'HelpPlateArrowUp')
  up.Arrow:SetPoint('BOTTOMLEFT')
  up.Glow = up:CreateTexture(nil, 'BORDER', 'HelpPlateArrow-GlowUp')
  up.Glow:SetPoint('BOTTOM')
  up.Glow:SetBlendMode('ADD')
  up.Glow:SetAlpha(0.5)
  return up
end

--[[-----------------------------------------------------------------------------
New Instance
-------------------------------------------------------------------------------]]
--- @param parent Frame
--- @return LibHelpTour_Tip
function lib:CreateTip(parent)
  --- @type LibHelpTour_Tip
  local tip = CreateFrame('Frame', nil, parent, 'GlowBoxTemplate' --[[@as Template]])
  Mixin(tip, TipMixin)
  tip:Hide()
  tip:EnableMouse(true)
  tip:SetClampedToScreen(true)
  CreateTexts(tip)
  CreateCloseButton(tip)
  tip.Arrow = CreateFrame('Frame', nil, tip, 'GlowBoxArrowTemplate' --[[@as Template]])
  tip.ArrowUp = CreateArrowUp(tip)
  return tip
end

--[[-----------------------------------------------------------------------------
Methods
-------------------------------------------------------------------------------]]
--- @param text string
--- @param anchorTo Region
--- @param index number   @Step position in its tour
--- @param count number   @Steps in the tour; 1 hides the counter
function TipMixin:ShowStep(text, anchorTo, index, count)
  self.Text:SetText(text)
  self.Counter:SetFormattedText('%d/%d', index, count)
  self.Counter:SetShown(count > 1)
  -- Per show: the parent may have changed or been raised
  self:SetFrameLevel(self:GetParent():GetFrameLevel() + 10)
  self:FitToText()
  self:PlaceAt(anchorTo)
  self:Show()
end

--- Short text shrinks the box; long text wraps at TEXT_MAX_WIDTH.
function TipMixin:FitToText()
  local text = self.Text
  local width = math.min(text:GetUnboundedStringWidth(), TEXT_MAX_WIDTH)
  text:SetWidth(width)
  self:SetSize(width + TEXT_PAD_X, text:GetHeight() + TEXT_PAD_Y)
end

--- Above anchorTo when it fits on screen, else below with the arrow flipped.
--- The tip opens away from the nearer screen edge.
--- @param anchorTo Region
function TipMixin:PlaceAt(anchorTo)
  local below = self:RoomAbove(anchorTo) < ARROW_GAP + self:GetHeight()
  local side = self:ArrowSide(anchorTo)
  local inset = (below and side == 'RIGHT') and ARROW_UP_RIGHT_INSET or ARROW_INSET
  self.Arrow:SetShown(not below)
  self.ArrowUp:SetShown(below)
  self:AnchorArrow(below and self.ArrowUp or self.Arrow, below, side, inset)

  local offset = inset + ARROW_HALF_WIDTH
  local x = side == 'LEFT' and -offset or offset
  self:ClearAllPoints()
  if below then
    self:SetPoint('TOP' .. side, anchorTo, 'BOTTOM', x, -ARROW_GAP)
  else
    self:SetPoint('BOTTOM' .. side, anchorTo, 'TOP', x, ARROW_GAP)
  end
end

--- @param arrow Frame
--- @param below boolean     @ArrowUp on the top edge, else Arrow on the bottom edge
--- @param side 'LEFT'|'RIGHT'
--- @param inset number      @From that side's edge
function TipMixin:AnchorArrow(arrow, below, side, inset)
  local x = side == 'LEFT' and inset or -inset
  arrow:ClearAllPoints()
  if below then
    arrow:SetPoint('BOTTOM' .. side, self, 'TOP' .. side, x, -ARROW_OVERLAP)
  else
    arrow:SetPoint('TOP' .. side, self, 'BOTTOM' .. side, x, ARROW_OVERLAP)
  end
end

--- @param anchorTo Region
--- @return 'LEFT'|'RIGHT' @Arrow side: the one nearer the screen edge the target is on
function TipMixin:ArrowSide(anchorTo)
  local anchorX = anchorTo:GetCenter() * anchorTo:GetEffectiveScale()
  local screenX = UIParent:GetCenter() * UIParent:GetEffectiveScale()
  return anchorX < screenX and 'LEFT' or 'RIGHT'
end

--- @param anchorTo Region
--- @return number @Space between anchorTo's top and the screen top, in this tip's units
function TipMixin:RoomAbove(anchorTo)
  local screenTop = UIParent:GetTop() * UIParent:GetEffectiveScale()
  local anchorTop = anchorTo:GetTop() * anchorTo:GetEffectiveScale()
  return (screenTop - anchorTop) / self:GetEffectiveScale()
end
