# CutLine security policy

I keep CutLine as a local-only graph experiment; i do not operate a hosted service, collect accounts, or transmit route selections to a remote endpoint.

## I keep the runtime local

I bind the HTTP service to loopback and choose an ephemeral port by default. i require the exact loopback host, reject any supplied origin outside the same local origin, enable no permissive CORS, and serve only fixed local assets.

I cap imported GeoJSON at 20 MiB, features at 10,000, coordinates at 500,000, and local extent at 0.25 degrees. i cap request bodies at 64 KiB, closure ids at 500, API responses at 32 MiB, and each served asset at 4 MiB; i validate ids, endpoints, directions, and nonnegative integer route weights before analysis.

I make no outbound request during startup or scenario analysis; i keep OpenStreetMap attribution links beside the map and open them only after a deliberate click. i store no account data, route history, or credential.

## I report a security concern

I prefer a private GitHub Security Advisory when private vulnerability reporting is available; i keep working exploit details out of public issues while i assess a report. i include the CutLine version, operating system, reproduction conditions, and impact without attaching access tokens, passwords, private keys, or personal data.

I treat malformed input, local request forgery, unexpected outbound traffic, dependency compromise, and data exposure as in-scope concerns. i keep ordinary feature requests and non-sensitive bug reports in the public issue tracker.

## I handle sensitive material

I never ask for a pasted credential, token, or private dataset in a public report. i redact secrets from logs and remove temporary reproductions after the investigation; i publish a fix and a concise impact note when a report is resolved.

I do not promise a response time or a hosted uptime target because i do not run a public service. i keep the local threat boundary documented in [`docs/architecture.md`](docs/architecture.md).
