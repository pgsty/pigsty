----------------------------------------------------------------------
-- File      :   pg-db-{{ database.name }}.sql
-- Desc      :   creation sql script for db {{ database.name }}
-- Time      :   {{ '%Y-%m-%d %H:%M' | strftime }}
-- Host      :   {{ pg_cluster }}-{{ pg_seq }} @ {{ inventory_hostname }}:{{ pg_port|default(5432) }}
-- Path      :   /pg/tmp/pg-db-{{ database.name }}.sql
-- Note      :   ANSIBLE MANAGED, DO NOT CHANGE!
-- License   :   Apache-2.0 @ https://pigsty.io/docs/about/license/
-- Copyright :   2018-2026  Ruohang Feng / Vonng (rh@vonng.com)
----------------------------------------------------------------------


--==================================================================--
--                            EXECUTION                             --
--==================================================================--
-- run as dbsu (postgres by default)
-- createdb -w -p {{ pg_port|default(5432) }} {% if 'owner' in database and database.owner != '' %}-O "{{ database.owner      }}" {% endif %}
{% if 'template'   in  database and database.template != ''   %}-T '{{ database.template   }}' {% endif %}
{% if 'encoding'   in  database and database.encoding != ''   %}-E '{{ database.encoding   }}' {% endif %}
{% if 'locale'     in  database and database.locale != ''     %}-l '{{ database.locale     }}' {% endif %}
{% if 'lc_collate' in  database and database.lc_collate != '' %}--lc-collate '{{ database.lc_collate }}' {% endif %}
{% if 'lc_ctype'   in  database and database.lc_ctype != ''   %}--lc-ctype '{{ database.lc_ctype   }}' {% endif %}
{% if 'tablespace' in  database and database.tablespace != '' %}-D '{{ database.tablespace }}' {% endif %}
'{{ database.name }}';
-- psql {{ database.name }} -p {{ pg_port|default(5432) }} -AXtwqf /pg/tmp/pg-db-{{ database.name }}.sql
{% if 'baseline' in database and database.baseline != '' %}
-- psql {{ database.name }} -p {{ pg_port|default(5432) }} -AXtwqf /pg/tmp/pg-db-{{ database.name }}-baseline.sql
{% endif %}

--==================================================================--
--                         CREATE DATABASE                          --
--==================================================================--
-- create database with following commands
-- CREATE DATABASE "{{ database.name }}" {% if 'owner' in  database and database.owner != '' %}OWNER "{{ database.owner }}" {% endif %}
{% if 'template'   in  database and database.template != ''   %}TEMPLATE "{{ database.template }}" {% endif %}
{% if 'encoding'   in  database and database.encoding != ''   %}ENCODING '{{ database.encoding }}' {% endif %}
{% if 'locale'     in  database and database.locale != ''     %}LOCALE "{{ database.locale }}" {% endif %}
{% if 'lc_collate' in  database and database.lc_collate != '' %}LC_COLLATE "{{ database.lc_collate }}" {% endif %}
{% if 'lc_ctype'   in  database and database.lc_ctype != ''   %}LC_CTYPE "{{ database.lc_ctype }}" {% endif %}
{% if 'tablespace' in  database and database.tablespace != '' %}TABLESPACE "{{ database.tablespace }}" {% endif %}
;
-- following commands are executed within database "{{ database.name }}"


--==================================================================--
--                         ALTER DATABASE                           --
--==================================================================--
-- owner
{% if 'owner' in database and database.owner is not none and database.owner != '' %}
ALTER DATABASE "{{ database.name }}" OWNER TO "{{ database.owner }}";
GRANT ALL PRIVILEGES ON DATABASE "{{ database.name }}" TO "{{ database.owner }}";
{% endif %}

-- tablespace
{% if 'tablespace' in database and database.tablespace != '' %}
ALTER DATABASE "{{ database.name }}" SET TABLESPACE "{{ database.tablespace }}";
{% endif %}

