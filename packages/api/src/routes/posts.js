import { z } from 'zod';
import { query } from '../db.js';

export default async function posts(app) {
  // Create a post
  app.post('/v1/posts', async (req, reply) => {
    const Body = z.object({
      userId: z.string().uuid().optional(),
      handle: z.string().min(1).optional(),
      title: z.string().min(1),
      description: z.string().optional().default('')
    });
    const p = Body.safeParse(req.body);
    if (!p.success) return reply.code(400).send({ error: 'Bad Request', issues: p.error.issues });

    let { userId, handle, title, description } = p.data;
    if (!userId && handle) {
      const r = await query('select id from users where handle=$1 limit 1', [handle]);
      if (!r.rowCount) return reply.code(404).send({ error: 'Unknown handle' });
      userId = r.rows[0].id;
    }
    if (!userId) return reply.code(400).send({ error: 'Missing user' });

    const ins = await query(
      'insert into posts(user_id,title,description) values ($1,$2,$3) returning id,created_at',
      [userId, title, description]
    );

    // log activity
    await query(
      `insert into activities(actor, verb, object_type, object_id, meta)
       values ($1,'publish','post',$2, jsonb_build_object('title',$3))`,
      [userId, ins.rows[0].id, title]
    );

    return { ok: true, post: { id: ins.rows[0].id, userId, title, description, created_at: ins.rows[0].created_at } };
  });

  // List posts for a user
  app.get('/v1/posts', async (req, reply) => {
    const Q = z.object({
      userId: z.string().uuid().optional(),
      handle: z.string().min(1).optional(),
      limit: z.coerce.number().int().min(1).max(100).default(25)
    });
    const p = Q.safeParse(req.query);
    if (!p.success) return reply.code(400).send({ error: 'Bad Request', issues: p.error.issues });
    let { userId, handle, limit } = p.data;

    if (!userId && handle) {
      const r = await query('select id from users where handle=$1 limit 1', [handle]);
      if (!r.rowCount) return reply.code(404).send({ error: 'Unknown handle' });
      userId = r.rows[0].id;
    }
    if (!userId) return reply.code(400).send({ error: 'Missing user' });

    const { rows } = await query(
      'select id,title,description,created_at from posts where user_id=$1 order by created_at desc limit $2',
      [userId, limit]
    );
    return { ok: true, items: rows };
  });
}
