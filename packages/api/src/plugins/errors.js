export default async function errors(app) {
  app.setErrorHandler((err, req, reply) => {
    if (err?.name === 'ZodError') {
      return reply.code(400).send({ error: 'Bad Request', issues: err.issues });
    }
    if (err?.code) {
      const status =
        err.code === '23505' ? 409 :
        (err.code.startsWith('22') ? 400 : 500);
      return reply.code(status).send({
        error: status === 500 ? 'Internal Server Error' : 'Error',
        code: err.code,
        detail: err.detail ?? err.message
      });
    }
    reply.code(err.statusCode || 500).send({
      error: err.statusCode ? 'Error' : 'Internal Server Error',
      message: err.message ?? 'Unexpected'
    });
  });
}
