# Economy Analyzer

Independent passive client observer. It reads accessible economic candidates,
tracks local-player changes, and exports JSON plus an offline HTML report on
request. No game remotes are called or hooked, and game modules are never run.

Use the [documentation and copy launcher](https://g0shtj0sh.github.io/CompleteSavePlace/docs/ECONOMY/)
or load the versioned `analyze.luau` entry point. Optional decompilation is explicit;
initial discovery uses only readable Source properties. `Analyzer.luau` contains
the implementation, separate from the place serializer.

Client values, display samples, configuration candidates, and unknown server
rules remain distinct. Full economy reconstruction and server-side formulas are
not guaranteed. See the [guide](../docs/ECONOMY.md) for settings, evidence labels,
file locations, and limits.
