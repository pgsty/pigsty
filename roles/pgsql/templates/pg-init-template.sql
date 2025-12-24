----------------------------------------------------------------------
-- File      :   pg-init-template.sql
-- Desc      :   init templates for postgres cluster {{ pg_cluster }}
-- Time      :   {{ '%Y-%m-%d %H:%M' | strftime }}
-- Host      :   {{ pg_instance }} @ {{ inventory_hostname }}:{{ pg_port }}
-- Path      :   /pg/tmp/pg-init-template.sql
-- Note      :   ANSIBLE MANAGED, DO NOT CHANGE!
-- License   :   Apache-2.0 @ https://pigsty.io/docs/about/license/
-- Copyright :   2018-2026  Ruohang Feng / Vonng (rh@vonng.com)
----------------------------------------------------------------------

--==================================================================--
--                           Executions                             --
--==================================================================--
-- {{ pg_bin_dir}}/psql template1 -AXtwqf /pg/tmp/pg-init-template.sql
-- this sql scripts is responsible for post-init procedure
-- it will
--    * create system users such as replicator, monitor user, admin user
--    * create system default roles
--    * create schema, extensions in template1 & postgres
--    * create monitor views in template1 & postgres


--==================================================================--
--                          Default Privileges                      --
--==================================================================--
{% for priv in pg_default_privileges %}
ALTER DEFAULT PRIVILEGES FOR ROLE {{ pg_dbsu }} {{ priv }};
{% endfor %}

{% for priv in pg_default_privileges %}
ALTER DEFAULT PRIVILEGES FOR ROLE {{ pg_admin_username }} {{ priv }};
{% endfor %}

-- for additional business admin, they can SET ROLE to dbrole_admin
{% for priv in pg_default_privileges %}
ALTER DEFAULT PRIVILEGES FOR ROLE "dbrole_admin" {{ priv }};
{% endfor %}

--==================================================================--
--                              Schemas                             --
--==================================================================--
{% for schema_name in pg_default_schemas %}
CREATE SCHEMA IF NOT EXISTS "{{ schema_name }}";
{% endfor %}

-- revoke public creation
REVOKE CREATE ON SCHEMA public FROM PUBLIC;

--==================================================================--
--                             Extensions                           --
--==================================================================--
{% for extension in pg_default_extensions %}
{% if extension is string %}
CREATE EXTENSION IF NOT EXISTS "{{ extension }}" CASCADE;
{% elif extension is mapping and 'name' in extension %}
CREATE EXTENSION IF NOT EXISTS "{{ extension.name }}"{% if 'schema' in extension %} WITH SCHEMA "{{ extension.schema }}"{% endif %}{% if 'version' in extension %} VERSION "{{ extension.version }}"{% endif %} CASCADE;
{% endif %}
{% endfor %}

-- always enable file_fdw and default server fs
CREATE EXTENSION IF NOT EXISTS file_fdw;
CREATE SERVER IF NOT EXISTS fs FOREIGN DATA WRAPPER file_fdw;


--==================================================================--
--                          Backup Privileges                       --
--==================================================================--
-- grant backup privileges to replication user
GRANT USAGE ON SCHEMA pg_catalog TO "{{ pg_replication_username }}";
GRANT EXECUTE ON FUNCTION pg_catalog.current_setting(text) TO "{{ pg_replication_username }}";
GRANT EXECUTE ON FUNCTION pg_catalog.set_config(text, text, boolean) TO "{{ pg_replication_username }}";
GRANT EXECUTE ON FUNCTION pg_catalog.pg_is_in_recovery() TO "{{ pg_replication_username }}";
{% if pg_version|int < 15 %}
GRANT EXECUTE ON FUNCTION pg_catalog.pg_start_backup(text, boolean, boolean) TO "{{ pg_replication_username }}";
GRANT EXECUTE ON FUNCTION pg_catalog.pg_stop_backup(boolean, boolean) TO "{{ pg_replication_username }}";
{% endif %}
GRANT EXECUTE ON FUNCTION pg_catalog.pg_create_restore_point(text) TO "{{ pg_replication_username }}";
GRANT EXECUTE ON FUNCTION pg_catalog.pg_switch_wal() TO "{{ pg_replication_username }}";
GRANT EXECUTE ON FUNCTION pg_catalog.pg_last_wal_replay_lsn() TO "{{ pg_replication_username }}";
GRANT EXECUTE ON FUNCTION pg_catalog.txid_current() TO "{{ pg_replication_username }}";
GRANT EXECUTE ON FUNCTION pg_catalog.txid_current_snapshot() TO "{{ pg_replication_username }}";
GRANT EXECUTE ON FUNCTION pg_catalog.txid_snapshot_xmax(txid_snapshot) TO "{{ pg_replication_username }}";
GRANT EXECUTE ON FUNCTION pg_catalog.pg_control_checkpoint() TO "{{ pg_replication_username }}";



--==================================================================--
--                            Monitor Schema                        --
--==================================================================--

