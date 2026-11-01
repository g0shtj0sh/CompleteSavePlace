---
sidebar_position: 2
title: Script Presets
---

# Script Presets

import PresetLauncher from '@site/src/csp/PresetLauncher';

Preset scripts select a configuration for the shared CompleteSavePlace
engine. They do not duplicate the serializer. The current development focus is
**UltraCompleteSavePlace**, the experimental maximum-coverage configuration.

Choose **Universal** or **Potassium**, then click **Copier le script**. Each
button copies the complete runnable loader shown below it. Potassium has a
[dedicated adapter](#potassium-profile) with native binary-property reads.

## DiagnosticSavePlace

An initial diagnostic with decompilation, bytecode capture, nil instances, and
compression disabled. Uses fallback property access. Start here to separate
file-writing and serialization failures from more advanced work.

<PresetLauncher id="DiagnosticSavePlace" />

## MapSavePlace

A full-root, map-focused export without decompilation or bytecode. It favors
scene properties and keeps default runtime-service exclusions. This is not a
strict map-only filter: accessible UI, sound, and other non-script content can
also be included.

<PresetLauncher id="MapSavePlace" />

## ScriptsSavePlace

An authorized script-focused export using the engine's `scripts` mode, bounded
decompilation and bytecode timeouts. Server-only scripts remain unavailable.
Structural instances can still appear as containers.

<PresetLauncher id="ScriptsSavePlace" />

## UltraCompleteSavePlace

**Experimental / current development target.** Uses full mode, decompilation,
bytecode capture, nil instances, special property access, non-archivable
instances, player content, and empty exclusion lists. Empty exclusions can
include large amounts of runtime content, so begin on a small test place.

This is the configuration we will diagnose and improve to preserve as much
accessible place content as possible. It is not a promise of complete capture
or a previously verified fix. Per-job timeouts cannot interrupt a native call
that blocks the entire client. `SafeMode`, script
termination, forced shutdown, and rendering changes stay disabled.

<PresetLauncher id="UltraCompleteSavePlace" />

## UltraNoModuleScripts

The Ultra configuration **without ModuleScript code**. It uses
`ExcludeModuleScripts = true`: module containers become Folders with the same
names, preserving descendant models, meshes, and the hierarchy. Their source
and bytecode are not read. Earlier versions excluded the entire module subtree.
Script and LocalScript extraction stays enabled with the usual Ultra settings.
Scripts that require an excluded module may no longer work in the export.

Choose Universal or Potassium below and click **Copier le script**.

<PresetLauncher id="UltraNoModuleScripts" />

## UltraCompleteSavePlaceGPS

Ultra with **experimental GPS collection before export**, including ModuleScript
code. The collector requests streaming regions on a bounded X/Z grid and retains
received Workspace instances and their observed hierarchy.

<PresetLauncher id="UltraCompleteSavePlaceGPS" />

## UltraNoModuleScriptsGPS

The same GPS collector with the UltraNoModuleScripts engine configuration.
Module containers become Folders; descendant models stay in the captured tree.

<PresetLauncher id="UltraNoModuleScriptsGPS" />

## GPS streaming collection

**Experimental, not yet verified on a live streaming map or by reopening its
output in Studio.** These presets add a collection stage before ordinary Ultra
export. They request regions with Roblox's `RequestStreamAroundAsync`; they do
not teleport the character, change streaming settings, or execute game remotes.

The initial grid is centered on the character (or camera when the character is
unavailable). Anchored geometry observed on the client can expand the estimated
X/Z bounds. Those bounds describe observed content, **not the real map boundary**.
A distant missing district may never be discovered. Use manual bounds when known.
Requests remain subject to server behavior, bandwidth, and client memory.

### Run and stop

1. Choose one of the GPS launchers above and select Universal or Potassium.
2. Run the copied loader. The GPS panel shows attempted points, an estimated
   grid total, retained instance count, and a progress bar. The estimate can grow.
3. Let the bounded traversal finish, or continue exploring manually once it pauses.
   **Only click Exporter la collecte when you want the export to start.**
   Reaching a limit or exhausting the grid never starts an export.
4. Ordinary serialization starts only after your Exporter button action. Open the resulting place in
   Studio and inspect the `gps` section of `report.json`.

The GPS bar measures **point attempts**, including unsuccessful requests. It
never represents a percentage of the real map recovered. A returned streaming
request does not establish that a region is fully loaded. If the progress panel
cannot be created, the GPS preset fails without exporting: a visible Exporter
button is required. Closing the panel externally also aborts without exporting.

### Default budgets

- `Step = 512`: distance between grid points in studs. These are request points,
  not Roblox's internal streaming chunks.
- `InitialRadius = 1024`, `MaxRadius = 4096`: initial X/Z range and hard maximum
  distance on each axis from the starting position.
- `MaxCells = 196`, `MaxSeconds = 600`: at most 196 point attempts or 10 minutes
  of automatic traversal, after which GPS waits for your click. The later Ultra
  export has its own duration.
- `RequestTimeout = 4`, `SettleSeconds = 1`: bounded request duration followed by
  a short interval to receive instances. One request runs at a time. An overdue
  yielding request ends collection rather than accumulating background requests.
- `MaxInstances = 300000`: maximum retained Workspace nodes. This is an object
  count budget, not a RAM measurement or a guarantee against native freezes.
- `AutoExpand = true`: expand from observed anchored geometry within MaxRadius.
  Supplying `Bounds` makes the X/Z area fixed. `Height` defaults to the initial
  character/camera Y coordinate; a single horizontal pass does not cover every floor.

After a budget is reached, automatic requests pause and **no export starts**.
The panel stays open; newly observed regions from manual exploration are retained
within MaxInstances. At the object limit, retention stops too, but the script
still waits for your Exporter click. Clicking during traversal stops requests and
exports the current collection. A grid exhausted
within estimated bounds does not establish full coverage. Native calls that block
the whole client cannot be interrupted by Lua deadlines or the stop button.

### Optional custom area

Pass GPS settings to the **preset loader**, not to the serializer's options table.
For example, a fixed area within 2048 studs of the starting player:

```lua
local origin = game:GetService("Players").LocalPlayer.Character:GetPivot().Position
local run = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/g0shtj0sh/CompleteSavePlace/v0.8.0/Executors/Potassium/Script%20Presets/UltraNoModuleScriptsGPS.luau",
    true
))
run({GPS = {
    Bounds = {
        Min = origin - Vector3.new(2048, 0, 2048),
        Max = origin + Vector3.new(2048, 0, 2048),
    },
    Step = 512,
    MaxRadius = 4096,
    MaxCells = 100,
    MaxSeconds = 600,
}})
```

Use the Universal path or `UltraCompleteSavePlaceGPS.luau` to switch profiles or
module selection. Bounds must fit within MaxRadius of the starting position;
invalid settings fail before collection. The grid can round to adjacent request
points, while all point coordinates remain within the hard MaxRadius limits.
For local development, also install `StreamingCapture.luau` at
`CompleteSavePlace/StreamingCapture.luau` alongside the engine.

### What is retained

The archive keeps **original instance references**, not clones, so native geometry
readers still receive original objects. It records observed parent/child links,
Name, and BasePart CFrame/Size, then supplies that tree to the shared serializer.
Streamed-out nodes are excluded from separate NilInstances recovery to avoid
moving them out of the captured Workspace hierarchy. Duplicate names remain
valid; repeat observations of the same object do not create duplicates.

Remaining properties and geometry are read during export. If the game destroys
or recreates objects, a retained reference may become unreadable or recreated
objects may appear twice. Dynamic objects are not a synchronized world snapshot.
**Terrain voxel regions are not accumulated**; missing Terrain and unsupported
union data remain separate limitations. The collector does not reconstruct
private assets, server-only content, or detailed meshes from LOD placeholders.

### GPS report

`report.json.gps` records `reason`, `exportTrigger: "button"`, `manualWaitSeconds`, `coverage: "unverified"`, point attempts,
requests completed/failed, retained object count, elapsed collection time,
estimated bounds, and the budgets. Its `points` list records request coordinates,
request return/success status, elapsed time, and newly retained instances per point.
These counts describe observations, not region completeness. Reasons include `grid_exhausted`, `cell_limit`,
`time_limit`, `instance_limit`, `user_stopped`, `request_failures`,
`request_deadline`, and `streaming_disabled`. With streaming disabled, the
collector inventories the current Workspace and proceeds without region requests.

## Versioned loaders

Run a preset in a compatible environment with HTTP access and file APIs:

```lua
loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/g0shtj0sh/CompleteSavePlace/v0.8.0/Script%20Presets/UltraCompleteSavePlace.luau",
    true
))()
```

Replace the final filename with `DiagnosticSavePlace.luau`,
`MapSavePlace.luau`, `ScriptsSavePlace.luau`, or
`UltraNoModuleScripts.luau` for a different goal.
The [catalog on GitHub](https://github.com/g0shtj0sh/CompleteSavePlace/blob/main/Script%20Presets/README.md)
shows each loader and its exact option values.

## Local installation

For local development, copy the engine and selected preset into the runtime's
file workspace:

```text
CompleteSavePlace/
  saveinstance.luau
  Script Presets/
    DiagnosticSavePlace.luau
    MapSavePlace.luau
    ScriptsSavePlace.luau
    UltraCompleteSavePlace.luau
    UltraNoModuleScripts.luau
```

Execute the chosen preset through the runtime's local script facility. If your
layout differs, change `CORE_PATH` at the top of the preset. Set
`USE_LOCAL_CORE = true` to opt into that local engine; the default downloads
the pinned version. A missing local file produces an error. External helpers are
still fetched by the engine and are not yet pinned.

Every preset performs a basic text write/read probe inside its own export folder,
and distinguishes a returned function from an existing file. Output contents
and Studio compatibility remain unverified until you inspect them.

Wrappers write `<export-folder>/report.json` with engine identity, file evidence,
class counts, and omitted binary property columns. A report-writing error is
printed explicitly. Use the [missing geometry guide](GEOMETRY.md) when objects
or surfaces are absent.

Since 0.4.2, all presets also write `<export-folder>/progress.json` during execution,
before script jobs and compression calls. Keep this file if the client freezes
before a final report is written. The final report includes `scriptJobs` and
`compression` counters. See [frozen exports](TROUBLESHOOTING.md) for interpretation.

## Output folders

Since 0.6.1, Universal and Potassium presets group each run in a folder named
after the game and selected preset. For example:

```text
(学乱) Gakuran - UltraNoModuleScripts/
  (学乱) Gakuran.rbxl
  progress.json
  report.json
```

The place file uses only the game title. The preset appears in the folder name.
If that folder already exists, the next run adds ` (2)`, then ` (3)`, to the
folder name only. Earlier exports and their
reports are preserved, including incomplete runs.

Game titles come from MarketplaceService, falling back to the DataModel name
or `Place <placeId>` when metadata is unavailable. Unicode characters are kept;
filesystem-invalid characters are replaced with spaces and long titles are
shortened without splitting a UTF-8 character. The preset name stays intact.

If the runtime rejects Unicode folder paths, presets retry with the readable
ASCII portion of the title (or `Place <placeId>`). The folder and `.rbxl` use
that fallback, while `report.json` retains the original game name.

The runtime must provide `makefolder` and `isfolder` alongside the existing file
APIs. A short-lived `write-test.tmp` checks writing inside the chosen folder;
it is removed when `delfile` is available. If folder creation or verification
fails, the preset stops before loading the exporter. The shared engine cache
remains in `completesaveplace_cache/`.

## Changing a configuration

Edit `Script Presets/presets.json`, then run:

```powershell
python scripts/generate_presets.py
```

The generated scripts and catalog stay in sync. Run the repository checks and
compile the generated scripts before committing. Runtime observations belong
in the issue report, including the exact preset revision and options.

## Potassium profile

Select **Potassium** above any preset and click **Copier le script**. The loader uses the dedicated adapter with the same shared serializer. Switch back to **Universal** to use ordinary capability discovery.

### What the adapter adds


- **Binary geometry:** `getbspval(instance, property, false)` attempts raw
  `BinaryString` reads before ordinary hidden-property fallbacks. No Base64
  text is written as binary geometry. Lua errors or invalid return types fall
  through to the existing reader. Empty strings remain valid byte sequences.
- **Explicit bindings:** documented `gethiddenproperty`, `getnilinstances`,
  `getscriptbytecode`, Base64 codecs, and GUI/clipboard helpers are bound
  directly, avoiding heuristic method discovery for this edition.
- **Compression:** `crypt.lz4compress` is offered to the existing format check
  and benchmark. Availability does not guarantee it is selected; incompatible
  output is rejected and existing fallbacks remain available.
- **Large writes:** Map, Scripts, and Ultra enable `AlternativeWritefile`.
  The existing writer uses approximately 4 MB append batches where supported,
  reducing whole-file string concatenation. Binary probes and ordinary writer
  fallbacks remain active.
- **Script extraction:** since 0.4.2, the shared engine reads each script's
  bytecode once per export and passes cached bytes to Potassium's documented
  `decompile` overload. Both Ultra configurations benefit when run on Potassium.
  The standard Ultra includes ModuleScripts; UltraNoModuleScripts excludes them.
  Version 0.4.4 removes forced per-script frame waits and deferral of immediately
  completed jobs. Native API latency remains executor-dependent; the selection
  and timeout settings are unchanged.
- **Reports:** `profile: "Potassium"` and `runtimeAdapter` identify the executor
  version, available APIs, and binary-read attempts, successes, and failures.
  `sharedCoreUrl` and `sharedCoreBytes` identify the second-stage source, while
  the wrapper's `sourceOrigin` identifies the dedicated entry point.

Both entry points use the same serializer. The Potassium entry point is under
`Executors/Potassium/saveinstance.luau`; its five presets are under
`Executors/Potassium/Script Presets/`. Loaders pin both stages to v0.8.0.
For local adapter development, edit its `CORE_URL` as well as the preset's
`CORE_PATH`; opting into a local adapter alone still downloads its pinned core.

### Reference review and limits

The official [reference index](https://docs.potassium.pro/llms.txt) and
[complete reference](https://docs.potassium.pro/llms-full.txt) were read on
2026-10-16. All **198 indexed pages** were present in the complete reference.
The repository's `Executors/Potassium/API_REVIEW.md` records the selection and
the snapshot hashes, including APIs considered but not integrated.

`getpcd` returns a hash and binary data. Its page does not specify how to pack
those values into the serializer's `PhysicalConfigData` property, so this
adapter does not invent a packing scheme. It also does not substitute
Potassium's built-in `saveinstance`, whose options and serializer differ.

Reading the reference establishes an API contract, not compatibility with the
installed executor build. Mock tests and compilation cannot validate Roblox
native calls or catch native crashes. Studio reopening and the missing road
still require a fresh export. See [missing geometry](GEOMETRY.md).

The 0.4.2 progress checkpoint is written before script jobs and compression.
Keep `<export-folder>/progress.json` if Potassium freezes. Lua deadlines cannot
interrupt native code that blocks the entire client; see
[troubleshooting](TROUBLESHOOTING.md). Source columns and chunks over 8 MiB are
stored uncompressed, which can increase file size without dropping their data.

Sources: [binary-property reads](https://docs.potassium.pro/api-reference/Reflection%20Library/getbspval),
[LZ4](https://docs.potassium.pro/api-reference/Crypt%20Library/crypt.lz4compress),
[physical configuration](https://docs.potassium.pro/api-reference/Reflection%20Library/getpcd),
[file appending](https://docs.potassium.pro/api-reference/FileSystem%20Library/appendfile).
