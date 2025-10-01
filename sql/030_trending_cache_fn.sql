-- Weighted trending, with recency decay and per-window recompute
-- If the table doesn't exist yet, create it (safe to re-run)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_tables WHERE schemaname='public' AND tablename='trending_cache') THEN
    CREATE TABLE trending_cache (
      id              uuid DEFAULT gen_random_uuid() PRIMARY KEY,
      object_type     text    NOT NULL,        -- 'video' | 'post'
      object_id       uuid    NOT NULL,
      creator_id      uuid    NOT NULL,        -- users.id
      title           text,
      created_at      timestamptz NOT NULL,
      last_engaged_at timestamptz,
      likes_count     integer NOT NULL DEFAULT 0,
      comments_count  integer NOT NULL DEFAULT 0,
      follows_count   integer NOT NULL DEFAULT 0, -- follows of the creator within window
      score           numeric(18,6) NOT NULL,
      window_hours    integer NOT NULL,
      computed_at     timestamptz NOT NULL DEFAULT now()
    );
    CREATE INDEX IF NOT EXISTS idx_trending_cache_wh   ON trending_cache(window_hours, score DESC, created_at DESC);
    CREATE INDEX IF NOT EXISTS idx_trending_cache_obj  ON trending_cache(object_type, object_id);
  END IF;
END $$;

-- helper: parse '48h' -> 48 (already present but safe to re-create)
CREATE OR REPLACE FUNCTION parse_hours(p TEXT)
RETURNS integer LANGUAGE sql IMMUTABLE AS $$
  SELECT COALESCE(NULLIF(regexp_replace(p, '\D','','g'),'')::int, 48)
$$;

-- Main recompute with weights + decay
CREATE OR REPLACE FUNCTION refresh_trending_cache(p_window_hours integer)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  since_ts timestamptz := now() - make_interval(hours => p_window_hours);
BEGIN
  -- Clear this window’s rows (note the parameter vs column name!)
  DELETE FROM trending_cache tc WHERE tc.window_hours = p_window_hours;

  -- Aggregate engagement in the same window
  WITH
  -- posts published in window
  post_pubs AS (
    SELECT p.id, p.user_id AS creator_id, p.title, p.created_at
    FROM posts p
    WHERE p.created_at >= since_ts
  ),
  -- videos published in window
  video_pubs AS (
    SELECT v.id, v.creator_id, v.title, v.created_at
    FROM videos v
    WHERE v.created_at >= since_ts
  ),
  -- engagement (posts)
  post_likes AS (
    SELECT pl.post_id, COUNT(*) AS c, MAX(pl.created_at) AS last_at
    FROM post_likes pl
    WHERE pl.created_at >= since_ts
    GROUP BY pl.post_id
  ),
  post_comments AS (
    SELECT pc.post_id, COUNT(*) AS c, MAX(pc.created_at) AS last_at
    FROM post_comments pc
    WHERE pc.created_at >= since_ts
    GROUP BY pc.post_id
  ),
  -- engagement (videos)
  video_likes AS (
    SELECT vl.video_id, COUNT(*) AS c, MAX(vl.created_at) AS last_at
    FROM video_likes vl
    WHERE vl.created_at >= since_ts
    GROUP BY vl.video_id
  ),
  video_comments AS (
    -- "comments" is the FK name in your videos schema
    SELECT c.video_id, COUNT(*) AS c, MAX(c.created_at) AS last_at
    FROM comments c
    WHERE c.created_at >= since_ts
    GROUP BY c.video_id
  ),
  -- new follows for creators within window
  creator_follows AS (
    SELECT f.followee_id AS creator_id, COUNT(*) AS c, MAX(f.created_at) AS last_at
    FROM follows f
    WHERE f.created_at >= since_ts
    GROUP BY f.followee_id
  ),
  -- posts joined with engagement
  post_rows AS (
    SELECT
      'post'::text               AS object_type,
      p.id                       AS object_id,
      p.creator_id,
      p.title,
      p.created_at,
      COALESCE(pl.c, 0)          AS likes_count,
      COALESCE(pc.c, 0)          AS comments_count,
      COALESCE(cf.c, 0)          AS follows_count,
      GREATEST(p.created_at, COALESCE(pl.last_at, p.created_at), COALESCE(pc.last_at, p.created_at), COALESCE(cf.last_at, p.created_at)) AS last_engaged_at
    FROM post_pubs p
    LEFT JOIN post_likes     pl ON pl.post_id = p.id
    LEFT JOIN post_comments  pc ON pc.post_id = p.id
    LEFT JOIN creator_follows cf ON cf.creator_id = p.creator_id
  ),
  -- videos joined with engagement
  video_rows AS (
    SELECT
      'video'::text              AS object_type,
      v.id                       AS object_id,
      v.creator_id,
      v.title,
      v.created_at,
      COALESCE(vl.c, 0)          AS likes_count,
      COALESCE(vc.c, 0)          AS comments_count,
      COALESCE(cf.c, 0)          AS follows_count,
      GREATEST(v.created_at, COALESCE(vl.last_at, v.created_at), COALESCE(vc.last_at, v.created_at), COALESCE(cf.last_at, v.created_at)) AS last_engaged_at
    FROM video_pubs v
    LEFT JOIN video_likes     vl ON vl.video_id = v.id
    LEFT JOIN video_comments  vc ON vc.video_id = v.id
    LEFT JOIN creator_follows cf ON cf.creator_id = v.creator_id
  ),
  -- union all candidates
  all_rows AS (
    SELECT * FROM post_rows
    UNION ALL
    SELECT * FROM video_rows
  ),
  -- compute weighted score with recency decay
  scored AS (
    SELECT
      ar.*,
      -- base weights (tweak as needed)
      (
        (ar.likes_count    * 1.0) +
        (ar.comments_count * 3.0) +
        (ar.follows_count  * 5.0) +
        1.0 -- seed so brand-new items aren’t zero
      )
      /
      -- recency decay ~ divide by ln(2 + age hours)
      GREATEST(1.0, LN(2.0 + (EXTRACT(EPOCH FROM (now() - ar.created_at)) / 3600.0)))
      AS score
    FROM all_rows ar
  )
  INSERT INTO trending_cache (
    object_type, object_id, creator_id, title, created_at,
    last_engaged_at, likes_count, comments_count, follows_count,
    score, window_hours, computed_at
  )
  SELECT
    s.object_type, s.object_id, s.creator_id, s.title, s.created_at,
    s.last_engaged_at, s.likes_count, s.comments_count, s.follows_count,
    ROUND(s.score::numeric, 6), p_window_hours, now()
  FROM scored s;

END
$$;
