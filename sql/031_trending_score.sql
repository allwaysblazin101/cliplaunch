-- Weighted trending refresher with time-decay
-- Knobs (tune & redeploy):
--   w_like=1, w_comment=3, w_follow=5, half_life_hours=12

CREATE OR REPLACE FUNCTION refresh_trending_cache(p_window_hours integer)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  since_ts timestamptz := now() - make_interval(hours => p_window_hours);
  w_like    numeric := 1.0;
  w_comment numeric := 3.0;
  w_follow  numeric := 5.0;
  half_life_hours numeric := 12.0;
BEGIN
  -- Clear previous snapshot for this window
  DELETE FROM trending_cache WHERE window_hours = p_window_hours;

  -- 1) Candidates = videos & posts published within window
  WITH pubs AS (
    SELECT 'video'::text AS object_type, v.id AS object_id, v.creator_id AS creator_id,
           v.title, v.created_at
    FROM videos v
    WHERE v.created_at >= since_ts
    UNION ALL
    SELECT 'post'::text  AS object_type, p.id AS object_id, p.user_id   AS creator_id,
           p.title, p.created_at
    FROM posts p
    WHERE p.created_at >= since_ts
  ),
  -- 2) Engagement within window (per object)
  likes AS (
    SELECT 'video'::text AS object_type, vl.video_id   AS object_id, count(*)::int AS cnt
    FROM video_likes vl
    WHERE vl.created_at >= since_ts
    GROUP BY 1,2
    UNION ALL
    SELECT 'post'::text  AS object_type, pl.post_id    AS object_id, count(*)::int AS cnt
    FROM post_likes pl
    WHERE pl.created_at >= since_ts
    GROUP BY 1,2
  ),
  comments AS (
    SELECT 'video'::text AS object_type, vc.video_id   AS object_id, count(*)::int AS cnt
    FROM video_comments vc
    WHERE vc.created_at >= since_ts
    GROUP BY 1,2
    UNION ALL
    SELECT 'post'::text  AS object_type, pc.post_id    AS object_id, count(*)::int AS cnt
    FROM post_comments pc
    WHERE pc.created_at >= since_ts
    GROUP BY 1,2
  ),
  -- 3) New follows *to the creator* within window
  follows AS (
    SELECT f.followee_id AS creator_id, count(*)::int AS cnt
    FROM follows f
    WHERE f.created_at >= since_ts
    GROUP BY 1
  ),
  -- 4) Join it all & compute score with decay
  scored AS (
    SELECT
      pu.object_type,
      pu.object_id,
      pu.creator_id,
      pu.title,
      pu.created_at,
      COALESCE(l.cnt, 0)  AS likes_count,
      COALESCE(c.cnt, 0)  AS comments_count,
      COALESCE(fo.cnt, 0) AS follows_count,
      -- Exponential decay: score_raw * 0.5^(age_hours/half_life)
      (
        (
          (COALESCE(l.cnt,0) * w_like) +
          (COALESCE(c.cnt,0) * w_comment) +
          (COALESCE(fo.cnt,0) * w_follow)
        )
        * exp( ln(0.5) * (extract(epoch from (now() - pu.created_at))/3600.0) / half_life_hours )
      )::numeric(18,6) AS score
    FROM pubs pu
    LEFT JOIN likes    l  ON l.object_type = pu.object_type AND l.object_id = pu.object_id
    LEFT JOIN comments c  ON c.object_type = pu.object_type AND c.object_id = pu.object_id
    LEFT JOIN follows  fo ON fo.creator_id = pu.creator_id
  )
  INSERT INTO trending_cache
    (object_type, object_id, creator_id, title, created_at,
     likes_count, comments_count, follows_count, score,
     window_hours, computed_at)
  SELECT
    object_type, object_id, creator_id, title, created_at,
    likes_count, comments_count, follows_count, score,
    p_window_hours, now()
  FROM scored;

END
$$;
