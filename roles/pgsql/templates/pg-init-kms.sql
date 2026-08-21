----------------------------------------------------------------------
-- File      :   pg-init-kms.sql
-- Desc      :   init kms for postgres cluster {{ pg_cluster }}
-- Time      :   {{ '%Y-%m-%d %H:%M' | strftime }}
-- Host      :   {{ pg_instance }} @ {{ inventory_hostname }}:{{ pg_port }}
-- Path      :   /pg/tmp/pg-init-kms.sql
-- Note      :   ANSIBLE MANAGED, DO NOT CHANGE!
-- License   :   Apache-2.0 @ https://pigsty.io/docs/about/license/
-- Copyright :   2018-2026  Ruohang Feng / Vonng (rh@vonng.com)
----------------------------------------------------------------------

--==================================================================--
--                           Executions                             --
--==================================================================--
-- {{ pg_bin_dir}}/psql template1 -AXtwqf /pg/tmp/pg-init-kms.sql
-- this sql scripts is responsible for kms init procedure
-- it will
--    * connect to your PostgreSQL database and add OpenBao as a global key provider
--    * create and set the default principal key using global key provider



--==================================================================--
--                            Logic                                 --
--==================================================================--
{% if groups['openbao'] is defined and groups['openbao'] | length > 0 %}
SELECT pg_tde_add_global_key_provider_vault_v2(
    '{{ openbao_cluster }}',
    'https://{{ openbao_domain }}:{{ openbao_api_port }}',
    'pg_tde',
    '/pg/tde-token',
    '/pg/cert/ca.crt'
);

SELECT pg_tde_create_key_using_global_key_provider(
    '{{ pg_cluster }}-principal-key',
    '{{ openbao_cluster }}'
);

SELECT pg_tde_set_default_key_using_global_key_provider(
    '{{ pg_cluster }}-principal-key',
    '{{ openbao_cluster }}'
);
{% endif %}