----------------------------------------------------------------------
-- cleanse & create monitor schema
----------------------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS monitor;
GRANT USAGE ON SCHEMA monitor TO "{{ pg_monitor_username }}";
GRANT USAGE ON SCHEMA monitor TO "{{ pg_admin_username }}";
GRANT USAGE ON SCHEMA monitor TO "{{ pg_replication_username }}";
ALTER USER "{{ pg_monitor_username }}" SET search_path TO monitor,public;


--==================================================================--
--                         Heartbeat Table                          --
--==================================================================--
-- table to hold heartbeat records
DROP TABLE IF EXISTS monitor.heartbeat CASCADE;
CREATE TABLE IF NOT EXISTS monitor.heartbeat
(
    id   VARCHAR(64) PRIMARY KEY,
    ts   TIMESTAMPTZ,
    lsn  BIGINT,
    txid BIGINT
);
COMMENT ON TABLE monitor.heartbeat IS 'heartbeat table, contains one row only';
REVOKE INSERT,UPDATE,DELETE ON TABLE monitor.heartbeat FROM dbrole_readwrite;
GRANT SELECT,INSERT,UPDATE,DELETE ON TABLE monitor.heartbeat TO pg_monitor;

-- function to generate & return generated heartbeat record
CREATE OR REPLACE FUNCTION monitor.upsert_heartbeat() RETURNS monitor.heartbeat SET search_path = '' AS
$$ INSERT INTO monitor.heartbeat(id, ts, lsn, txid) VALUES (coalesce(current_setting('cluster_name', true), 'unknown'), now(), pg_current_wal_lsn() - '0/0'::PG_LSN, pg_current_xact_id()::text::BIGINT)
   ON CONFLICT(id) DO UPDATE SET ts=EXCLUDED.ts, lsn=EXCLUDED.lsn, txid=EXCLUDED.txid RETURNING *;
$$ LANGUAGE SQL VOLATILE;
COMMENT ON FUNCTION monitor.upsert_heartbeat() IS 'upsert a heartbeat record';

REVOKE ALL ON FUNCTION monitor.upsert_heartbeat() FROM PUBLIC;
REVOKE ALL ON FUNCTION monitor.upsert_heartbeat() FROM dbrole_readonly;
REVOKE ALL ON FUNCTION monitor.upsert_heartbeat() FROM dbrole_offline;
GRANT EXECUTE ON FUNCTION monitor.upsert_heartbeat() TO pg_monitor;

-- function to be used by monitor tools
CREATE OR REPLACE FUNCTION monitor.beating() RETURNS
    TABLE (cls TEXT, ts TIMESTAMPTZ, lsn PG_LSN, lsn_int BIGINT, txid BIGINT, status TEXT)
    SET search_path = '' AS
$$ SELECT id AS cls, ts , '0/0'::PG_LSN + lsn AS lsn, lsn AS lsn_int, txid, CASE WHEN pg_is_in_recovery() THEN 'recovery' ELSE 'leading' END AS status FROM
    (SELECT (CASE WHEN pg_is_in_recovery() THEN (SELECT h FROM monitor.heartbeat h) ELSE monitor.upsert_heartbeat() END).*) d;
$$ LANGUAGE SQL VOLATILE;
COMMENT ON FUNCTION monitor.beating() IS 'refresh heartbeat on leader and return status';
REVOKE ALL ON FUNCTION monitor.beating() FROM PUBLIC;
REVOKE ALL ON FUNCTION monitor.beating() FROM dbrole_readonly;
REVOKE ALL ON FUNCTION monitor.beating() FROM dbrole_offline;
GRANT EXECUTE ON FUNCTION monitor.beating() TO pg_monitor;

-- function to return explain plan of given query
CREATE OR REPLACE FUNCTION monitor.explain(query TEXT) RETURNS JSON
SET search_path = '' AS $$
DECLARE result JSON;
BEGIN
    EXECUTE format('EXPLAIN (ANALYZE, COSTS, VERBOSE, BUFFERS, FORMAT JSON) %s', query) INTO result;
    RETURN result;
END; $$ LANGUAGE plpgsql;
COMMENT ON FUNCTION monitor.explain(TEXT) IS 'return verbose explain json plan for given query text';


--==================================================================--
--                          Monitor Views                           --
--==================================================================--

----------------------------------------------------------------------
-- Table bloat estimate : monitor.pg_table_bloat
----------------------------------------------------------------------
DROP FUNCTION IF EXISTS monitor.pg_table_bloat() CASCADE;
DROP FUNCTION IF EXISTS monitor.pg_index_bloat() CASCADE;
DROP VIEW IF EXISTS monitor.pg_table_bloat CASCADE;
DROP VIEW IF EXISTS monitor.pg_index_bloat CASCADE;

-- table bloat func
CREATE OR REPLACE FUNCTION monitor.pg_table_bloat()
    RETURNS TABLE(datname TEXT,nspname TEXT,relname TEXT,tblid OID,size BIGINT,ratio FLOAT)
    SET search_path = '' AS
