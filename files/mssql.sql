-- License   :   AGPLv3 @ https://doc.pgsty.com/about/license
-- Copyright :   2018-2025  Ruohang Feng / Vonng (rh@vonng.com)

ALTER SYSTEM SET babelfishpg_tsql.database_name = 'mssql';

SELECT pg_reload_conf();

CALL sys.initialize_babelfish('dbuser_mssql');
