import { query } from '../db.js';

export default async function wallets(app) {
  app.get('/v1/wallets/:owner', async (req, reply) => {
    const { owner } = req.params;
    const rows = await query(
      `SELECT owner, mint, balance
         FROM wallet_balances
        WHERE owner = $1
        ORDER BY mint`,
      [owner]
    );
    return { ok:true, balances: rows.rows };
  });
}
