-- ######################################################################
-- # File      :   supabase.sql
-- # Desc      :   Pigsty self-hosting supabase baseline schema
-- # Ctime     :   2021-04-21
-- # Mtime     :   2025-07-01
-- # License   :   Apache-2.0 @ https://pigsty.io/docs/about/license/
-- # Copyright :   2018-2026  Ruohang Feng / Vonng (rh@vonng.com)
-- ######################################################################

-- This schema file consists of 2 parts:
-- the baseline: init scripts from supabase postgres container
--   gather from: https://github.com/supabase/postgres/tree/develop/migrations/db/init-scripts
-- the migration: schema from supabase docker compose
--   gather from: https://github.com/supabase/postgres/tree/develop/migrations/db/migrations


--===========================================================--
--                            baseline                       --
--===========================================================--
-- supabase init schema baseline, run this as postgres, the dbsu



-----------------------------------------
--- name: 01-initial-schema
-----------------------------------------
CREATE PUBLICATION supabase_realtime;

grant create on database postgres to supabase_etl_admin;

-- setup schema owner
ALTER SCHEMA "_analytics"       OWNER TO supabase_admin;
ALTER SCHEMA "_realtime"        OWNER TO supabase_admin;
ALTER SCHEMA auth               OWNER TO supabase_admin;
ALTER SCHEMA extensions         OWNER TO supabase_admin;
ALTER SCHEMA graphql_public     OWNER TO supabase_admin;
ALTER SCHEMA realtime           OWNER TO supabase_admin;
ALTER SCHEMA storage            OWNER TO supabase_admin;
ALTER SCHEMA supabase_functions OWNER TO supabase_admin;

GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
GRANT USAGE ON SCHEMA extensions TO anon, authenticated, service_role;

ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO anon, authenticated, service_role;

ALTER USER supabase_admin SET search_path TO public, extensions;
ALTER DEFAULT PRIVILEGES FOR USER supabase_admin IN SCHEMA public GRANT ALL ON TABLES TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES FOR USER supabase_admin IN SCHEMA public GRANT ALL ON FUNCTIONS TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES FOR USER supabase_admin IN SCHEMA public GRANT ALL ON SEQUENCES TO anon, authenticated, service_role;

ALTER ROLE anon SET statement_timeout = '3s';
ALTER ROLE authenticated SET statement_timeout = '8s';


-----------------------------------------
--- name: 02-auth-schema
-----------------------------------------

CREATE SCHEMA IF NOT EXISTS auth AUTHORIZATION supabase_admin;

-- auth.users definition

CREATE TABLE auth.users
(
    instance_id          uuid         NULL,
    id                   uuid         NOT NULL UNIQUE,
    aud                  varchar(255) NULL,
    "role"               varchar(255) NULL,
    email                varchar(255) NULL UNIQUE,
    encrypted_password   varchar(255) NULL,
    confirmed_at         timestamptz  NULL,
    invited_at           timestamptz  NULL,
    confirmation_token   varchar(255) NULL,
    confirmation_sent_at timestamptz  NULL,
    recovery_token       varchar(255) NULL,
    recovery_sent_at     timestamptz  NULL,
    email_change_token   varchar(255) NULL,
    email_change         varchar(255) NULL,
    email_change_sent_at timestamptz  NULL,
    last_sign_in_at      timestamptz  NULL,
    raw_app_meta_data    jsonb        NULL,
    raw_user_meta_data   jsonb        NULL,
    is_super_admin       bool         NULL,
    created_at           timestamptz  NULL,
    updated_at           timestamptz  NULL,
    CONSTRAINT users_pkey PRIMARY KEY (id)
);
CREATE INDEX users_instance_id_email_idx ON auth.users USING btree (instance_id, email);
CREATE INDEX users_instance_id_idx ON auth.users USING btree (instance_id);
COMMENT ON TABLE auth.users IS 'Auth: Stores user login data within a secure schema.';

-- auth.refresh_tokens definition

CREATE TABLE auth.refresh_tokens
(
    instance_id uuid         NULL,
    id          bigserial    NOT NULL,
    "token"     varchar(255) NULL,
    user_id     varchar(255) NULL,
    revoked     bool         NULL,
    created_at  timestamptz  NULL,
    updated_at  timestamptz  NULL,
    CONSTRAINT refresh_tokens_pkey PRIMARY KEY (id)
);
CREATE INDEX refresh_tokens_instance_id_idx ON auth.refresh_tokens USING btree (instance_id);
CREATE INDEX refresh_tokens_instance_id_user_id_idx ON auth.refresh_tokens USING btree (instance_id, user_id);
CREATE INDEX refresh_tokens_token_idx ON auth.refresh_tokens USING btree (token);
COMMENT ON TABLE auth.refresh_tokens IS 'Auth: Store of tokens used to refresh JWT tokens once they expire.';

-- auth.instances definition

CREATE TABLE auth.instances
(
    id              uuid        NOT NULL,
    uuid            uuid        NULL,
    raw_base_config text        NULL,
    created_at      timestamptz NULL,
    updated_at      timestamptz NULL,
    CONSTRAINT instances_pkey PRIMARY KEY (id)
);
COMMENT ON TABLE auth.instances IS 'Auth: Manages users across multiple sites.';

-- auth.audit_log_entries definition

CREATE TABLE auth.audit_log_entries
(
    instance_id uuid        NULL,
    id          uuid        NOT NULL,
    payload     json        NULL,
    created_at  timestamptz NULL,
    CONSTRAINT audit_log_entries_pkey PRIMARY KEY (id)
);
CREATE INDEX audit_logs_instance_id_idx ON auth.audit_log_entries USING btree (instance_id);
COMMENT ON TABLE auth.audit_log_entries IS 'Auth: Audit trail for user actions.';

-- auth.schema_migrations definition

CREATE TABLE auth.schema_migrations
(
    "version" varchar(255) NOT NULL,
    CONSTRAINT schema_migrations_pkey PRIMARY KEY ("version")
);
COMMENT ON TABLE auth.schema_migrations IS 'Auth: Manages updates to the auth system.';

INSERT INTO auth.schema_migrations (version)
VALUES ('20171026211738'),
       ('20171026211808'),
       ('20171026211834'),
       ('20180103212743'),
       ('20180108183307'),
       ('20180119214651'),
       ('20180125194653');

CREATE OR REPLACE FUNCTION auth.uid() RETURNS UUID LANGUAGE SQL STABLE AS
$$SELECT coalesce(current_setting('request.jwt.claim.sub', true),(current_setting('request.jwt.claims', true)::jsonb ->> 'sub'))::UUID$$;

CREATE OR REPLACE FUNCTION auth.role() RETURNS TEXT LANGUAGE SQL STABLE AS
$$SELECT coalesce(current_setting('request.jwt.claim.role', true),(current_setting('request.jwt.claims', true)::jsonb ->> 'role'))::text$$;

CREATE OR REPLACE FUNCTION auth.email() RETURNS TEXT LANGUAGE SQL STABLE AS
$$select coalesce(current_setting('request.jwt.claim.email', true),(current_setting('request.jwt.claims', true)::jsonb ->> 'email'))::TEXT$$;

-- usage on auth functions to API roles
GRANT USAGE ON SCHEMA auth TO anon, authenticated, service_role;

-- Supabase super admin
-- CREATE USER supabase_auth_admin NOINHERIT CREATEROLE LOGIN NOREPLICATION;
GRANT ALL PRIVILEGES ON SCHEMA auth TO supabase_auth_admin;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA auth TO supabase_auth_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA auth TO supabase_auth_admin;

ALTER USER supabase_auth_admin SET search_path = "auth";
ALTER TABLE "auth".users OWNER TO supabase_auth_admin;
ALTER TABLE "auth".refresh_tokens OWNER TO supabase_auth_admin;
ALTER TABLE "auth".audit_log_entries OWNER TO supabase_auth_admin;
ALTER TABLE "auth".instances OWNER TO supabase_auth_admin;
ALTER TABLE "auth".schema_migrations OWNER TO supabase_auth_admin;

ALTER FUNCTION auth.uid OWNER TO supabase_auth_admin;
ALTER FUNCTION auth.role OWNER TO supabase_auth_admin;
ALTER FUNCTION auth.email OWNER TO supabase_auth_admin;
GRANT EXECUTE ON FUNCTION "auth"."uid"() TO PUBLIC;
GRANT EXECUTE ON FUNCTION "auth"."role"() TO PUBLIC;
GRANT EXECUTE ON FUNCTION "auth"."email"() TO PUBLIC;






-----------------------------------------
--- name: 03-storage-schema
-----------------------------------------
CREATE SCHEMA IF NOT EXISTS storage AUTHORIZATION supabase_admin;

GRANT USAGE ON SCHEMA storage TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA storage GRANT ALL ON TABLES TO postgres, anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA storage GRANT ALL ON FUNCTIONS TO postgres, anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA storage GRANT ALL ON SEQUENCES TO postgres, anon, authenticated, service_role;

