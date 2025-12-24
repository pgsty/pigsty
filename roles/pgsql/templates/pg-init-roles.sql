----------------------------------------------------------------------
-- File      :   pg-init-roles.sql
-- Desc      :   create roles for postgres cluster {{ pg_cluster }}
-- Time      :   {{ '%Y-%m-%d %H:%M' | strftime }}
-- Host      :   {{ pg_instance }} @ {{ inventory_hostname }}:{{ pg_port }}
-- Path      :   /pg/tmp/pg-init-roles.sql
-- Note      :   ANSIBLE MANAGED, DO NOT CHANGE!
-- License   :   Apache-2.0 @ https://pigsty.io/docs/about/license/
-- Copyright :   2018-2026  Ruohang Feng / Vonng (rh@vonng.com)
----------------------------------------------------------------------

{% for user in pg_default_roles %}

--###################################################################--
--                         {{ user.name }}                           --
--###################################################################--
-- run as dbsu (postgres by default)
-- createuser -w -p {{ pg_port }} {% if 'login' in user and not user.login %}--no-login{% endif %}
{% if 'superuser' in user and user.superuser %} --superuser{% endif %}
{% if 'createdb' in user and user.createdb %} --createdb{% endif %}
{% if 'createrole' in user and user.createrole %} --createrole{% endif %}
{% if 'inherit' in user and not user.inherit %} --no-inherit{% endif %}
{% if 'replication' in user and user.replication %} --replication{% endif %}
'{{ user.name }}';
-- {{ pg_bin_dir}}/psql -p {{ pg_port }} -AXtwqf /pg/tmp/pg-user-{{ user.name }}.sql

--==================================================================--
--                           CREATE USER                            --
--==================================================================--
CREATE USER "{{ user.name }}" {% if 'login' in user and not user.login %} NOLOGIN{% endif %}
{% if 'superuser' in user and user.superuser %} SUPERUSER{% endif %}
{% if 'createdb' in user and user.createdb %} CREATEDB{% endif %}
{% if 'createrole' in user and user.createrole %} CREATEROLE{% endif %}
{% if 'inherit' in user and not user.inherit %} NOINHERIT{% endif %}
{% if 'replication' in user and user.replication %} REPLICATION{% endif %}
{% if 'bypassrls' in user and user.bypassrls %} BYPASSRLS{% endif %}
;

--==================================================================--
--                           ALTER USER                             --
--==================================================================--
-- options
ALTER USER "{{ user.name }}" {% if 'login' in user and not user.login %} NOLOGIN{% endif %}
{% if 'superuser' in user and user.superuser %} SUPERUSER{% endif %}
{% if 'createdb' in user and user.createdb %} CREATEDB{% endif %}
{% if 'createrole' in user and user.createrole %} CREATEROLE{% endif %}
{% if 'inherit' in user and not user.inherit %} NOINHERIT{% endif %}
{% if 'replication' in user and user.replication %} REPLICATION{% endif %}
{% if 'bypassrls' in user and user.bypassrls %} BYPASSRLS{% endif %}
;

-- password
{% if 'password' in user %}
SET log_statement TO 'none';
ALTER USER "{{ user.name }}" PASSWORD '{{ user.password }}';
SET log_statement TO DEFAULT;
{% endif %}

-- expire
{% if 'expire_in' in user %}
-- expire at {{ '%Y-%m-%d' | strftime(('%s' | strftime() | int  + user.expire_in * 86400)|int)  }} in {{ user.expire_in }} days since {{ '%Y-%m-%d' | strftime }}
ALTER USER "{{ user.name }}" VALID UNTIL '{{ '%Y-%m-%d' | strftime(('%s' | strftime() | int  + user.expire_in * 86400)|int)  }}';
{% elif 'expire_at' in user %}
-- expire at {{ user.expire_at }}
ALTER USER "{{ user.name }}" VALID UNTIL '{{ user.expire_at }}';
{% endif %}

-- conn limit
{% if 'connlimit' in user %}
{% if user.connlimit == -1 %} -- remove conn limit
-- {% endif %}
ALTER USER "{{ user.name }}" CONNECTION LIMIT {{ user.connlimit }};
{% endif %}

-- parameters
{% if 'parameters' in user %}
{% for key, value in user.parameters.items() %}
ALTER USER "{{ user.name }}" SET {{ key }} = {{ value }};
{% endfor %}{% endif %}

-- comment
{% if 'comment' in user %}
COMMENT ON ROLE "{{ user.name }}" IS '{{ user.comment }}';
{% else %}
COMMENT ON ROLE "{{ user.name }}" IS 'business user {{ user.name }}';
{% endif %}


--==================================================================--
--                           GRANT ROLE                             --
--==================================================================--
{% if 'roles' in user %}
{% for role in user.roles %}
GRANT "{{ role }}" TO "{{ user.name }}";
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

--==================================================================--



{% endfor %}



--==================================================================--
--                       PASSWORD OVERWRITE                         --
--==================================================================--
SET log_statement TO 'none';
ALTER ROLE "{{ pg_replication_username }}" PASSWORD '{{ pg_replication_password }}';
ALTER ROLE "{{ pg_monitor_username }}" PASSWORD '{{ pg_monitor_password }}';
ALTER ROLE "{{ pg_admin_username }}" PASSWORD '{{ pg_admin_password }}';
SET log_statement TO DEFAULT;
--==================================================================--

