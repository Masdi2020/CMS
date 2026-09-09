import bcrypt from 'bcryptjs';
import { z } from 'zod';
import { pool } from '../src/database/pool.js';
import { createProcedures } from '../src/database/procedures.js';

try {
  const input = z.object({
    CMS_ADMIN_NAME: z.string().trim().min(1).max(150),
    CMS_ADMIN_EMAIL: z.email().max(254).toLowerCase(),
    CMS_ADMIN_PASSWORD: z.string().min(12).max(72).refine(
      (value) => Buffer.byteLength(value, 'utf8') <= 72, 'Password exceeds 72 bytes'),
  }).parse(process.env);
  const [user] = await createProcedures(pool)('sp_user_create', [
    input.CMS_ADMIN_NAME, input.CMS_ADMIN_EMAIL,
    await bcrypt.hash(input.CMS_ADMIN_PASSWORD, 12), 'admin',
  ]);
  console.log('Administrator dibuat: ' + user.email);
} catch (error) {
  console.error(error.code === 'ER_DUP_ENTRY'
    ? 'Email sudah terdaftar; akun tidak diubah.'
    : 'Gagal membuat admin. Periksa CMS_ADMIN_NAME, CMS_ADMIN_EMAIL, CMS_ADMIN_PASSWORD (12-72 byte), dan database.');
  process.exitCode = 1;
} finally {
  await pool.end();
}
