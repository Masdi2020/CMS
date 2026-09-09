import { Router } from 'express';
import { rateLimit } from 'express-rate-limit';
import { z } from 'zod';
import { authenticate } from '../middleware/authenticate.js';
import { eventAccess, idSchema } from '../middleware/event-access.js';
import { HttpError } from '../errors.js';

const loginSchema = z.object({
  email: z.string().trim().toLowerCase().pipe(z.email().max(254)),
  password: z.string().min(1).max(72).refine((value) => Buffer.byteLength(value, 'utf8') <= 72, 'Password melebihi 72 byte.'),
}).strict();

export function createApi({ call, auth }) {
  const router = Router();
  router.get('/health', async (_req, res) => {
    await call('sp_health');
    res.json({ data: { status: 'ok' } });
  });
  router.post('/login', rateLimit({
    windowMs: 15 * 60 * 1000,
    limit: 10,
    standardHeaders: 'draft-8',
    legacyHeaders: false,
    message: { message: 'Terlalu banyak percobaan login. Coba lagi nanti.' },
  }), async (req, res) => {
    const input = loginSchema.parse(req.body);
    res.json({ data: await auth.login(input.email, input.password) });
  });
  router.use(authenticate(auth));
  router.get('/me', (req, res) => res.json({ data: req.user }));
  router.post('/logout', async (req, res) => {
    await auth.logout(req.token);
    res.status(204).end();
  });
  router.get('/events', async (req, res) => {
    res.json({ data: await call('sp_events_for_user', [req.user.id, req.user.role === 'admin']) });
  });
  router.get('/users/:id/events', async (req, res) => {
    const userId = idSchema.parse(req.params.id);
    if (userId !== req.user.id && req.user.role !== 'admin') {
      throw new HttpError(403, 'Anda hanya dapat melihat Event Saya milik sendiri.');
    }
    res.json({ data: await call('sp_events_for_user', [userId, false]) });
  });
  router.use('/events/:id', eventAccess(call));
  router.get('/events/:id', (req, res) => res.json({ data: req.event }));
  router.get('/events/:id/dashboard', async (req, res) => {
    const [dashboard] = await call('sp_event_dashboard', [String(req.event.id)]);
    res.json({ data: dashboard });
  });
  for (const resource of ['divisions', 'members', 'tasks']) {
    router.get(`/events/:id/${resource}`, async (req, res) => {
      res.json({ data: await call(`sp_event_${resource}`, [String(req.event.id)]) });
    });
  }
  return router;
}
