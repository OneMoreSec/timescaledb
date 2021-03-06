-- This file and its contents are licensed under the Apache License 2.0.
-- Please see the included NOTICE for copyright information and
-- LICENSE-APACHE for a copy of the license.

-- print chunks ordered by time to ensure ordering we want
SELECT
  ht.table_name AS hypertable,
  c.table_name AS chunk,
  ds.range_start
FROM
  _timescaledb_catalog.chunk c
  INNER JOIN LATERAL(SELECT * FROM _timescaledb_catalog.chunk_constraint cc WHERE c.id = cc.chunk_id ORDER BY cc.dimension_slice_id LIMIT 1) cc ON true
  INNER JOIN _timescaledb_catalog.dimension_slice ds ON ds.id=cc.dimension_slice_id
  INNER JOIN _timescaledb_catalog.dimension d ON ds.dimension_id = d.id
  INNER JOIN _timescaledb_catalog.hypertable ht ON d.hypertable_id = ht.id
ORDER BY ht.table_name, range_start, chunk;

-- test ASC for ordered chunks
:PREFIX SELECT
  time, device_id, value
FROM ordered_append
ORDER BY time ASC LIMIT 1;

-- test DESC for ordered chunks
:PREFIX SELECT
  time, device_id, value
FROM ordered_append
ORDER BY time DESC LIMIT 1;

-- test ASC for reverse ordered chunks
:PREFIX SELECT
  time, device_id, value
FROM ordered_append_reverse
ORDER BY time ASC LIMIT 1;

-- test DESC for reverse ordered chunks
:PREFIX SELECT
  time, device_id, value
FROM ordered_append_reverse
ORDER BY time DESC LIMIT 1;

-- test query with ORDER BY column not in targetlist
:PREFIX SELECT
  device_id, value
FROM ordered_append
ORDER BY time ASC LIMIT 1;

-- ORDER BY may include other columns after time column
:PREFIX SELECT
  time, device_id, value
FROM ordered_append
ORDER BY time DESC, device_id LIMIT 1;

-- test RECORD in targetlist
:PREFIX SELECT
  (time, device_id, value)
FROM ordered_append
ORDER BY time DESC, device_id LIMIT 1;

-- queries with ORDER BY non-time column shouldn't use ordered append
:PREFIX SELECT
  time, device_id, value
FROM ordered_append
ORDER BY device_id LIMIT 1;

-- time column must be primary sort order
:PREFIX SELECT
  time, device_id, value
FROM ordered_append
ORDER BY device_id, time LIMIT 1;

-- queries without LIMIT shouldnt use ordered append
:PREFIX SELECT
  time, device_id, value
FROM ordered_append
ORDER BY time ASC;

-- queries without ORDER BY shouldnt use ordered append (still uses append though)
:PREFIX SELECT
  time, device_id, value
FROM ordered_append
LIMIT 1;

-- test interaction with constraint exclusion
:PREFIX SELECT
  time, device_id, value
FROM ordered_append
WHERE time > '2000-01-07'
ORDER BY time ASC LIMIT 1;

:PREFIX SELECT
  time, device_id, value
FROM ordered_append
WHERE time > '2000-01-07'
ORDER BY time DESC LIMIT 1;

-- test interaction with constraint aware append
:PREFIX SELECT
  time, device_id, value
FROM ordered_append
WHERE time > now_s()
ORDER BY time ASC LIMIT 1;

:PREFIX SELECT
  time, device_id, value
FROM ordered_append
WHERE time < now_s()
ORDER BY time ASC LIMIT 1;

-- test constraint exclusion
:PREFIX SELECT
  time, device_id, value
FROM ordered_append
WHERE time > now_s() AND time < '2000-01-10'
ORDER BY time ASC LIMIT 1;

:PREFIX SELECT
  time, device_id, value
FROM ordered_append
WHERE time < now_s() AND time > '2000-01-07'
ORDER BY time ASC LIMIT 1;

-- min/max queries
:PREFIX SELECT max(time) FROM ordered_append;

:PREFIX SELECT min(time) FROM ordered_append;

