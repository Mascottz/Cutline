# I prepare the Hacker News post

## I use this title

> Show HN: CutLine, a local graph explorer for hypothetical street closures

## I use this copy

I built CutLine as a small offline-first experiment in street-network disruption. i close a street segment in a frozen OpenStreetMap graph, compare the shortest route before and after, and count which graph nodes remain reachable.

I bundle an attributed Yaba, Lagos extract collected on 2026-10-04; i treat the selected closure as hypothetical. i measure graph distance only, not live traffic, travel time, access, or real-world resilience.

I run the graph core and local API in OCaml, render the atlas in Elm, and keep the demo on loopback with no account or runtime network dependency. i welcome feedback on the graph boundaries, local setup, and screen-reader path.

I keep the source, test commands, and limits at https://github.com/Mascottz/CutLine.

## I add this comment if the thread needs context

I chose OCaml for explicit graph invariants and deterministic integer routing, and Elm for a small typed UI state machine. i kept JavaScript to a local bootstrap, stored route weights in integer millimeters, and used integer basis points for the route-change ratio. i wrote the architecture and visual contract before building the screen.
