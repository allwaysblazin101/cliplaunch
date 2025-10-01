export default async function health(app) {
  app.get('/health', async () => ({ ok: true }));
  app.get('/v1/health', async () => ({ ok: true }));
}
