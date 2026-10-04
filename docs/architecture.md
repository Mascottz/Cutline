# CutLine architecture proposal

I propose ocaml plus elm for CutLine; i have not written application code, a screen, or a mockup. i am submitting the stack and boundary for approval before implementation. i pair this proposal with [the design specification](design.md), written before any screen.

## Product boundary

I model a small, frozen street graph around yaba, lagos; i remove explicitly selected edges as hypothetical closures and compare routes from a chosen origin to a chosen destination. i calculate graph reachability and shortest paths only; i make no claim about live traffic, safety, emergency access, accessibility, or population impact.

## First release

1. I ship a local command line tool and a quiet interactive atlas with one bundled, attributed street graph.
2. I accept a documented geojson subset for local imports; i do not parse raw osm pbf in v0.1.
3. I preserve directed streets where source tags provide direction; i document unsupported access rules and turn restrictions.
4. I let a local scenario remove selected edge ids without changing the source graph.
5. I compare the same origin and destination before and after each closure; i report route length, route availability, and reachable-node count.
6. I label every closure as a hypothetical scenario and every result as a graph calculation.

## Language decisions

### OCaml core and command line

I choose [ocaml 5.5.1](https://ocaml.org/changelog/2026-09-05-ocaml-551), opam 2.6.0, [dune 3.24.2](https://opam.ocaml.org/packages/dune/), and [alcotest 1.9.1](https://opam.ocaml.org/packages/alcotest/) for graph normalization, routing, local serving, and the command line; i pin the full dependency graph in an opam lockfile. i choose ocaml over a conventional python, rust, or go default because i want explicit graph invariants, algebraic data types for missing or invalid states, and one compact native executable; i do not need a distributed service or a large framework.

### Elm interface

I choose [elm 0.19.2](https://github.com/elm/compiler/releases/tag/0.19.2) for the browser atlas; i model selections, closures, route states, and decoding failures as explicit values in a pure update loop. i choose elm over a javascript framework because the interface is a bounded state machine, the compiler checks every view transition, and the built-in package boundary keeps remote runtime code out. i pin [elm-test 0.19.2-0](https://www.npmjs.com/package/elm-test/v/0.19.2-0) and [elm-explorations/test 2.2.0](https://package.elm-lang.org/packages/elm-explorations/test/2.2.0/); i write no application logic in javascript.

### Language boundary

I keep graph algorithms and data normalization in ocaml, and i keep selection state and rendering in elm; i pass a versioned json contract between processes. i reject unknown schema versions and malformed ids before calculation; i keep one authoritative graph model rather than duplicating route logic in the browser.

## Runtime shape

I make `cutline demo` load the bundled graph and start a local preview; i target a cold start under five minutes from a public release binary, with no account and no outbound network requirement. i make `cutline import streets.geojson --out network.json` normalize a local extract, and i make `cutline serve network.json` launch the same preview against that graph.

I serve the compiled elm interface and a small same-origin json api from ocaml with cohttp-lwt-unix; i bind only to 127.0.0.1 on an ephemeral port and print the local url. i accept no data upload over http; i load input files from an explicit command line path. i make the browser call only relative local routes and i disable cors.

## Graph and numeric contract

I store stable node ids, integer latitude and longitude in microdegrees, directed edge ids, endpoint ids, source way ids, and route weights in integer millimeters. i calculate route weights once during import with a pinned local fixed-point projection; i store the projection parameters with the graph and label distances as graph estimates. i use integer basis points for route-change ratios and avoid floating-point values in route scoring and display math; i include no monetary fields.

I run deterministic dijkstra searches with nonnegative integer weights; i break equal-cost ties by stable node id and edge id. i apply closures as a read-only edge filter, run breadth-first reachability from the selected origin, and return a named no-route state when the destination becomes unreachable. i keep the original graph immutable for every scenario.

## Data provenance and licensing

I plan a small frozen openstreetmap-derived extract around yaba, lagos; i have not downloaded or committed the extract yet. i will record the snapshot date, query or bounding box, import command, source ids, and data fingerprint beside the fixture. i will show the openstreetmap attribution beside each rendered map and link the credit to [openstreetmap copyright](https://www.openstreetmap.org/copyright) and the [attribution guidelines](https://osmfoundation.org/wiki/Licence/Attribution_Guidelines).

I plan to license source code under mit and keep the derived demo graph under odbl 1.0 in a separately marked data directory; i will ship distinct license notices and will not imply that the street data shares the source-code license.

## Test and ci contract

1. I pin ocaml 5.5.1, opam 2.6.0, dune 3.24.2, and alcotest 1.9.1; i lock transitive packages and run `dune runtest`.
2. I pin elm 0.19.2, elm-test 0.19.2-0, and elm-explorations/test 2.2.0; i lock npm tooling and run `elm-test` plus a production compile.
3. I test graph import, stable ids, one-way handling, closure filtering, no-route states, equal-cost tie breaking, deterministic output, and invalid input in ocaml.
4. I test selection updates, keyboard paths, route-state decoding, and error rendering in elm.
5. I run every language test and build on every pull request and every push to main; i make any failed language suite block a release.
6. I cache opam, npm, and elm toolchains outside the repository; i never commit compiler binaries, package caches, node_modules, or generated build output.

## Real and demo boundary

I plan to use real, frozen openstreetmap geometry in the bundled sample and a synthetic closure scenario; i will label both facts beside the map. i can claim only shortest-path and reachability results over the recorded graph, tags, projection, and closure set. i cannot claim live road conditions, travel time, traffic flow, access rights, turn restrictions, accessibility, emergency response, or real-world resilience from this model.

## Security boundary

I bind the preview server to loopback only, choose an ephemeral port, validate host and origin headers, and accept no permissive cors request. i set explicit limits for input size, feature count, coordinate range, and response size; i reject malformed json, duplicate ids, missing endpoints, and negative weights. i make no external request, collect no account data, and store no credential.

## Approval point

I am asking approval for the ocaml and elm stack, the local-only runtime, the graph model, and the yaba, lagos demo scope; i will not write source code or create a screen before approval.
