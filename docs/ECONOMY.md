---
sidebar_position: 4
title: Economy Analyzer
---

# Economy Analyzer

import EconomyLauncher from '@site/src/csp/EconomyLauncher';

**A separate passive observation tool.** It does not save a `.rbxl`, alter the
game economy, call or hook game remotes, or execute game ModuleScripts.
Use Potassium or another compatible runtime with HTTP, `loadstring`, and file
APIs for report export. The ordinary save presets remain independent.

<EconomyLauncher />

## What this version does

The analyzer discovers candidate currency, level, XP, rebirth, price, multiplier,
and collection fields in the local player and ReplicatedStorage. It reads numeric,
boolean, and string attributes/Value objects, relevant GUI text, and readable
ModuleScript Source properties. Config/data modules have priority over controllers.
Scanning is breadth-first with a quota per root so a large GUI cannot consume
the entire discovery budget.

The first live test target is PlaceId `120219252362013`. Discovery remains
generic; it does **not** assume XP formulas, rebirth availability, caps, or sell prices.
Local-player attributes and accessible configuration names were checked on a
connected Potassium client. This is not a verified reconstruction of that game's
entire economy.

## Observe, mark, export

1. Run the loader. A panel shows discovered fields and recorded changes.
2. Play normally. Before an action, type a label such as **Vente**, **Achat**, or
   **Rebirth**, then press **Marquer l'action**.
3. Perform that action yourself. Subsequent field changes are associated with
   the most recent marker by time. This is **not proof** the action caused them;
   passive income, boosts, and other events can happen at the same time.
4. Press **Exporter le rapport** when you want to write files. Observation continues.
5. Press **Arrêter l'observation** when finished. The report remains exportable.

Export is always manual. The default ten-minute duration stops observation
without exporting. Closing the panel stops the observers too. Re-running the
loader destroys the preceding observer session before starting a new one.

## Inspect client configurations

Many runtimes cannot read a game's Source properties directly. The initial
observation does **not** decompile automatically. Click **Analyser les modules**
to request a bounded, read-only decompilation pass over selected candidate modules.
It never `require`s or runs those modules, and it does not decompile server-only
code that was never replicated.

The source reader extracts numeric assignment candidates and short return
expression hints from relevant named functions. It skips comments and string
contents; it does not evaluate expressions or act as a full Luau parser.
Every source result remains a **client candidate**, not an authoritative server
rule. Full source files are not copied into reports. Truncation and parser limits
are recorded. Unsupported decompilation is reported; a yielding deadline ends
the source pass rather than accumulating background requests. A native call
that freezes the whole client cannot be interrupted by a Lua deadline.

## Reports

Each export creates a new `Game title - Economy Analysis` folder in the runtime's
file workspace, containing:

- **report.html**: a standalone, offline report with grouped fields, source
  candidates, manual markers, recorded changes, and unresolved questions.
- **report.json**: structured findings and time-stamped events, source paths,
  per-field observed ranges, candidate configuration literals/return expressions,
  sampling limits, truncation, and explicit unknowns.

Existing paths receive numbered suffixes. Unicode folder failures retry using an
ASCII title. File contents are verified by readback when `readfile` is available.
These reports stay on your PC; the tool does not upload them to the repository
or send them to an external analysis service.

## Read the evidence correctly

- `replicated_observation`: a value read from a replicated attribute/Value object.
  It establishes that client-visible value at that time, not its server formula.
- `display_observation`: text read from an interface. Abbreviated or rounded
  numbers remain approximate, with the original text preserved.
- `client_literal_candidate`: a numeric source assignment candidate.
- `client_return_expression_candidate`: a short source expression hint, neither
  executed nor proven to be a complete formula.
- `not_observed`: no matching candidate was found. This never means a feature
  is absent. A name/keyword alone cannot establish what a system does.
- `not_verified`: the XP formula, maximum level, maximum rebirth, or other rule
  remains unresolved. No maximum is inferred from a leaderboard or current level.

Numbers use English grouping and known K/M/B/T/Qa/Qi/Sx/Sp/Oc/No/Dc suffixes.
Unknown suffixes or ambiguous decimal-comma formatting stay unparsed. Large
numbers still have Luau floating-point precision limits. UI updates are throttled;
event omissions are counted. Observed minima/maxima are sample ranges, **not caps**.
Discovery is heuristic and can include false positives or miss unfamiliar names.

Shared PlayerData for other players, chat, leaderboard, and likely secret/token
paths are excluded. Own-player paths are normalized to `LocalPlayer`. This is a
scope filter, not a guarantee that arbitrary game UI contains no personal text;
review reports before sharing them.

## Settings and session API

Pass settings to the loader, for example:

```lua
local run = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/g0shtj0sh/CompleteSavePlace/v0.8.0/Economy%20Analyzer/analyze.luau",
    true
))
local session = run({MaxSeconds = 900, MaxModules = 20})
```

Defaults are `MaxSeconds = 600`, `MaxInstances = 30000` per discovery pass,
`MaxFindings = 500`, `MaxEvents = 2000`, `MaxModules = 20`,
`MaxSourceBytes = 100000` per module, and `SourceTimeout = 3` seconds.
Discovery repeats every ten seconds. Modules are not repeatedly decompiled on
each discovery pass. `Decompile = true` explicitly enables the source fallback
from startup; otherwise use the panel button. `ShowUI = false` requires the API
for marking, stopping, and exporting.

The active session is also available as `getgenv().CSP_EconomyAnalyzer`:

```lua
local session = getgenv().CSP_EconomyAnalyzer
session:mark("Vente")
session:analyzeSources() -- explicit bounded decompilation pass
session:export()         -- writes a new report folder
session:stop()           -- disconnects observers; report remains available
session:destroy()        -- also removes the panel
```

The analyzer works independently of the save preset's ModuleScript exclusion:
excluding module code from a `.rbxl` does not disable this separate investigation.

## Limits of this first version

No universal complete-economy claim is made. Source candidates, observations,
and temporal markers need interpretation and sometimes a game-specific adapter.
Server-only rules, hidden future unlocks, unrevealed drop probabilities, and
dynamic server modifiers may remain unknown. Regression tests and limited live
client checks validate discovery and observation, not complete balancing models.
