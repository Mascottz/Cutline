# CutLine changelog

I keep release notes concise and record graph scope beside interface changes.

## I prepare v0.1.0, 2026-10-04

### Added

- I add an OCaml graph core with validation, deterministic shortest paths, reachability, and read-only closure analysis.
- I add a bounded GeoJSON importer, a version 1 graph codec, and a loopback-only local API.
- I bundle a frozen, attributed OpenStreetMap extract from Yaba, Lagos and a synthetic initial closure.
- I add a local Elm atlas with endpoint and segment selection, integer measures, route overlays, and honest graph-only framing.
- I pin OCaml, opam, Dune, Alcotest, Elm, elm-test, Node, and package dependencies; i cache toolchains outside the repository.
- I add seven OCaml tests, eight Elm tests, a production frontend compile, and a local HTTP smoke check.
- I add the architecture and design records, contribution and security notes, and a GitHub Actions test workflow.

### Limits

I model the frozen street graph and selected edge ids only; i do not model live traffic, travel time, turn restrictions, access rules, or a real-world road closure. i keep those boundaries explicit in the [README](README.md) and [architecture record](docs/architecture.md).
