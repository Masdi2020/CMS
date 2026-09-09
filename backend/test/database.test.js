import test from 'node:test';
import assert from 'node:assert/strict';
import mysql from 'mysql2/promise';
import { readFile } from 'node:fs/promises';
import { sqlStatements } from '../scripts/sql-statements.js';
import { createProcedures } from '../src/database/procedures.js';

// Only use a disposable local MySQL instance; this test creates its own schema.
test('MySQL procedures enforce cross-event roles, unique membership, PIC and progress', {
  skip: !process.env.TEST_MYSQL_PORT,
}, async () => {
  const db = 'cms_test_' + process.pid + '_' + Date.now();
  const connection = await mysql.createConnection({
    host: '127.0.0.1', port: Number(process.env.TEST_MYSQL_PORT),
    user: process.env.TEST_MYSQL_USER ?? 'root',
    password: process.env.TEST_MYSQL_PASSWORD ?? '',
    supportBigNumbers: true, bigNumberStrings: true, timezone: 'Z',
  });
  try {
    await connection.query('CREATE DATABASE ' + db);
    await connection.query('USE ' + db);
    for (const file of ['001_schema.sql', '002_procedures.sql']) {
      const sql = await readFile(new URL('../database/migrations/' + file, import.meta.url), 'utf8');
      for (const statement of sqlStatements(sql)) await connection.query(statement);
    }
    await connection.query(`INSERT INTO users (id, name, email, password_hash, role) VALUES
      (1, 'Admin', 'admin@example.test', 'test-only', 'admin'),
      (2, 'Budi', 'budi@example.test', 'test-only', 'user'),
      (3, 'Sinta', 'sinta@example.test', 'test-only', 'user'),
      (4, 'Rina', 'rina@example.test', 'test-only', 'user')`);
    await connection.query(`INSERT INTO events (id, title, start_date, end_date, ketua_panitia_id) VALUES
      (1, 'Seminar', '2026-09-01', '2026-09-02', 2),
      (2, 'Pelatihan', '2026-09-01', '2026-09-02', 4),
      (3, 'Event privat', '2026-09-01', '2026-09-02', 4)`);
    await connection.query("INSERT INTO divisions (id, event_id, name) VALUES (1, 1, 'Acara'), (2, 1, 'Konsumsi'), (3, 2, 'Dokumentasi')");
    await connection.query('INSERT INTO members (user_id, division_id) VALUES (3, 1), (3, 2), (2, 3), (3, 3)');
    const call = createProcedures(connection);
    const events = await call('sp_events_for_user', ['2', false]);
    assert.equal(events.length, 2);
    assert.equal(events.find((event) => String(event.id) === '1').event_role, 'ketua');
    assert.equal(events.find((event) => String(event.id) === '2').event_role, 'anggota');
    assert.equal((await call('sp_events_for_user', ['1', false])).length, 0);
    assert.equal((await call('sp_events_for_user', ['1', true])).length, 3);
    assert.equal((await call('sp_events_for_user', ['2', true])).length, 2);
    assert.equal((await call('sp_event_access', ['2', '3'])).length, 0);
    let [dashboard] = await call('sp_event_dashboard', ['1']);
    assert.equal(Number(dashboard.progress), 0);
    assert.equal(Number(dashboard.total_members), 1);
    await connection.query(`INSERT INTO tasks (division_id, assigned_to, title, deadline, status) VALUES
      (1, 3, 'Poster', '2026-09-01 12:00:00', 'done'),
      (2, 3, 'Konsumsi', '2026-09-01 12:00:00', 'to_do')`);
    [dashboard] = await call('sp_event_dashboard', ['1']);
    assert.equal(Number(dashboard.progress), 50);
    assert.equal(Number(dashboard.done), 1);
    assert.equal(Number(dashboard.total_tasks), 2);
    const [otherDashboard] = await call('sp_event_dashboard', ['2']);
    assert.equal(Number(otherDashboard.total_tasks), 0);
    await assert.rejects(connection.query('INSERT INTO members (user_id, division_id) VALUES (3, 1)'),
      { code: 'ER_DUP_ENTRY' });
    await assert.rejects(connection.query(`INSERT INTO tasks (division_id, assigned_to, title, deadline)
      VALUES (1, 2, 'Invalid PIC', '2026-09-01 12:00:00')`), { code: 'ER_NO_REFERENCED_ROW_2' });
    await connection.query("INSERT INTO attachments (task_id, type, url) VALUES (1, 'link', 'https://example.test/proof')");
    await assert.rejects(connection.query("INSERT INTO attachments (task_id, type, url) VALUES (1, 'link', 'https://example.test/duplicate')"),
      { code: 'ER_DUP_ENTRY' });
    await call('sp_session_create', ['2', 'a'.repeat(64), new Date(Date.now() + 60_000)]);
    assert.equal((await call('sp_session_user', ['a'.repeat(64)])).length, 1);
    await call('sp_session_delete', ['a'.repeat(64)]);
    assert.equal((await call('sp_session_user', ['a'.repeat(64)])).length, 0);
    await call('sp_session_create', ['2', 'b'.repeat(64), new Date(Date.now() - 60_000)]);
    assert.equal((await call('sp_session_user', ['b'.repeat(64)])).length, 0);
  } finally {
    await connection.query('DROP DATABASE ' + db);
    await connection.end();
  }
});
