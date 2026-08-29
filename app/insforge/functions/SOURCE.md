# Upstream function runtime

This directory vendors `functions/` from InsForge v2.3.1:

- Repository: https://github.com/InsForge/InsForge
- Commit: `099e101d744ac0bc9496afaf415e4dad2f55c64f`
- Source: https://github.com/InsForge/InsForge/tree/099e101d744ac0bc9496afaf415e4dad2f55c64f/functions
- Copyright: 2025 Insforge Inc. and upstream contributors
- License: Apache-2.0; the upstream license is reproduced in [LICENSE](LICENSE).

Pigsty pins the worker's `@insforge/sdk` import to `1.5.2`, the version used by
the normal function regression, and includes `deno.lock` for reproducible
bootstrap of the host and worker dependencies. The server source is unchanged;
`deno.json` has only a normalized final newline. There is no upstream NOTICE file
at this release. Keep the snapshot aligned with the InsForge image version.