$$SELECT CURRENT_CATALOG AS datname, nspname, relname , tblid , bs * tblpages AS size,
         CASE WHEN tblpages - est_tblpages_ff > 0 THEN (tblpages - est_tblpages_ff)/tblpages::FLOAT ELSE 0 END AS ratio
  FROM (
           SELECT ceil( reltuples / ( (bs-page_hdr)*fillfactor/(tpl_size*100) ) ) + ceil( toasttuples / 4 ) AS est_tblpages_ff,
                  tblpages, fillfactor, bs, tblid, nspname, relname, is_na
           FROM (
                    SELECT
                        ( 4 + tpl_hdr_size + tpl_data_size + (2 * ma)
                            - CASE WHEN tpl_hdr_size % ma = 0 THEN ma ELSE tpl_hdr_size % ma END
                            - CASE WHEN ceil(tpl_data_size)::INT % ma = 0 THEN ma ELSE ceil(tpl_data_size)::INT % ma END
                            ) AS tpl_size, (heappages + toastpages) AS tblpages, heappages,
                        toastpages, reltuples, toasttuples, bs, page_hdr, tblid, nspname, relname, fillfactor, is_na
                    FROM (
                             SELECT
                                 tbl.oid AS tblid, ns.nspname , tbl.relname, tbl.reltuples,
                                 tbl.relpages AS heappages, coalesce(toast.relpages, 0) AS toastpages,
                                 coalesce(toast.reltuples, 0) AS toasttuples,
                                 coalesce(substring(array_to_string(tbl.reloptions, ' ') FROM 'fillfactor=([0-9]+)')::smallint, 100) AS fillfactor,
                                 current_setting('block_size')::numeric AS bs,
                                 CASE WHEN version()~'mingw32' OR version()~'64-bit|x86_64|ppc64|ia64|amd64' THEN 8 ELSE 4 END AS ma,
                                 24 AS page_hdr,
                                 23 + CASE WHEN MAX(coalesce(s.null_frac,0)) > 0 THEN ( 7 + count(s.attname) ) / 8 ELSE 0::int END
                                     + CASE WHEN bool_or(att.attname = 'oid' and att.attnum < 0) THEN 4 ELSE 0 END AS tpl_hdr_size,
                                 sum( (1-coalesce(s.null_frac, 0)) * coalesce(s.avg_width, 0) ) AS tpl_data_size,
                                 bool_or(att.atttypid = 'pg_catalog.name'::regtype)
                                     OR sum(CASE WHEN att.attnum > 0 THEN 1 ELSE 0 END) <> count(s.attname) AS is_na
                             FROM pg_attribute AS att
                                      JOIN pg_class AS tbl ON att.attrelid = tbl.oid
                                      JOIN pg_namespace AS ns ON ns.oid = tbl.relnamespace
                                      LEFT JOIN pg_stats AS s ON s.schemaname=ns.nspname AND s.tablename = tbl.relname AND s.inherited=false AND s.attname=att.attname
                                      LEFT JOIN pg_class AS toast ON tbl.reltoastrelid = toast.oid
                             WHERE NOT att.attisdropped AND tbl.relkind = 'r' AND nspname NOT IN ('pg_catalog','information_schema')
                             GROUP BY tbl.oid, ns.nspname, tbl.relname, tbl.reltuples, tbl.relpages, toast.relpages, toast.reltuples, tbl.reloptions
                         ) AS s
                ) AS s2
       ) AS s3
  WHERE NOT is_na;
$$ LANGUAGE SQL SECURITY DEFINER;

-- index bloat func
CREATE OR REPLACE FUNCTION monitor.pg_index_bloat()
    RETURNS TABLE(datname TEXT,nspname TEXT,relname TEXT,tblid OID,idxid OID,size BIGINT,ratio FLOAT)
    SET search_path = '' AS
$$ SELECT CURRENT_CATALOG AS datname, nspname, idxname AS relname, tblid, idxid,
          relpages::BIGINT * bs AS size,
          COALESCE((relpages - ( reltuples * (6 + ma - (CASE WHEN index_tuple_hdr % ma = 0 THEN ma ELSE index_tuple_hdr % ma END)
                                                  + nulldatawidth + ma - (CASE WHEN nulldatawidth % ma = 0 THEN ma ELSE nulldatawidth % ma END))
                                     / (bs - pagehdr)::FLOAT  + 1 )), 0) / relpages::FLOAT AS ratio
   FROM (
            SELECT nspname, idxname, indrelid AS tblid, indexrelid AS idxid,
                   reltuples, relpages,
                   current_setting('block_size')::INTEGER AS bs,
                   (CASE WHEN version() ~ 'mingw32' OR version() ~ '64-bit|x86_64|ppc64|ia64|amd64' THEN 8 ELSE 4 END) AS ma,
                   24 AS pagehdr,
                   (CASE WHEN max(COALESCE(pg_stats.null_frac, 0)) = 0 THEN 2 ELSE 6 END) AS index_tuple_hdr,
                   sum((1.0 - COALESCE(pg_stats.null_frac, 0.0)) *
                       COALESCE(pg_stats.avg_width, 1024))::INTEGER AS nulldatawidth
            FROM pg_attribute
                     JOIN (
                SELECT pg_namespace.nspname, ic.relname AS idxname, ic.reltuples, ic.relpages, pg_index.indrelid,
                       pg_index.indexrelid, tc.relname AS tablename,
                       regexp_split_to_table(pg_index.indkey::TEXT, ' ')::INTEGER AS attnum,
                       pg_index.indexrelid AS index_oid
                FROM pg_index
                         JOIN pg_class ic ON pg_index.indexrelid = ic.oid
                         JOIN pg_class tc ON pg_index.indrelid = tc.oid
                         JOIN pg_namespace ON ic.relnamespace = pg_namespace.oid
                         JOIN pg_am ON ic.relam = pg_am.oid
                WHERE pg_am.amname = 'btree' AND ic.relpages > 0 AND pg_namespace.nspname NOT IN ('pg_catalog', 'information_schema')
            ) ind_atts ON pg_attribute.attrelid = ind_atts.indexrelid AND pg_attribute.attnum = ind_atts.attnum
                     JOIN pg_stats ON pg_stats.schemaname = ind_atts.nspname
                AND ((pg_stats.tablename = ind_atts.tablename AND pg_stats.attname = pg_get_indexdef(pg_attribute.attrelid, pg_attribute.attnum, TRUE))
                    OR (pg_stats.tablename = ind_atts.idxname AND pg_stats.attname = pg_attribute.attname))
            WHERE pg_attribute.attnum > 0
            GROUP BY nspname, idxname, indrelid, indexrelid, reltuples, relpages
        ) est
