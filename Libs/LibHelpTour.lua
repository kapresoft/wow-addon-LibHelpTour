--[[-----------------------------------------------------------------------------
LibHelpTour: picks which tour step an addon's help tip shows.

One controller per addon (lib:New). One tour per session: the first eligible
tour with unseen steps owns the session until /reload, even after it
finishes. A step's close button or its action (CompleteStep) advances to the
next step. A skippable tour's Skip button (SkipTour) dismisses all its steps.
-------------------------------------------------------------------------------]]
local MAJOR, MINOR = 'LibHelpTour-1.0', 2
--- @class LibHelpTour-1.0
--- @field Controller LibHelpTour_Controller
local lib = LibStub:NewLibrary(MAJOR, MINOR); if not lib then return end
-- Older copies stop above, so their Tip.lua skips too
lib.loadTip = true

--- @alias LibHelpTour_Target table @Frame or AceGUI widget

--- @class LibHelpTour_Step
--- @field key string                                      @Key in config.dismissed(); unique across tours
--- @field textKey string                                  @Resolved through config.text
--- @field anchor fun(target: LibHelpTour_Target): Region? @Step is skipped while this is nil or hidden

--- @class LibHelpTour_Tour
--- @field id string
--- @field targetId string       @Matches the targetId passed to OnTargetShown
--- @field since number?         @Feature tours only; nil means always eligible
--- @field skippable boolean?    @Shows a Skip button on every step but the last
--- @field steps LibHelpTour_Step[]

--- @class LibHelpTour_Config
--- @field tours LibHelpTour_Tour[]
--- @field dismissed fun(): table<string, boolean>
--- @field getBaseline fun(): number?
--- @field setBaseline fun(baseline: number)
--- @field text fun(textKey: string): string
--- @field skipTextKey? string                               @Skip button label; required if a tour is skippable
--- @field tipParent? fun(target: LibHelpTour_Target): Frame @Default: the target, as a Frame
--- @field tipStrata? FrameStrata

--- @class LibHelpTour_Showing
--- @field targetId string
--- @field target LibHelpTour_Target
--- @field step LibHelpTour_Step

--[[-----------------------------------------------------------------------------
Support Functions
-------------------------------------------------------------------------------]]
--- @param config LibHelpTour_Config
--- @return number
local function HighestSince(config)
  local highest = 0
  for _, tour in ipairs(config.tours) do
    highest = math.max(highest, tour.since or 0)
  end
  return highest
end

--- Saved on the first open, so new users skip older feature tours.
--- @param config LibHelpTour_Config
--- @return number?
local function Baseline(config)
  if not config.getBaseline() then config.setBaseline(HighestSince(config)) end
  return config.getBaseline()
end

--- @param config LibHelpTour_Config
--- @param tour LibHelpTour_Tour
--- @return boolean
local function IsEligible(config, tour) return tour.since == nil or tour.since > Baseline(config) end

--- @param config LibHelpTour_Config
--- @param tour LibHelpTour_Tour
--- @return boolean
local function HasUnseenStep(config, tour)
  local dismissed = config.dismissed()
  for _, step in ipairs(tour.steps) do
    if not dismissed[step.key] then return true end
  end
  return false
end

--- @param config LibHelpTour_Config
--- @param tour LibHelpTour_Tour
--- @param target LibHelpTour_Target
--- @return number? @nil if every unseen step's anchor is missing or hidden
local function FirstShowableStep(config, tour, target)
  local dismissed = config.dismissed()
  for index, step in ipairs(tour.steps) do
    if not dismissed[step.key] then
      local anchor = step.anchor(target)
      if anchor and anchor:IsVisible() then return index end
    end
  end
end

--[[-----------------------------------------------------------------------------
Controller
-------------------------------------------------------------------------------]]
--- Kept across versions so older instances get newer methods.
--- @class LibHelpTour_Controller
--- @field config LibHelpTour_Config
--- @field sessionTour LibHelpTour_Tour?
--- @field showing LibHelpTour_Showing?
--- @field tip LibHelpTour_Tip?
local Controller = lib.Controller or {}; lib.Controller = Controller
Controller.__index = Controller

--- @param config LibHelpTour_Config
--- @return LibHelpTour_Controller
function lib:New(config) return setmetatable({ config = config }, Controller) end

--- @param targetId string
--- @return LibHelpTour_Tour? @nil if another target's tour owns the session, or none is left
function Controller:SessionTour(targetId)
  local config = self.config
  if not self.sessionTour then
    -- Save now; IsEligible skips it for tours without since
    Baseline(config)
    for _, tour in ipairs(config.tours) do
      if tour.targetId == targetId and IsEligible(config, tour) and HasUnseenStep(config, tour) then
        self.sessionTour = tour
        break
      end
    end
  end
  local tour = self.sessionTour
  return tour and tour.targetId == targetId and tour or nil
end

--- Created on first use, so the newest embedded copy builds it.
--- @param target LibHelpTour_Target
--- @return LibHelpTour_Tip
function Controller:TipFor(target)
  local config = self.config
  local parent = config.tipParent and config.tipParent(target) or target
  self.tip = self.tip or lib:CreateTip(parent)
  self.tip:SetParent(parent)
  -- After SetParent, which resets strata to the parent's
  if config.tipStrata then self.tip:SetFrameStrata(config.tipStrata) end
  return self.tip
end

function Controller:HideTip()
  self.showing = nil
  if self.tip then self.tip:Hide() end
end

--- Call from the target's OnShow; shows its next step or hides the tip.
--- @param targetId string
--- @param target LibHelpTour_Target
function Controller:OnTargetShown(targetId, target)
  local tour = self:SessionTour(targetId)
  local index = tour and FirstShowableStep(self.config, tour, target)
  if not index then return self:HideTip() end
  local step = tour.steps[index]
  self.showing = { targetId = targetId, target = target, step = step }
  local tip = self:TipFor(target)
  local skipText = self:SkipText(tour, index)
  tip.onClose = function() self:CompleteStep(step.key) end
  tip.onSkip = skipText and function() self:SkipTour() end
  tip:ShowStep(self.config.text(step.textKey), step.anchor(target), index, #tour.steps, skipText)
end

--- @param tour LibHelpTour_Tour
--- @param index number
--- @return string? @nil unless the tour is skippable and index isn't its last step
function Controller:SkipText(tour, index)
  if not tour.skippable or index == #tour.steps then return nil end
  local config = self.config
  assert(config.skipTextKey, 'LibHelpTour: skippable tours need config.skipTextKey')
  return config.text(config.skipTextKey)
end

--- Dismisses every step of the session tour and hides the tip.
function Controller:SkipTour()
  local tour = self.sessionTour
  if not tour then return end
  local dismissed = self.config.dismissed()
  for _, step in ipairs(tour.steps) do
    dismissed[step.key] = true
  end
  self:HideTip()
end

--- Hides the tip when its target goes away, e.g. a released dialog.
--- @param target LibHelpTour_Target
function Controller:OnTargetHidden(target)
  if not (self.showing and self.showing.target == target) then return end
  self:HideTip()
end

--- Marks a step done, e.g. when the user does what it points at;
--- advances if it's the step on screen.
--- @param key string
function Controller:CompleteStep(key)
  self.config.dismissed()[key] = true
  local showing = self.showing
  if not (showing and showing.step.key == key) then return end
  self:OnTargetShown(showing.targetId, showing.target)
end
