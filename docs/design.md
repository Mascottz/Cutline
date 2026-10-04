# CutLine design specification

I am fixing the visual contract before any screen exists; i have created no interface, mockup, screenshot, or generated image. i pair this contract with [the architecture proposal](architecture.md), and i will not draw a screen before stack approval.

## Visual thesis

I treat CutLine as a field atlas for graph experiments; i use generous whitespace, small editorial labels, and restrained accents. i make one hypothetical closure the visual interruption, not a dashboard alarm.

## Palette

I give CutLine a project-specific role palette with custom names and fixed values; i reuse the same roles in the interface, documentation images, and social preview.

1. **River iron**, `#182D31`; i use this for primary ink, dark page anchors, and route labels on light ground.
2. **Linen map**, `#F1E9D7`; i use this as the page and map ground.
3. **Moss contour**, `#4D6854`; i use this for the baseline network and reachable routes.
4. **Burnt signal**, `#A64E32`; i use this for hypothetical closures and affected segments.
5. **Plum trace**, `#6B5A6B`; i use this for the alternate route after a closure.
6. **Pollen mark**, `#D2CB83`; i use this for selected origins and small annotation fields, always with river iron text.

I measured river iron at 11.91:1, moss contour at 5.08:1, burnt signal at 4.62:1, and plum trace at 5.26:1 against linen map; i use pollen mark as a surface, not as small text on linen map. i pair every state with a line pattern, marker shape, or label so color never carries meaning alone.

## Typography

I use a local serif stack for display titles, a neutral system sans stack for controls and explanatory text, and a system monospace stack for coordinates, counts, distances, and percentages. i request no remote font and keep all displayed values in a stable numeric style.

## Composition

I build an open two-field spread; i give the map roughly two thirds of the wide canvas and the scenario ledger the remaining space. i use whitespace, offset alignment, fine rules, and generous margins instead of plain rectangle section cards. i avoid generic pills and badges; i mark selection with an underline, a short side rule, and a direct label.

## Map language

I keep the source network quiet in moss contour and draw the baseline route with a fine broken stroke. i draw the rerouted path in plum trace with a solid stroke, and i mark each hypothetical closure in burnt signal with a crossbar and a text label. i add a simple north cue and a scale note only when the projection supports a defensible scale. i keep attribution beside the map, not buried in a footer.

## Information order

I place the dataset name, source snapshot, and scenario label above the map. i place origin, destination, baseline distance, changed distance, and reachable-node count in a ruled measurement strip below the map. i set every number in monospace, keep units visible, and show unavailable routes as named states rather than blank values.

## Interaction

I expose scenario choices as a text ledger with a clear active line; i make every closure selectable from both the map and the ledger. i keep keyboard focus visible, provide arrow-key navigation through map segments, and make space toggle a selected closure. i keep the route summary available as ordinary text beside the graphic.

## Accessibility

I target wcag aa contrast for small text, preserve visible focus, and provide a textual route and closure summary. i use labels, stroke patterns, and marker shapes together; i support reduced motion and avoid hover-only information. i verify contrast and keyboard flow before calling the design complete.

## Responsive behavior

I keep the map first on narrow screens, move the measurement strip directly below, and stack the scenario ledger after the route summary. i preserve the same reading order and never hide data behind a horizontal-only interaction.

## Social preview

I compose a 1200 by 630 preview from the same palette and type system; i show one quiet street field, one rust closure, one rerouted line, the CutLine name, and a small monospace before-and-after measure. i keep the preview self-contained and free of external tiles, borrowed map imagery, and prediction claims.

## Asset policy

I use inline svg, local css, and bundled data only; i fetch no external font, tile, script, or image. i show the openstreetmap credit beside every rendered map and link the credit to the public copyright and license page.
