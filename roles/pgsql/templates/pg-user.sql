----------------------------------------------------------------------
-- File      :   pg-user-{{ user.name }}.sql
-- Desc      :   creation sql script for user {{ user.name }}
-- Time      :   {{ '%Y-%m-%d %H:%M' | strftime }}
-- Host      :   {{ pg_cluster }}-{{ pg_seq }} @ {{ inventory_hostname }}:{{ pg_port|default(5432) }}
-- Path      :   /pg/tmp/pg-user-{{ user.name }}.sql
-- Note      :   ANSIBLE MANAGED, DO NOT CHANGE!
-- License   :   Apache-2.0 @ https://pigsty.io/docs/about/license/
-- Copyright :   2018-2026  Ruohang Feng / Vonng (rh@vonng.com)
----------------------------------------------------------------------

--==================================================================--
--                       IDENTIFIER VALIDATION                      --
--==================================================================--
-- valid identifier: ^[a-z_][a-z0-9_]{0,62}$
{% if not user.name | regex_search('^[a-z_][a-z0-9_]{0,62}$') %}
{{ None['ERROR: Invalid username "' ~ user.name ~ '". Must match ^[a-z_][a-z0-9_]{0,62}$ (lowercase, digits, underscore, start with letter/underscore, max 63 chars)'] }}
{% endif %}

--==================================================================--
--                            EXECUTION                             --
--==================================================================--
-- run as dbsu (postgres by default)
-- createuser -w -p {{ pg_port|default(5432) }} {% if 'login' in user and not user.login %}--no-login{% endif %}
{% if 'superuser' in user and user.superuser %} --superuser{% endif %}
{% if 'createdb' in user and user.createdb %} --createdb{% endif %}
{% if 'createrole' in user and user.createrole %} --createrole{% endif %}
{% if 'inherit' in user and not user.inherit %} --no-inherit{% endif %}
{% if 'replication' in user and user.replication %} --replication{% endif %}
'{{ user.name }}';
-- /psql -p {{ pg_port|default(5432) }} -AXtwqf /pg/tmp/pg-user-{{ user.name }}.sql

--==================================================================--
--                           CREATE USER                            --
--==================================================================--
CREATE USER "{{ user.name }}"
{%- if 'login' in user and user.login is not none %}{% if user.login %} LOGIN{% else %} NOLOGIN{% endif %}{% endif %}
{%- if 'superuser' in user and user.superuser is not none %}{% if user.superuser %} SUPERUSER{% else %} NOSUPERUSER{% endif %}{% endif %}
{%- if 'createdb' in user and user.createdb is not none %}{% if user.createdb %} CREATEDB{% else %} NOCREATEDB{% endif %}{% endif %}
{%- if 'createrole' in user and user.createrole is not none %}{% if user.createrole %} CREATEROLE{% else %} NOCREATEROLE{% endif %}{% endif %}
{%- if 'inherit' in user and user.inherit is not none %}{% if user.inherit %} INHERIT{% else %} NOINHERIT{% endif %}{% endif %}
{%- if 'replication' in user and user.replication is not none %}{% if user.replication %} REPLICATION{% else %} NOREPLICATION{% endif %}{% endif %}
{%- if 'bypassrls' in user and user.bypassrls is not none %}{% if user.bypassrls %} BYPASSRLS{% else %} NOBYPASSRLS{% endif %}{% endif %}
;

--==================================================================--
--                           ALTER USER                             --
--==================================================================--
-- options
ALTER USER "{{ user.name }}"
{%- if 'login' in user and user.login is not none %}{% if user.login %} LOGIN{% else %} NOLOGIN{% endif %}{% endif %}
{%- if 'superuser' in user and user.superuser is not none %}{% if user.superuser %} SUPERUSER{% else %} NOSUPERUSER{% endif %}{% endif %}
{%- if 'createdb' in user and user.createdb is not none %}{% if user.createdb %} CREATEDB{% else %} NOCREATEDB{% endif %}{% endif %}
{%- if 'createrole' in user and user.createrole is not none %}{% if user.createrole %} CREATEROLE{% else %} NOCREATEROLE{% endif %}{% endif %}
{%- if 'inherit' in user and user.inherit is not none %}{% if user.inherit %} INHERIT{% else %} NOINHERIT{% endif %}{% endif %}
{%- if 'replication' in user and user.replication is not none %}{% if user.replication %} REPLICATION{% else %} NOREPLICATION{% endif %}{% endif %}
{%- if 'bypassrls' in user and user.bypassrls is not none %}{% if user.bypassrls %} BYPASSRLS{% else %} NOBYPASSRLS{% endif %}{% endif %}
;

-- password
{% if 'password' in user and user.password is not none %}
SET log_statement TO 'none';
ALTER USER "{{ user.name }}" PASSWORD '{{ user.password | replace("'", "''") }}';
SET log_statement TO DEFAULT;
{% endif %}

