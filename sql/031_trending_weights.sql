-- === Weighted trending (videos & posts) ======================================
-- Requires tables: videos, posts, video_likes, post_likes, comments/video_comments,
-- post_comments, follows (follower_id, followee_id, created_at)

-- Freshness decay: 1 / (1 + (age_hours / half_life))
CREATE OR REPLACE FUNCTION freshness_decay(age_hours numeric, half_life numeric)
RETURNS numeric
LANGUAGE sql IMMUTABLE AS $$
  SELECT 1 / (1 + (GREATEST(age_hours, 0) / GREATEST(half_life, 1)))
$$;

-- Weighted score parameters (easy to tweak)
CREATE OR REPLACE FUNCTION trending_weights()
RETURNS TABLE (w_like numeric, w_comment numeric, w_follow numeric, half_life_hours int)
LANGUAGE sql STABLE AS $$
  -- Like = 1.0, Comment = 2.0, Follow = 3.0, half-life = 18h
  SELECT 1.0::numeric, 2.0::numeric, 3.0::numeric, 18::int;
$$;

-- Recompute cache for a window (hours)
CREATE OR REPLACE FUNCTION refresh_trending_cache(p_window_hours integer)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  since_ts timestamptz := now() - make_interval(hours => p_window_hours);
  _w_like numeric;
  _w_comment numeric;
  _w_follow numeric;
  _half_life int;
BEGIN
  -- Clear this window
  DELETE FROM trending_cache WHERE window_hours = p_window_hours;

  -- Read weights
  SELECT w_like, w_comment, w_follow, half_life_hours
  INTO   _w_like, _w_comment, _w_follow, _half_life
  FROM trending_weights();

  -- Candidates: posts & videos created within window
  WITH pubs AS (
    SELECT 'post'::text AS object_type, p.id AS object_id, p.user_id AS creator_id,
           p.title, p.created_at
    FROM posts p
    WHERE p.created_at >= since_ts

    UNION ALL

    SELECT 'video'::text AS object_type, v.id AS object_id, v.creator_id AS creator_id,
           v.title, v.created_at
    FROM videos v
    WHERE v.created_at >= since_ts
  ),
  -- Likes per object (both post & video)
  likes AS (
    SELECT 'post'::text AS object_type, pl.post_id AS object_id, COUNT(*)::int AS cnt
    FROM post_likes pl
    WHERE pl.created_at >= since_ts
    GROUP BY 1,2
    UNION ALL
    SELECT 'video'::text AS object_type, vl.video_id AS object_id, COUNT(*)::int AS cnt
    FROM video_likes vl
    WHERE vl.created_at >= since_ts
    GROUP BY 1,2
  ),
  -- Comments per object
  comments AS (
    SELECT 'post'::text AS object_type, pc.post_id AS object_id, COUNT(*)::int AS cnt
    FROM post_comments pc
    WHERE pc.created_at >= since_ts
    GROUP BY 1,2
    UNION ALL
    SELECT 'video'::text AS object_type, vc.video_id AS object_id, COUNT(*)::int AS cnt
    FROM video_comments vc
    WHERE vc.created_at >= since_ts
    GROUP BY 1,2
  ),
  -- New follows of the creator within window (signal = “momentum of creator”)
  follows AS (
    SELECT f.followee_id AS creator_id, COUNT(*)::int AS cnt
    FROM follows f
    WHERE f.created_at >= since_ts
    GROUP BY 1
  ),
  -- Join aggregates and compute score
  scored AS (
    SELECT
      pu.object_type,
      pu.object_id,
      pu.creator_id,
      pu.title,
      pu.created_at,
      COALESCE(l.cnt,0) AS likes_count,
      COALESCE(c.cnt,0) AS comments_count,
      COALESCE(fl.cnt,0) AS follows_count,
      (
        (_w_like   * COALESCE(l.cnt,0)) +
        (_w_comment* COALESCE(c.cnt,0)) +
        (_w_follow * COALESCE(fl.cnt,0))
      ) * freshness_decay(EXTRACT(EPOCH FROM (now() - pu.created_at))/3600.0, _half_life)
      AS score
    FROM pubs pu
    LEFT JOIN likes    l  ON l.object_type  = pu.object_type AND l.object_id  = pu.object_id
    LEFT JOIN comments c  ON c.object_type  = pu.object_type AND c.object_id  = pu.object_id
    LEFT JOIN follows  fl ON fl.creator_id  = pu.creator_id
  )
  INSERT INTO trending_cache
    (object_type, object_id, creator_id, title, created_at,
     likes_count, comments_count, follows_count, score, window_hours)
  SELECT
    object_type, object_id, creator_id, title, created_at,
    likes_count, comments_count, follows_count, score, p_window_hours
  FROM scored;

END
$$;
