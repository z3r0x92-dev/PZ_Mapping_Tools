# Building Editor UI redesign

## Direction

The first redesign pass uses a modern creative-software layout with a dark,
low-glare workspace. It improves hierarchy and discoverability while leaving
the building model, `.tbx` format, undo stack, and export pipeline unchanged.

## Workspace structure

- **Mode rail:** Blueprint, Isometric, Tiles, and Attributes remain available
  at the left edge with larger icons and full names.
- **Creation toolbar:** frequently used building tools are grouped by task and
  use short labels. Advanced roof variants remain available from the Roof
  menu instead of occupying several ambiguous toolbar positions.
- **Context controls:** room and floor selection sit together. The floor
  display uses `Floor 1 of 3`, with previous/next controls beside it.
- **Canvas:** the document receives the majority of the window. `Fit Building`
  and `100%` are separate actions so users can recover the view quickly.
- **Asset browser:** Tiles, Furniture, and Favorites are searchable from one
  panel. Categories and results are visually separated, with preview scale at
  the bottom.
- **Status bar:** tool instructions, coordinates, and zoom remain visible
  without competing with the canvas.

## Implemented workspace

1. Replace the document-open Welcome shortcut with a four-mode studio rail.
2. Keep Room, Wall, Door, Window, Stairs, Roof, and Furniture visible while
   moving selection, object, basement, and advanced roof tools into `More`.
3. Group current-room and level controls and expose `Fit Building` and `100%`
   recovery actions directly on the toolbar.
4. Provide a unified dark Asset Browser with search, Tiles/Furniture/Favorites
   tabs, category counts, a dark thumbnail canvas, and selection preview.
5. Preserve the building model, existing tool actions, keyboard shortcuts,
   saved dock state, `.tbx` files, undo stack, and export behavior.

The Favorites tab currently exposes the intended workspace location but does
not yet persist favorite assets. Grid and save-state indicators from the
concept image are also follow-up functionality rather than decorative dummy
controls.

## Responsive behavior

- At widths below 1100 px, the creation toolbar uses its overflow menu.
- The asset browser has a useful minimum width but remains collapsible.
- Search results replace the category hierarchy while a query is active.
- Saved dock and splitter state remains supported, with Reset Layout available
  when a stored layout becomes unusable.