-- test first/last (doesn't use ordered append yet)
:PREFIX SELECT first(time, time) FROM ordered_append;

:PREFIX SELECT last(time, time) FROM ordered_append;

-- test query with time_bucket
:PREFIX SELECT
  time_bucket('1d',time), device_id, value
FROM ordered_append
ORDER BY time ASC LIMIT 1;

-- test query with order by time_bucket (should not use ordered append)
:PREFIX SELECT
  time_bucket('1d',time), device_id, value
FROM ordered_append
ORDER BY 1 LIMIT 1;

-- test query with order by time_bucket (should not use ordered append)
:PREFIX SELECT
  time_bucket('1d',time), device_id, value
FROM ordered_append
ORDER BY time_bucket('1d',time) LIMIT 1;

-- test query with now() should result in ordered append with constraint aware append
:PREFIX SELECT * FROM ordered_append WHERE time < now() + '1 month'
ORDER BY time DESC limit 1;

-- test CTE
:PREFIX WITH i AS (SELECT * FROM ordered_append WHERE time < now() ORDER BY time DESC limit 100)
SELECT * FROM i;

-- test LATERAL with ordered append in the outer query
:PREFIX SELECT * FROM ordered_append, LATERAL(SELECT * FROM (VALUES (1),(2)) v) l ORDER BY time DESC limit 2;

-- test LATERAL with ordered append in the lateral query
:PREFIX SELECT * FROM (VALUES (1),(2)) v, LATERAL(SELECT * FROM ordered_append ORDER BY time DESC limit 2) l;

-- test plan with best index is chosen
-- this should use device_id, time index
:PREFIX SELECT * FROM ordered_append WHERE device_id = 1 ORDER BY time DESC LIMIT 1;

-- test plan with best index is chosen
-- this should use time index
:PREFIX SELECT * FROM ordered_append ORDER BY time DESC LIMIT 1;

-- test with table with only dimension column
:PREFIX SELECT * FROM dimension_only ORDER BY time DESC LIMIT 1;

-- test LEFT JOIN against hypertable
:PREFIX_NO_ANALYZE SELECT *
FROM dimension_last
LEFT JOIN dimension_only USING (time)
ORDER BY dimension_last.time DESC
LIMIT 2;

-- test INNER JOIN against non-hypertable
:PREFIX_NO_ANALYZE SELECT *
FROM dimension_last
INNER JOIN dimension_only USING (time)
ORDER BY dimension_last.time DESC
LIMIT 2;

-- test join against non-hypertable
:PREFIX SELECT *
FROM dimension_last
INNER JOIN devices USING(device_id)
ORDER BY dimension_last.time DESC
LIMIT 2;

-- test hypertable with index missing on one chunk
:PREFIX SELECT
  time, device_id, value
FROM ht_missing_indexes
ORDER BY time ASC LIMIT 1;

-- test hypertable with index missing on one chunk
-- and no data
:PREFIX SELECT
  time, device_id, value
FROM ht_missing_indexes
WHERE device_id = 2
ORDER BY time DESC LIMIT 1;

-- test hypertable with index missing on one chunk
-- and no data
:PREFIX SELECT
  time, device_id, value
FROM ht_missing_indexes
WHERE time > '2000-01-07'
ORDER BY time LIMIT 10;

-- test hypertable with dropped columns
:PREFIX SELECT
  time, device_id, value
FROM ht_dropped_columns
ORDER BY time ASC LIMIT 1;

-- test hypertable with dropped columns
:PREFIX SELECT
  time, device_id, value
FROM ht_dropped_columns
WHERE device_id = 1
ORDER BY time DESC;

-- test hypertable with space partitioning
:PREFIX SELECT
  time, device_id, value
FROM space
ORDER BY time;

-- test hypertable with space partitioning and reverse order
:PREFIX SELECT
  time, device_id, value
FROM space
ORDER BY time DESC;

-- test hypertable with space partitioning ORDER BY multiple columns
-- does not use ordered append
:PREFIX SELECT
  time, device_id, value
FROM space
ORDER BY time, device_id LIMIT 1;

-- test hypertable with space partitioning ORDER BY non-time column
-- does not use ordered append
:PREFIX SELECT
  time, device_id, value
FROM space
ORDER BY device_id, time LIMIT 1;

-- test hypertable with 2 space dimensions
-- does not use ordered append
:PREFIX SELECT
  time, device_id, value
FROM space2
ORDER BY time DESC;

-- test LATERAL with correlated query
-- only last chunk should be executed
:PREFIX SELECT *
FROM generate_series('2000-01-01'::timestamptz,'2000-01-03','1d') AS g(time)
LEFT OUTER JOIN LATERAL(
  SELECT * FROM ordered_append o
    WHERE o.time >= g.time AND o.time < g.time + '1d'::interval ORDER BY time DESC LIMIT 1
) l ON true;

-- test LATERAL with correlated query
-- only 2nd chunk should be executed
:PREFIX SELECT *
FROM generate_series('2000-01-10'::timestamptz,'2000-01-11','1d') AS g(time)
LEFT OUTER JOIN LATERAL(
  SELECT * FROM ordered_append o
    WHERE o.time >= g.time AND o.time < g.time + '1d'::interval ORDER BY time LIMIT 1
) l ON true;

-- test startup and runtime exclusion together
:PREFIX SELECT *
FROM generate_series('2000-01-01'::timestamptz,'2000-01-03','1d') AS g(time)
LEFT OUTER JOIN LATERAL(
  SELECT * FROM ordered_append o
    WHERE o.time >= g.time AND o.time < g.time + '1d'::interval AND o.time < now() ORDER BY time DESC LIMIT 1
) l ON true;

-- test startup and runtime exclusion together
-- all chunks should be filtered
:PREFIX SELECT *
FROM generate_series('2000-01-01'::timestamptz,'2000-01-03','1d') AS g(time)
LEFT OUTER JOIN LATERAL(
  SELECT * FROM ordered_append o
    WHERE o.time >= g.time AND o.time < g.time + '1d'::interval AND o.time > now() ORDER BY time DESC LIMIT 1
) l ON true;

-- test CTE
-- no chunk exclusion for CTE because cte query is not pulled up
:PREFIX WITH cte AS (SELECT * FROM ordered_append ORDER BY time)
SELECT * FROM cte WHERE time < '2000-02-01'::timestamptz;

-- test JOIN
-- no exclusion on joined table because its not ChunkAppend node
:PREFIX SELECT *
FROM ordered_append o1
INNER JOIN ordered_append o2 ON o1.time = o2.time
WHERE o1.time < '2000-02-01'
ORDER BY o1.time;

-- test JOIN
-- last chunk of o2 should not be executed
:PREFIX SELECT *
FROM ordered_append o1
INNER JOIN (SELECT * FROM ordered_append o2 ORDER BY time) o2 ON o1.time = o2.time
WHERE o1.time < '2000-01-08'
ORDER BY o1.time;

-- test subquery
-- not ChunkAppend so no chunk exclusion
:PREFIX SELECT *
FROM ordered_append WHERE time = (SELECT max(time) FROM ordered_append) ORDER BY time;

-- test join against max query
-- not ChunkAppend so no chunk exclusion
:PREFIX SELECT *
FROM ordered_append o1 INNER JOIN (SELECT max(time) AS max_time FROM ordered_append) o2 ON o1.time = o2.max_time ORDER BY time;

-- test ordered append with limit expression
:PREFIX SELECT *
FROM ordered_append ORDER BY time LIMIT (SELECT length('four'));

-- test with ordered guc disabled
SET timescaledb.enable_ordered_append TO off;
:PREFIX SELECT *
FROM ordered_append ORDER BY time LIMIT 3;

RESET timescaledb.enable_ordered_append;
:PREFIX SELECT *
FROM ordered_append ORDER BY time LIMIT 3;

-- test with chunk append disabled
SET timescaledb.enable_chunk_append TO off;
:PREFIX SELECT *
FROM ordered_append ORDER BY time LIMIT 3;

RESET timescaledb.enable_chunk_append;
:PREFIX SELECT *
FROM ordered_append ORDER BY time LIMIT 3;

-- test space partitioning with startup exclusion
:PREFIX SELECT *
FROM space WHERE time < now() ORDER BY time;

-- test runtime exclusion together with space partitioning
:PREFIX SELECT *
FROM generate_series('2000-01-01'::timestamptz,'2000-01-03','1d') AS g(time)
LEFT OUTER JOIN LATERAL(
  SELECT * FROM space o
    WHERE o.time >= g.time AND o.time < g.time + '1d'::interval ORDER BY time DESC LIMIT 1
) l ON true;

-- test startup and runtime exclusion together with space partitioning
:PREFIX SELECT *
FROM generate_series('2000-01-01'::timestamptz,'2000-01-03','1d') AS g(time)
LEFT OUTER JOIN LATERAL(
  SELECT * FROM space o
    WHERE o.time >= g.time AND o.time < g.time + '1d'::interval AND o.time < now() ORDER BY time DESC LIMIT 1
) l ON true;


