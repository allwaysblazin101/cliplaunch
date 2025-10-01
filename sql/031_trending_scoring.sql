-- === trending cache with engagement-based scoring ============================

CREATE OR REPLACE FUNCTION refresh_trending_cache(p_window_hours integer)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  since_ts timestamptz := now() - make_interval(hours => p_window_hours);
BEGIN
  -- wipe previous rows for this window
  DELETE FROM trending_cache tc WHERE tc.window_hours = p_window_hours;

  -- recompute
  INSERT INTO trending_cache (object_type, object_id, creator_id, title, created_at,
                              likes_count, comments_count, follows_count,
                              score, window_hours)
  SELECT
    x.object_type,
    x.object_id,
    x.creator_id,
    x.title,
    x.created_at,
    COALESCE(l.cnt,0)   AS likes_count,
    COALESCE(c.cnt,0)   AS comments_count,
    COALESCE(f.cnt,0)   AS follows_count,
    (COALESCE(l.cnt,0) * 2 + COALESCE(c.cnt,0) * 3 + COALESCE(f.cnt,0) * 1)
      + EXTRACT(EPOCH FROM (now() - x.created_at)) / -3600.0  -- recency boost
      AS score,
    p_window_hours
  FROM (
    SELECT 'video'::text AS object_type, v.id AS object_id, v.creator_id, v.title, v.created_at
    FROM videos v WHERE v.created_at >= since_ts
    UNION ALL
    SELECT 'post'::text AS object_type, p.id AS object_id, p.user_id, p.title, p.created_at
    FROM posts p WHERE p.created_at >= since_ts
  ) x
  LEFT JOIN (SELECT post_id, COUNT(*) cnt FROM post_likes GROUP BY post_id) l ON x.object_id = l.post_id
  LEFT JOIN (SELECT post_id, COUNT(*) cnt FROM post_comments GROUP BY post_id) c ON x.object_id = c.post_id
  LEFT JOIN (SELECT followee_id, COUNT(*) cnt FROM follows GROUP BY followee_id) f ON x.creator_id = f.followee_id;
END
$$;
