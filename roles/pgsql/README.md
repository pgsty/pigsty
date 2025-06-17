# PGSQL



## Tune

How does pigsty tune parameters?

max_connections:
- user specified value: (50 - 5000) : `pg_max_conn`
- tiny: 100
- olap: 200
- oltp: 200 (pgbouncer) / 1000 (postgres)
- crit: 200 (pgbouncer) / 1000 (postgres)
- pgbouncer or postgres is distinguished by the value of `pg_default_service_dest`

shared_buffers: 
- 25% of RAM
- user specified ratio (0.10 - 0.40) : `pg_shared_buffer_ratio`
- round to 1MB

work_mem: (in ratio 0~1)
- tiny: shared_buffers / max_connections , min @ 16MB, max at 256MB (6G, 100G)
- olap: shared_buffers / max_connections , min @ 64MB, max at 8GiB  (25G, 500G)
- oltp: shared_buffers / max_connections , min @ 64MB, max at 1GiB  (50G/256G, 800G/4T)
- crit: shared_buffers / max_connections , min @ 64MB, max at 1GiB  (50G/256G, 800G/4T)

hash_mem_multiplier (available since PG 13)
- all: 8

max_prepared_transactions:
- = max_connections if citus enabled, else 0

max_locks_per_transaction:
- OLAP: 16 x max_connections if citus/timescaledb enabled, 2x in common cases
- OTHER: 2 x max_connections if citus/timescaledb enabled, 1x in common cases 
- This value must equal or higher on standby server

effective_cache_size:
- node_mem - shared_buffer 
- usually 75% mem

maintenance_work_mem:
- OLAP: shared buffer * 50% = 12.5%
- OTHER: shared buffer * 25% = 6.25%

max_worker_processes
- number of cpu, lower limit is 8

max_parallel_workers
- number of pg_max_worker_processes

max_parallel_workers_per_gather
- tiny, crit: 0
- oltp: 1/16 cpu and take floor
- olap: 1/2 pg_max_parallel_workers

max_parallel_maintenance_workers
- 1/8 pg_max_parallel_workers, and ceil to 2