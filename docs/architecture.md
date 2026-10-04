# CutLine architecture and implementation

I wrote the architecture proposal before implementation and received approval for OCaml plus Elm; i now record the built system, its constraints, and its limits. i keep the language case here because both uncommon language choices predate the code.

## Product boundary

I model a small, frozen street graph around Yaba, Lagos; i remove selected edges as hypothetical closures and compare routes between chosen graph nodes. i calculate shortest paths and reachability only; i do not predict live traffic, travel time, access rights, safety, emergency response, accessibility, or population impact.

## Release shape

1. I ship a local command line tool and a quiet interactive atlas with one bundled, attributed street graph.
2. I accept a documented GeoJSON subset for local imports; i do not parse raw OSM PBF in v0.1.
3. I preserve direction where source tags provide it; i do not model turn restrictions or every access rule.
4. I apply closure ids as a read-only filter; i never rewrite the source graph for a scenario.
5. I compare the same origin and destination before and after closures; i report route distance, route availability, and reachable-node count.
6. I label every closure as hypothetical and every result as a graph calculation.

## Language decisions

### OCaml core and local service

I chose [OCaml 5.5.1](https://ocaml.org/changelog/2026-09-05-ocaml-551) for graph validation, import, routing, serialization, and the local HTTP service; i chose [opam 2.6.0](https://github.com/ocaml/opam/releases/tag/2.6.0), [Dune 3.24.2](https://opam.ocaml.org/packages/dune/), and [Alcotest 1.9.1](https://opam.ocaml.org/packages/alcotest/) for the pinned build and test boundary. i chose OCaml instead of a default scripting or systems language because i wanted algebraic error states, explicit graph invariants, deterministic integer routing, and one compact native executable without a distributed-service framework.

### Elm browser application

I chose [Elm 0.19.2](https://github.com/elm/compiler/releases/tag/0.19.2) for the browser atlas; i keep origin, destination, closures, pending requests, and decoded route states in one typed update loop. i chose Elm instead of a default JavaScript UI framework because the screen is a bounded state machine, the compiler checks the model and view boundary, and the runtime has no framework or package-fetch requirement. i pin [elm-test 0.19.2-0](https://www.npmjs.com/package/elm-test/v/0.19.2-0) and [elm-explorations/test 2.2.0](https://package.elm-lang.org/packages/elm-explorations/test/2.2.0/); i keep production dependencies exact in `web/elm.json`.

### JavaScript bootstrap and Node tooling

I keep JavaScript to a small local bootstrap that starts the compiled Elm module after the document loads; i use the browser's native DOM event rather than a framework because Elm needs a mount node and no application logic needs JavaScript. i pin Node 22.23.3 in `.nvmrc`, verify its cached archive in `scripts/install-node.sh`, pin the Elm test runner in `package-lock.json`, and syntax-check the bootstrap from `make test`.

### Language boundary

I keep graph algorithms and source-data normalization in OCaml; i keep selection state and rendering in Elm. i pass a version 1 JSON contract between the local service and browser; i keep one authoritative graph model and never duplicate route calculation in the browser.

## Runtime shape

I use `make setup` to cache OCaml, Elm, and npm toolchains outside the repository; i use `make test` to build both applications and run both language suites. i use `make demo` to compile the interface, load the bundled Yaba graph, and start an ephemeral loopback server; i need no account and make no outbound request after setup.

I use `cutline import streets.geojson --out network.cutline.json` to normalize a local extract; i use `cutline serve network.cutline.json` to open a normalized graph. i keep the demo data and source notes under `data/demo/`; i keep generated compiler output, npm packages, and toolchains out of version control.

## Graph and numeric contract

I store stable node ids, integer latitude and longitude in microdegrees, source way ids, directed segment ids, endpoint ids, and route weights in integer millimeters. i calculate route weights during import with a fixed-point local projection and keep the projection parameters in the graph; i use integer millimeters for route scoring and integer basis points for route-change ratios.

I run deterministic Dijkstra searches with nonnegative integer weights; i break equal-cost ties by the ordered source arc ids. i apply closures as a read-only edge filter, run breadth-first reachability from the selected origin, and return a named no-route state when the destination becomes unreachable. i keep display distances and percentage formatting in integer arithmetic; i use floating-point coordinates only to draw the local map geometry, never to score routes.

I render the street extract as a fitted local graph rather than a tiled basemap; i show no scale bar because the drawing is fit to the view and is not a navigation map. i keep the route line patterns, closure crossbars, and node markers distinct so color does not carry meaning alone.

## Versioned local API

I expose `GET /api/bootstrap` for graph, dataset, initial scenario, and first analysis data; i expose `POST /api/analyze` for a JSON object with `origin`, `destination`, and a list of `closed` segment ids. i return route node ids, segment ids, integer lengths, reachable-node count, and an optional integer basis-point change; i reject schema versions outside version 1 in the browser.

I serve only the compiled Elm module, its local bootstrap, local CSS, and the two API routes; i use same-origin relative requests and keep the server bound to loopback. i limit request bodies to 64 KiB, closure lists to 500 ids, serialized API responses to 32 MiB, and each local asset to 4 MiB.

## Data provenance and licensing

I bundle an OpenStreetMap-derived Yaba extract collected on 2026-10-04 from `https://api.openstreetmap.org/api/0.6/map?bbox=3.370,6.510,3.380,6.520`; i record the bounding box, 199 ways, 1,754 source coordinates, OSM attribution, and ODbL-1.0 in `data/demo/metadata.json` and `data/demo/README.md`. i import that extract into 1,513 graph nodes and 1,555 directed street segments; i keep the graph source separate from the application source.

I credit OpenStreetMap beside the rendered map and link the credit to the copyright and attribution guidance; i keep the derived data under ODbL-1.0 and plan the application source under MIT. i do not imply that the street data shares the source-code license.

## Test and build contract

1. I pin OCaml 5.5.1, opam 2.6.0, Dune 3.24.2, and Alcotest 1.9.1; i lock the OCaml dependency graph in `cutline.opam.locked`.
2. I pin Elm 0.19.2, exact Elm package versions, `elm-test` 0.19.2-0, and `elm-explorations/test` 2.2.0; i lock npm tooling in `package-lock.json`.
3. I test shortest paths, detours, disconnection, one-way direction, tie breaking, bad closure ids, GeoJSON import, graph round trips, and the frozen extract in OCaml.
4. I test bootstrap decoding, integer formatting, selection updates, closure toggling, and stale-response rejection in Elm; i compile the production module and syntax-check the local JavaScript bootstrap.
5. I run both language builds and suites from `make test`; i keep failed tests blocking for every pull request and release.
6. I cache opam, npm, and Elm toolchains outside the repository; i never commit compiler binaries, package caches, `node_modules`, or generated output.

## Real and demo boundary

I use real frozen street geometry and source ids from OpenStreetMap; i use a hypothetical closure chosen for a graph experiment. i can claim only shortest-path and reachability results over the recorded geometry, direction tags, projection, and selected closure set. i cannot claim live street status, travel-time estimates, traffic flow, access rights, turn restrictions, accessibility, emergency response, or real-world network resilience.

## Security boundary

I bind the local service to loopback, choose an ephemeral port by default, require the exact loopback Host, reject any supplied Origin outside that local origin, and enable no permissive CORS. i load imports from an explicit local file path; i cap file, feature, coordinate, request, response, and asset sizes and reject malformed JSON, duplicate ids, missing endpoints, and invalid route weights. i collect no account data, store no credential, and fetch nothing outside the local atlas during startup or analysis.