$$ LANGUAGE SQL SECURITY DEFINER;

CREATE OR REPLACE VIEW monitor.pg_table_bloat AS SELECT * FROM monitor.pg_table_bloat();
COMMENT ON VIEW monitor.pg_table_bloat IS 'postgres table bloat estimate';

CREATE OR REPLACE VIEW monitor.pg_index_bloat AS SELECT * FROM monitor.pg_index_bloat();
COMMENT ON VIEW monitor.pg_index_bloat IS 'postgres index bloat estimate (btree)';

GRANT EXECUTE ON FUNCTION monitor.pg_table_bloat() TO pg_monitor;
GRANT EXECUTE ON FUNCTION monitor.pg_index_bloat() TO pg_monitor;
GRANT SELECT ON monitor.pg_table_bloat TO pg_monitor;
GRANT SELECT ON monitor.pg_index_bloat TO pg_monitor;

----------------------------------------------------------------------
-- Relation Bloat : monitor.pg_bloat
----------------------------------------------------------------------
DROP VIEW IF EXISTS monitor.pg_bloat CASCADE;
CREATE OR REPLACE VIEW monitor.pg_bloat AS
SELECT coalesce(ib.datname, tb.datname)                                                   AS datname,
       coalesce(ib.nspname, tb.nspname)                                                   AS nspname,
       coalesce(ib.tblid, tb.tblid)                                                       AS tblid,
       coalesce(tb.nspname || '.' || tb.relname, ib.nspname || '.' || ib.tblid::RegClass) AS tblname,
       tb.size                                                                            AS tbl_size,
       CASE WHEN tb.ratio < 0 THEN 0 ELSE round(tb.ratio::NUMERIC, 6) END                 AS tbl_ratio,
       (tb.size * (CASE WHEN tb.ratio < 0 THEN 0 ELSE tb.ratio::NUMERIC END)) ::BIGINT    AS tbl_wasted,
       ib.idxid,
       ib.nspname || '.' || ib.relname                                                    AS idxname,
       ib.size                                                                            AS idx_size,
       CASE WHEN ib.ratio < 0 THEN 0 ELSE round(ib.ratio::NUMERIC, 5) END                 AS idx_ratio,
       (ib.size * (CASE WHEN ib.ratio < 0 THEN 0 ELSE ib.ratio::NUMERIC END)) ::BIGINT    AS idx_wasted
FROM monitor.pg_index_bloat ib
         FULL OUTER JOIN monitor.pg_table_bloat tb ON ib.tblid = tb.tblid;

COMMENT ON VIEW monitor.pg_bloat IS 'postgres relation bloat detail';
GRANT SELECT ON monitor.pg_bloat TO pg_monitor;

----------------------------------------------------------------------
-- monitor.pg_index_bloat_human
----------------------------------------------------------------------
DROP VIEW IF EXISTS monitor.pg_index_bloat_human CASCADE;
CREATE OR REPLACE VIEW monitor.pg_index_bloat_human AS
SELECT idxname                            AS name,
       tblname,
       idx_wasted                         AS wasted,
       pg_size_pretty(idx_size)           AS idx_size,
       round(100 * idx_ratio::NUMERIC, 2) AS idx_ratio,
       pg_size_pretty(idx_wasted)         AS idx_wasted,
       pg_size_pretty(tbl_size)           AS tbl_size,
       round(100 * tbl_ratio::NUMERIC, 2) AS tbl_ratio,
       pg_size_pretty(tbl_wasted)         AS tbl_wasted
FROM monitor.pg_bloat
WHERE idxname IS NOT NULL;
COMMENT ON VIEW monitor.pg_index_bloat_human IS 'postgres index bloat info in human-readable format';
GRANT SELECT ON monitor.pg_index_bloat_human TO pg_monitor;


