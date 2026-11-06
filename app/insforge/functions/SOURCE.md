# Upstream function runtime

This directory vendors `functions/` from InsForge v2.3.5. Upstream `functions/`
is unchanged between v2.3.3 and v2.3.5, so the snapshot taken at v2.3.3 is
identical to the v2.3.5 tree:

- Repository: https://github.com/InsForge/InsForge
- Commit: `c1c886e775d286433e4b50c78c24335783e8fc00` (v2.3.5; snapshot originally taken at v2.3.3 `636d1e207d2bca246f7b8ccd0e0b6572528809fa`)
- Source: https://github.com/InsForge/InsForge/tree/c1c886e775d286433e4b50c78c24335783e8fc00/functions
- Copyright: 2025 Insforge Inc. and upstream contributors
- License: Apache-2.0; the upstream license is reproduced in [LICENSE](LICENSE).

Pigsty pins the worker's `@insforge/sdk` import to `1.5.2`, the version used by
the normal function regression, and includes `deno.lock` for reproducible
bootstrap of the host and worker dependencies. The server source is unchanged;
`deno.json` has only a normalized final newline. There is no upstream NOTICE file
at this release. Keep the snapshot aligned with the InsForge image version.
