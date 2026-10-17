# CompleteSavePlace for Potassium

Dedicated API bindings and presets, sharing the primary serializer.

Use the [documentation and copy buttons](https://g0shtj0sh.github.io/CompleteSavePlace/docs/PRESETS/#potassium-profile)
or execute this versioned Ultra loader:

```lua
loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/g0shtj0sh/CompleteSavePlace/v0.6.4/Executors/Potassium/Script%20Presets/UltraCompleteSavePlace.luau",
    true
))()
```

- [UltraNoModuleScripts](Script%20Presets/UltraNoModuleScripts.luau): Ultra without module code, preserving containers and descendant models.
- [UltraCompleteSavePlace](Script%20Presets/UltraCompleteSavePlace.luau): experimental full coverage.
- [DiagnosticSavePlace](Script%20Presets/DiagnosticSavePlace.luau): property/writer diagnosis without scripts or compression.
- [MapSavePlace](Script%20Presets/MapSavePlace.luau): full-root scene export without script extraction.
- [ScriptsSavePlace](Script%20Presets/ScriptsSavePlace.luau): script-focused mode.
- [saveinstance.luau](saveinstance.luau): dedicated entry point returning the exporter function.
- [API review](API_REVIEW.md): reviewed reference, adopted APIs, and deferred features.

The adapter identifies Potassium and passes explicit native functions to the
shared engine. It attempts `getbspval` with `base64=false` for raw BinaryString
properties, including Terrain and union data when readable. Invalid values
and Lua failures fall back to the ordinary property reader.

Presets enable special property reads. Map, Scripts, and Ultra also enable
the existing append writer. Native `crypt.lz4compress` must pass the engine's
existing block-format check before selection. Reports include profile,
executor version, capabilities, and binary-read counters.

Since 0.4.2, script jobs reuse cached bytecode and presets write a
`<export-folder>/progress.json` checkpoint while running. Preserve it if the client
freezes before producing a final report. Lua deadlines cannot preempt a blocked
native call. Source columns and chunks over 8 MiB are stored uncompressed,
preserving their data at the cost of potentially larger files.

No general-purpose globals are overwritten. Both stages download code pinned
to v0.6.4; inherited helper dependencies remain unpinned. Local adapter
development also requires changing its core URL if the shared engine is local.
Regenerate presets with `python scripts/generate_presets.py` at repository root.

Compilation and mocked regression checks pass; installed Potassium behavior
and Studio reopening still require testing. Native crashes cannot be caught
with `pcall`. Use only experiences you own or are authorized to archive.
