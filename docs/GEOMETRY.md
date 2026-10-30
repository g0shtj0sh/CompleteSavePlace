---
title: Missing geometry
---

# Investigating missing geometry

A road absent from an exported place can be Terrain, a union, a mesh, ordinary
parts, or a surface whose appearance changed. A screenshot alone cannot tell
which data is missing. Start with the exact version and its diagnostic report.

## Run the current Ultra preset

Use the versioned [Ultra loader](PRESETS.md#versioned-loaders). Version 0.3.0
downloads its pinned engine by default, so an old local engine cannot silently
replace it. The console records the source origin and byte count.

The wrapper writes the place and `<export-folder>/report.json` to the runtime's
file workspace. Keep the JSON and console output from the same run. If report
writing fails, the wrapper prints the reason.

## Read the evidence

- `engineVersion`, `wrapperVersion`, and `sourceOrigin` identify the code used.
- `ok` records completion of the export function. `outputExists` is a separate
  filesystem check. `validation: "unverified"` means Studio has not validated it.
- `classCounts` counts collected instances by class, including `Terrain`,
  `MeshPart`, and `UnionOperation` when present. Counts do not prove their geometry
  was serialized or their assets can load.
- `droppedPropertyColumns` counts omitted binary property columns. A single
  failed value can omit a property for every instance in that class column.
- `criticalGeometryOmissions` flags selected Terrain, mesh, and union properties
  among those omissions. This is a diagnostic heuristic, not a completeness test.
- `propertyFailures` includes up to 256 samples: class, property, column size,
  failing position, reason, and an example instance path. Totals may exceed
  the sample count.
- `streamingEnabled` reports the workspace setting when readable. Unloaded
  instances cannot be recovered just by increasing the export scope. The
  experimental [GPS presets](PRESETS.md#gps-streaming-collection) request regions
  before export and retain observed Workspace trees; coverage remains unverified.

Property auditing currently covers **binary columns only**. XML reports use
`propertyAudit: "not_instrumented_for_xml"`; zero recorded omissions there
does not mean every property was readable.

## Reader changes

For Potassium, the [dedicated profile](PRESETS.md#potassium-profile) in 0.4.0 additionally
attempts raw `getbspval` reads before the ordinary hidden-property reader.
Its report includes `runtimeAdapter.capabilities.getbspval` and
`runtimeAdapter.binaryStringReads` counters. A successful byte read does not
establish that the road was serialized correctly or reopened successfully.

The following reader fix was introduced in 0.3.0 and remains in the current engine.

An ordinary hidden-property read failure previously marked its entire datatype
as unsupported. For example, one inaccessible BinaryString could prevent later
Terrain or union geometry properties from being attempted. The primary engine
now keeps ordinary property failures separate from datatype self-check failures
and native-crash markers. Regression tests cover that distinction.

This fixes a real reader defect. It does not establish the cause of the road
shown in the exported screenshot or guarantee that the next export contains it.
Missing or restricted source data is not replaced with invented geometry.

## Inspect in Studio

Open the new file and inspect the affected area in Explorer. Use the report's
class and example paths to look for Terrain or mesh/union objects with omitted
properties. Compare object presence and geometry separately from textures,
materials, and asset-loading errors. Share the report and the corresponding
console messages when a surface remains absent.
