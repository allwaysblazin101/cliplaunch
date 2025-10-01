import { query } from '../db.js';
export default async function trendingDebug(app) {
  app.get('/v1/trending/debug', async (req, reply) => {
    const hours = parseInt((req.query.window || '48h').toString().replace(/h$/,'') || '48', 10);
    const { rows } = await query(
      `SELECT object_type, object_id, creator_id, title,
              likes_count, comments_count, follows_count,
              score, created_at, last_engaged_at
         FROM trending_cache
        WHERE window_hours = $1
        ORDER BY score DESC, created_at DESC
        LIMIT 50`, [hours]);
    return reply.send({ ok: true, windowHours: hours, items: rows });
  });
}
