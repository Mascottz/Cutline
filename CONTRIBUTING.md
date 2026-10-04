# I contribute to CutLine

I keep CutLine small, reproducible, and clear about the difference between graph measurements and real-world predictions. i welcome focused changes to routing, import validation, offline setup, accessibility, documentation, and tests.

## I set up the toolchain

I run the pinned setup and test commands from the repository root:

```sh
make setup
make test
```

I keep Node 22.23.3, opam 2.6.0, OCaml 5.5.1, Dune 3.24.2, Elm 0.19.2, and downloaded package caches under `~/.cache`; i commit lockfiles and source, never toolchain binaries or generated compiler output.

## I shape a change

I keep each change narrow and write a regression test beside the behavior. i update `docs/architecture.md` when a language boundary, data contract, numeric rule, or threat boundary changes; i update `docs/design.md` when an interaction or visual rule changes.

I write repository prose in first person, keep the opening word of each heading and paragraph uppercase, and keep the rest of the prose lowercase except for product names and technical identifiers. i use plain punctuation and avoid em dashes.

## I preserve the data boundary

I keep new data local, attributed, and licensed before adding it to a fixture. i record the source, collection date, bounding box, counts, and license beside each extract; i do not add live tile calls or claim that a synthetic closure is a field observation.

I preserve integer millimeter route weights and integer basis-point ratios in the routing path; i add separate tests before changing graph scoring or schema version 1. i keep source graph mutation out of scenario analysis.

## I prepare a change for review

I run `make test` before submitting a change; i include the test outcome, behavior change, and any known limit in the change summary. i keep generated files, credentials, raw tokens, and personal data out of commits.

I use focused commits with direct messages; i add or revise a good-first issue when a small follow-up becomes clear. i keep pull requests free of unrelated formatting changes so each review stays easy to trace.
