# Changelog

## 0.6.4 ? 2026-10-17

- Omit empty Folder placeholders created for unsupported services. Real services
  and ordinary empty folders remain unchanged; unsupported services with children
  retain their containers and content. Reports count skipped empty service containers.
- Added collection regression coverage for each case, including parent references.

## 0.6.3 ? 2026-10-17

- Preserved reloadable `MeshPart.MeshContent`, `MeshPart.TextureContent`, and
  `PartOperation.Content` references when Reflection marks them non-serialized.
  This fixes a metadata-dependent omission shared by universal and Potassium exports.
- Verified on the connected client: the previous engine drops the two modern
  road Content columns with Reflection enabled; the fixed engine produces a
  byte-identical file to the isolated road model confirmed visible in Studio.
- Added a regression test using the actual metadata selector, with conflicting
  Reflection flags, a negative control, and checks that unrelated filters remain active.

These fields preserve asset references; they do not embed private assets or
restore unsupported native union data. Visual confirmation of a full affected
place remains separate from the metadata regression test.

## 0.6.2 — 2026-10-17

- Kept the preset label in export folder names only; the `.rbxl` uses the game
  title without a preset or repeated-export suffix.
- Fixed UltraNoModuleScripts dropping models nested under ModuleScripts.
  `ExcludeModuleScripts` replaces module containers with named Folders, keeping
  descendants and parent references without reading module source or bytecode.
- Added collection regression coverage, including the old subtree-loss behavior
  as a negative control. Reports count converted containers and include property
  datatypes and guard states when binary columns cannot be saved.

This does not repair inaccessible union geometry. The inspected 0.5.1 export
omitted `UnionOperation.SolidMeshHolder` with a failed `NetAssetRef` self-check;
restoring those native values still requires a connected-client investigation.

## 0.6.1 — 2026-10-17

- Grouped preset exports in a `Game title - Preset` folder, with a matching
  `.rbxl` filename and concise `progress.json` / `report.json` companions.
- Preserved Unicode titles, sanitized filesystem-invalid characters, and bounded
  title length without splitting UTF-8. Metadata failures use a name/ID fallback.
- Added numbered folder/file suffixes for repeated exports instead of long
  timestamp/random filenames. Folder checks and an in-folder write probe run
  before loading the exporter; existing runs are not overwritten.
- Applied the shared wrapper change to all Universal and Potassium presets,
  with regression cases for Unicode, collisions, fallbacks, and folder errors.

## 0.6.0 — 2026-10-17

- Renamed the project, repository links, API, presets, runtime namespace, and
  branding to CompleteSavePlace. The shared engine keeps `saveinstance.luau`.
- Replaced the banner and consolidated presets into one page, keeping the
  Universal/Potassium switch and copy button beside every loader.
- Removed remaining XML exporter-credit comments. Recovered script source
  retains original/native decompiler comments and optional bytecode data.
- Removed the obsolete Lua variant, placeholder TODO file, and generated
  metadata dumps; retained metadata tools and runtime regression coverage.
- Preserved prior executor safety state during cache migration, including
  native-crash markers.

## 0.5.1 — 2026-10-17

- Added UltraNoModuleScripts in Universal and Potassium: the Ultra configuration
  with ModuleScript instances and their descendants excluded from collection.
  Script and LocalScript extraction settings remain unchanged.
- Added copy launchers to both preset guides and the API configuration explorer.
  Excluded modules can leave scripts that require them unable to run.

## 0.5.0 — 2026-10-17

- Added a compact status panel with a progress bar below the current operation.
  Binary property/source counts, XML instance counts, and post-write byte counts
  drive each stage. Unknown totals show an indeterminate indicator, never a
  percentage inferred from elapsed time. This is stage progress, not a whole-export ETA.
- Throttled GUI refreshes to at most 10 Hz and released the heartbeat connection
  with the existing export cleanup. Checkpoint reports include the current meter.
- Added `WorkBudgetMs` (default 4, clamped to 1–16). Collection, property reads,
  XML traversal, and large binary encoding loops now cooperate with the scheduler
  more frequently. Binary buffers carry their own callback; no global hook is used.
- Added post-append writer counters and tests that preserve exact output bytes,
  including large segments and partial write failures.
- Verified 32 binary encoders against 0.4.4 byte fixtures across cooperative yields.
  Tested the native GUI's construction, bounds, counter width, and caption fit on
  the connected client without replacing its ongoing export.

These changes apply to the shared Luau engine used by both Ultra profiles.
FPS during a full 0.5.0 export remains unmeasured. Native API calls, compression,
and individual large allocations can still block the client beyond the Lua
work budget. Existing exports keep their originally loaded engine.

## 0.4.4 — 2026-10-17

- Removed the forced display-frame wait before every primary-engine bytecode
  and decompilation call. Script jobs use the existing periodic yield budget.
- Start each independent worker immediately so synchronous results do not wait
  for a deferred scheduler turn. Yielding jobs retain deadline polling,
  cancellation, late-result rejection, and packed return values.
- Track scheduler waits when enforcing the work-slice budget, avoiding another
  redundant frame wait after an asynchronous job. Zero deadlines skip native work.
