----------------------------------------------------------------------
-- InsForge Database Baseline for Pigsty
-- https://github.com/InsForge/InsForge
----------------------------------------------------------------------

----------------------------------------------------------------------
-- Grant schema permissions to InsForge PostgREST roles
----------------------------------------------------------------------
GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO anon, authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO anon, authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO anon, authenticated;

----------------------------------------------------------------------
-- Project admin uses service-key semantics in recent InsForge releases
----------------------------------------------------------------------
ALTER ROLE project_admin BYPASSRLS;
GRANT ALL ON SCHEMA public TO project_admin;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO project_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO project_admin;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO project_admin;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON TABLES TO project_admin;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON SEQUENCES TO project_admin;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO project_admin;

DO $$
BEGIN
  EXECUTE format('GRANT CREATE ON DATABASE %I TO project_admin', current_database());
END $$;

----------------------------------------------------------------------
-- PostgREST schema reload helper
----------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.reload_postgrest_schema()
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  NOTIFY pgrst, 'reload schema';
END;
$$;

GRANT EXECUTE ON FUNCTION public.reload_postgrest_schema() TO project_admin;
GRANT EXECUTE ON FUNCTION public.reload_postgrest_schema() TO authenticated;

----------------------------------------------------------------------
-- Pigsty standard role integration: grant default privileges
----------------------------------------------------------------------
ALTER DEFAULT PRIVILEGES FOR ROLE dbuser_insforge IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO anon, authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE dbuser_insforge IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO anon, authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE dbuser_insforge IN SCHEMA public GRANT ALL PRIVILEGES ON TABLES TO project_admin;
ALTER DEFAULT PRIVILEGES FOR ROLE dbuser_insforge IN SCHEMA public GRANT ALL PRIVILEGES ON SEQUENCES TO project_admin;
ALTER DEFAULT PRIVILEGES FOR ROLE dbuser_insforge IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO project_admin;
ALTER DEFAULT PRIVILEGES FOR ROLE dbuser_insforge IN SCHEMA public GRANT SELECT ON TABLES TO dbrole_readonly;
ALTER DEFAULT PRIVILEGES FOR ROLE dbuser_insforge IN SCHEMA public GRANT INSERT, UPDATE, DELETE ON TABLES TO dbrole_readwrite;
ALTER DEFAULT PRIVILEGES FOR ROLE dbuser_insforge IN SCHEMA public GRANT TRUNCATE, REFERENCES, TRIGGER ON TABLES TO dbrole_admin;
ALTER DEFAULT PRIVILEGES FOR ROLE dbuser_insforge IN SCHEMA public GRANT USAGE ON SEQUENCES TO dbrole_readonly;
ALTER DEFAULT PRIVILEGES FOR ROLE dbuser_insforge IN SCHEMA public GRANT USAGE, UPDATE ON SEQUENCES TO dbrole_readwrite;

----------------------------------------------------------------------
-- Cleanup obsolete project_admin policy triggers from older baselines
----------------------------------------------------------------------
DROP EVENT TRIGGER IF EXISTS create_policies_on_table_create;
DROP EVENT TRIGGER IF EXISTS create_policies_on_rls_enable;
DROP FUNCTION IF EXISTS public.create_default_policies() CASCADE;
DROP FUNCTION IF EXISTS public.create_policies_after_rls() CASCADE;

----------------------------------------------------------------------
-- Restrict outbound HTTP RPC to project_admin (upstream migration 065)
----------------------------------------------------------------------
-- https://github.com/InsForge/InsForge/blob/636d1e207d2bca246f7b8ccd0e0b6572528809fa/backend/src/infra/database/migrations/065_restrict-http-extension-to-admin.sql
-- Pigsty installs http in public; project_admin was granted EXECUTE above.

REVOKE EXECUTE ON FUNCTION
  public.http(public.http_request),
  public.http_get(varchar),
  public.http_get(varchar, jsonb),
  public.http_post(varchar, varchar, varchar),
  public.http_post(varchar, jsonb),
  public.http_put(varchar, varchar, varchar),
  public.http_patch(varchar, varchar, varchar),
  public.http_delete(varchar),
  public.http_delete(varchar, varchar, varchar),
  public.http_head(varchar),
  public.http_set_curlopt(varchar, varchar),
  public.http_reset_curlopt(),
  public.http_list_curlopt()
FROM PUBLIC;
