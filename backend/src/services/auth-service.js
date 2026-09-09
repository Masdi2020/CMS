import bcrypt from 'bcryptjs';
import { createHash, randomBytes } from 'node:crypto';
import { HttpError } from '../errors.js';

export const hashToken = (token) => createHash('sha256').update(token).digest('hex');
const dummyHash = bcrypt.hashSync('unused-password-for-timing', 12);

function publicUser(user) {
  return { id: String(user.id), name: user.name, email: user.email, role: user.role };
}

export function createAuthService(call, sessionHours = 24) {
  return {
    async login(email, password) {
      const [user] = await call('sp_user_by_email', [email]);
      const matches = await bcrypt.compare(password, user?.password_hash ?? dummyHash);
      if (!user || !matches) throw new HttpError(401, 'Email atau password salah.');
      const token = randomBytes(32).toString('hex');
      const expiresAt = new Date(Date.now() + sessionHours * 3_600_000);
      await call('sp_session_create', [String(user.id), hashToken(token), expiresAt]);
      return { token, expires_at: expiresAt.toISOString(), user: publicUser(user) };
    },
    async authenticate(token) {
      const [user] = await call('sp_session_user', [hashToken(token)]);
      if (!user) throw new HttpError(401, 'Sesi berakhir. Silakan login kembali.');
      return publicUser(user);
    },
    async logout(token) {
      await call('sp_session_delete', [hashToken(token)]);
    },
  };
}
