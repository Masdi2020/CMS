import { HttpError } from '../errors.js';

export function authenticate(auth) {
  return async (req, _res, next) => {
    const match = /^Bearer ([a-f0-9]{64})$/i.exec(req.get('authorization') ?? '');
    if (!match) throw new HttpError(401, 'Silakan login terlebih dahulu.');
    req.token = match[1];
    req.user = await auth.authenticate(req.token);
    next();
  };
}