-- expire (expire_in: days from now, expire_at: 'YYYY-MM-DD' or 'infinity')
{% if 'expire_in' in user and user.expire_in is not none %}
-- expire at {{ '%Y-%m-%d' | strftime(('%s' | strftime() | int  + user.expire_in * 86400)|int)  }} in {{ user.expire_in }} days since {{ '%Y-%m-%d' | strftime }}
ALTER USER "{{ user.name }}" VALID UNTIL '{{ '%Y-%m-%d' | strftime(('%s' | strftime() | int  + user.expire_in * 86400)|int)  }}';
{% elif 'expire_at' in user and user.expire_at is not none %}
-- expire at {{ user.expire_at }} (format: YYYY-MM-DD or 'infinity')
ALTER USER "{{ user.name }}" VALID UNTIL '{{ user.expire_at | replace("'", "''") }}';
{% endif %}

-- conn limit
{% if 'connlimit' in user and user.connlimit is not none %}
ALTER USER "{{ user.name }}" CONNECTION LIMIT {{ user.connlimit | int }};
{% endif %}

-- parameters
{% if 'parameters' in user and user.parameters is not none and user.parameters|length > 0 %}
{% set list_params = ['search_path', 'temp_tablespaces', 'local_preload_libraries', 'session_preload_libraries'] %}
{% for key, value in user.parameters.items() %}
{% if value is not none %}
{% if value | string | upper == 'DEFAULT' %}
ALTER USER "{{ user.name }}" SET "{{ key }}" = DEFAULT;
{% elif key in list_params %}
ALTER USER "{{ user.name }}" SET "{{ key }}" = {{ value }};
{% else %}
ALTER USER "{{ user.name }}" SET "{{ key }}" = '{{ value | replace("'", "''") }}';
{% endif %}
{% endif %}
{% endfor %}{% endif %}

-- comment
{% if 'comment' in user and user.comment is not none %}
COMMENT ON ROLE "{{ user.name }}" IS '{{ user.comment | replace("'", "''") }}';
{% else %}
COMMENT ON ROLE "{{ user.name }}" IS 'business user {{ user.name | replace("'", "''") }}';
{% endif %}


--==================================================================--
--                           GRANT ROLE                             --
--==================================================================--
-- roles: "role_name" | {name, state?, admin?, set?, inherit?}
-- state: grant (default) | revoke/absent → controls membership
-- admin/set/inherit: true → WITH xxx TRUE | false → REVOKE xxx OPTION | null → no-op
-- set/inherit require PostgreSQL 16+, ignored on earlier versions with warning
{% if user.roles is defined and user.roles %}
{% set pg_ver = pg_version | default(18) | int %}
{% set member = user.name %}
{% for r in user.roles %}
{% set role = {'name': r} if r is string else r %}
{% set rname = role.name %}
{% if (role.state | default('grant')) in ['revoke', 'absent'] %}
REVOKE "{{ rname }}" FROM "{{ member }}";
{% else %}
GRANT "{{ rname }}" TO "{{ member }}";
{% if role.admin is defined and role.admin is not none %}
{% if role.admin %}
GRANT "{{ rname }}" TO "{{ member }}" WITH ADMIN {{ 'TRUE' if pg_ver >= 16 else 'OPTION' }};
{% else %}
REVOKE ADMIN OPTION FOR "{{ rname }}" FROM "{{ member }}";
{% endif %}
{% endif %}
{% if role.set is defined and role.set is not none %}
{% if pg_ver >= 16 %}
{% if role.set %}
GRANT "{{ rname }}" TO "{{ member }}" WITH SET TRUE;
{% else %}
REVOKE SET OPTION FOR "{{ rname }}" FROM "{{ member }}";
{% endif %}
{% else %}
-- WARNING: 'set' option requires PostgreSQL 16+, ignored on PG{{ pg_ver }}
{% endif %}
{% endif %}
{% if role.inherit is defined and role.inherit is not none %}
{% if pg_ver >= 16 %}
{% if role.inherit %}
GRANT "{{ rname }}" TO "{{ member }}" WITH INHERIT TRUE;
{% else %}
REVOKE INHERIT OPTION FOR "{{ rname }}" FROM "{{ member }}";
{% endif %}
{% else %}
-- WARNING: 'inherit' option requires PostgreSQL 16+, ignored on PG{{ pg_ver }}
{% endif %}
{% endif %}
{% endif %}
{% endfor %}
{% endif %}


--==================================================================--
--                          PGBOUNCER USER                          --
--==================================================================--
-- user will not be added to pgbouncer user list by default,
-- unless pgbouncer is explicitly set to 'true', which means production user

{% if 'pgbouncer' in user and user.pgbouncer|bool == true %}
-- User '{{ user.name }}' will be added to /etc/pgbouncer/userlist.txt via
-- /pg/bin/pgb-user '{{ user.name }}' 'AUTO'
{% else %}
-- User '{{ user.name }}' will NOT be added to /etc/pgbouncer/userlist.txt
{% endif %}

----------------------------------------------------------------------
