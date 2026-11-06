# Edge Functions source

`main/index.ts`, `main/memory-pressure.ts` and `deno.jsonc` follow the official Supabase
[`self-hosted/v0.8.4` tree](https://github.com/supabase/supabase/tree/189adda99d1b56da55fc5a6ee3f849354aaea92a/docker/volumes/functions),
commit `189adda99d1b56da55fc5a6ee3f849354aaea92a`.

The worker retains legacy HS256 and ES256/RS256 JWKS verification, the upstream
authentication error format, and the per-request `SUPABASE_FUNCTION_SLUG`.
It also accepts the gateway-minted `sb-api-key` header for `sb_` API keys,
returns structured `{ code, message }` errors with CORS headers, retries retired
workers, and reclaims idle workers under the container memory limit
(`FUNCTIONS_MEMORY_LIMIT`, default `2g`).
The shared import map resolves `@supabase/functions-js` and `@supabase/server`.
