# I seed good-first issues

I keep these first contributions narrow, testable, and useful without changing the graph contract. i will open them with the `good first issue` label when the public repository is ready.

## I cover reverse-oneway GeoJSON imports

**Title:** I add import coverage for reverse one-way streets

I add a small GeoJSON fixture with `oneway: "-1"` and source node ids; i assert that the normalized graph allows travel only from the second coordinate to the first. i keep the existing version 1 schema and route weights unchanged.

**Acceptance:** I add a focused importer test, keep the fixture local and attributed, and pass `make test`.

## I exercise rejected closure ids over HTTP

**Title:** I test an unknown closure id through the local API

I extend the loopback smoke check with an `/api/analyze` request containing an unknown segment id; i assert a `400` response and keep the server process cleanup reliable.

**Acceptance:** I cover the request path without adding a network dependency, keep the response body bounded, and pass `make test`.

## I test display rounding boundaries

**Title:** I cover distance formatting at the meter and kilometer thresholds

I add Elm tests around values just below and above one kilometer and around the tenth-kilometer rounding boundary; i preserve integer arithmetic and existing display units.

**Acceptance:** I add pure formatter tests, keep the values in integer millimeters, and pass the Elm suite from `make test`.
