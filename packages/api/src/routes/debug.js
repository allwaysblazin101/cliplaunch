import path from 'node:path';
import { promises as fs } from 'node:fs';

export default async function debug(app) {
  app.get('/debug/code/*', async (req, reply) => {
    try {
      const rel = decodeURIComponent((req.params)['*'] || '');
      if (!rel || rel.includes('..')) return reply.code(400).send('Bad path');
      const base = path.resolve(path.join(import.meta.dirname, '..'));
      const full = path.resolve(base, rel);
      if (!full.startsWith(base)) return reply.code(400).send('Out of bounds');
      const data = await fs.readFile(full, 'utf8');
      reply
        .header('Content-Type', 'text/plain; charset=utf-8')
        .header('Content-Disposition', `inline; filename="${path.basename(full)}.txt"`);
      return data;
    } catch {
      return reply.code(404).send('Not found');
    }
  });
}
