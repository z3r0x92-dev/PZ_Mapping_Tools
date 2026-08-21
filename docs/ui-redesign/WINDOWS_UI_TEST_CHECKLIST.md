# Windows UI prototype test checklist

Use a copy of a real `.tbx` building. Do not use the only copy of an active
mapping project for the first test.

## Build

1. Install Visual Studio 2022 with **Desktop development with C++**.
2. Install Qt 5.14.2 `msvc2017_64`.
3. Open an x64 Visual Studio developer command prompt.
4. Create an empty build directory outside the source tree.
5. Run qmake against `TileZed/tiled.pro`, then run `nmake`.
6. Launch the generated `BuildingEd.exe` with the matching configuration and
   authorized Project Zomboid Tiles directory.

The repository-level `BUILDING.md` contains the exact build commands and
packaging layout.

## Visual checks

- A first-run window opens at approximately 1280 by 800.
- Breeze Dark is selected by default for a new settings profile.
- Object tools use 24-pixel icons and readable labels.
- Room and floor controls remain usable at 1280-pixel window width.
- Narrowing the window moves excess toolbar actions into Qt's overflow menu.
- The Asset Browser remains at least 300 pixels wide when visible.
- Searching `wall`, `roof`, or `furniture` filters categories without changing
  the underlying tile catalogue.
- Clearing search restores category separators and every category.
- **Fit Building to View** shows the entire building in Blueprint, Isometric,
  Tile, and Attributes modes.
- **Center Building** changes the camera position without changing zoom.
- Dock sizes and visibility survive an application restart.

## Compatibility checks

- Open, save, close, and reopen a copied `.tbx` file.
- Confirm undo and redo still operate in every edit mode.
- Export the copied building to TMX and compare the output with the unmodified
  application when no map edits were made.
- Confirm existing themes can still be selected in Preferences.
- Confirm floor switching, room selection, furniture placement, and roof menus
  behave as before.
