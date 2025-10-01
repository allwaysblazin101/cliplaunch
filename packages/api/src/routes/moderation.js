export default async function moderation(app) {
  // simple liveness for admin tooling
  app.get('/v1/mod/health', async () => ({ ok: true, mod: 'up' }));
}