- Added cumulative `scriptJobs.bytecodeSeconds` and `decompileSeconds` to reports.
- Added regression coverage for fast batches through the actual UI/job/bytecode
  pipeline, periodic yielding, and deadlines. A live mocked-API microbenchmark
  confirms reduced scheduling overhead; real export throughput remains unmeasured.
  A single native ModuleScript bytecode read also succeeded through the new path.

Both Ultra profiles keep their selection, bytecode capture, decompilation,
and timeout settings. These changes affect the shared Luau engine. Native API
latency and native crash behavior are unchanged; an already-running export
continues using the engine it originally loaded.

## 0.4.3 — 2026-10-17

- Removed the exporter-added `Saved by CompleteSavePlace` and `Original
  Source` comment prefixes from recovered/decompiled script Source in both
  engine variants. Both preset profiles use the updated shared Luau engine.
- Preserved comments returned with recovered source, native decompiler output,
  bytecode comments selected by `SaveBytecode`, and diagnostic failure messages.
  The optional export README and repository license/attribution remain separate.

This release changes source presentation; it does not resolve or validate the
native crash observed during the 0.4.2 initialization test.

## 0.4.2 — 2026-10-17

- Replaced the primary engine's shared pending-job slot and manual coroutine
  resumption with independent bytecode/decompilation jobs and deadline checks.
- Memoized each script's bytecode per export; Potassium decompilation reuses
  those bytes through its documented overload. Failed decompilations are no
  longer cached as successful source.
- Added progress checkpoints before script jobs, property extraction/encoding,
  compression, and writing. Presets write `<output-path>.progress.json` while
  running; final reports include script-job and compression counters.
- Yield more frequently during collection and binary property reads. Binary
  Source columns and chunks over 8 MiB bypass compression; compressor errors
  fall back to the original bytes. Output can be larger without omitting data.
- Added actual-function scheduler, bytecode-cache, and chunk-format regressions;
  extended both preset profiles and Potassium adapter tests.

These changes affect the shared Luau engine used by both Ultra presets. The
reported client freeze still requires a fresh runtime test. Lua deadlines cannot
interrupt a native call that blocks the entire client. The older `.lua` engine
does not receive these runtime changes.

## 0.4.1 — 2026-10-17

- Removed duplicated upstream branding and the Discord link from both engine
  headers, generated export text, and the English/French README presentation.
- Centralized attribution and provenance in NOTICE.md and the unchanged LICENSE.
- Updated versioned preset loaders and the Potassium entry point to v0.4.1.

## 0.4.0 — 2026-10-16

- Added direct runnable-script copy buttons to all preset sections and the API
  Explorer, with Universal/Potassium selection and manual clipboard fallback.
- Added `Executors/Potassium/` with a dedicated entry point and four generated
  presets sharing the primary serializer.
- Added native raw BinaryString reads through getbspval, explicit API bindings,
  native LZ4 candidate validation, and profile/capability/read-counter reports.
- Enabled the existing append writer for Potassium Map, Scripts, and Ultra.
- Reviewed all 198 pages in the official Potassium reference and documented
  adopted APIs and deferred integrations without duplicating its source text.
- Expanded mock coverage to both sets of presets and adapter contracts.

Installed Potassium behavior and the missing road still require a fresh Roblox
export and Studio inspection. The universal path retains its existing fallbacks.

## 0.3.0 — 2026-10-16

- Replaced the API's large type block with a searchable option explorer,
  category filters, preset comparisons, and copyable configurations. Redesigned
  the developer homepage and responsive theme.
- Fixed primary-engine hidden-property failures incorrectly disabling later
  reads of the same datatype. Retained self-check and native-crash guards.
- Added a primary-engine report with collected class counts and omitted binary
  property columns, plus a JSON sidecar from every preset wrapper.
- Presets now download the pinned engine by default; local development is an
  explicit opt-in. Source identity and engine version are recorded.
- Added reader regression coverage and expanded wrapper mock scenarios.

The missing road in the reported export still requires a new Roblox export
and Studio inspection. XML property omission auditing is not implemented.

## 0.2.0 — 2026-10-16

- Public repository and public GitHub Pages documentation.
- Moonwave API reference generated from the primary Luau source, with guides,
  local search, responsive homepage, and the CompleteSavePlace theme.
- Added `Script Presets`: DiagnosticSavePlace, MapSavePlace,
  ScriptsSavePlace, and the experimental UltraCompleteSavePlace target.
- Presets share the engine, prefer local source, and otherwise use the
  `v0.2.0` engine. Each includes a basic write/read probe and explicit output
  evidence without claiming file validity.
- Generated catalog checks, 44 mocked wrapper scenarios, preset compilation,
  built-site checks, and automatic documentation deployment.

Ultra's export behavior remains unverified in Roblox and Studio; this milestone
establishes the configuration we will diagnose, not a complete-backup guarantee.

## 0.1.0 — 2026-10-16

First CompleteSavePlace foundation, based on the supplied upstream snapshot.

- New identity, logo, README banner, and Moonwave assets.
- Updated project links, examples, documentation classes, and function names.
- Dedicated `CSP` global namespace and `completesaveplace_cache/` disk cache.
- English and French presentation, usage, troubleshooting, architecture, roadmap.
- Issue forms, contribution guide, repository validation, and compilation CI.
- Preserved original license, required attribution, and source import history.

This milestone does not certify runtime compatibility or a successful Studio
export. Serializer and writer redesign remain future work.