----------------------------------------------------------------------
-- monitor.pg_table_bloat_human
----------------------------------------------------------------------
DROP VIEW IF EXISTS monitor.pg_table_bloat_human CASCADE;
CREATE OR REPLACE VIEW monitor.pg_table_bloat_human AS
SELECT tblname                                          AS name,
       idx_wasted + tbl_wasted                          AS wasted,
       pg_size_pretty(idx_wasted + tbl_wasted)          AS all_wasted,
       pg_size_pretty(tbl_wasted)                       AS tbl_wasted,
       pg_size_pretty(tbl_size)                         AS tbl_size,
       tbl_ratio,
       pg_size_pretty(idx_wasted)                       AS idx_wasted,
       pg_size_pretty(idx_size)                         AS idx_size,
       round(idx_wasted::NUMERIC * 100.0 / idx_size, 2) AS idx_ratio
FROM (SELECT datname,
             nspname,
             tblname,
             coalesce(max(tbl_wasted), 0)                         AS tbl_wasted,
             coalesce(max(tbl_size), 1)                           AS tbl_size,
             round(100 * coalesce(max(tbl_ratio), 0)::NUMERIC, 2) AS tbl_ratio,
             coalesce(sum(idx_wasted), 0)                         AS idx_wasted,
             coalesce(sum(idx_size), 1)                           AS idx_size
      FROM monitor.pg_bloat
      WHERE tblname IS NOT NULL
      GROUP BY datname,nspname,tblname
     ) d;
COMMENT ON VIEW monitor.pg_table_bloat_human IS 'postgres table bloat info in human-readable format';
GRANT SELECT ON monitor.pg_table_bloat_human TO pg_monitor;


----------------------------------------------------------------------
-- Activity Overview: monitor.pg_session
----------------------------------------------------------------------
DROP VIEW IF EXISTS monitor.pg_session CASCADE;
CREATE OR REPLACE VIEW monitor.pg_session AS
SELECT coalesce(datname, 'all') AS datname, numbackends, active, idle, ixact, max_duration, max_tx_duration, max_conn_duration
FROM (
         SELECT datname,
                count(*)                                         AS numbackends,
                count(*) FILTER ( WHERE state = 'active' )       AS active,
                count(*) FILTER ( WHERE state = 'idle' )         AS idle,
                count(*) FILTER ( WHERE state = 'idle in transaction'
                    OR state = 'idle in transaction (aborted)' ) AS ixact,
                max(extract(epoch from now() - state_change))
                FILTER ( WHERE state = 'active' )                AS max_duration,
                max(extract(epoch from now() - xact_start))      AS max_tx_duration,
                max(extract(epoch from now() - backend_start))   AS max_conn_duration
         FROM pg_stat_activity
         WHERE backend_type = 'client backend'
           AND pid <> pg_backend_pid()
         GROUP BY ROLLUP (datname)
         ORDER BY 1 NULLS FIRST
     ) t;
COMMENT ON VIEW monitor.pg_session IS 'postgres activity group by session';
GRANT SELECT ON monitor.pg_session TO pg_monitor;


----------------------------------------------------------------------
-- Sequential Scan: monitor.pg_seq_scan
----------------------------------------------------------------------
DROP VIEW IF EXISTS monitor.pg_seq_scan CASCADE;
CREATE OR REPLACE VIEW monitor.pg_seq_scan AS
    SELECT schemaname                                                        AS nspname,
           relname,
           seq_scan,
           seq_tup_read,
           seq_tup_read / seq_scan                                           AS seq_tup_avg,
           idx_scan,
           n_live_tup + n_dead_tup                                           AS tuples,
           round(n_live_tup * 100.0::NUMERIC / (n_live_tup + n_dead_tup), 2) AS live_ratio
    FROM pg_stat_user_tables
    WHERE seq_scan > 0
      and (n_live_tup + n_dead_tup) > 0
    ORDER BY seq_scan DESC;
COMMENT ON VIEW monitor.pg_seq_scan IS 'table that have seq scan';
GRANT SELECT ON monitor.pg_seq_scan TO pg_monitor;


