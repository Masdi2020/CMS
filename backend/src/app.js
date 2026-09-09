import express from 'express';
import helmet from 'helmet';
import { ZodError } from 'zod';
import { createAuthService } from './services/auth-service.js';
import { createApi } from './routes/api.js';

export function createApp({ call, sessionHours = 24, logger = console }) {
  const app = express();
  app.disable('x-powered-by');
  app.use(helmet());
  app.use(express.json({ limit: '64kb' }));
  app.use('/api', (_req, res, next) => {
    res.set('Cache-Control', 'no-store');
    next();
  }, createApi({ call, auth: createAuthService(call, sessionHours) }));
  app.use((_req, res) => res.status(404).json({ message: 'Endpoint tidak ditemukan.' }));
  app.use((error, _req, res, _next) => {
    if (error instanceof ZodError) {
      return res.status(422).json({
        message: 'Input tidak valid.',
        errors: error.issues.map(({ path, message }) => ({ field: path.join('.'), message })),
      });
    }
    if (error.type === 'entity.parse.failed') {
      return res.status(400).json({ message: 'JSON tidak valid.' });
    }
    if (error.type === 'entity.too.large') {
      return res.status(413).json({ message: 'Payload terlalu besar.' });
    }
    if (error.status && error.status < 500) {
      return res.status(error.status).json({ message: error.message });
    }
    logger.error('Request failed', { code: error.code ?? 'INTERNAL_ERROR' });
    res.status(503).json({ message: 'Layanan sementara tidak tersedia.' });
  });
  return app;
}
