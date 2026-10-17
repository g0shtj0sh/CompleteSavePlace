<p align="center">
  <img src="assets/brand/banner.png" alt="CompleteSavePlace — Roblox instance archival" width="100%" />
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-AGPL--3.0-76F2CF?style=flat-square&labelColor=0B1220" alt="License: AGPL-3.0" /></a>
  <img src="https://img.shields.io/badge/language-Luau-9EDBFF?style=flat-square&labelColor=0B1220" alt="Language: Luau" />
  <img src="https://img.shields.io/badge/status-early_development-F1C875?style=flat-square&labelColor=0B1220" alt="Status: early development" />
</p>

<p align="center">
  <strong>A clearer foundation for Roblox instance archival.</strong><br />
  Accessible data. Explicit limits. Evidence before success.
</p>

<p align="center">
  <a href="https://g0shtj0sh.github.io/CompleteSavePlace/">Documentation</a> ·
  <a href="Script%20Presets/README.md">Script Presets</a> ·
  <a href="#getting-started">Get started</a> ·
  <a href="docs/USAGE.md">Usage</a> ·
  <a href="docs/TROUBLESHOOTING.md">Troubleshooting</a> ·
  <a href="docs/ROADMAP.md">Roadmap</a> ·
  <a href="README.fr.md">Français</a>
</p>

---

The [UltraNoModuleScripts preset](docs/PRESETS.md#ultranomodulescripts) keeps Ultra settings without module code. Module containers become Folders to preserve descendant models. Universal and Potassium copy launchers are available in the documentation.

## The project

**CompleteSavePlace** is a Luau toolkit for exporting accessible Roblox
instances to place and model files. It builds on an existing serializer and
establishes a separate identity for future diagnostics, verification, and
reliability work.

Use it with experiences you own or have permission to archive. For your own
projects, start with Roblox Studio's built-in save and export features.

> **Development status:** executable presets, source-generated API documentation,
> and repository checks are available. End-to-end export and Studio reopening
> have not been validated for this distribution. A completed function call is
> not proof of a usable backup.

## What is in the code today

- **Place and model serialization:** binary `.rbxl` / `.rbxm` and XML `.rbxlx` / `.rbxmx` paths.
- **Configurable selection:** instance roots, exclusion lists, properties, and modes.
- **Environment adapters:** detection and fallbacks for environment-specific APIs.
- **Live diagnostics:** stage progress below the current operation, JSON checkpoints,
  console messages, and selected write probes.
- **Cooperative scheduling:** configurable Lua work slices, including large binary
  loops, to leave more scheduler time to the game. Native pauses remain possible.
- **One shared engine:** `saveinstance.luau`, with a dedicated Potassium adapter.

The project includes an [interactive API Explorer](https://g0shtj0sh.github.io/CompleteSavePlace/api/CompleteSavePlace/),
fixes datatype-wide suppression after an individual hidden-property failure,
and records binary geometry omissions in preset JSON reports. See the
[missing geometry guide](docs/GEOMETRY.md) when an exported surface is absent.

Presets also write a `progress.json` checkpoint during export, identifying the
latest operation if a final report cannot be produced. Version 0.4.2 improves
script-job scheduling and avoids repeated bytecode reads; a native call that
blocks the client still cannot be interrupted by a Lua timeout.

Availability depends on the runtime, readable properties, and loaded instances.
The Lua variant differs from the Luau source and is not feature-equivalent.

## Getting started

Read [the usage guide](docs/USAGE.md) first. This example uses a project tag and
an explicit diagnostic configuration. It requires a compatible runtime with
HTTP access, `loadstring`, and file APIs; it is not an ordinary Roblox
LocalScript or Studio command-bar script.

```lua
local source = game:HttpGet(
    "https://raw.githubusercontent.com/g0shtj0sh/CompleteSavePlace/v0.6.4/saveinstance.luau",
    true
)
local completeSavePlace = assert(loadstring(source, "CompleteSavePlace"))()

completeSavePlace({
    FilePath = "CompleteSavePlace_Diagnostic.rbxl",
    mode = "optimized",
    Binary = true,
    CompressionMode = false,
    Decompile = false,
    SaveBytecode = false,
    NilInstances = false,
    IgnoreSpecialProperties = true,
    AlternativeWritefile = false,
    SafeMode = false,
    KillAllScripts = false,
    BoostFPS = false,
    ShutdownWhenDone = false,
    ShowStatus = true,
    __DEBUG_MODE = true,
})
```

The repository and [documentation website](https://g0shtj0sh.github.io/CompleteSavePlace/)
are public. No access token is required. The root engine is pinned to the project
tag; inherited external helpers are not yet pinned.

## Script Presets

The [preset documentation](https://g0shtj0sh.github.io/CompleteSavePlace/docs/PRESETS/)
has a **Copier le script** button for every configuration, with Universal and
Potassium profiles. The [Potassium edition](Executors/Potassium/README.md)
adds explicit native API bindings and raw binary-property reads to the shared
engine; it includes its own five generated presets.

Choose an executable configuration from [Script Presets](Script%20Presets/README.md):

- [DiagnosticSavePlace](Script%20Presets/DiagnosticSavePlace.luau): initial serializer and file-writing diagnosis.
- [MapSavePlace](Script%20Presets/MapSavePlace.luau): map-focused export without decompilation or bytecode.
- [ScriptsSavePlace](Script%20Presets/ScriptsSavePlace.luau): authorized script-focused export with per-job timeouts.
- [UltraCompleteSavePlace](Script%20Presets/UltraCompleteSavePlace.luau): **experimental development target** for the widest accessible coverage.

All presets share the same engine. Ultra is the configuration we are diagnosing
and improving to preserve as much of a place as possible; it is not a verified
complete backup. The [preset guide](docs/PRESETS.md) explains installation,
exact options, and the limits of each mode.

## Know what was actually saved

Confirm that the output exists in the runtime's real workspace, then open it
in Roblox Studio and inspect a representative sample. A referenced asset ID
does not mean the asset binary was included. Client-side inspection cannot
recover server-only code, private DataStores, or unloaded streamed content.

`PROP dropped` reports a property omission; it does not by itself mean an
entire instance was lost. See [troubleshooting](docs/TROUBLESHOOTING.md).

## Explore the documentation

- [Documentation website](https://g0shtj0sh.github.io/CompleteSavePlace/) — searchable guides and API.
- [API reference](https://g0shtj0sh.github.io/CompleteSavePlace/api/CompleteSavePlace/) — source-generated types, defaults, and aliases.

- [Usage and compatibility](docs/USAGE.md) — entry points, first run, important options.
- [Troubleshooting](docs/TROUBLESHOOTING.md) — missing files, crashes, property omissions.
- [Architecture](docs/ARCHITECTURE.md) — inherited runtime and external dependencies.
- [Roadmap](docs/ROADMAP.md) — planned work after this foundation.
- [Contributing](CONTRIBUTING.md) — checks and useful bug reports.
- [Brand assets](assets/brand/README.md) — logo, banner, palette, and generation prompts.

## Development checks

```powershell
python scripts/check_repository.py
luau-compile --null saveinstance.luau Executors/Potassium/saveinstance.luau
```

GitHub Actions validates repository consistency and compiles both entry points
using Luau **0.742**. These checks do not exercise Roblox APIs or verify an
exported place.

## License and credits

Distributed under [AGPL-3.0](LICENSE). Required attribution, source provenance,
and acknowledgments are collected in [NOTICE.md](NOTICE.md).

Independent, unofficial project. Not affiliated with Roblox Corporation.
