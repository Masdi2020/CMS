import { createApp } from './app.js';
import { env } from './config/env.js';
import { pool } from './database/pool.js';
import { createProcedures } from './database/procedures.js';

const app = createApp({ call: createProcedures(pool), sessionHours: env.SESSION_HOURS });
const server = app.listen(env.PORT, env.HOST, () => {
  console.log(`CMS API berjalan pada port ${env.PORT} (${env.NODE_ENV}).`);
});

for (const signal of ['SIGTERM', 'SIGINT']) {
  process.once(signal, () => {
    server.close(async () => {
      await pool.end();
      process.exit(0);
    });
    setTimeout(() => process.exit(1), 10_000).unref();
  });
}