CREATE TABLE "storage"."buckets"
(
    "id"         text not NULL,
    "name"       text NOT NULL,
    "owner"      uuid,
    "created_at" timestamptz DEFAULT now(),
    "updated_at" timestamptz DEFAULT now(),
    CONSTRAINT "buckets_owner_fkey" FOREIGN KEY ("owner") REFERENCES "auth"."users" ("id"),
    PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "bname" ON "storage"."buckets" USING BTREE ("name");

CREATE TABLE "storage"."objects"
(
    "id"               uuid NOT NULL DEFAULT extensions.uuid_generate_v4(),
    "bucket_id"        text,
    "name"             text,
    "owner"            uuid,
    "created_at"       timestamptz   DEFAULT now(),
    "updated_at"       timestamptz   DEFAULT now(),
    "last_accessed_at" timestamptz   DEFAULT now(),
    "metadata"         jsonb,
    CONSTRAINT "objects_bucketId_fkey" FOREIGN KEY ("bucket_id") REFERENCES "storage"."buckets" ("id"),
    CONSTRAINT "objects_owner_fkey" FOREIGN KEY ("owner") REFERENCES "auth"."users" ("id"),
    PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "bucketid_objname" ON "storage"."objects" USING BTREE ("bucket_id", "name");
CREATE INDEX name_prefix_search ON storage.objects (name text_pattern_ops);

ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

CREATE FUNCTION storage.foldername(name text) RETURNS text[] LANGUAGE plpgsql AS $function$
DECLARE
    _parts text[];
BEGIN
    select string_to_array(name, '/') into _parts;
    return _parts[1:array_length(_parts, 1) - 1];
END
$function$;

CREATE FUNCTION storage.filename(name text) RETURNS text LANGUAGE plpgsql AS $function$
DECLARE
    _parts text[];
BEGIN
    select string_to_array(name, '/') into _parts;
    return _parts[array_length(_parts, 1)];
END
$function$;

CREATE FUNCTION storage.extension(name text) RETURNS text LANGUAGE plpgsql AS $function$
DECLARE
    _parts    text[];
    _filename text;
BEGIN
    select string_to_array(name, '/') into _parts;
    select _parts[array_length(_parts, 1)] into _filename;
    -- @todo return the last part instead of 2
    return split_part(_filename, '.', 2);
END
$function$;

CREATE FUNCTION storage.search(prefix text, bucketname text, limits int DEFAULT 100, levels int DEFAULT 1,offsets int DEFAULT 0)
    RETURNS TABLE
            (
                name             text,
                id               uuid,
                updated_at       TIMESTAMPTZ,
                created_at       TIMESTAMPTZ,
                last_accessed_at TIMESTAMPTZ,
                metadata         jsonb
            )
    LANGUAGE plpgsql AS $function$
DECLARE
    _bucketId text;
BEGIN
    -- will be replaced by migrations when server starts
    -- saving space for cloud-init
END
$function$;

-- create migrations table
-- https://github.com/ThomWright/postgres-migrations/blob/master/src/migrations/0_create-migrations-table.sql
-- we add this table here and not let it be auto-created so that the permissions are properly applied to it
CREATE TABLE IF NOT EXISTS storage.migrations
(
    id          integer PRIMARY KEY,
    name        varchar(100) UNIQUE NOT NULL,
    hash        varchar(40)         NOT NULL, -- sha1 hex encoded hash of the file name and contents, to ensure it hasn't been altered since applying the migration
    executed_at timestamp DEFAULT current_timestamp
);

-- CREATE USER supabase_storage_admin NOINHERIT CREATEROLE LOGIN NOREPLICATION;
GRANT ALL PRIVILEGES ON SCHEMA storage TO supabase_storage_admin;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA storage TO supabase_storage_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA storage TO supabase_storage_admin;
ALTER USER supabase_storage_admin SET search_path = "storage";
ALTER TABLE "storage".objects OWNER TO supabase_storage_admin;
ALTER TABLE "storage".buckets OWNER TO supabase_storage_admin;
ALTER TABLE "storage".migrations OWNER TO supabase_storage_admin;
ALTER FUNCTION "storage".foldername(text) OWNER TO supabase_storage_admin;
ALTER FUNCTION "storage".filename(text)   OWNER TO supabase_storage_admin;
ALTER FUNCTION "storage".extension(text) OWNER TO supabase_storage_admin;
ALTER FUNCTION "storage".search(text,text,int,int,int) OWNER TO supabase_storage_admin;



-----------------------------------------
--- name: 04-post-setup
-----------------------------------------
ALTER ROLE postgres SET search_path TO "\$user",public,extensions;
CREATE OR REPLACE FUNCTION extensions.notify_api_restart()
    RETURNS event_trigger
    LANGUAGE plpgsql
AS
$$
BEGIN
    NOTIFY ddl_command_end;
END;
$$;
CREATE EVENT TRIGGER api_restart ON ddl_command_end
EXECUTE PROCEDURE extensions.notify_api_restart();
COMMENT ON FUNCTION extensions.notify_api_restart IS 'Sends a notification to the API to restart. If your database schema has changed, this is required so that Supabase can rebuild the relationships.';

-- Trigger for pg_cron
CREATE OR REPLACE FUNCTION extensions.grant_pg_cron_access()
    RETURNS event_trigger
    LANGUAGE plpgsql
AS
$$
DECLARE
    schema_is_cron bool;
BEGIN
    schema_is_cron = (SELECT n.nspname = 'cron'
                      FROM pg_event_trigger_ddl_commands() AS ev
                               LEFT JOIN pg_catalog.pg_namespace AS n
                                         ON ev.objid = n.oid);

    IF schema_is_cron
    THEN
        grant usage on schema cron to postgres with grant option;

        alter default privileges in schema cron grant all on tables to postgres with grant option;
        alter default privileges in schema cron grant all on functions to postgres with grant option;
        alter default privileges in schema cron grant all on sequences to postgres with grant option;

        alter default privileges for user supabase_admin in schema cron grant all
            on sequences to postgres with grant option;
        alter default privileges for user supabase_admin in schema cron grant all
            on tables to postgres with grant option;
        alter default privileges for user supabase_admin in schema cron grant all
            on functions to postgres with grant option;

        grant all privileges on all tables in schema cron to postgres with grant option;

    END IF;

END;
$$;
CREATE EVENT TRIGGER issue_pg_cron_access ON ddl_command_end WHEN TAG IN ('CREATE SCHEMA')
EXECUTE PROCEDURE extensions.grant_pg_cron_access();
COMMENT ON FUNCTION extensions.grant_pg_cron_access IS 'Grants access to pg_cron';

-- Supabase dashboard user
-- CREATE ROLE dashboard_user NOSUPERUSER CREATEDB CREATEROLE REPLICATION;
GRANT ALL ON DATABASE postgres TO dashboard_user;
GRANT ALL ON SCHEMA auth TO dashboard_user;
GRANT ALL ON SCHEMA extensions TO dashboard_user;
GRANT ALL ON SCHEMA storage TO dashboard_user;
GRANT ALL ON ALL TABLES IN SCHEMA auth TO dashboard_user;
GRANT ALL ON ALL TABLES IN SCHEMA extensions TO dashboard_user;
-- GRANT ALL ON ALL TABLES IN SCHEMA storage TO dashboard_user;
GRANT ALL ON ALL SEQUENCES IN SCHEMA auth TO dashboard_user;
GRANT ALL ON ALL SEQUENCES IN SCHEMA storage TO dashboard_user;
GRANT ALL ON ALL SEQUENCES IN SCHEMA extensions TO dashboard_user;
GRANT ALL ON ALL ROUTINES  IN SCHEMA auth TO dashboard_user;
GRANT ALL ON ALL ROUTINES  IN SCHEMA storage TO dashboard_user;
GRANT ALL ON ALL ROUTINES  IN SCHEMA extensions TO dashboard_user;


-----------------------------------------
-- name: 05-reset-auth
-----------------------------------------
-- ALTER ROLE authenticator inherit;
-- alter role authenticator superuser;
GRANT pgsodium_keyholder to service_role;

---













--===========================================================--
--                         migration                         --
--===========================================================--
-- run with supabase_admin, idempotent (can be run multiple times)
SET ROLE supabase_admin;

----------------------------------------------------
-- 10000000000000_demote-postgres.sql
----------------------------------------------------
-- skip this because we don't want to demote postgres user in Pigsty's postgres instances

-- migrate:up

-- demote postgres user
-- GRANT ALL ON DATABASE postgres TO postgres;
-- GRANT ALL ON SCHEMA auth TO postgres;
-- GRANT ALL ON SCHEMA extensions TO postgres;
-- GRANT ALL ON SCHEMA storage TO postgres;
-- GRANT ALL ON ALL TABLES IN SCHEMA auth TO postgres;
-- GRANT ALL ON ALL TABLES IN SCHEMA storage TO postgres;
-- GRANT ALL ON ALL TABLES IN SCHEMA extensions TO postgres;
-- GRANT ALL ON ALL SEQUENCES IN SCHEMA auth TO postgres;
-- GRANT ALL ON ALL SEQUENCES IN SCHEMA storage TO postgres;
-- GRANT ALL ON ALL SEQUENCES IN SCHEMA extensions TO postgres;
-- GRANT ALL ON ALL ROUTINES IN SCHEMA auth TO postgres;
-- GRANT ALL ON ALL ROUTINES IN SCHEMA storage TO postgres;
-- GRANT ALL ON ALL ROUTINES IN SCHEMA extensions TO postgres;
-- ALTER ROLE postgres NOSUPERUSER CREATEDB CREATEROLE LOGIN REPLICATION BYPASSRLS;

-- migrate:down




----------------------------------------------------
-- 20211115181400_update-auth-permissions.sql
----------------------------------------------------
-- migrate:up

-- update auth schema permissions
GRANT ALL PRIVILEGES ON SCHEMA auth TO supabase_auth_admin;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA auth TO supabase_auth_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA auth TO supabase_auth_admin;

ALTER table IF EXISTS "auth".users OWNER TO supabase_auth_admin;
ALTER table IF EXISTS "auth".refresh_tokens OWNER TO supabase_auth_admin;
ALTER table IF EXISTS "auth".audit_log_entries OWNER TO supabase_auth_admin;
ALTER table IF EXISTS "auth".instances OWNER TO supabase_auth_admin;
ALTER table IF EXISTS "auth".schema_migrations OWNER TO supabase_auth_admin;

GRANT USAGE ON SCHEMA auth TO postgres;
GRANT ALL ON ALL TABLES IN SCHEMA auth TO postgres, dashboard_user;
GRANT ALL ON ALL SEQUENCES IN SCHEMA auth TO postgres, dashboard_user;
GRANT ALL ON ALL ROUTINES IN SCHEMA auth TO postgres, dashboard_user;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_auth_admin IN SCHEMA auth GRANT ALL ON TABLES TO postgres, dashboard_user;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_auth_admin IN SCHEMA auth GRANT ALL ON SEQUENCES TO postgres, dashboard_user;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_auth_admin IN SCHEMA auth GRANT ALL ON ROUTINES TO postgres, dashboard_user;

-- migrate:down





----------------------------------------------------
-- 20211118015519_create-realtime-schema.sql
----------------------------------------------------
-- migrate:up

-- create realtime schema for Realtime RLS (WALRUS)
CREATE SCHEMA IF NOT EXISTS realtime;

-- migrate:down





----------------------------------------------------
-- 20211122051245_update-realtime-permissions.sql
----------------------------------------------------
-- migrate:up

-- update realtime schema permissions
GRANT USAGE ON SCHEMA realtime TO postgres;
GRANT ALL ON ALL TABLES IN SCHEMA realtime TO postgres, dashboard_user;
GRANT ALL ON ALL SEQUENCES IN SCHEMA realtime TO postgres, dashboard_user;
GRANT ALL ON ALL ROUTINES IN SCHEMA realtime TO postgres, dashboard_user;

-- migrate:down





----------------------------------------------------
-- 20211124212715_update-auth-owner.sql
----------------------------------------------------
-- migrate:up

-- update owner for auth.uid, auth.role and auth.email functions
DO $$
BEGIN
    ALTER FUNCTION auth.uid owner to supabase_auth_admin;
EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'Error encountered when changing owner of auth.uid to supabase_auth_admin';
END $$;

DO $$
BEGIN
    ALTER FUNCTION auth.role owner to supabase_auth_admin;
EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'Error encountered when changing owner of auth.role to supabase_auth_admin';
END $$;

DO $$
BEGIN
    ALTER FUNCTION auth.email owner to supabase_auth_admin;
EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'Error encountered when changing owner of auth.email to supabase_auth_admin';
END $$;
-- migrate:down





----------------------------------------------------
-- 20211130151719_update-realtime-permissions.sql
----------------------------------------------------
-- migrate:up

-- Update future objects' permissions
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA realtime GRANT ALL ON TABLES TO postgres, dashboard_user;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA realtime GRANT ALL ON SEQUENCES TO postgres, dashboard_user;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA realtime GRANT ALL ON ROUTINES TO postgres, dashboard_user;

-- migrate:down





----------------------------------------------------
-- 20220118070449_enable-safeupdate-postgrest.sql
----------------------------------------------------
-- migrate:up
ALTER ROLE authenticator SET session_preload_libraries = 'safeupdate';

-- migrate:down





----------------------------------------------------
-- 20220126121436_finer-postgrest-triggers.sql
----------------------------------------------------
-- migrate:up

drop event trigger if exists api_restart;
drop function if exists extensions.notify_api_restart();

-- https://postgrest.org/en/latest/schema_cache.html#finer-grained-event-trigger
-- watch create and alter
CREATE OR REPLACE FUNCTION extensions.pgrst_ddl_watch() RETURNS event_trigger AS $$
DECLARE
    cmd record;
BEGIN
    FOR cmd IN SELECT * FROM pg_event_trigger_ddl_commands()
        LOOP
            IF cmd.command_tag IN (
                                   'CREATE SCHEMA', 'ALTER SCHEMA'
                , 'CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO', 'ALTER TABLE'
                , 'CREATE FOREIGN TABLE', 'ALTER FOREIGN TABLE'
                , 'CREATE VIEW', 'ALTER VIEW'
                , 'CREATE MATERIALIZED VIEW', 'ALTER MATERIALIZED VIEW'
                , 'CREATE FUNCTION', 'ALTER FUNCTION'
                , 'CREATE TRIGGER'
                , 'CREATE TYPE'
                , 'CREATE RULE'
                , 'COMMENT'
                )
                -- don't notify in case of CREATE TEMP table or other objects created on pg_temp
                AND cmd.schema_name is distinct from 'pg_temp'
            THEN
                NOTIFY pgrst, 'reload schema';
            END IF;
        END LOOP;
END; $$ LANGUAGE plpgsql;

-- watch drop
CREATE OR REPLACE FUNCTION extensions.pgrst_drop_watch() RETURNS event_trigger AS $$
DECLARE
    obj record;
BEGIN
    FOR obj IN SELECT * FROM pg_event_trigger_dropped_objects()
        LOOP
            IF obj.object_type IN (
                                   'schema'
                , 'table'
                , 'foreign table'
                , 'view'
                , 'materialized view'
                , 'function'
                , 'trigger'
                , 'type'
                , 'rule'
                )
                AND obj.is_temporary IS false -- no pg_temp objects
            THEN
                NOTIFY pgrst, 'reload schema';
            END IF;
        END LOOP;
END; $$ LANGUAGE plpgsql;

DROP EVENT TRIGGER IF EXISTS pgrst_ddl_watch;
CREATE EVENT TRIGGER pgrst_ddl_watch
    ON ddl_command_end
EXECUTE PROCEDURE extensions.pgrst_ddl_watch();

DROP EVENT TRIGGER IF EXISTS pgrst_drop_watch;
CREATE EVENT TRIGGER pgrst_drop_watch
    ON sql_drop
EXECUTE PROCEDURE extensions.pgrst_drop_watch();


-- migrate:down





----------------------------------------------------
-- 20220224211803_fix-postgrest-supautils.sql
----------------------------------------------------
-- migrate:up

-- Note: supatils extension is not installed in docker image.

DO $$
    DECLARE
        supautils_exists boolean;
    BEGIN
        supautils_exists = (
            select count(*) = 1
            from pg_available_extensions
            where name = 'supautils'
        );

        IF supautils_exists
        THEN
            ALTER ROLE authenticator SET session_preload_libraries = supautils, safeupdate;
        END IF;
    END $$;

-- migrate:down





----------------------------------------------------
-- 20220317095840_pg_graphql.sql
----------------------------------------------------
-- migrate:up
create schema if not exists graphql_public;

-- GraphQL Placeholder Entrypoint
create or replace function graphql_public.graphql(
    "operationName" text default null,
    query text default null,
    variables jsonb default null,
    extensions jsonb default null
)
    returns jsonb
    language plpgsql
as $$
DECLARE
    server_version float;
BEGIN
    server_version = (SELECT (SPLIT_PART((select version()), ' ', 2))::float);

    IF server_version >= 14 THEN
        RETURN jsonb_build_object(
                'data', null::jsonb,
                'errors', array['pg_graphql extension is not enabled.']
               );
    ELSE
        RETURN jsonb_build_object(
                'data', null::jsonb,
                'errors', array['pg_graphql is only available on projects running Postgres 14 onwards.']
               );
    END IF;
END;
$$;

grant usage on schema graphql_public to postgres, anon, authenticated, service_role;
alter default privileges in schema graphql_public grant all on tables to postgres, anon, authenticated, service_role;
alter default privileges in schema graphql_public grant all on functions to postgres, anon, authenticated, service_role;
alter default privileges in schema graphql_public grant all on sequences to postgres, anon, authenticated, service_role;

alter default privileges for user supabase_admin in schema graphql_public grant all
    on sequences to postgres, anon, authenticated, service_role;
alter default privileges for user supabase_admin in schema graphql_public grant all
    on tables to postgres, anon, authenticated, service_role;
alter default privileges for user supabase_admin in schema graphql_public grant all
    on functions to postgres, anon, authenticated, service_role;

-- Trigger upon enabling pg_graphql
CREATE OR REPLACE FUNCTION extensions.grant_pg_graphql_access()
    RETURNS event_trigger
    LANGUAGE plpgsql
AS $func$
DECLARE
    func_is_graphql_resolve bool;
BEGIN
    func_is_graphql_resolve = (
        SELECT n.proname = 'resolve'
        FROM pg_event_trigger_ddl_commands() AS ev
                 LEFT JOIN pg_catalog.pg_proc AS n
                           ON ev.objid = n.oid
    );

    IF func_is_graphql_resolve
    THEN
        grant usage on schema graphql to postgres, anon, authenticated, service_role;
        grant all on function graphql.resolve to postgres, anon, authenticated, service_role;

        alter default privileges in schema graphql grant all on tables to postgres, anon, authenticated, service_role;
        alter default privileges in schema graphql grant all on functions to postgres, anon, authenticated, service_role;
        alter default privileges in schema graphql grant all on sequences to postgres, anon, authenticated, service_role;

        DROP FUNCTION IF EXISTS graphql_public.graphql;
        create or replace function graphql_public.graphql(
            "operationName" text default null,
            query text default null,
            variables jsonb default null,
            extensions jsonb default null
        )
            returns jsonb
            language sql
        as $$
        SELECT graphql.resolve(query, coalesce(variables, '{}'));
        $$;

        grant execute on function graphql.resolve to postgres, anon, authenticated, service_role;
    END IF;

END;
$func$;

DROP EVENT TRIGGER IF EXISTS issue_pg_graphql_access;
CREATE EVENT TRIGGER issue_pg_graphql_access ON ddl_command_end WHEN TAG in ('CREATE FUNCTION')
EXECUTE PROCEDURE extensions.grant_pg_graphql_access();
COMMENT ON FUNCTION extensions.grant_pg_graphql_access IS 'Grants access to pg_graphql';

-- Trigger upon dropping the pg_graphql extension
CREATE OR REPLACE FUNCTION extensions.set_graphql_placeholder()
    RETURNS event_trigger
    LANGUAGE plpgsql
AS $func$
DECLARE
    graphql_is_dropped bool;
BEGIN
    graphql_is_dropped = (
        SELECT ev.schema_name = 'graphql_public'
        FROM pg_event_trigger_dropped_objects() AS ev
        WHERE ev.schema_name = 'graphql_public'
    );

    IF graphql_is_dropped
    THEN
        create or replace function graphql_public.graphql(
            "operationName" text default null,
            query text default null,
            variables jsonb default null,
            extensions jsonb default null
        )
            returns jsonb
            language plpgsql
        as $$
        DECLARE
            server_version float;
        BEGIN
            server_version = (SELECT (SPLIT_PART((select version()), ' ', 2))::float);

            IF server_version >= 14 THEN
                RETURN jsonb_build_object(
                        'data', null::jsonb,
                        'errors', array['pg_graphql extension is not enabled.']
                       );
            ELSE
                RETURN jsonb_build_object(
                        'data', null::jsonb,
                        'errors', array['pg_graphql is only available on projects running Postgres 14 onwards.']
                       );
            END IF;
        END;
        $$;
    END IF;

END;
$func$;

DROP EVENT TRIGGER IF EXISTS issue_graphql_placeholder;
CREATE EVENT TRIGGER issue_graphql_placeholder ON sql_drop WHEN TAG in ('DROP EXTENSION')
EXECUTE PROCEDURE extensions.set_graphql_placeholder();
COMMENT ON FUNCTION extensions.set_graphql_placeholder IS 'Reintroduces placeholder function for graphql_public.graphql';

-- migrate:down





-------------------------------------------------------
-- 20220321174452_fix-postgrest-alter-type-event-triger.sql
------------------------------------------------------
-- migrate:up

drop event trigger if exists api_restart;
drop function if exists extensions.notify_api_restart();

-- https://postgrest.org/en/latest/schema_cache.html#finer-grained-event-trigger
-- watch create and alter
CREATE OR REPLACE FUNCTION extensions.pgrst_ddl_watch() RETURNS event_trigger AS $$
DECLARE
    cmd record;
BEGIN
    FOR cmd IN SELECT * FROM pg_event_trigger_ddl_commands()
        LOOP
            IF cmd.command_tag IN (
                                   'CREATE SCHEMA', 'ALTER SCHEMA'
                , 'CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO', 'ALTER TABLE'
                , 'CREATE FOREIGN TABLE', 'ALTER FOREIGN TABLE'
                , 'CREATE VIEW', 'ALTER VIEW'
                , 'CREATE MATERIALIZED VIEW', 'ALTER MATERIALIZED VIEW'
                , 'CREATE FUNCTION', 'ALTER FUNCTION'
                , 'CREATE TRIGGER'
                , 'CREATE TYPE', 'ALTER TYPE'
                , 'CREATE RULE'
                , 'COMMENT'
                )
                -- don't notify in case of CREATE TEMP table or other objects created on pg_temp
                AND cmd.schema_name is distinct from 'pg_temp'
            THEN
                NOTIFY pgrst, 'reload schema';
            END IF;
        END LOOP;
END; $$ LANGUAGE plpgsql;

-- watch drop
CREATE OR REPLACE FUNCTION extensions.pgrst_drop_watch() RETURNS event_trigger AS $$
DECLARE
    obj record;
BEGIN
    FOR obj IN SELECT * FROM pg_event_trigger_dropped_objects()
        LOOP
            IF obj.object_type IN (
                                   'schema'
                , 'table'
                , 'foreign table'
                , 'view'
                , 'materialized view'
                , 'function'
                , 'trigger'
                , 'type'
                , 'rule'
                )
                AND obj.is_temporary IS false -- no pg_temp objects
            THEN
                NOTIFY pgrst, 'reload schema';
            END IF;
        END LOOP;
END; $$ LANGUAGE plpgsql;

DROP EVENT TRIGGER IF EXISTS pgrst_ddl_watch;
CREATE EVENT TRIGGER pgrst_ddl_watch
    ON ddl_command_end
EXECUTE PROCEDURE extensions.pgrst_ddl_watch();

DROP EVENT TRIGGER IF EXISTS pgrst_drop_watch;
CREATE EVENT TRIGGER pgrst_drop_watch
    ON sql_drop
EXECUTE PROCEDURE extensions.pgrst_drop_watch();


-- migrate:down



----------------------------------------------------
-- 20220322085208_gotrue-session-limit.sql
----------------------------------------------------
-- migrate:up
ALTER ROLE supabase_auth_admin SET idle_in_transaction_session_timeout TO 60000;

-- migrate:down





----------------------------------------------------
-- 20220404205710_pg_graphql-on-by-default.sql
----------------------------------------------------
-- migrate:up

-- Update Trigger upon enabling pg_graphql
create or replace function extensions.grant_pg_graphql_access()
    returns event_trigger
    language plpgsql
AS $func$
DECLARE
    func_is_graphql_resolve bool;
BEGIN
    func_is_graphql_resolve = (
        SELECT n.proname = 'resolve'
        FROM pg_event_trigger_ddl_commands() AS ev
                 LEFT JOIN pg_catalog.pg_proc AS n
                           ON ev.objid = n.oid
    );

    IF func_is_graphql_resolve
    THEN
        grant usage on schema graphql to postgres, anon, authenticated, service_role;
        grant all on function graphql.resolve to postgres, anon, authenticated, service_role;

        alter default privileges in schema graphql grant all on tables to postgres, anon, authenticated, service_role;
        alter default privileges in schema graphql grant all on functions to postgres, anon, authenticated, service_role;
        alter default privileges in schema graphql grant all on sequences to postgres, anon, authenticated, service_role;

        -- Update public wrapper to pass all arguments through to the pg_graphql resolve func
        DROP FUNCTION IF EXISTS graphql_public.graphql;
        create or replace function graphql_public.graphql(
            "operationName" text default null,
            query text default null,
            variables jsonb default null,
            extensions jsonb default null
        )
            returns jsonb
            language sql
        as $$
            -- This changed
        select graphql.resolve(
                       query := query,
                       variables := coalesce(variables, '{}'),
                       "operationName" := "operationName",
                       extensions := extensions
               );
        $$;

        grant execute on function graphql.resolve to postgres, anon, authenticated, service_role;
    END IF;

END;
$func$;

CREATE OR REPLACE FUNCTION extensions.set_graphql_placeholder()
    RETURNS event_trigger
    LANGUAGE plpgsql
AS $func$
DECLARE
    graphql_is_dropped bool;
BEGIN
    graphql_is_dropped = (
        SELECT ev.schema_name = 'graphql_public'
        FROM pg_event_trigger_dropped_objects() AS ev
        WHERE ev.schema_name = 'graphql_public'
    );

    IF graphql_is_dropped
    THEN
        create or replace function graphql_public.graphql(
            "operationName" text default null,
            query text default null,
            variables jsonb default null,
            extensions jsonb default null
        )
            returns jsonb
            language plpgsql
        as $$
        DECLARE
            server_version float;
        BEGIN
            server_version = (SELECT (SPLIT_PART((select version()), ' ', 2))::float);

            IF server_version >= 14 THEN
                RETURN jsonb_build_object(
                        'errors', jsonb_build_array(
                                jsonb_build_object(
                                        'message', 'pg_graphql extension is not enabled.'
                                )
                                  )
                       );
            ELSE
                RETURN jsonb_build_object(
                        'errors', jsonb_build_array(
                                jsonb_build_object(
                                        'message', 'pg_graphql is only available on projects running Postgres 14 onwards.'
                                )
                                  )
                       );
            END IF;
        END;
        $$;
    END IF;

END;
$func$;

-- GraphQL Placeholder Entrypoint
create or replace function graphql_public.graphql(
    "operationName" text default null,
    query text default null,
    variables jsonb default null,
    extensions jsonb default null
)
    returns jsonb
    language plpgsql
as $$
DECLARE
    server_version float;
BEGIN
    server_version = (SELECT (SPLIT_PART((select version()), ' ', 2))::float);

    IF server_version >= 14 THEN
        RETURN jsonb_build_object(
                'errors', jsonb_build_array(
                        jsonb_build_object(
                                'message', 'pg_graphql extension is not enabled.'
                        )
                          )
               );
    ELSE
        RETURN jsonb_build_object(
                'errors', jsonb_build_array(
                        jsonb_build_object(
                                'message', 'pg_graphql is only available on projects running Postgres 14 onwards.'
                        )
                          )
               );
    END IF;
END;
$$;


drop extension if exists pg_graphql;
-- Avoids limitation of only being able to load the extension via dashboard
-- Only install as well if the extension is actually installed
DO $$
    DECLARE
        graphql_exists boolean;
    BEGIN
        graphql_exists = (
            select count(*) = 1
            from pg_available_extensions
            where name = 'pg_graphql'
        );

        IF graphql_exists
        THEN
            create extension if not exists pg_graphql;
        END IF;
    END $$;

-- migrate:down





------------------------------------------------------
-- 20220609081115_grant-supabase-auth-admin-and-supabase-storage-admin-to-postgres.sql
-- ----------------------------------------------------
-- migrate:up

-- This is done so that the `postgres` role can manage auth tables triggers,
-- storage tables policies, etc. which unblocks the revocation of superuser
-- access.
--
-- More context: https://www.notion.so/supabase/RFC-Postgres-Permissions-I-40cb4f61bd4145fd9e75ce657c0e31dd#bf5d853436384e6e8e339d0a2e684cbb
grant supabase_auth_admin, supabase_storage_admin to postgres;

-- migrate:down






----------------------------------------------------
-- 20220613123923_pg_graphql-pg-dump-perms.sql
----------------------------------------------------
-- migrate:up

create or replace function extensions.grant_pg_graphql_access()
    returns event_trigger
    language plpgsql
AS $func$
DECLARE
    func_is_graphql_resolve bool;
BEGIN
    func_is_graphql_resolve = (
        SELECT n.proname = 'resolve'
        FROM pg_event_trigger_ddl_commands() AS ev
                 LEFT JOIN pg_catalog.pg_proc AS n
                           ON ev.objid = n.oid
    );

    IF func_is_graphql_resolve
    THEN
        -- Update public wrapper to pass all arguments through to the pg_graphql resolve func
        DROP FUNCTION IF EXISTS graphql_public.graphql;
        create or replace function graphql_public.graphql(
            "operationName" text default null,
            query text default null,
            variables jsonb default null,
            extensions jsonb default null
        )
            returns jsonb
            language sql
        as $$
        select graphql.resolve(
                       query := query,
                       variables := coalesce(variables, '{}'),
                       "operationName" := "operationName",
                       extensions := extensions
               );
        $$;

        -- This hook executes when `graphql.resolve` is created. That is not necessarily the last
        -- function in the extension so we need to grant permissions on existing entities AND
        -- update default permissions to any others that are created after `graphql.resolve`
        grant usage on schema graphql to postgres, anon, authenticated, service_role;
        grant select on all tables in schema graphql to postgres, anon, authenticated, service_role;
        grant execute on all functions in schema graphql to postgres, anon, authenticated, service_role;
        grant all on all sequences in schema graphql to postgres, anon, authenticated, service_role;
        alter default privileges in schema graphql grant all on tables to postgres, anon, authenticated, service_role;
        alter default privileges in schema graphql grant all on functions to postgres, anon, authenticated, service_role;
        alter default privileges in schema graphql grant all on sequences to postgres, anon, authenticated, service_role;
    END IF;

END;
$func$;

-- Cycle the extension off and back on to apply the permissions update.

drop extension if exists pg_graphql;
-- Avoids limitation of only being able to load the extension via dashboard
-- Only install as well if the extension is actually installed
DO $$
    DECLARE
        graphql_exists boolean;
    BEGIN
        graphql_exists = (
            select count(*) = 1
            from pg_available_extensions
            where name = 'pg_graphql'
        );

        IF graphql_exists
        THEN
            create extension if not exists pg_graphql;
        END IF;
    END $$;

-- migrate:down





----------------------------------------------------
-- 20220713082019_pg_cron-pg_net-temp-perms-fix.sql
----------------------------------------------------
-- migrate:up
DO $$
    DECLARE
        pg_cron_installed boolean;
    BEGIN
        -- checks if pg_cron is enabled
        pg_cron_installed = (
            select count(*) = 1
            from pg_available_extensions
            where name = 'pg_cron'
              and installed_version is not null
        );

        IF pg_cron_installed
        THEN
            grant usage on schema cron to postgres with grant option;
            grant all on all functions in schema cron to postgres with grant option;

            alter default privileges in schema cron grant all on tables to postgres with grant option;
            alter default privileges in schema cron grant all on functions to postgres with grant option;
            alter default privileges in schema cron grant all on sequences to postgres with grant option;

            alter default privileges for user supabase_admin in schema cron grant all
                on sequences to postgres with grant option;
            alter default privileges for user supabase_admin in schema cron grant all
                on tables to postgres with grant option;
            alter default privileges for user supabase_admin in schema cron grant all
                on functions to postgres with grant option;

            grant all privileges on all tables in schema cron to postgres with grant option;
        END IF;
    END $$;

DO $$
    DECLARE
        pg_net_installed boolean;
    BEGIN
        -- checks if pg_net is enabled
        pg_net_installed = (
            select count(*) = 1
            from pg_available_extensions
            where name = 'pg_net'
              and installed_version is not null

        );

        IF pg_net_installed
        THEN
            IF NOT EXISTS (
                SELECT 1
                FROM pg_roles
                WHERE rolname = 'supabase_functions_admin'
            )
            THEN
                CREATE USER supabase_functions_admin NOINHERIT CREATEROLE LOGIN NOREPLICATION;
            END IF;

            GRANT USAGE ON SCHEMA net TO supabase_functions_admin, postgres, anon, authenticated, service_role;

            ALTER function net.http_get(url text, params jsonb, headers jsonb, timeout_milliseconds integer) SECURITY DEFINER;
            ALTER function net.http_post(url text, body jsonb, params jsonb, headers jsonb, timeout_milliseconds integer) SECURITY DEFINER;

            ALTER function net.http_get(url text, params jsonb, headers jsonb, timeout_milliseconds integer) SET search_path = net;
            ALTER function net.http_post(url text, body jsonb, params jsonb, headers jsonb, timeout_milliseconds integer) SET search_path = net;

            REVOKE ALL ON FUNCTION net.http_get(url text, params jsonb, headers jsonb, timeout_milliseconds integer) FROM PUBLIC;
            REVOKE ALL ON FUNCTION net.http_post(url text, body jsonb, params jsonb, headers jsonb, timeout_milliseconds integer) FROM PUBLIC;

            GRANT EXECUTE ON FUNCTION net.http_get(url text, params jsonb, headers jsonb, timeout_milliseconds integer) TO supabase_functions_admin, postgres, anon, authenticated, service_role;
            GRANT EXECUTE ON FUNCTION net.http_post(url text, body jsonb, params jsonb, headers jsonb, timeout_milliseconds integer) TO supabase_functions_admin, postgres, anon, authenticated, service_role;
        END IF;
    END $$;

-- migrate:down





----------------------------------------------------
-- 20221028101028_set_authenticator_timeout.sql
----------------------------------------------------
-- migrate:up
alter role authenticator set statement_timeout = '8s';

-- migrate:down






----------------------------------------------------
-- 20221103090837_revoke_admin.sql
----------------------------------------------------
-- migrate:up
revoke supabase_admin from authenticator;

-- migrate:down






----------------------------------------------------
-- 20221207154255_create_pgsodium_and_vault.sql
----------------------------------------------------
-- migrate:up

DO $$
    DECLARE
        pgsodium_exists boolean;
        vault_exists boolean;
    BEGIN
        pgsodium_exists = (
            select count(*) = 1
            from pg_available_extensions
            where name = 'pgsodium'
        );

        vault_exists = (
            select count(*) = 1
            from pg_available_extensions
            where name = 'supabase_vault'
        );

        IF pgsodium_exists
        THEN
            create extension if not exists pgsodium;

            grant pgsodium_keyiduser to postgres with admin option;
            grant pgsodium_keyholder to postgres with admin option;
            grant pgsodium_keymaker  to postgres with admin option;

            grant execute on function pgsodium.crypto_aead_det_decrypt(bytea, bytea, uuid, bytea) to service_role;
            grant execute on function pgsodium.crypto_aead_det_encrypt(bytea, bytea, uuid, bytea) to service_role;
            grant execute on function pgsodium.crypto_aead_det_keygen to service_role;

            IF vault_exists
            THEN
                create extension if not exists supabase_vault;
            END IF;
        END IF;
    END $$;

-- migrate:down





----------------------------------------------------
-- 20230201083204_grant_auth_roles_to_postgres.sql
----------------------------------------------------
-- migrate:up
grant anon, authenticated, service_role to postgres;

-- migrate:down






-------------------------------------------------------
-- 20230224042246_grant_extensions_perms_for_postgres.sql
------------------------------------------------------
-- migrate:up
grant all privileges on all tables in schema extensions to postgres with grant option;
grant all privileges on all routines in schema extensions to postgres with grant option;
grant all privileges on all sequences in schema extensions to postgres with grant option;
alter default privileges in schema extensions grant all on tables to postgres with grant option;
alter default privileges in schema extensions grant all on routines to postgres with grant option;
alter default privileges in schema extensions grant all on sequences to postgres with grant option;

-- migrate:down






----------------------------------------------------
-- 20230306081037_grant_pg_monitor_to_postgres.sql
----------------------------------------------------
-- migrate:up
grant pg_monitor to postgres;

-- migrate:down






------------------------------------------------------
-- 20230327032006_grant_auth_roles_to_supabase_storage_admin.sql
------------------------------------------------------
-- migrate:up
grant anon, authenticated, service_role to supabase_storage_admin;

-- migrate:down




----------------------------------------------------
-- 20230529180330_alter_api_roles_for_inherit.sql
----------------------------------------------------
-- migrate:up

ALTER ROLE authenticated inherit;
ALTER ROLE anon inherit;
ALTER ROLE service_role inherit;

GRANT pgsodium_keyholder to service_role;

-- migrate:down



----------------------------------------------------
-- 20231013070755_grant_authenticator_to_supabase_storage_admin.sql
----------------------------------------------------
-- migrate:up
grant authenticator to supabase_storage_admin;
revoke anon, authenticated, service_role from supabase_storage_admin;

-- migrate:down



----------------------------------------------------
-- 20231017062225_grant_pg_graphql_permissions_for_custom_roles.sql
----------------------------------------------------
-- migrate:up

create or replace function extensions.grant_pg_graphql_access()
    returns event_trigger
    language plpgsql
AS $func$
DECLARE
    func_is_graphql_resolve bool;
BEGIN
    func_is_graphql_resolve = (
        SELECT n.proname = 'resolve'
        FROM pg_event_trigger_ddl_commands() AS ev
                 LEFT JOIN pg_catalog.pg_proc AS n
                           ON ev.objid = n.oid
    );

    IF func_is_graphql_resolve
    THEN
        -- Update public wrapper to pass all arguments through to the pg_graphql resolve func
        DROP FUNCTION IF EXISTS graphql_public.graphql;
        create or replace function graphql_public.graphql(
            "operationName" text default null,
            query text default null,
            variables jsonb default null,
            extensions jsonb default null
        )
            returns jsonb
            language sql
        as $$
        select graphql.resolve(
                       query := query,
                       variables := coalesce(variables, '{}'),
                       "operationName" := "operationName",
                       extensions := extensions
               );
        $$;

        -- This hook executes when `graphql.resolve` is created. That is not necessarily the last
        -- function in the extension so we need to grant permissions on existing entities AND
        -- update default permissions to any others that are created after `graphql.resolve`
        grant usage on schema graphql to postgres, anon, authenticated, service_role;
        grant select on all tables in schema graphql to postgres, anon, authenticated, service_role;
        grant execute on all functions in schema graphql to postgres, anon, authenticated, service_role;
        grant all on all sequences in schema graphql to postgres, anon, authenticated, service_role;
        alter default privileges in schema graphql grant all on tables to postgres, anon, authenticated, service_role;
        alter default privileges in schema graphql grant all on functions to postgres, anon, authenticated, service_role;
        alter default privileges in schema graphql grant all on sequences to postgres, anon, authenticated, service_role;

        -- Allow postgres role to allow granting usage on graphql and graphql_public schemas to custom roles
        grant usage on schema graphql_public to postgres with grant option;
        grant usage on schema graphql to postgres with grant option;
    END IF;

END;
$func$;

-- Cycle the extension off and back on to apply the permissions update.

drop extension if exists pg_graphql;
-- Avoids limitation of only being able to load the extension via dashboard
-- Only install as well if the extension is actually installed
DO $$
    DECLARE
        graphql_exists boolean;
    BEGIN
        graphql_exists = (
            select count(*) = 1
            from pg_available_extensions
            where name = 'pg_graphql'
        );

        IF graphql_exists
        THEN
            create extension if not exists pg_graphql;
        END IF;
    END $$;

-- migrate:down


----------------------------------------------------
-- 20231020085357_revoke_writes_on_cron_job_from_postgres.sql
----------------------------------------------------
-- migrate:up
do $$
    begin
        if exists (select from pg_extension where extname = 'pg_cron') then
            revoke all on table cron.job from postgres;
            grant select on table cron.job to postgres with grant option;
        end if;
    end $$;

CREATE OR REPLACE FUNCTION extensions.grant_pg_cron_access() RETURNS event_trigger
    LANGUAGE plpgsql
AS $$
BEGIN
    IF EXISTS (
        SELECT
        FROM pg_event_trigger_ddl_commands() AS ev
                 JOIN pg_extension AS ext
                      ON ev.objid = ext.oid
        WHERE ext.extname = 'pg_cron'
    )
    THEN
        grant usage on schema cron to postgres with grant option;

        alter default privileges in schema cron grant all on tables to postgres with grant option;
        alter default privileges in schema cron grant all on functions to postgres with grant option;
        alter default privileges in schema cron grant all on sequences to postgres with grant option;

        alter default privileges for user supabase_admin in schema cron grant all
            on sequences to postgres with grant option;
        alter default privileges for user supabase_admin in schema cron grant all
            on tables to postgres with grant option;
        alter default privileges for user supabase_admin in schema cron grant all
            on functions to postgres with grant option;

        grant all privileges on all tables in schema cron to postgres with grant option;
        revoke all on table cron.job from postgres;
        grant select on table cron.job to postgres with grant option;
    END IF;
END;
$$;

drop event trigger if exists issue_pg_cron_access;
CREATE EVENT TRIGGER issue_pg_cron_access ON ddl_command_end
    WHEN TAG IN ('CREATE EXTENSION')
EXECUTE FUNCTION extensions.grant_pg_cron_access();

-- migrate:down

----------------------------------------------------
-- 20231130133139_set_lock_timeout_to_authenticator_role.sql
----------------------------------------------------
-- migrate:up
ALTER ROLE authenticator set lock_timeout to '8s';

-- migrate:down


----------------------------------------------------
-- 20240124080435_alter_lo_export_lo_import_owner.sql
----------------------------------------------------
-- migrate:up
alter function pg_catalog.lo_export owner to supabase_admin;
alter function pg_catalog.lo_import(text) owner to supabase_admin;
alter function pg_catalog.lo_import(text, oid) owner to supabase_admin;

-- migrate:down


----------------------------------------------------
-- 20240606060239_grant_predefined_roles_to_postgres.sql
----------------------------------------------------
-- migrate:up
-- grant pg_read_all_data, pg_signal_backend to postgres;

-- migrate:down


----------------------------------------------------
-- 20241031003909_create_orioledb.sql
----------------------------------------------------
-- migrate:up
do $$
begin
    if exists (select 1 from pg_available_extensions where name = 'orioledb') then
        if not exists (select 1 from pg_extension where extname = 'orioledb') then
            create extension if not exists orioledb;
        end if;
    end if;
end $$;
-- migrate:down


----------------------------------------------------
-- 20241215003910_backfill_pgmq_metadata.sql
----------------------------------------------------
-- migrate:up
do $$
    begin
        -- Check if the pgmq.meta table exists
        if exists (
            select
                1
            from
                pg_catalog.pg_class c
                    join pg_catalog.pg_namespace n
                         on c.relnamespace = n.oid
            where
                n.nspname = 'pgmq'
              and c.relname = 'meta'
              and c.relkind = 'r' -- regular table
              -- Make sure only expected columns exist and are correctly named
              and (
                      select array_agg(attname::text order by attname)
                      from pg_catalog.pg_attribute a
                      where
                          a.attnum > 0
                        and a.attrelid = c.oid
                  ) = array['created_at', 'is_partitioned', 'is_unlogged', 'queue_name']::text[]
        ) then
            -- Insert data into pgmq.meta for all tables matching the naming pattern 'pgmq.q_<queue_name>'
            insert into pgmq.meta (queue_name, is_partitioned, is_unlogged, created_at)
            select
                substring(c.relname from 3) as queue_name,
                false as is_partitioned,
                case when c.relpersistence = 'u' then true else false end as is_unlogged,
                now() as created_at
            from
                pg_catalog.pg_class c
                    join pg_catalog.pg_namespace n
                         on c.relnamespace = n.oid
            where
                n.nspname = 'pgmq'
              and c.relname like 'q_%'
              and c.relkind in ('r', 'p', 'u')
            on conflict (queue_name) do nothing;
        end if;
    end $$;

-- For logical backups we detach the queue and archive tables from the pgmq extension
-- prior to pausing. Once detached, pgmq.drop_queue breaks. This re-attaches them
-- when a project is unpaused and allows pgmq.drop_queue to work normally.
do $$
    declare
        ext_exists boolean;
        tbl record;
    begin
        -- check if pgmq extension is installed
        select exists(select 1 from pg_extension where extname = 'pgmq') into ext_exists;

        if ext_exists then
            for tbl in
                select c.relname as table_name
                from pg_class c
                         join pg_namespace n on c.relnamespace = n.oid
                where n.nspname = 'pgmq'
                  and c.relkind in ('r', 'u')  -- include ordinary and unlogged tables
                  and (c.relname like 'q\_%' or c.relname like 'a\_%')
                  and c.oid not in (
                    select d.objid
                    from pg_depend d
                             join pg_extension e on d.refobjid = e.oid
                    where e.extname = 'pgmq'
                      and d.classid = 'pg_class'::regclass
                      and d.deptype = 'e'
                )
                loop
                    execute format('alter extension pgmq add table pgmq.%I', tbl.table_name);
                end loop;
        end if;
    end;
$$;


-- migrate:down


----------------------------------------------------
-- 20250205060043_disable_log_statement_on_internal_roles.sql
----------------------------------------------------
-- migrate:up
alter role supabase_admin set log_statement = none;
alter role supabase_auth_admin set log_statement = none;
alter role supabase_storage_admin set log_statement = none;

-- migrate:down


----------------------------------------------------
-- 20250218031949_pgsodium_mask_role.sql
----------------------------------------------------
-- migrate:up

DO $$
BEGIN
  IF EXISTS (SELECT FROM pg_extension WHERE extname = 'pgsodium') THEN
    CREATE OR REPLACE FUNCTION pgsodium.mask_role(masked_role regrole, source_name text, view_name text)
    RETURNS void
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path TO ''
    AS $function$
    BEGIN
      EXECUTE format(
        'GRANT SELECT ON pgsodium.key TO %s',
        masked_role);

      EXECUTE format(
        'GRANT pgsodium_keyiduser, pgsodium_keyholder TO %s',
        masked_role);

      EXECUTE format(
        'GRANT ALL ON %I TO %s',
        view_name,
        masked_role);
      RETURN;
    END
    $function$;
  END IF;
END $$;

-- migrate:down

----------------------------------------------------
-- 20250220051611_pg_net_perms_fix.sql
----------------------------------------------------
-- migrate:up
CREATE OR REPLACE FUNCTION extensions.grant_pg_net_access()
RETURNS event_trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_event_trigger_ddl_commands() AS ev
    JOIN pg_extension AS ext
    ON ev.objid = ext.oid
    WHERE ext.extname = 'pg_net'
  )
  THEN
    IF NOT EXISTS (
      SELECT 1
      FROM pg_roles
      WHERE rolname = 'supabase_functions_admin'
    )
    THEN
      CREATE USER supabase_functions_admin NOINHERIT CREATEROLE LOGIN NOREPLICATION;
    END IF;

    GRANT USAGE ON SCHEMA net TO supabase_functions_admin, postgres, anon, authenticated, service_role;

    IF EXISTS (
      SELECT FROM pg_extension
      WHERE extname = 'pg_net'
      -- all versions in use on existing projects as of 2025-02-20
      -- version 0.12.0 onwards don't need these applied
      AND extversion IN ('0.2', '0.6', '0.7', '0.7.1', '0.8', '0.10.0', '0.11.0')
    ) THEN
      ALTER function net.http_get(url text, params jsonb, headers jsonb, timeout_milliseconds integer) SECURITY DEFINER;
      ALTER function net.http_post(url text, body jsonb, params jsonb, headers jsonb, timeout_milliseconds integer) SECURITY DEFINER;

      ALTER function net.http_get(url text, params jsonb, headers jsonb, timeout_milliseconds integer) SET search_path = net;
      ALTER function net.http_post(url text, body jsonb, params jsonb, headers jsonb, timeout_milliseconds integer) SET search_path = net;

      REVOKE ALL ON FUNCTION net.http_get(url text, params jsonb, headers jsonb, timeout_milliseconds integer) FROM PUBLIC;
      REVOKE ALL ON FUNCTION net.http_post(url text, body jsonb, params jsonb, headers jsonb, timeout_milliseconds integer) FROM PUBLIC;

      GRANT EXECUTE ON FUNCTION net.http_get(url text, params jsonb, headers jsonb, timeout_milliseconds integer) TO supabase_functions_admin, postgres, anon, authenticated, service_role;
      GRANT EXECUTE ON FUNCTION net.http_post(url text, body jsonb, params jsonb, headers jsonb, timeout_milliseconds integer) TO supabase_functions_admin, postgres, anon, authenticated, service_role;
    END IF;
  END IF;
END;
$$;

DO $$
BEGIN
  IF EXISTS (SELECT FROM pg_extension WHERE extname = 'pg_net')
  THEN
    ALTER function net.http_get(url text, params jsonb, headers jsonb, timeout_milliseconds integer) SECURITY INVOKER;
    ALTER function net.http_post(url text, body jsonb, params jsonb, headers jsonb, timeout_milliseconds integer) SECURITY INVOKER;

    REVOKE EXECUTE ON FUNCTION net.http_get(url text, params jsonb, headers jsonb, timeout_milliseconds integer) FROM supabase_functions_admin, postgres, anon, authenticated, service_role;
    REVOKE EXECUTE ON FUNCTION net.http_post(url text, body jsonb, params jsonb, headers jsonb, timeout_milliseconds integer) FROM supabase_functions_admin, postgres, anon, authenticated, service_role;

    GRANT ALL ON FUNCTION net.http_get(url text, params jsonb, headers jsonb, timeout_milliseconds integer) TO PUBLIC;
    GRANT ALL ON FUNCTION net.http_post(url text, body jsonb, params jsonb, headers jsonb, timeout_milliseconds integer) TO PUBLIC;
  END IF;
END $$;

-- migrate:down

----------------------------------------------------
-- 20250312095419_pgbouncer_ownership.sql
----------------------------------------------------
-- migrate:up
-- alter function pgbouncer.get_auth owner to supabase_admin;
-- grant execute on function pgbouncer.get_auth(p_usename text) to postgres;
-- migrate:down


----------------------------------------------------
-- 20250402065937_alter_internal_event_triggers_owner_to_supabase_admin.sql
----------------------------------------------------
-- migrate:up
drop event trigger if exists issue_pg_net_access;

alter function extensions.grant_pg_net_access owner to supabase_admin;

CREATE EVENT TRIGGER issue_pg_net_access ON ddl_command_end
    WHEN TAG IN ('CREATE EXTENSION')
EXECUTE FUNCTION extensions.grant_pg_net_access();

-- migrate:down


----------------------------------------------------
-- 20250417190610_update_pgbouncer_get_auth.sql
----------------------------------------------------
-- migrate:up
-- skip since pigsty already have this function
-- create or replace function pgbouncer.get_auth(p_usename text) returns table (username text, password text)
--     language plpgsql security definer
-- as $$
-- begin
--     raise debug 'PgBouncer auth request: %', p_usename;
--
--     return query
--         select
--             rolname::text,
--             case when rolvaliduntil < now()
--                      then null
--                  else rolpassword::text
--                 end
--         from pg_authid
--         where rolname=$1 and rolcanlogin;
-- end;
-- $$;
--
-- -- from migrations/db/migrations/20250312095419_pgbouncer_ownership.sql
-- grant execute on function pgbouncer.get_auth(p_usename text) to postgres;

-- migrate:down


----------------------------------------------------
-- 20250421084701_revoke_admin_roles_from_postgres.sql
----------------------------------------------------
-- migrate:up

revoke supabase_storage_admin from postgres;
revoke create on schema storage from postgres;
revoke all on storage.migrations from anon, authenticated, service_role, postgres;

revoke supabase_auth_admin from postgres;
revoke create on schema auth from postgres;
revoke all on auth.schema_migrations from dashboard_user, postgres;

-- migrate:down


----------------------------------------------------
-- 20250605172253_grant_with_admin_to_postgres_16_and_above.sql
----------------------------------------------------
-- migrate:up
DO $$
    DECLARE
        major_version INT;
    BEGIN
        SELECT current_setting('server_version_num')::INT / 10000 INTO major_version;

        IF major_version >= 16 THEN
            GRANT anon, authenticated, service_role, authenticator, pg_monitor, pg_read_all_data, pg_signal_backend TO postgres WITH ADMIN OPTION;
        END IF;
    END $$;

-- migrate:down


----------------------------------------------------
-- 20250623125453_tmp_grant_storage_tables_to_postgres_with_grant_option.sql
----------------------------------------------------
-- migrate:up
-- TODO: remove this migration once STORAGE-211 is completed
-- DRI: bobbie
grant all on storage.buckets, storage.objects to postgres with grant option;

-- migrate:down


----------------------------------------------------
-- 20250709135250_grant_storage_schema_to_postgres_with_grant_option.sql
----------------------------------------------------
-- migrate:up
grant usage on schema storage to postgres with grant option;
-- migrate:down


----------------------------------------------------
-- 20250710151649_supabase_read_only_user_default_transaction_read_only.sql
----------------------------------------------------
-- migrate:up
alter role supabase_read_only_user set default_transaction_read_only = on;

-- migrate:down


----------------------------------------------------
-- 20251001204436_predefined_role_grants.sql
----------------------------------------------------
-- migrate:up
grant pg_monitor to supabase_etl_admin, supabase_read_only_user;

do $$
declare
    major_version int;
begin
    select current_setting('server_version_num')::int / 10000 into major_version;

    if major_version >= 16 then
        grant pg_create_subscription to postgres with admin option;
    end if;
end $$;

-- migrate:down


----------------------------------------------------
-- 20251105172723_grant_pg_reload_conf_to_postgres.sql
----------------------------------------------------
-- migrate:up
grant execute on function pg_catalog.pg_reload_conf() to postgres with grant option;

-- migrate:down


----------------------------------------------------
-- post migration: webhooks:
-- https://github.com/supabase/supabase/blob/master/docker/volumes/db/webhooks.sql
----------------------------------------------------
BEGIN;
-- Create pg_net extension
CREATE EXTENSION IF NOT EXISTS pg_net SCHEMA extensions;
-- Create supabase_functions schema
CREATE SCHEMA IF NOT EXISTS supabase_functions AUTHORIZATION supabase_admin;
GRANT USAGE ON SCHEMA supabase_functions TO postgres, anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA supabase_functions GRANT ALL ON TABLES TO postgres, anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA supabase_functions GRANT ALL ON FUNCTIONS TO postgres, anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA supabase_functions GRANT ALL ON SEQUENCES TO postgres, anon, authenticated, service_role;
-- supabase_functions.migrations definition
CREATE TABLE supabase_functions.migrations (
   version text PRIMARY KEY,
   inserted_at timestamptz NOT NULL DEFAULT NOW()
);
-- Initial supabase_functions migration
INSERT INTO supabase_functions.migrations (version) VALUES ('initial');
-- supabase_functions.hooks definition
CREATE TABLE supabase_functions.hooks (
  id bigserial PRIMARY KEY,
  hook_table_id integer NOT NULL,
  hook_name text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT NOW(),
  request_id bigint
);
CREATE INDEX supabase_functions_hooks_request_id_idx ON supabase_functions.hooks USING btree (request_id);
CREATE INDEX supabase_functions_hooks_h_table_id_h_name_idx ON supabase_functions.hooks USING btree (hook_table_id, hook_name);
COMMENT ON TABLE supabase_functions.hooks IS 'Supabase Functions Hooks: Audit trail for triggered hooks.';
CREATE FUNCTION supabase_functions.http_request()
    RETURNS trigger
    LANGUAGE plpgsql
AS $function$
DECLARE
    request_id bigint;
    payload jsonb;
    url text := TG_ARGV[0]::text;
    method text := TG_ARGV[1]::text;
    headers jsonb DEFAULT '{}'::jsonb;
    params jsonb DEFAULT '{}'::jsonb;
    timeout_ms integer DEFAULT 1000;
BEGIN
    IF url IS NULL OR url = 'null' THEN
        RAISE EXCEPTION 'url argument is missing';
    END IF;

    IF method IS NULL OR method = 'null' THEN
        RAISE EXCEPTION 'method argument is missing';
    END IF;

    IF TG_ARGV[2] IS NULL OR TG_ARGV[2] = 'null' THEN
        headers = '{"Content-Type": "application/json"}'::jsonb;
    ELSE
        headers = TG_ARGV[2]::jsonb;
    END IF;

    IF TG_ARGV[3] IS NULL OR TG_ARGV[3] = 'null' THEN
        params = '{}'::jsonb;
    ELSE
        params = TG_ARGV[3]::jsonb;
    END IF;

    IF TG_ARGV[4] IS NULL OR TG_ARGV[4] = 'null' THEN
        timeout_ms = 1000;
    ELSE
        timeout_ms = TG_ARGV[4]::integer;
    END IF;

    CASE
        WHEN method = 'GET' THEN
            SELECT http_get INTO request_id FROM net.http_get(
                    url,
                    params,
                    headers,
                    timeout_ms
                                                 );
        WHEN method = 'POST' THEN
            payload = jsonb_build_object(
                    'old_record', OLD,
                    'record', NEW,
                    'type', TG_OP,
                    'table', TG_TABLE_NAME,
                    'schema', TG_TABLE_SCHEMA
                      );

            SELECT http_post INTO request_id FROM net.http_post(
                    url,
                    payload,
                    params,
                    headers,
                    timeout_ms
                                                  );
        ELSE
            RAISE EXCEPTION 'method argument % is invalid', method;
        END CASE;

    INSERT INTO supabase_functions.hooks
    (hook_table_id, hook_name, request_id)
    VALUES
        (TG_RELID, TG_NAME, request_id);

    RETURN NEW;
END
$function$;
-- Supabase super admin
DO
$$
    BEGIN
        IF NOT EXISTS (
            SELECT 1
            FROM pg_roles
            WHERE rolname = 'supabase_functions_admin'
        )
        THEN
            CREATE USER supabase_functions_admin NOINHERIT CREATEROLE LOGIN NOREPLICATION;
        END IF;
    END
$$;
GRANT ALL PRIVILEGES ON SCHEMA supabase_functions TO supabase_functions_admin;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA supabase_functions TO supabase_functions_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA supabase_functions TO supabase_functions_admin;
ALTER USER supabase_functions_admin SET search_path = "supabase_functions";
ALTER table "supabase_functions".migrations OWNER TO supabase_functions_admin;
ALTER table "supabase_functions".hooks OWNER TO supabase_functions_admin;
ALTER function "supabase_functions".http_request() OWNER TO supabase_functions_admin;
GRANT supabase_functions_admin TO postgres;
-- Remove unused supabase_pg_net_admin role
DO
$$
    BEGIN
        IF EXISTS (
            SELECT 1
            FROM pg_roles
            WHERE rolname = 'supabase_pg_net_admin'
        )
        THEN
            REASSIGN OWNED BY supabase_pg_net_admin TO supabase_admin;
            DROP OWNED BY supabase_pg_net_admin;
            DROP ROLE supabase_pg_net_admin;
        END IF;
    END
$$;
-- pg_net grants when extension is already enabled
DO
$$
    BEGIN
        IF EXISTS (
            SELECT 1
            FROM pg_extension
            WHERE extname = 'pg_net'
        )
        THEN
            GRANT USAGE ON SCHEMA net TO supabase_functions_admin, postgres, anon, authenticated, service_role;
            ALTER function net.http_get(url text, params jsonb, headers jsonb, timeout_milliseconds integer) SECURITY DEFINER;
            ALTER function net.http_post(url text, body jsonb, params jsonb, headers jsonb, timeout_milliseconds integer) SECURITY DEFINER;
            ALTER function net.http_get(url text, params jsonb, headers jsonb, timeout_milliseconds integer) SET search_path = net;
            ALTER function net.http_post(url text, body jsonb, params jsonb, headers jsonb, timeout_milliseconds integer) SET search_path = net;
            REVOKE ALL ON FUNCTION net.http_get(url text, params jsonb, headers jsonb, timeout_milliseconds integer) FROM PUBLIC;
            REVOKE ALL ON FUNCTION net.http_post(url text, body jsonb, params jsonb, headers jsonb, timeout_milliseconds integer) FROM PUBLIC;
            GRANT EXECUTE ON FUNCTION net.http_get(url text, params jsonb, headers jsonb, timeout_milliseconds integer) TO supabase_functions_admin, postgres, anon, authenticated, service_role;
            GRANT EXECUTE ON FUNCTION net.http_post(url text, body jsonb, params jsonb, headers jsonb, timeout_milliseconds integer) TO supabase_functions_admin, postgres, anon, authenticated, service_role;
        END IF;
    END
$$;
-- Event trigger for pg_net
CREATE OR REPLACE FUNCTION extensions.grant_pg_net_access()
    RETURNS event_trigger
    LANGUAGE plpgsql
AS $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM pg_event_trigger_ddl_commands() AS ev
                 JOIN pg_extension AS ext
                      ON ev.objid = ext.oid
        WHERE ext.extname = 'pg_net'
    )
    THEN
        GRANT USAGE ON SCHEMA net TO supabase_functions_admin, postgres, anon, authenticated, service_role;
        ALTER function net.http_get(url text, params jsonb, headers jsonb, timeout_milliseconds integer) SECURITY DEFINER;
        ALTER function net.http_post(url text, body jsonb, params jsonb, headers jsonb, timeout_milliseconds integer) SECURITY DEFINER;
        ALTER function net.http_get(url text, params jsonb, headers jsonb, timeout_milliseconds integer) SET search_path = net;
        ALTER function net.http_post(url text, body jsonb, params jsonb, headers jsonb, timeout_milliseconds integer) SET search_path = net;
        REVOKE ALL ON FUNCTION net.http_get(url text, params jsonb, headers jsonb, timeout_milliseconds integer) FROM PUBLIC;
        REVOKE ALL ON FUNCTION net.http_post(url text, body jsonb, params jsonb, headers jsonb, timeout_milliseconds integer) FROM PUBLIC;
        GRANT EXECUTE ON FUNCTION net.http_get(url text, params jsonb, headers jsonb, timeout_milliseconds integer) TO supabase_functions_admin, postgres, anon, authenticated, service_role;
        GRANT EXECUTE ON FUNCTION net.http_post(url text, body jsonb, params jsonb, headers jsonb, timeout_milliseconds integer) TO supabase_functions_admin, postgres, anon, authenticated, service_role;
    END IF;
END;
$$;
COMMENT ON FUNCTION extensions.grant_pg_net_access IS 'Grants access to pg_net';
DO
$$
    BEGIN
        IF NOT EXISTS (
            SELECT 1
            FROM pg_event_trigger
            WHERE evtname = 'issue_pg_net_access'
        ) THEN
            CREATE EVENT TRIGGER issue_pg_net_access ON ddl_command_end WHEN TAG IN ('CREATE EXTENSION')
            EXECUTE PROCEDURE extensions.grant_pg_net_access();
        END IF;
    END
$$;
INSERT INTO supabase_functions.migrations (version) VALUES ('20210809183423_update_grants');
ALTER function supabase_functions.http_request() SECURITY DEFINER;
ALTER function supabase_functions.http_request() SET search_path = supabase_functions;
REVOKE ALL ON FUNCTION supabase_functions.http_request() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION supabase_functions.http_request() TO postgres, anon, authenticated, service_role;
COMMIT;