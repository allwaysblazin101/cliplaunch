CREATE OR REPLACE FUNCTION refresh_trending_cache(p_window_hours integer)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  since_ts timestamptz := now() - make_interval(hours => p_window_hours);
BEGIN
  DELETE FROM trending_cache WHERE window_hours = p_window_hours;

  WITH
  post_rows AS (
    SELECT
      'post'::text AS object_type,
      p.id         AS object_id,
      p.user_id    AS creator_id,
      p.title,
      p.created_at AS created_at,
      p.created_at AS engaged_at,                -- posts: no engagement bump yet
      COALESCE(pl.cnt,0) AS likes_count,
      COALESCE(pc.cnt,0) AS comments_count,
      0 AS follows_count
    FROM posts p
    LEFT JOIN (SELECT post_id, COUNT(*) AS cnt FROM post_likes GROUP BY post_id) pl ON pl.post_id = p.id
    LEFT JOIN (SELECT post_id, COUNT(*) AS cnt FROM post_comments GROUP BY post_id) pc ON pc.post_id = p.id
    WHERE p.created_at >= since_ts
  ),
  video_rows AS (
    SELECT
      'video'::text AS object_type,
      v.id          AS object_id,
      v.user_id     AS creator_id,
      v.title,
      v.created_at,
      GREATEST(v.created_at, COALESCE(v.last_engaged_at, v.created_at)) AS engaged_at,
      COALESCE(vl.cnt,0) AS likes_count,
      COALESCE(vc.cnt,0) AS comments_count,
      0 AS follows_count
    FROM videos v
    LEFT JOIN (SELECT video_id, COUNT(*) AS cnt FROM video_likes GROUP BY video_id)  vl ON vl.video_id = v.id
    LEFT JOIN (SELECT video_id, COUNT(*) AS cnt FROM video_comments GROUP BY video_id) vc ON vc.video_id = v.id
    WHERE GREATEST(v.created_at, COALESCE(v.last_engaged_at, v.created_at)) >= since_ts
  ),
  all_rows AS (
    SELECT * FROM post_rows
    UNION ALL
    SELECT * FROM video_rows
  ),
  scored AS (
    SELECT
      ar.*,
      (
        (ar.likes_count    * 1.0) +
        (ar.comments_count * 3.0) +
        (ar.follows_count  * 5.0) +
        1.0
      )
      / GREATEST(1.0, LN(2.0 + (EXTRACT(EPOCH FROM (now() - ar.engaged_at)) / 3600.0)))
      AS score
    FROM all_rows ar
  )
  INSERT INTO trending_cache (
    object_type, object_id, creator_id, title,
    created_at, last_engaged_at,
    likes_count, comments_count, follows_count,
    score, window_hours, computed_at
  )
  SELECT
    s.object_type, s.object_id, s.creator_id, s.title,
    s.created_at, s.engaged_at,
    s.likes_count, s.comments_count, s.follows_count,
    ROUND(s.score::numeric, 6), p_window_hours, now()
  FROM scored s;
END;
$$;