----------------------------------------------------------------------
-- Lock Waiting: monitor.pg_lock_waiting
----------------------------------------------------------------------
DROP VIEW IF EXISTS monitor.pg_lock_waiting CASCADE;
CREATE VIEW monitor.pg_lock_waiting AS
  WITH RECURSIVE
    activity as (select pg_blocking_pids(pid) blocked_by, *,
                        extract(seconds FROM age(clock_timestamp(), xact_start)) as xact_wait,
                        extract(seconds FROM age(clock_timestamp(),
{% if pg_version|int >= 14 %}
                        (select max(l.waitstart) from pg_locks l where a.pid = l.pid)    -- PG 14 and newer
{% else %}
                        state_change       -- PG 13 and below
{% endif %}

                            )) as lock_wait
                 -- "pg_locks.waitstart" – PG14+ only; for older versions:  age(clock_timestamp(), state_change) as wait_age
                 from pg_stat_activity a
                 where state is distinct from 'idle'),
    blockers as (select array_agg(distinct c order by c) as pids
                 from (select unnest(blocked_by)
                       from activity) as dt(c)),
    tree as (select activity.*,
                    1                           as level,
                    activity.pid                as top_blocker_pid,
                    array [activity.pid]        as path,
                    array [activity.pid]::int[] as all_blockers_above
             from activity, blockers
             where array [pid] <@ blockers.pids and blocked_by = '{}'::int[]
             union all
             select activity.*,
                    tree.level + 1 as level,
                    tree.top_blocker_pid,
                    path || array [activity.pid] as path,
                    tree.all_blockers_above || array_agg(activity.pid) over () as all_blockers_above
             from activity,
                  tree
             where not array [activity.pid] <@ tree.all_blockers_above
               and activity.blocked_by <> '{}'::int[]
               and activity.blocked_by <@ tree.all_blockers_above)
  SELECT pid,
       blocked_by,
       case when wait_event_type = 'Lock' then 'waiting' else state end                                      as state,
       wait_event_type,
       wait_event,
       xact_wait,
       lock_wait,
       age(backend_xid) AS xid_age,
       -- 2147483647 - age(backend_xmin) as xmin_ttf,
       datname, usename, level - 1 AS level,
       (select count(distinct t1.pid) from tree t1 where array [tree.pid] <@ t1.path and t1.pid <> tree.pid) as blkd,
       format('%s %s%s', lpad('[' || pid::text || ']', 9, ' '), repeat('.', level - 1) || case when level > 1 then ' ' end, left(query, 1000) ) as query
FROM tree
WHERE datname = CURRENT_DATABASE()
ORDER BY top_blocker_pid, level, pid;

COMMENT ON VIEW monitor.pg_lock_waiting IS 'lock waiting tree';
GRANT SELECT ON monitor.pg_lock_waiting TO pg_monitor;



--==================================================================--
--                            Functions                             --
--==================================================================--

{% if pg_version|int >= 13 %}
----------------------------------------------------------------------
-- pg_shmem auxiliary function (PG13+ only)
----------------------------------------------------------------------
DROP FUNCTION IF EXISTS monitor.pg_shmem() CASCADE;
CREATE OR REPLACE FUNCTION monitor.pg_shmem() RETURNS SETOF
    pg_shmem_allocations
    SET search_path = '' AS
    $$SELECT * FROM pg_shmem_allocations;$$ LANGUAGE SQL SECURITY DEFINER;
COMMENT ON FUNCTION monitor.pg_shmem() IS 'security wrapper for system view pg_shmem';
REVOKE ALL ON FUNCTION monitor.pg_shmem() FROM PUBLIC;
REVOKE ALL ON FUNCTION monitor.pg_shmem() FROM dbrole_readonly;
REVOKE ALL ON FUNCTION monitor.pg_shmem() FROM dbrole_offline;
GRANT EXECUTE ON FUNCTION monitor.pg_shmem() TO pg_monitor;
{% endif %}


----------------------------------------------------------------------
-- monitor.pgbouncer_auth for pgbouncer_auth_query
----------------------------------------------------------------------
{% if pgbouncer_enabled|bool %}
CREATE OR REPLACE FUNCTION monitor.pgbouncer_auth(p_username TEXT) RETURNS TABLE(username TEXT, password TEXT)
    SET search_path = '' AS
$$
BEGIN
    RAISE WARNING 'PgBouncer auth request: %', p_username;
    RETURN QUERY SELECT rolname::TEXT, rolpassword::TEXT FROM pg_authid WHERE NOT rolsuper AND rolname = p_username;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
