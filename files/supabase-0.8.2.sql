-- Pigsty Supabase self-hosted/v0.8.2: narrow upgrade for an existing database.
-- Connect to the target Supabase database as its administrator after a backup.
-- Migrate custom SQL that reads current_setting('app.settings.jwt_secret') first.
-- This does not replay the fresh-install baseline or change application JWT keys.
-- Sources:
-- https://github.com/supabase/supabase/pull/45003
-- https://github.com/supabase/supabase/blob/564eab8ad7840b13324f68b1bfac074ef8d51c21/docker/volumes/db/webhooks.sql
\set ON_ERROR_STOP on

BEGIN;

-- The old Pigsty template persisted the secret at database scope. Keep jwt_exp.
DO $$
BEGIN
    EXECUTE format('ALTER DATABASE %I RESET "app.settings.jwt_secret"', current_database());
END
$$;

-- The SECURITY DEFINER webhook function needs to serialize extension types.
GRANT USAGE ON SCHEMA extensions TO supabase_functions_admin;

COMMIT;

-- Existing connections can retain the old setting. Verify using a new session
-- after replacing the old PostgREST configuration and recreating its container.
