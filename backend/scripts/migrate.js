import { readdir, readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { pool } from '../src/database/pool.js';
import { sqlStatements } from './sql-statements.js';

const directory = fileURLToPath(new URL('../database/migrations/', import.meta.url));
const connection = await pool.getConnection();
try {
  const [[lock]] = await connection.query("SELECT GET_LOCK(CONCAT(DATABASE(), ':migrate'), 10) AS acquired");
  if (Number(lock.acquired) !== 1) throw new Error('Migration lock unavailable');
  await connection.query(`CREATE TABLE IF NOT EXISTS schema_migrations (
    name VARCHAR(255) PRIMARY KEY, applied_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
  )`);
  const [applied] = await connection.query('SELECT name FROM schema_migrations');
  for (const file of (await readdir(directory)).filter((name) => name.endsWith('.sql')).sort()) {
    if (applied.some((row) => row.name === file)) continue;
    for (const sql of sqlStatements(await readFile(new URL('../database/migrations/' + file, import.meta.url), 'utf8'))) {
      await connection.query(sql);
    }
    await connection.execute('INSERT INTO schema_migrations (name) VALUES (?)', [file]);
    console.log('Applied ' + file);
  }
} finally {
  await connection.query("SELECT RELEASE_LOCK(CONCAT(DATABASE(), ':migrate'))");
  connection.release();
  await pool.end();
}