-- allow connection
{% if 'allowconn' in database and database.allowconn is not none %}
ALTER DATABASE "{{ database.name }}" ALLOW_CONNECTIONS {{ database.allowconn }};
{% endif %}

-- connection limit
{% if 'connlimit' in database and database.connlimit is not none %}
ALTER DATABASE "{{ database.name }}" CONNECTION LIMIT {{ database.connlimit }};
{% endif %}

-- parameters
{% if 'parameters' in database and database.parameters is not none %}
{% for key, value in database.parameters.items() %}
ALTER DATABASE "{{ database.name }}" SET {{ key }} = {{ value }};
{% endfor %}{% endif %}

-- comment
{% if 'comment' in database and database.comment is not none %}
COMMENT ON DATABASE "{{ database.name }}" IS '{{ database.comment }}';
{% else %}
COMMENT ON DATABASE "{{ database.name }}" IS 'business database {{ database.name }}';
{% endif %}


--==================================================================--
--                       REVOKE/GRANT CONNECT                       --
--==================================================================--
{% if 'revokeconn' in database and database.revokeconn == true %}
-- revoke public connect privilege
REVOKE CONNECT ON DATABASE "{{ database.name }}" FROM PUBLIC;

-- replicator, monitor have connect privilege
GRANT CONNECT ON DATABASE "{{ database.name }}" TO "{{ pg_replication_username|default('replicator') }}";
GRANT CONNECT ON DATABASE "{{ database.name }}" TO "{{ pg_monitor_username|default('dbuser_monitor') }}";

-- admin have connect privilege with grant option
GRANT CONNECT ON DATABASE "{{ database.name }}" TO "{{ pg_admin_username|default('dbuser_dba') }}" WITH GRANT OPTION;

-- owner have connect privilege with grant option if exists
{% if 'owner' in  database and database.owner is not none and database.owner != '' %}
GRANT CONNECT ON DATABASE "{{ database.name }}" TO "{{ database.owner }}" WITH GRANT OPTION;
{% endif %}

{% endif %}

--==================================================================--
--                       REVOKE/GRANT CREATE                        --
--==================================================================--
-- revoke create (schema) privilege from public
REVOKE CREATE ON DATABASE "{{ database.name }}" FROM PUBLIC;

-- only admin role have create privilege
GRANT CREATE ON DATABASE "{{ database.name }}" TO "dbrole_admin";

-- revoke public schema creation
REVOKE CREATE ON SCHEMA public FROM PUBLIC;

-- admin can create objects in public schema
GRANT CREATE ON SCHEMA public TO "dbrole_admin";


