# Usage

## Runtime and entry points

For experiences you own, prefer Roblox Studio's built-in export options first.
The inherited runtime expects environment-specific file, HTTP, and introspection
functions, which are not generally available in standard Scripts or LocalScripts.
Support varies by runtime; this distribution has no validated compatibility
matrix yet.

`saveinstance.luau` is the primary entry point. It returns the
`completeSavePlace` function, which accepts an options table. Existing file
names are retained for compatibility. The Potassium adapter returns the same
function with explicit executor bindings; the obsolete Lua variant was removed.

## Access to the source and presets

The repository and documentation are public. Clone the project:

```powershell
gh repo clone g0shtj0sh/CompleteSavePlace
```

Choose a versioned preset loader from [Script Presets](PRESETS.md), or load the
checked-out script using your runtime's local script facility. No GitHub token
is required. Presets download the root engine pinned to `v0.6.4` by default.
For local development, explicitly set `USE_LOCAL_CORE = true` and configure
`CORE_PATH` in the wrapper. A missing local file then fails visibly.

The project tag pins the entry point. External helpers still load from upstream
`main` URLs; the entire dependency chain is not reproducible yet.

## First diagnostic

1. Use a small experience you own or are authorized to archive.
2. Record the source revision, Roblox version, and runtime version.
3. Find the runtime's real file workspace; relative paths are resolved there.
4. Write and read back a small unique text file using its file APIs.
5. Start with the DiagnosticSavePlace configuration in [Script Presets](PRESETS.md).
6. Confirm the output exists, then open and inspect it in Studio.

## Important options in the primary source

These descriptions are based on the supplied source, not runtime certification.
The inline `CustomOptions` documentation in `saveinstance.luau` gives more detail.

- `FilePath`: output name or runtime-relative path. Explicit paths can overwrite
  existing output; use a unique filename for each diagnostic.
- `mode`: `full`, `optimized`, or `scripts`; controls selected roots, without
  guaranteeing every property, object, or asset will be captured.
- `Binary`: selects binary output. `XML = true` is the inverse alias.
- `CompressionMode`: `zstd`, `lz4`, or `false`, subject to runtime capabilities.
- `Decompile` and `SaveBytecode`: require optional runtime APIs. Disable both
  initially to isolate serializer and writer behavior.
- `IgnoreSpecialProperties`: selects fallback property access paths; it is not
  a guarantee that every unusual property will be safely skipped.
- `SafeMode`: deliberately disconnects the client and can enable script
  termination and rendering changes. Leave false for initial diagnosis.
- `KillAllScripts`, `BoostFPS`, `ShutdownWhenDone`: change client behavior;
  explicitly disable all three for the first run.
- `AlternativeWritefile`: uses an append-based writer where supported. Existing
  probes and fallbacks still need validation in Roblox for this distribution.
- `ShowStatus`, `__DEBUG_MODE`: existing status display and console diagnostics.
- `WorkBudgetMs`: cooperative Lua work budget, default `4` milliseconds and
  clamped to `1–16`. Smaller values leave more scheduler time to the game and
  can lengthen exports. This is not a guaranteed FPS setting or a native-call timeout.

## Verify the result

Preset runs create `Game title - Preset/Game title.rbxl` with
`progress.json` and `report.json` in the same folder. Repeated exports use a
numbered folder suffix. See [output folders](PRESETS.md#output-folders)
for Unicode names, title fallbacks, and folder API requirements. Direct engine
calls continue to honor the `FilePath` you supply.

Check the exact path, existence, plausible file size, and Studio opening.
Inspect representative models, meshes, materials, UI, and authorized scripts.
A return from the function does not prove that the output is valid.

Presets write a companion `<export-folder>/report.json` after the attempt. It records
the engine version, source origin, file existence, collected classes, and
omitted binary property columns. `ok` means the export function completed;
`validation` stays `unverified`. XML property omissions are not instrumented.
See [missing geometry](GEOMETRY.md) for interpreting the report.

Since 0.4.2, presets also write `<export-folder>/progress.json` during the run.
It identifies the latest phase and script job or binary property column, even
when a final report cannot be produced. Script-job failures and compression
fallbacks appear in the final report. If the client freezes, keep the progress
file and console output; see [troubleshooting](TROUBLESHOOTING.md).

Server-only data, private DataStores, unloaded streamed instances, and restricted
assets can be absent. An asset ID is a reference, not an embedded binary asset.

## Exported script comments

The engine adds no exporter credit or
`Original Source` URL above recovered/decompiled script Source. Existing source
comments and anything returned by the native decompiler are preserved. With
`SaveBytecode = true`, the separate Base64 bytecode comment is still prepended;
Ultra and Scripts enable that option. Failed or inaccessible source can contain
a diagnostic comment instead of code. Decompiled output is reconstructed code,
not a guarantee of the original source text.

`ReadMe = true` adds a separate export README; it does not add credits to each
game script. Repository attribution is maintained in LICENSE and NOTICE.md.

## Bytecode read speed

Version 0.4.4 removes per-script display-frame waits and deferred dispatch for
immediate script jobs. The engine keeps periodic yields, the per-export bytecode
cache, and deadlines for yielding jobs. This reduces scheduling overhead without
changing Ultra's instance selection or script extraction settings.

Real speed depends on the native APIs, frame scheduling, and number of scripts.
Ultra's empty exclusion list also includes Roblox's internal CorePackages and
CoreGui content when accessible. Disabling bytecode or excluding these instances
would change coverage; the optimization does neither. A native call that blocks
the client still cannot be preempted. Reports include cumulative handler timings
in `scriptJobs.bytecodeSeconds` and `decompileSeconds`.

Start a new export with the new version to use the optimization. Existing runs
keep their loaded engine; avoid starting another export in the same client
while one is active.

## Live progress and responsiveness

Since 0.5.0, `ShowStatus` displays a progress bar below the current operation.
The caption identifies exactly what is counted: a binary property column such
as `ModuleScript.Source`, XML instances, or bytes written. Source counters advance
after processing each instance, including cache hits and diagnostic placeholders.
They do not certify successful recovery of every source.

The bar resets for the next stage/property. It is not an overall export percentage
or a time estimate. Preparation, collection, encoding, and compression can have
unknown totals; those stages use an animated indicator without a percentage.
The final completed state is set after the export function finishes; inspect the
file in Studio to establish validity. The current meter is also in progress JSON.

GUI refreshes are limited to 10 Hz. The default `WorkBudgetMs = 4` replaces the
previous approximately 100 ms Lua work slice; large binary value loops check
the budget every 256 values. XML traversal also yields periodically. Work is
preserved, but more frequent scheduling can trade export throughput for game
responsiveness. Native calls, compression, large allocations, and string copies
can exceed the budget. Normal FPS cannot be guaranteed during a full export.

An existing export keeps its loaded code. Use a new versioned preset on the
next run to get the panel and scheduling changes; do not start a second export
in the same client while one is active.

## Namespace changes

Runtime globals now use `CSP`, including `CSP_scriptcache` and `CSP_placeName`.
The disk cache is `completesaveplace_cache/`. Executor safety state is also read
from the previous cache when available, preserving datatype self-check failures
and native-crash markers. Old cache files are not deleted. Avoid running two
versions against the same output file.