REVOKE ALL ON FUNCTION monitor.pgbouncer_auth(p_username TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION monitor.pgbouncer_auth(p_username TEXT) FROM dbrole_readonly;
REVOKE ALL ON FUNCTION monitor.pgbouncer_auth(p_username TEXT) FROM dbrole_offline;
{% endif %}


--==================================================================--
--                         Foreign Tables                           --
--==================================================================--

----------------------------------------------------------------------
-- current log
----------------------------------------------------------------------
CREATE TYPE monitor.log_level AS ENUM (
    'LOG','INFO','NOTICE','WARNING','ERROR','FATAL','PANIC','DEBUG'
);
COMMENT ON TYPE monitor.log_level IS 'PostgreSQL Log Level';

-- current log
DROP FOREIGN TABLE IF EXISTS monitor.pg_log;
CREATE FOREIGN TABLE monitor.pg_log
    (
        ts        TIMESTAMPTZ, -- ts
        username  TEXT,        -- user name
        datname   TEXT,        -- database name
        pid       INTEGER,     -- process_id
        conn      TEXT,        -- connect_from
        sid       TEXT,        -- session id
        sln       BIGINT,      -- session line number
        cmd_tag   TEXT,        -- command tag
        stime     TIMESTAMPTZ, -- session start time
        vxid      TEXT,        -- virtual transaction id
        txid      BIGINT,      -- transaction id
        level     monitor.log_level, -- log level
        code      VARCHAR(5),  -- sql state error code
        msg       TEXT,        -- message
        detail    TEXT,        -- detail
        hint      TEXT,        -- hint
        iq        TEXT,        -- internal query
        iqp       INTEGER,     -- internal query position
        context   TEXT,        -- context
        q         TEXT,        -- query
        qp        INTEGER,     -- query position
        location  TEXT,        -- location
        appname   TEXT         -- application name
{% if pg_version|int >= 13%}
        ,backend    TEXT      -- backend_type (PG13)
{% endif %}
{% if pg_version|int >= 14%}
        ,leader_pid INTEGER   -- parallel group leader pid, if this is worker
{% endif %}
{% if pg_version|int >= 14%}
        ,query_id   BIGINT    -- query id of the current query
{% endif %}

) SERVER fs OPTIONS (program $$cat $(cat /pg/data/current_logfiles | awk '{print $2}');$$, format 'csv');
COMMENT ON FOREIGN TABLE monitor.pg_log IS 'current log file foreign table';

REVOKE ALL ON monitor.pg_log FROM PUBLIC;
REVOKE ALL ON monitor.pg_log FROM dbrole_offline;
REVOKE ALL ON monitor.pg_log FROM dbrole_readonly;
REVOKE ALL ON monitor.pg_log FROM dbrole_readwrite;
REVOKE ALL ON monitor.pg_log FROM dbrole_admin;
GRANT SELECT ON monitor.pg_log TO pg_monitor;


----------------------------------------------------------------------
-- pgbackrest information
----------------------------------------------------------------------
DROP FOREIGN TABLE IF EXISTS monitor.pgbackrest_info CASCADE;
CREATE FOREIGN TABLE IF NOT EXISTS monitor.pgbackrest_info (data JSONB)
    SERVER fs OPTIONS (PROGRAM $$pgbackrest --stanza={{ pg_cluster }} --output=json info$$ , FORMAT 'text');

REVOKE ALL ON monitor.pgbackrest_info FROM PUBLIC;
REVOKE ALL ON monitor.pgbackrest_info FROM dbrole_offline;
REVOKE ALL ON monitor.pgbackrest_info FROM dbrole_readonly;
REVOKE ALL ON monitor.pgbackrest_info FROM dbrole_readwrite;
GRANT SELECT ON monitor.pgbackrest_info TO pg_monitor;

DROP VIEW IF EXISTS monitor.pgbackrest;
CREATE OR REPLACE VIEW monitor.pgbackrest AS
SELECT name,
       value ->> 'type'                                          AS bk_type,
       (value ->> 'error')::BOOLEAN                              AS bk_error,
       current_archive ->> 'min'                                 as wal_min,
       current_archive ->> 'max'                                 as wal_max,
       value ->> 'label'                                         AS bk_label,
       value ->> 'prior'                                         AS bk_prior,
       (value -> 'timestamp' ->> 'start')::NUMERIC               AS bk_start_ts,
       (value -> 'timestamp' ->> 'stop')::NUMERIC                AS bk_stop_ts,
       to_timestamp((value -> 'timestamp' ->> 'start')::NUMERIC) AS bk_start_at,
       to_timestamp((value -> 'timestamp' ->> 'stop')::NUMERIC)  AS bk_stop_at,
       value -> 'lsn' ->> 'start'                                AS bk_start_lsn,
       value -> 'lsn' ->> 'stop'                                 AS bk_stop_lsn,
       (value -> 'info' ->> 'size')::BIGINT                      AS bk_size,
       (value -> 'info' ->> 'delta')::BIGINT                     AS bk_delta,
       (value -> 'info' -> 'repo' ->> 'size')::BIGINT            AS bk_repo_size,
       (value -> 'info' -> 'repo' ->> 'delta')::BIGINT           AS bk_repo_delta,
       value -> 'reference'                                      AS bk_reference,
       value -> 'annotation'                                     AS bk_annotation
FROM (SELECT value ->> 'name'   AS name,
             value -> 'backup'  AS backups,
             value -> 'archive' -> (jsonb_array_length(value -> 'archive') - 1) AS current_archive
      FROM monitor.pgbackrest_info i, jsonb_array_elements(i.data)) z, jsonb_array_elements(z.backups);

REVOKE ALL ON monitor.pgbackrest FROM PUBLIC;
REVOKE ALL ON monitor.pgbackrest FROM dbrole_offline;
REVOKE ALL ON monitor.pgbackrest FROM dbrole_readonly;
REVOKE ALL ON monitor.pgbackrest FROM dbrole_readwrite;
REVOKE ALL ON monitor.pgbackrest FROM dbrole_admin;
GRANT SELECT ON monitor.pgbackrest TO pg_monitor;


----------------------------------------------------------------------
-- patroni information
----------------------------------------------------------------------
DROP FOREIGN TABLE IF EXISTS monitor.patroni_info CASCADE;
CREATE FOREIGN TABLE IF NOT EXISTS monitor.patroni_info (data JSONB)
    SERVER fs OPTIONS (PROGRAM $$curl http{% if patroni_ssl_enabled|bool %}s{% endif %}://127.0.0.1:{{ patroni_port }}/cluster$$ , FORMAT 'text');

REVOKE ALL ON monitor.patroni_info FROM PUBLIC;
REVOKE ALL ON monitor.patroni_info FROM dbrole_offline;
REVOKE ALL ON monitor.patroni_info FROM dbrole_readonly;
REVOKE ALL ON monitor.patroni_info FROM dbrole_readwrite;
GRANT SELECT ON monitor.patroni_info TO pg_monitor;

DROP FOREIGN TABLE IF EXISTS monitor.patroni_conf CASCADE;
CREATE FOREIGN TABLE IF NOT EXISTS monitor.patroni_conf (data JSONB)
    SERVER fs OPTIONS (PROGRAM $$cat patroni.dynamic.json$$ , FORMAT 'text');

REVOKE ALL ON monitor.patroni_conf FROM PUBLIC;
REVOKE ALL ON monitor.patroni_conf FROM dbrole_offline;
REVOKE ALL ON monitor.patroni_conf FROM dbrole_readonly;
REVOKE ALL ON monitor.patroni_conf FROM dbrole_readwrite;
GRANT SELECT ON monitor.patroni_conf TO pg_monitor;

DROP VIEW IF EXISTS monitor.patroni;
CREATE OR REPLACE VIEW monitor.patroni AS
SELECT value ->> 'name'                                                             AS name,
       CASE value ->> 'role' WHEN 'leader' THEN 'primary' ELSE value ->> 'role' END AS role,
       value ->> 'host'                                                             AS host,
       value ->> 'port'                                                             AS port,
       value ->> 'state'                                                            AS state,
       (value ->> 'timeline')::INTEGER                                              AS timeline,
       (value ->> 'lag')::BIGINT                                                    AS lag,
       value ->> 'api_url'                                                          AS url,
       value -> 'tags' ->> 'replicatefrom'                                          AS replicatefrom,
       coalesce((value -> 'tags' -> 'nofailover') ::BOOLEAN, false)::BOOLEAN        AS nofailover,
       coalesce((value -> 'tags' -> 'clonefrom') ::BOOLEAN, false)::BOOLEAN         AS clonefrom,
       coalesce((value -> 'tags' -> 'noloadbalance') ::BOOLEAN, false)::BOOLEAN     AS noloadbalance,
       coalesce((value -> 'tags' -> 'nosync') ::BOOLEAN, false)::BOOLEAN            AS nosync,
       value -> 'tags'                                                              AS tags
FROM monitor.patroni_info i, jsonb_array_elements(data -> 'members');

REVOKE ALL ON monitor.patroni FROM PUBLIC;
REVOKE ALL ON monitor.patroni FROM dbrole_offline;
REVOKE ALL ON monitor.patroni FROM dbrole_readonly;
REVOKE ALL ON monitor.patroni FROM dbrole_readwrite;
GRANT SELECT ON monitor.patroni TO pg_monitor;

-- get process status
DROP FOREIGN TABLE IF EXISTS monitor.process_status CASCADE;
CREATE FOREIGN TABLE monitor.process_status (
  username TEXT,
  pid      INTEGER,
  cpu      NUMERIC,
  mem      NUMERIC,
  vsz      BIGINT,
  rss      BIGINT,
  tty      TEXT,
  stat     TEXT,
  start    TEXT,
  uptime   TEXT,
  command  TEXT
) SERVER fs OPTIONS (PROGRAM $$
ps aux | awk '{print $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,substr($0,index($0,$11))}' OFS='\037'
$$ , FORMAT 'csv', DELIMITER E'\037', HEADER 'TRUE');

REVOKE ALL ON monitor.process_status FROM PUBLIC;
REVOKE ALL ON monitor.process_status FROM dbrole_offline;
REVOKE ALL ON monitor.process_status FROM dbrole_readonly;
REVOKE ALL ON monitor.process_status FROM dbrole_readwrite;
GRANT SELECT ON monitor.process_status TO pg_monitor;


-- get disk usage
DROP FOREIGN TABLE IF EXISTS monitor.disk_free CASCADE;
CREATE FOREIGN TABLE monitor.disk_free (
  fsname      TEXT,
  fstype      TEXT,
  total_1m    BIGINT,
  used_1m     BIGINT,
  avail_1m    BIGINT,
  percent     TEXT,
  itotal      BIGINT,
  iused       BIGINT,
  ifree       BIGINT,
  ipercent    TEXT,
  mountpoint  TEXT
) SERVER fs OPTIONS (PROGRAM $$
df -ml --output=source,fstype,size,used,avail,pcent,itotal,iused,iavail,ipcent,target | tail -n +2 | awk '{print $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11}' OFS='\037'
$$,
FORMAT 'csv', DELIMITER E'\037'
);

REVOKE ALL ON monitor.disk_free FROM PUBLIC;
REVOKE ALL ON monitor.disk_free FROM dbrole_offline;
REVOKE ALL ON monitor.disk_free FROM dbrole_readonly;
REVOKE ALL ON monitor.disk_free FROM dbrole_readwrite;
GRANT SELECT ON monitor.disk_free TO pg_monitor;

--==================================================================--
--                          Customize Logic                         --
--==================================================================--
-- This script will be executed on primary instance among a newly created
-- postgres cluster. it will be executed as dbsu on template1 database
-- put your own customize logic here, and make sure they are idempotent
