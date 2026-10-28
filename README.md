# LibHelpTour

> **Point. Explain. Guide.**

Embeddable WoW library for guided help tours that point at an addon's controls step by step.

## Features

- Glowing tips with an arrow that point at your controls, one step at a time, with a step counter and a close button.
- Remembers which steps each user has seen, in your addon's own saved variables.
- Feature tours: a tour added in a later release shows only to users who installed before it, not to new users.
- One tour per session, so users are never flooded with tips.
- Optional Skip button, so users who know your addon can dismiss a whole tour at once.
- Safe to embed in many addons at once: no XML templates and no global names besides `LibStub`.
- Works on Retail and Classic clients.

## Embedding

Add LibHelpTour as an external in your `pkgmeta.yaml`:

```yaml
externals:
  ThirdParty/Libs/LibHelpTour:
    url: https://github.com/kapresoft/wow-addon-LibHelpTour
    tag: latest
```

Then load it from your TOC or XML, after LibStub:

```xml
<Script file="ThirdParty\Libs\LibStub\LibStub.lua"/>
<Include file="ThirdParty\Libs\LibHelpTour\LibHelpTour.xml"/>
```

## Usage

### 1. Define your tours

Each tour belongs to a target, usually a dialog, named by `targetId`. Each step points at a control inside that target.

```lua
local Tours = {
  {
    id = 'welcome',
    targetId = 'MainDialog',
    skippable = false, -- true adds a Skip button
    steps = {
      {
        key = 'OptionsMenu',
        textKey = 'Options::HelpTip',
        anchor = function(dialog) return dialog.OptionsButton end,
      },
      {
        key = 'RunButton',
        textKey = 'Run::HelpTip',
        anchor = function(dialog) return dialog.RunButton end,
      },
    },
  },
  {
    id = 'history',
    targetId = 'MainDialog',
    since = 1, -- feature tour: only users who installed before it see it
    steps = {
      {
        key = 'HistoryButton',
        textKey = 'History::HelpTip',
        anchor = function(dialog) return dialog.HistoryButton end,
      },
    },
  },
}
```

- `textKey` is passed to your `text` function (see below), so it can be a locale key. With AceLocale, each locale file gives it the text:
  ```lua
  L['Options::HelpTip'] = 'Settings, themes and more'  -- enUS.lua
  L['Options::HelpTip'] = 'Réglages, thèmes et plus'   -- frFR.lua
  ```
  Without localization, put the text itself in `textKey` and use `text = function(textKey) return textKey end`.
- `key` is saved once the user has seen the step, so keep it stable and unique across all your tours.
- `anchor` is called each time the step shows. A step whose anchor is `nil` or hidden is skipped.
- `since` marks a feature tour. Give each new feature tour the next number (1, 2, 3, ...). Leave it out for tours everyone should see, such as a welcome tour.
- `skippable = true` adds a Skip button to every step but the last. Skipping marks all of the tour's steps as seen, so it doesn't come back. It needs `skipTextKey` in the controller settings.

### 2. Create a controller

Create one controller per addon. It reads and writes your saved data through the functions you pass, and only calls them when a tour shows, so your database can be set up later (e.g. in `OnInitialize`).

```lua
local L = LibStub('AceLocale-3.0'):GetLocale('MyAddon')

local HelpTour = LibStub('LibHelpTour-1.0'):New({
  tours = Tours,
  dismissed = function() return db.global.helpTipsDismissed end,
  getBaseline = function() return db.global.tourBaseline end,
  setBaseline = function(baseline) db.global.tourBaseline = baseline end,
  text = function(textKey) return L[textKey] end,
})
```

| Setting | Required | Description |
|---|---|---|
| `tours` | yes | Your tour list. |
| `dismissed` | yes | Returns the saved table of seen step keys, e.g. `{}` by default. |
| `getBaseline` / `setBaseline` | yes | Read and write the saved feature-tour baseline, a number. It's saved on the first show, so new users skip existing feature tours. |
| `text` | yes | Turns a step's `textKey` into the text shown, e.g. a locale lookup. |
| `skipTextKey` | if a tour is `skippable` | The Skip button's label, passed to `text` like a step's `textKey`. |
| `tipParent` | no | `function(target)` returning the tip's parent frame. Defaults to the target itself. |
| `tipStrata` | no | The tip's frame strata, e.g. `'FULLSCREEN_DIALOG'` when the tip is parented to `UIParent`. |

### 3. Call it from your target

```lua
function MainDialogMixin:OnShow()
  HelpTour:OnTargetShown('MainDialog', self)
end

function MainDialogMixin:OnRunClick()
  -- Doing what a step points at counts as seeing it
  HelpTour:CompleteStep('RunButton')
end
```

- `OnTargetShown(targetId, target)` shows the next unseen step, or hides the tip when there is none. The controller creates the tip itself the first time.
- `CompleteStep(key)` marks a step as seen. If that step is on screen, the tip moves on to the next one. Closing the tip does the same.
- `SkipTour()` marks every step of the current tour as seen and hides the tip. The Skip button calls it; you only need it for your own skip control.
- `OnTargetHidden(target)` hides the tip when its target goes away. It's only needed when the tip isn't the target's child (a `tipParent` such as `UIParent`), or when the target is an AceGUI widget that gets released.

## License

[MIT](LICENSE)

### Donations

If LibHelpTour has made your addon development easier, consider supporting its development:

- **[Paypal&trade; Donation](https://www.paypal.com/donate/?hosted_button_id=AX58YP3GSGXVU)**
- **[Bitcoin Donation](https://www.blockchain.com/btc/address/3QQVAwJGkKHMM2oq6CLVWYgfx83TFVwp39)**

## About

- About the Author [(Tony Lagnada)](https://tony.resume.lagnada.com/)
- My AddOn Portfolio Can Be Found Here [Curse Forge/Kapresoft](https://www.curseforge.com/members/kapresoft/projects)
