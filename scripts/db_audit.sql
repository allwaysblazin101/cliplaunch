\echo '==== EXTENSIONS ===='
SELECT extname FROM pg_extension ORDER BY 1;

\echo '==== SCHEMAS ===='
SELECT nspname AS schema
FROM pg_namespace
WHERE nspname !~ '^pg_' AND nspname <> 'information_schema'
ORDER BY 1;

\echo '==== TABLES (size, row_est) ===='
SELECT schemaname, relname AS table,
       pg_size_pretty(pg_total_relation_size(relid)) AS size,
       n_live_tup AS est_rows
FROM pg_stat_user_tables
ORDER BY pg_total_relation_size(relid) DESC, relname;

\echo '==== COLUMNS (public.*) ===='
SELECT table_name, column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema='public'
ORDER BY table_name, ordinal_position;

\echo '==== PRIMARY KEYS ===='
SELECT tc.table_name, kcu.column_name
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
  USING (constraint_name, table_schema, table_name)
WHERE tc.table_schema='public' AND tc.constraint_type='PRIMARY KEY'
ORDER BY 1,2;

\echo '==== FOREIGN KEYS ===='
SELECT conrelid::regclass AS table, conname, pg_get_constraintdef(c.oid) AS def
FROM pg_constraint c
JOIN pg_namespace n ON n.oid=c.connamespace
WHERE n.nspname='public' AND contype='f'
ORDER BY 1,2;

\echo '==== INDEXES ===='
SELECT tab.relname AS table, idx.relname AS index, pg_get_indexdef(i.indexrelid) AS def
FROM pg_index i
JOIN pg_class idx ON idx.oid=i.indexrelid
JOIN pg_class tab ON tab.oid=i.indrelid
JOIN pg_namespace n ON n.oid=tab.relnamespace
WHERE n.nspname='public'
ORDER BY tab.relname, idx.relname;

\echo '==== TRIGGERS ===='
SELECT event_object_table AS table, trigger_name, action_timing AS timing, event_manipulation AS event
FROM information_schema.triggers
WHERE trigger_schema='public'
ORDER BY 1,2;

\echo '==== EXPECTED TABLE PRESENCE (Y/N) ===='
WITH want(name) AS (
  VALUES ('creators'),('tokens'),('orders'),('ledger_entries'),('users'),('videos'),
         ('posts'),('video_likes'),('video_comments'),('video_comment_likes')
)
SELECT w.name,
       CASE WHEN to_regclass('public.'||w.name) IS NULL THEN 'N' ELSE 'Y' END AS present
FROM want w
ORDER BY 1;

\echo '==== QUICK ORPHAN CHECKS (first 20) ===='
\echo '-- tokens.creator_id -> creators.id'
SELECT t.mint, t.creator_id
FROM public.tokens t
LEFT JOIN public.creators c ON c.id=t.creator_id
WHERE c.id IS NULL
LIMIT 20;

\echo '-- orders.mint -> tokens.mint'
SELECT o.id, o.mint
FROM public.orders o
LEFT JOIN public.tokens t ON t.mint=o.mint
WHERE t.mint IS NULL
LIMIT 20;

\echo '-- ledger_entries.owner -> creators.id (runs only if column exists)'
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='ledger_entries' AND column_name='owner'
  ) THEN
    RAISE NOTICE 'ledger_entries.owner orphan sample (up to 20):';
    PERFORM 1 FROM public.ledger_entries le
      LEFT JOIN public.creators c ON c.id=le.owner
      WHERE c.id IS NULL LIMIT 1;
  ELSE
    RAISE NOTICE 'ledger_entries.owner column not present; skipping';
  END IF;
END $$;

\echo '==== ROW ESTIMATES (public.*) ===='
SELECT relname AS table, n_live_tup AS est_rows
FROM pg_stat_user_tables
ORDER BY relname;