--==================================================================--
--                          Default Privileges                      --
--==================================================================--
{% if 'owner' in database and database.owner is not none and database.owner != '' %}
{% if pg_default_privileges is defined and pg_default_privileges is iterable and pg_default_privileges is not string and pg_default_privileges | length > 0 %}
-- setup default privileges for database owner from pg_default_privileges
{% for priv in pg_default_privileges %}
ALTER DEFAULT PRIVILEGES FOR ROLE "{{ database.owner }}" {{ priv }};
{% endfor %}
{% else %}
-- setup default privileges for database owner from default settings
ALTER DEFAULT PRIVILEGES FOR ROLE "{{ database.owner }}" GRANT USAGE      ON SCHEMAS   TO dbrole_readonly;
ALTER DEFAULT PRIVILEGES FOR ROLE "{{ database.owner }}" GRANT SELECT     ON TABLES    TO dbrole_readonly;
ALTER DEFAULT PRIVILEGES FOR ROLE "{{ database.owner }}" GRANT SELECT     ON SEQUENCES TO dbrole_readonly;
ALTER DEFAULT PRIVILEGES FOR ROLE "{{ database.owner }}" GRANT EXECUTE    ON FUNCTIONS TO dbrole_readonly;
ALTER DEFAULT PRIVILEGES FOR ROLE "{{ database.owner }}" GRANT USAGE      ON SCHEMAS   TO dbrole_offline;
ALTER DEFAULT PRIVILEGES FOR ROLE "{{ database.owner }}" GRANT SELECT     ON TABLES    TO dbrole_offline;
ALTER DEFAULT PRIVILEGES FOR ROLE "{{ database.owner }}" GRANT SELECT     ON SEQUENCES TO dbrole_offline;
ALTER DEFAULT PRIVILEGES FOR ROLE "{{ database.owner }}" GRANT EXECUTE    ON FUNCTIONS TO dbrole_offline;
ALTER DEFAULT PRIVILEGES FOR ROLE "{{ database.owner }}" GRANT INSERT     ON TABLES    TO dbrole_readwrite;
ALTER DEFAULT PRIVILEGES FOR ROLE "{{ database.owner }}" GRANT UPDATE     ON TABLES    TO dbrole_readwrite;
ALTER DEFAULT PRIVILEGES FOR ROLE "{{ database.owner }}" GRANT DELETE     ON TABLES    TO dbrole_readwrite;
ALTER DEFAULT PRIVILEGES FOR ROLE "{{ database.owner }}" GRANT USAGE      ON SEQUENCES TO dbrole_readwrite;
ALTER DEFAULT PRIVILEGES FOR ROLE "{{ database.owner }}" GRANT UPDATE     ON SEQUENCES TO dbrole_readwrite;
ALTER DEFAULT PRIVILEGES FOR ROLE "{{ database.owner }}" GRANT TRUNCATE   ON TABLES    TO dbrole_admin;
ALTER DEFAULT PRIVILEGES FOR ROLE "{{ database.owner }}" GRANT REFERENCES ON TABLES    TO dbrole_admin;
ALTER DEFAULT PRIVILEGES FOR ROLE "{{ database.owner }}" GRANT TRIGGER    ON TABLES    TO dbrole_admin;
ALTER DEFAULT PRIVILEGES FOR ROLE "{{ database.owner }}" GRANT CREATE     ON SCHEMAS   TO dbrole_admin;
{% endif %}
{% endif %}


--==================================================================--
--                          CREATE SCHEMAS                          --
--==================================================================--
-- create schemas
{% if 'schemas' in database and database.schemas is not none and database.schemas|length > 0 %}{% for schema_name in database.schemas %}
CREATE SCHEMA IF NOT EXISTS "{{ schema_name }}";
{% endfor %}{% endif %}


--==================================================================--
--                        CREATE EXTENSIONS                        --
--==================================================================--
-- create extensions
{% if 'extensions' in database and database.extensions is not none and database.extensions|length > 0 %}{% for extension in database.extensions %}
{% if extension is string %}
CREATE EXTENSION IF NOT EXISTS "{{ extension }}" CASCADE;
{% elif extension is mapping and 'name' in extension %}
CREATE EXTENSION IF NOT EXISTS "{{ extension.name }}"{% if 'schema' in extension %} WITH SCHEMA "{{ extension.schema }}"{% endif %}{% if 'version' in extension %} VERSION "{{ extension.version }}"{% endif %} CASCADE;
{% endif %}
{% endfor %}{% endif %}


--==================================================================--
--                        PGBOUNCER DATABASE                        --
--==================================================================--
-- database will be added to pgbouncer database list by default,
-- unless pgbouncer is explicitly set to 'false', means hidden database

{% if 'pgbouncer' not in database or database.pgbouncer|bool == true %}
-- Database '{{ database.name }}' will be added to /etc/pgbouncer/database.txt via

-- foreach database created on pgb, add the function to retrieve
-- user passwords from pg_authid when auth_query is set to 'true'
-- The user designated for this purpose is {{ pg_monitor_username|default('dbuser_monitor') }}
{% else %}
-- Database '{{ database.name }}' will NOT be added to /etc/pgbouncer/database.txt
{% endif %}
--==================================================================--