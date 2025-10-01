import { z } from 'zod';
import { query } from '../db.js';

export default async function tokens(app) {
  const Query = z.object({
    side: z.enum(['buy','sell']),
    amount: z.coerce.number().positive()
  });

  app.get('/v1/tokens/:mint/quote', async (req, reply) => {
    const v = Query.safeParse(req.query);
    if (!v.success) return reply.code(400).send({ error:'Bad Request', issues: v.error.issues });

    const t = await query(`select mint, decimals, initial_supply from tokens where mint=$1`, [req.params.mint]);
    if (!t.rowCount) return reply.code(404).send({ error:'TokenNotFound' });

    const meta = t.rows[0];
    // Stub pricing: base + slope * circulating
    const base = 0.5;
    const slope = 0.0000001;
    const circulating = Number(meta.initial_supply);
    const price = base + slope * circulating;

    const { side, amount } = v.data;
    const out = side === 'buy'
      ? Math.floor(amount / price)
      : Math.floor(amount * price);

    return {
      ok: true,
      mint: meta.mint,
      side,
      price: Number(price.toFixed(6)),
      amountIn: String(amount),
      out: String(out)
    };
  });
}
