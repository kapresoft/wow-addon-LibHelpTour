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
-- Footer row, bottom-right: SkipButton, then Counter.
local FOOTER_Y = 6
-- Extra room under the text while the footer row shows.
local FOOTER_PAD_Y = 8
local COUNTER_INSET = 10
-- Counter's bottom inset on a tour's last step, where SkipButton hides.
local LAST_COUNTER_Y = 10
-- Space between SkipButton and Counter.
local FOOTER_GAP = 12

--- @class LibHelpTour_Tip : Frame
--- @field Text FontString
--- @field Counter FontString @Step position, e.g. 1/3; hidden on one-step tours
--- @field CloseButton Button
--- @field SkipButton Button  @Hidden unless the step is skippable
--- @field Arrow Frame        @Points down; shown while the tip is above its target
--- @field ArrowUp Frame      @Points up; shown while the tip is below its target
--- @field onClose fun()?     @Set by the controller; runs on the close button
--- @field onSkip fun()?      @Set by the controller; runs on the Skip button
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
  tip.Counter:Hide()
end

--- @param tip LibHelpTour_Tip
local function CreateSkipButton(tip)
  local button = CreateFrame('Button', nil, tip)
  button:SetNormalFontObject('GameFontNormalSmall')
  button:SetHighlightFontObject('GameFontHighlightSmall')
  button:SetPoint('BOTTOMRIGHT', tip.Counter, 'BOTTOMLEFT', -FOOTER_GAP, 0)
  button:SetScript('OnClick', function()
    if tip.onSkip then tip.onSkip() end
  end)
  button:Hide()
  tip.SkipButton = button
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
  CreateSkipButton(tip)
  tip.Arrow = CreateFrame('Frame', nil, tip, 'GlowBoxArrowTemplate' --[[@as Template]])
  tip.ArrowUp = CreateArrowUp(tip)
  return tip
end

--[[-----------------------------------------------------------------------------
Methods
-------------------------------------------------------------------------------]]
--- @param text string
--- @param anchorTo Region
--- @param index number     @Step position in its tour
--- @param count number     @Steps in the tour; 1 hides the counter
--- @param skipText string? @Skip button label; nil hides it
function TipMixin:ShowStep(text, anchorTo, index, count, skipText)
  self.Text:SetText(text)
  self:SetCounter(index, count)
  self:SetSkipText(skipText)
  -- Per show: the parent may have changed or been raised
  self:SetFrameLevel(self:GetParent():GetFrameLevel() + 10)
  self:FitToText()
  self:PlaceAt(anchorTo)
  self:Show()
end

--- @param index number
--- @param count number @1 hides the Counter
function TipMixin:SetCounter(index, count)
  local counter = self.Counter
  counter:SetFormattedText('%d/%d', index, count)
  counter:SetShown(count > 1)
  local y = index == count and LAST_COUNTER_Y or FOOTER_Y
  counter:SetPoint('BOTTOMRIGHT', -COUNTER_INSET, y)
end

--- @param text string? @nil hides the Skip button
function TipMixin:SetSkipText(text)
  local button = self.SkipButton
  button:SetShown(text ~= nil)
  if not text then return end
  button:SetText(text)
  button:SetSize(button:GetTextWidth(), button:GetTextHeight())
end

--- Short text shrinks the box; long text wraps at TEXT_MAX_WIDTH.
--- The footer can widen it past the text. FOOTER_PAD_Y follows the
--- Counter, not SkipButton, so the last step keeps the same gap.
function TipMixin:FitToText()
  local text = self.Text
  local width = math.min(text:GetUnboundedStringWidth(), TEXT_MAX_WIDTH)
  text:SetWidth(width)
  local footerPad = self.Counter:IsShown() and FOOTER_PAD_Y or 0
  local height = text:GetHeight() + TEXT_PAD_Y + footerPad
  self:SetSize(math.max(width + TEXT_PAD_X, self:FooterWidth()), height)
end

--- @return number @Width SkipButton and Counter need side by side; 0 without SkipButton
function TipMixin:FooterWidth()
  if not self.SkipButton:IsShown() then return 0 end
  local counterWidth = self.Counter:GetUnboundedStringWidth()
  return TEXT_INSET + self.SkipButton:GetWidth() + FOOTER_GAP + counterWidth + COUNTER_INSET
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
