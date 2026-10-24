--[[-----------------------------------------------------------------------------
For LuaDevKit Editor: run with the editor open.

Tours LuaDevKit's own editor buttons. Saved data is in-memory, so each run
starts over. Afterwards:
  /run LHT_TEST:CompleteStep('Options')            -- advances, like the action
  /run LHT_TEST:OnTargetHidden(LDK_CodeEditorDialog) -- hides the tip
-------------------------------------------------------------------------------]]
local HelpTourLib = LibStub('LibHelpTour-1.0')
local editor = LDK_CodeEditorDialog

--- @param overrides table? @e.g. { tipParent = ..., tipStrata = ... }
local function NewTestTour(overrides)
  local dismissed, baseline = {}, nil
  --- @type LibHelpTour_Config
  local config = {
    tours = {
      {
        id = 'test',
        targetId = 'Editor',
        steps = {
          {
            key = 'Options',
            textKey = 'Options menu: settings, themes and more.',
            anchor = function(d) return d.Header.OptionsButton end,
          },
          {
            key = 'Run',
            textKey = 'Runs the code in the editor.',
            anchor = function(d) return d.StatusDivider.RunButton end,
          },
          {
            key = 'History',
            textKey = 'Recent commands; pick one to run it again.',
            anchor = function(d) return d.HistoryButton end,
          },
        },
      },
    },
    dismissed = function() return dismissed end,
    getBaseline = function() return baseline end,
    setBaseline = function(value) baseline = value end,
    -- Test tours put the text itself in textKey
    text = function(textKey) return textKey end,
  }
  for k, v in pairs(overrides or {}) do
    config[k] = v
  end
  return HelpTourLib:New(config), function() return baseline end
end

--- Default: the tip lives inside the editor.
local function TestInsideTarget()
  local tour, getBaseline = NewTestTour()
  _G.LHT_TEST = tour
  tour:OnTargetShown('Editor', editor)
  print('LHT inside target: baseline =', getBaseline())
end

--- AddonSuite's case: the tip on UIParent above the target.
local function TestOnUIParent()
  local tour = NewTestTour({
    tipParent = function() return UIParent end,
    tipStrata = 'FULLSCREEN_DIALOG',
  })
  _G.LHT_TEST = tour
  tour:OnTargetShown('Editor', editor)
  print('LHT on UIParent: strata =', tour.tip:GetFrameStrata())
end

--- A tour for another target never shows here.
local function TestOtherTarget()
  local tour = NewTestTour()
  _G.LHT_TEST = tour
  tour:OnTargetShown('SomeOtherDialog', editor)
  print('LHT other target: tip created =', tour.tip ~= nil)
end

TestInsideTarget()
--TestOnUIParent()
--TestOtherTarget()
