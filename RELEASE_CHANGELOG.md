# Changes since Build 20260818b

The exact public release baseline used for this changelog is
[`42.20B260818b`](https://github.com/Unjammer/PZ_Mapping_Tools/releases/tag/42.20B260818b),
commit
[`89617f75aa29ed824d6ee96d00fccc58a69aeed7`](https://github.com/Unjammer/PZ_Mapping_Tools/commit/89617f75aa29ed824d6ee96d00fccc58a69aeed7),
published on 2026-08-19 at 01:12 UTC as **Build 20260818b**.

This changelog contains only user-visible work added after that tagged release.

## PZTools Modernized v1.0.4

- Updated TileZed, BuildingEd, and PZWorldEd for upstream Build 42.20B260820b.
- Fixed Qt 5.14.2 and MinGW build compatibility issues.
- Fixed BuildingEd transparent tiles being displayed as missing-tile placeholders.
- Restored transparent tile handling in the tile, furniture, and mixed tileset browsers.
- Preserved the modernized Breeze Dark interface and shared portable settings.
- Updated the compiled Windows executables and matching tiled/worlded libraries.


## Shared / All applications

- Malformed TMX and TBX references, dimensions, colors, coordinates, and
  thumbnail metadata are rejected safely instead of reaching unchecked
  container access or being accepted as valid cached data. TMX maps and tile
  layers are limited to 300 x 300 tiles across creation, resizing, and loading.
  Map resizing asks for confirmation before existing content is cropped.

## PZWorldEd

- Confirming Preferences with an unchanged Tiles directory no longer reloads
  the complete tileset catalogue or reconstructs every open map and lot.
  Preference changes are applied coherently before the dialog closes.
- Right-clicking a supported special object opens a guided property editor
  limited to the fields expected for its type. WaterFlow, WaterZone, RoomTone,
  SpawnPoint, ParkingStall, Vehicle, Mannequin, Animal, Basement, and WorldGen
  use enum lists, profession checklists, booleans, text fields, or numeric
  controls as appropriate. Missing expected properties are added on Save,
  unrelated custom properties are retained, and the complete existing
  Properties dock remains available. The same menu is available while Select
  or Create Object is active and always targets the zone geometry directly
  under the pointer. Choose Basement Access is offered only for a Basement
  zone. Closing the menu, including with a second right-click, performs no
  action.
- Cell Move, Copy, and Paste retain the complete cell payload. This includes
  the assigned map, lots, cell properties and notes, cell templates, zones and
  objects with their properties, notes, templates, visibility, geometry points
  and polyline widths, plus InGameMap features and properties.
- Ctrl+V and **Edit > Paste** open the same translucent placement preview
  anchored to the selected destination cell. Multi-cell layouts retain their
  relative positions, remain inside the project bounds, and may be confirmed
  by click or Enter. InGameMap features use the destination cell coordinates,
  and existing destination features remain intact through Paste, Undo, and
  Redo. The preview follows the pointer even when world thumbnails are hidden,
  uses green for empty targets and orange for occupied targets, and
  recalculates the destination from the confirming click. One confirmation
  performs one paste and returns to normal cell selection. Non-empty targets
  require explicit confirmation with No as the default.
- World-map overlay placement converts source cells to absolute map-square
  coordinates before projecting them over the World view. Build 42.20
  256-square overlay data now aligns over both Native256 and Legacy300
  projects.
- World-map XML and binary output is normalized to the Build 42.20 256-square
  cell grid. XML records `cellSize="256"`, while Legacy300 features are
  re-bucketed and clipped across the required 256-square world-map cells.

## BuildingEd

- Building dimensions are limited to 300 x 300 tiles during creation, TBX
  loading, and resizing. Furniture layouts, roof dimensions, and wall lengths
  use the same maximum. Destructive resize operations require confirmation.
  Clipboard placement that would exceed the limit warns before continuing and
  crops only clipboard content outside the bounded building grid.
- The Layers visibility threshold is saved to and restored from the portable
  application INI.
- Moving a clipboard preview reuses its converted isometric tile grid instead
  of resolving every copied tile again for each pointer position.
- Room name and internal-name edits commit when editing finishes or a list
  value is selected. Metadata-only room changes no longer rebuild every
  isometric floor.

## Credits and special thanks

- Tim Baker for the original WorldEd and TileZed work that remains the upstream
  foundation of these tools.
- Alree / Unjammer for the unofficial Qt 5 continuation, current maintenance,
  new features, fixes, integrations, and releases.
- A very special thank you to Fred 'Military Surplus' Cooper.
- Petro, Pabbiqo [pq], Dane, ! Cacador, Kyber, shakaloblok, and the Project
  Zomboid mapping and modding community for reproducible reports, project
  files, screenshots, logs, and practical workflow feedback.

Legal authorship and third-party attribution are documented in `AUTHORS.txt`,
`FEATURE_PROVENANCE.md`, `UPSTREAM-HISTORY.md`, and the bundled license notices.
