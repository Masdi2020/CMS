import { z } from 'zod';
import { HttpError } from '../errors.js';

export const idSchema = z.string().regex(/^[1-9][0-9]{0,18}$/);

export function eventAccess(call) {
  return async (req, _res, next) => {
    const eventId = idSchema.parse(req.params.id);
    const [event] = await call('sp_event_access', [req.user.id, eventId]);
    // Tidak membocorkan keberadaan event yang tidak dapat diakses.
    if (!event) throw new HttpError(404, 'Event tidak ditemukan.');
    req.event = event;
    next();
  };
}
