# Architecture and current scope

## Current implementation

The runtime uses one shared engine, `saveinstance.luau`, and a dedicated
Potassium adapter. The obsolete Lua variant, placeholder TODO file, and stale
generated metadata dumps were removed in 0.6.0. `Tools/` retains metadata
dumpers for future property investigations; their outputs are ignored.

The implementation performs capability discovery, metadata loading, option
resolution, instance selection, property extraction, serialization, and output.
Some write probes and fallbacks already exist; they do not establish a validated
end-to-end diagnostics pipeline.

## External dependencies

The Luau entry point loads `StreamBuffer` and `UniversalMethodFinder` from
`luau/SomeHub`. These
names identify external dependencies, so their URLs remain intact.

The runtime also queries external metadata and API dumps. Pinning the root
script tag does not pin these dependencies. Vendoring or pinning them, with
their provenance and licenses, is future work.

## Foundation changes — 2026-10-16

- CompleteSavePlace logo, banner, documentation, and repository configuration.
- Updated project links, function names, and documentation classes.
- Global state prefix changed to `CSP`; disk cache to `completesaveplace_cache/`.
- Repository attribution is preserved separately from recovered script source.
- Repository consistency checks and Luau compilation CI.

Serializer algorithms, compression, property coverage, and output verification
have not been redesigned in this milestone. The import commit preserves the
original files for comparison.

## Documentation and preset layer

Moonwave 1.4.2 generates the API from `saveinstance.luau`. Guides and a local
search index are built into the static Docusaurus website, deployed by GitHub
Actions to GitHub Pages.

`Script Presets/presets.json` defines the five configurations. The generator
combines them with a shared wrapper template. Wrappers perform a basic text
write/read probe and load the pinned `v0.6.4` engine by default. Local development
requires an explicit `USE_LOCAL_CORE = true`. They record source identity,
exceptions, and file existence in a JSON sidecar separately from file validity.
The actual serializer is not duplicated.

UltraCompleteSavePlace is the experimental configuration for the next
diagnostic work. Mock tests validate wrapper branches, not Roblox serialization.

## Property reads and reports in 0.3.0

The primary engine distinguishes an ordinary hidden-property read failure from
a failed datatype self-check or a native crash. An inaccessible property no
longer disables subsequent properties sharing its datatype. Ambiguous cached
failures from older versions are reset; native-crash markers stay blocked.

Binary property columns are omitted as a whole if a value cannot be read.
The returned report counts these columns, records up to 256 failure samples,
and flags selected geometry properties for investigation. XML omission auditing
is not implemented. Neither report creation nor the existing writer verifies
that Studio can open the result.

The API Explorer uses generated option metadata and preset values. The build
integrates it through a webpack component alias in Moonwave's generated
Docusaurus configuration; dependency source files remain untouched.

## Executor adapters in 0.4.0

Version 0.4.0 adds a narrow adapter argument to the primary source chunk.
`Executors/Potassium/saveinstance.luau` supplies canonical native functions
without global hooks or a second serializer. BinaryString reads can use its
protected raw reader before the ordinary fallback chain; dedicated presets
explicitly enable those reads. See [Potassium](PRESETS.md#potassium-profile) for contracts and
the reference review. The universal entry point still uses method discovery.

## Script jobs and checkpoints in 0.4.2

Each bounded bytecode/decompilation invocation owns its arguments, worker,
result, and deadline. The caller polls through `task.wait`; it never manually
resumes the serializer coroutine. Expired workers are cancelled when possible
and late results are rejected. A native call blocking the client also blocks
Lua scheduling, so this is not native preemption or a total export time budget.

Bytecode results, including failures, are memoized per Instance for one export.
Only successful decompilations enter the source cache. On Potassium, cached
bytecode is passed to the documented decompile overload. ModuleScripts remain
eligible under the existing selection and ignore options.

The source chunk accepts `onProgress` through its runtime adapter. Generated
wrappers forward it, including through the Potassium entry point, and write a
JSON checkpoint while the engine runs. The final report contains script-job
counts, limited failure samples, compression counters, and failure context.
Property checkpoints currently instrument the binary path; they do not audit
every native call or establish output validity.

Binary Source columns and chunks larger than 8 MiB bypass compression. Native
compressor exceptions and invalid empty/non-string results fall back to the
original bytes with an uncompressed chunk header. This can increase output
size; it does not remove source or geometry. Collection and binary reads yield
when their work slice exceeds approximately 100 ms; individual native calls
and encoders can still exceed that interval.

## Job dispatch in 0.4.4

Independent workers start with `task.spawn`. A synchronous result can return
without waiting for another frame; a yielding call still uses deadline polling.
Polling updates the last-yield timestamp so the next job does not add another
frame wait after time already ceded to the scheduler. A zero timeout starts no
native work.

Bytecode and decompilation status updates no longer force a frame before each
call. `runScriptJob` instead checks the existing approximately 100 ms work-slice
budget. Cached bytecode remains shared between source caching and bytecode
capture. Selection, decompilation settings, and deadlines are unchanged.
`scriptJobs.bytecodeSeconds` and `decompileSeconds` accumulate handler wall time;
they are not CPU timings or the total export duration.

Actual-function tests cover fast batches, periodic yields, deadlines, independent
jobs, cached failures, and packed values. A mock-API microbenchmark on the live
client confirms lower scheduling/UI overhead; it does not establish a multiplier
for real native reads or a complete place export.
One native ModuleScript read also succeeded through the updated job pipeline;
this is a compatibility sample, not a full export or Studio validation.

## Progress UI and work slices in 0.5.0

The primary engine keeps an independent `Progress.meter` with a label, completed
count, and optional total. This survives changes from property reading to an
individual bytecode/decompilation job. Binary reads count attempted instances
within the current property column; XML counts processed instances. Append
progress advances only after each native write returns. Unknown totals remain
indeterminate. No estimated duration or global percentage is manufactured.

The GUI reads this state at most every 100 ms. Disk checkpoints retain their
separate policy, including pre-call checkpoints for script jobs. Cleanup releases
the GUI heartbeat and spinner. The optional `ShowStatus = false` path remains
headless while reports and cooperative scheduling continue.
The exporter excludes its own status GUI from collection, including when the
GUI falls back to CoreGui; game interfaces remain governed by the selected preset.

`WorkBudgetMs` defaults to 4 ms and clamps to 1–16. Binary StreamBuffers carry a
per-buffer yield callback, checked every 256 values in the encoding helpers.
Encoding order and byte planes are unchanged. Regression fixtures cover 32
types with 1025 values each, both with and without yielding, against 0.4.4 bytes.
Collection, property traversal, XML, shared strings, and chunk assembly also
yield between work slices. This is cooperative Lua scheduling, not preemption
of native work, and it cannot guarantee a target frame rate.

The connected-client check instantiated the actual GUI and verified its native
bounds, bar width, placement below the status label, and caption fit. A full
0.5.0 export, FPS comparison, and Studio reopening remain to be tested.

## Next engine work

The next pipeline should expose preflight, write probe, inventory, extraction,
serialization, writing, validation, and reporting as measurable phases. Logs
should be buffered and repetitive failures aggregated. A backup needs evidence
about its actual output. See [the roadmap](ROADMAP.md) for unimplemented work.

## Rename and cleanup in 0.6.0

The public project, presets, API class, function, runtime globals, and cache
namespace now use CompleteSavePlace. The executable filename remains
`saveinstance.luau`. Presets share one documentation page with per-loader
Universal/Potassium switches. XML output contains no exporter credit comment.
The cache reader preserves prior executor safety state across the rename.
