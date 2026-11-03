# Edge Functions source

`main/index.ts` and `deno.jsonc` follow the official Supabase
[`self-hosted/v0.8.2` tree](https://github.com/supabase/supabase/tree/564eab8ad7840b13324f68b1bfac074ef8d51c21/docker/volumes/functions),
commit `564eab8ad7840b13324f68b1bfac074ef8d51c21`.

The worker retains legacy HS256 and ES256/RS256 JWKS verification, the upstream
authentication error format, and the per-request `SUPABASE_FUNCTION_SLUG`.
The shared import map resolves `@supabase/functions-js` and `@supabase/server`.
