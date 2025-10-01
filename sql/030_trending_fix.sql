DROP FUNCTION IF EXISTS refresh_trending_cache(integer);

CREATE OR REPLACE FUNCTION refresh_trending_cache(p_window_hours integer)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  since_ts timestamptz := now() - make_interval(hours => p_window_hours);
BEGIN
  DELETE FROM trending_cache WHERE window_hours = p_window_hours;

  WITH pubs AS (
    SELECT 'video'::text, v.id, v.user_id, v.title, v.created_at
    FROM videos v WHERE v.created_at >= since_ts
    UNION ALL
    SELECT 'post'::text, p.id, p.user_id, p.title, p.created_at
    FROM posts p WHERE p.created_at >= since_ts
  )
  INSERT INTO trending_cache(object_type, object_id, creator_id, title, created_at, score, window_hours)
  SELECT * , 1.0, p_window_hours FROM pubs;
END
$$;
