# CutLine design system

I wrote this contract before the first screen; i now record how the shipped atlas follows it and where i intentionally keep the first release simple. i pair it with the [architecture record](architecture.md).

## Visual thesis

I treat CutLine as a field atlas for graph experiments; i use open space, small editorial labels, and restrained accents. i make one hypothetical closure the visual interruption, not a dashboard alarm.

## Palette

I give CutLine a project-specific role palette with fixed values; i reuse these roles in the interface, documentation images, and social preview.

1. **River iron**, `#182D31`; i use this for primary ink, dark anchors, and route labels on the light ground.
2. **Linen map**, `#F1E9D7`; i use this for the page and map ground.
3. **Moss contour**, `#4D6854`; i use this for the quiet network and baseline route.
4. **Burnt signal**, `#A64E32`; i use this for hypothetical closures and affected segments.
5. **Plum trace**, `#6B5A6B`; i use this for the route after a closure.
6. **Pollen mark**, `#D2CB83`; i use this for the selected segment and small annotation marks, never as small text on linen map.

I measured river iron at 11.91:1, moss contour at 5.08:1, burnt signal at 4.62:1, and plum trace at 5.26:1 against linen map; i use pollen mark as a surface rather than small text on linen map. i pair each state with a line pattern, crossbar, marker, or label so color never carries meaning alone.

## Typography

I use a local serif stack for display titles, a neutral system sans stack for controls and explanatory text, and a system monospace stack for coordinates, counts, distances, and percentages. i request no remote font and keep displayed measures in a stable numeric style.

## Composition

I build an open two-field spread; i give the map roughly two thirds of a wide canvas and the scenario ledger the remaining space. i place the measurement strip below the map and keep the legend and controls in the right rail. i use whitespace, offset alignment, fine rules, and generous margins instead of plain rectangle section cards; i avoid generic pills and badges.

## Map language

I keep the source network quiet in moss contour and draw the baseline route with a dotted stroke. i draw the changed route in plum trace with a solid stroke, and i mark each hypothetical closure in burnt signal with a broken stroke and a crossbar. i distinguish origin and destination with separate marker colors; i use the labeled endpoint controls as the accessible alternative to map-only interaction. i omit a north cue and scale bar because the fitted drawing is not a navigation map. i keep OpenStreetMap attribution beside the map.

## Information order

I place the dataset name, source snapshot, and graph-only framing above the map. i place baseline distance, changed distance, detour change, and reachable-node count directly below it. i set every measure in monospace, keep units visible, and show unavailable routes as named states rather than blank values.

## Interaction

I let a click on a street line select its segment; i also expose every node and segment through labeled native selects for keyboard operation. i let the text button close or reopen the selected segment, and i announce recalculation status with a polite live region. i discard older route responses after a newer selection so a slow reply cannot replace the current scenario. i keep the route summary available as ordinary text beside the graphic.

## Accessibility

I target WCAG AA contrast for small text, preserve visible focus, and provide a textual route and closure summary. i use labels, stroke patterns, and marker shapes together; i support reduced motion and avoid hover-only information. i keep keyboard selection in the native controls instead of promising keyboard traversal through every drawn line.

## Responsive behavior

I keep the map first on narrow screens, move the measurement strip directly below it, and stack the scenario rail after the route summary. i preserve that visual reading order and never hide data behind a horizontal-only interaction.

## Social preview

I compose a 1200 by 630 preview from the same palette and type system; i show one quiet street field, one rust closure, one rerouted line, the CutLine name, and a small monospace before-and-after measure. i keep the preview self-contained and free of external tiles, borrowed map imagery, and prediction claims.

## Asset policy

I use bundled data, local CSS, a locally compiled Elm module, and a small local JavaScript bootstrap; i fetch no external font, tile, script, or image. i make no external request while the atlas is open, and i keep the OpenStreetMap attribution links available beside the map.
