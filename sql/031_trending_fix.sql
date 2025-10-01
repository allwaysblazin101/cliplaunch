-- Fix refresh_trending_cache:
--  - avoid ambiguous DELETE
--  - only use posts (videos can be added back when schema is confirmed)

DROP FUNCTION IF EXISTS refresh_trending_cache(integer);

CREATE OR REPLACE FUNCTION refresh_trending_cache(p_window_hours integer)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  since_ts timestamptz := now() - make_interval(hours => p_window_hours);
BEGIN
  -- wipe previous rows for just this window
  DELETE FROM trending_cache WHERE window_hours = p_window_hours;

  -- candidates = posts published in window (videos can be re-added later)
  WITH pubs AS (
    SELECT
      'post'::text     AS object_type,
      p.id            AS object_id,
      p.user_id       AS creator_id,
      p.title         AS title,
      p.created_at    AS created_at
    FROM posts p
    WHERE p.created_at >= since_ts
  )
  INSERT INTO trending_cache
    (object_type, object_id, creator_id, title, created_at, score, window_hours)
  SELECT
    object_type, object_id, creator_id, title, created_at,
    1.0::numeric        AS score,
    p_window_hours      AS window_hours
  FROM pubs;
END
$$;
