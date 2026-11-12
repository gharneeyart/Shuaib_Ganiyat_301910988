\timing on

-- 1. What is running, and where?
SELECT version();
SELECT current_database() AS database, current_user AS db_user;
SHOW server_version;
SELECT inet_server_addr() AS server_address, inet_server_port() AS port;

-- 2. Is this connection encrypted?  (ssl should be true)
\conninfo
SELECT ssl, version AS tls_version, cipher FROM pg_stat_ssl WHERE pid = pg_backend_pid();

-- 3. Primary or replica?  false = this is the writable primary.
--    If you ever create a Neon read replica and connect to it, this returns true
--    and INSERT/UPDATE statements fail with "cannot execute ... in a read-only transaction".
SELECT pg_is_in_recovery() AS is_replica;

-- 4. How big is the data? (record it next to your plan limits)
SELECT pg_size_pretty(pg_database_size(current_database())) AS database_size;

-- 5. Cold-start experiment (availability / latency).
--    Neon suspends idle compute (about 5 minutes on the free plan; check your console).
--    a) Run this block, note the two values, then do nothing for 10 minutes.
--    b) Reconnect and run ONLY the next two lines again.
--    c) Compare: the first query's time (shown by \timing) and the start time.
--       A later start time and a slower first query show the compute was suspended and restarted.
SELECT pg_postmaster_start_time() AS compute_started_at;
SELECT now() - pg_postmaster_start_time() AS compute_uptime;
SELECT count(*) AS products FROM products;   -- a simple query to time
