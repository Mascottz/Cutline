# I built CutLine to measure a closure without pretending to predict traffic

I started CutLine with a narrow question: if i remove one street segment from a recorded graph, how much does the shortest route change, and which nodes remain reachable? i wanted a small, inspectable experiment rather than a traffic model dressed up as a map.

## I keep the claim small

I use a frozen OpenStreetMap extract around Yaba, Lagos, collected on 2026-10-04 from a 0.01-degree bounding box. i preserve source way ids, node ids, direction tags, and local geometry; i record the query, counts, attribution, and ODbL-1.0 terms beside the bundled data.

I choose one street segment as a hypothetical closure. i do not claim a live road closure, current coverage, travel-time estimate, traffic-flow prediction, safety result, emergency-access result, or network-resilience measure. i calculate paths over the stored geometry, direction tags, projection, and closure set; that is the whole claim.

I get a baseline route of about 4.6 km and a route of about 4.9 km after the bundled closure; i calculate a 7.73 percent increase in graph distance and 1,162 reachable nodes for the selected origin. i display the same integer-backed measurements in the local atlas and keep the caveat beside the map.

## I keep the graph authoritative

I normalize a bounded GeoJSON subset into a graph with stable ids and integer latitude and longitude in microdegrees. i calculate each segment weight once in integer millimeters, preserve supported one-way direction, and validate endpoints, ids, sizes, and local extent before routing.

I use deterministic Dijkstra searches for shortest paths and breadth-first reachability for the remaining graph. i apply closures as a read-only edge filter rather than editing the source graph; i keep the original route and changed route comparable under the same endpoints. i resolve equal-cost paths with a stable ordering and calculate route-change ratios in integer basis points.

I keep the browser out of the routing business. i send a versioned JSON bootstrap from the local OCaml service, let Elm hold the selection and pending state, and send relative same-origin requests for each graph analysis. i reject stale replies so an older response cannot replace a newer scenario.

## I choose a small stack on purpose

I chose OCaml for import validation, graph invariants, integer routing, serialization, and the loopback service. i wanted a compiled core with explicit invalid and unavailable states, not a distributed system or a broad service framework.

I chose Elm for the atlas because the interaction is a bounded state machine with a small number of states and messages. i keep JavaScript to a short bootstrap that mounts the compiled Elm module; i use no frontend framework, external map tile, external font, or runtime account.

I pin OCaml 5.5.1, opam 2.6.0, Dune 3.24.2, Elm 0.19.2, Node 22.23.3, and their test packages. i keep the compilers and package caches outside the repository; i run the OCaml and Elm suites, compile the production UI, and smoke-test the local HTTP routes with `make test`.

## I make the demo local

I bundle the Yaba extract and metadata, compile the checked-in Elm source, and start a local server command. i run `make setup` once to cache the pinned tools and packages; after setup, i run `make demo` without an account or outbound request. i bind the service to loopback and use an ephemeral port by default.

I keep the map quiet, mark baseline and changed paths differently, and cross the hypothetical closure with a rust-colored bar. i place the numbers in monospace and expose the same origin, destination, and segment choices through native controls. i omit a basemap, a scale bar, and any visual promise of real-world precision.

## I leave the limits visible

I do not model turn restrictions, every access rule, live traffic, travel time, road condition, pedestrian access, or emergency response. i do not infer population impact or identify a real closure from the graph. i keep those omissions in the architecture notes and the screen copy instead of hiding them in a footnote.

I built CutLine as a portfolio project and a place to practice clear boundaries across a graph core, local data, a typed UI, and honest measurement language. i keep the source and the next small issues at https://github.com/Mascottz/CutLine; i welcome corrections to the implementation and to the limits i have drawn.
