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
