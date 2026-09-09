import test from 'node:test';
import assert from 'node:assert/strict';
import request from 'supertest';
import bcrypt from 'bcryptjs';
import { createApp } from '../src/app.js';
import { hashToken } from '../src/services/auth-service.js';
import { createProcedures } from '../src/database/procedures.js';

const password = 'a-long-test-password';
const user = { id: '7', name: 'Budi', email: 'budi@example.test', role: 'user',
  password_hash: await bcrypt.hash(password, 4) };
const token = 'a'.repeat(64);

function fixture(overrides = {}) {
  const calls = [];
  const sessions = new Map([[hashToken(token), user]]);
  const handlers = {
    sp_health: () => [{ healthy: 1 }],
    sp_user_by_email: ([email]) => email === user.email ? [user] : [],
    sp_session_create: ([, hash]) => { sessions.set(hash, user); return []; },
    sp_session_user: ([hash]) => sessions.has(hash) ? [sessions.get(hash)] : [],
    sp_session_delete: ([hash]) => { sessions.delete(hash); return []; },
    sp_events_for_user: () => [{ id: '10', title: 'Seminar', event_role: 'ketua' }],
    sp_event_access: ([, id]) => id === '10' ? [{ id: '10', title: 'Seminar' }] : [],
    sp_event_dashboard: () => [{ total_tasks: 0, progress: 0 }],
    sp_event_tasks: () => [],
    ...overrides,
  };
  const app = createApp({ call: async (name, parameters = []) => {
    calls.push({ name, parameters });
    if (!handlers[name]) throw new Error('Unexpected procedure ' + name);
    return handlers[name](parameters);
  }, logger: { error() {} } });
  return { app, calls };
}
const authorized = (req) => req.set('Authorization', 'Bearer ' + token);

test('login returns a token, stores only its hash, and omits password hash', async () => {
  const { app, calls } = fixture();
  const response = await request(app).post('/api/login').send({ email: user.email, password }).expect(200);
  assert.match(response.body.data.token, /^[a-f0-9]{64}$/);
  assert.equal(response.body.data.user.password_hash, undefined);
  const saved = calls.find((call) => call.name === 'sp_session_create');
  assert.equal(saved.parameters[1], hashToken(response.body.data.token));
  assert.notEqual(saved.parameters[1], response.body.data.token);
});

test('wrong password and unknown email have the same public failure', async () => {
  const { app } = fixture();
  const wrong = await request(app).post('/api/login').send({ email: user.email, password: 'incorrect' }).expect(401);
  const missing = await request(app).post('/api/login').send({ email: 'missing@example.test', password }).expect(401);
  assert.deepEqual(wrong.body, missing.body);
});

test('invalid input is rejected before querying the database', async () => {
  const { app, calls } = fixture();
  await request(app).post('/api/login').send({ email: 'invalid', password: '' }).expect(422);
  assert.equal(calls.length, 0);
});

test('authentication is required; unknown sessions cannot access events', async () => {
  const { app } = fixture();
  await request(app).get('/api/events').expect(401);
  await request(app).get('/api/events').set('Authorization', 'Bearer ' + 'b'.repeat(64)).expect(401);
});

test('logout revokes the session for subsequent requests', async () => {
  const { app } = fixture();
  await authorized(request(app).post('/api/logout')).expect(204);
  await authorized(request(app).get('/api/me')).expect(401);
});

test('users cannot query another users Event Saya', async () => {
  const { app, calls } = fixture();
  await authorized(request(app).get('/api/users/8/events')).expect(403);
  assert.equal(calls.some((call) => call.name === 'sp_events_for_user'), false);
});

test('event guard prevents dashboard and task reads across unrelated events', async () => {
  const { app, calls } = fixture();
  await authorized(request(app).get('/api/events/99/dashboard')).expect(404);
  await authorized(request(app).get('/api/events/99/tasks')).expect(404);
  assert.equal(calls.some((call) => ['sp_event_dashboard', 'sp_event_tasks'].includes(call.name)), false);
});

test('Event Saya always uses membership mode, and dashboard preserves zero progress', async () => {
  const { app, calls } = fixture();
  await authorized(request(app).get('/api/users/7/events')).expect(200);
  assert.deepEqual(calls.find((call) => call.name === 'sp_events_for_user').parameters, ['7', false]);
  const response = await authorized(request(app).get('/api/events/10/dashboard')).expect(200);
  assert.equal(response.body.data.progress, 0);
});

test('database failures and malformed JSON do not leak internals', async () => {
  const { app } = fixture({ sp_health: () => { throw new Error('secret connection string'); } });
  const response = await request(app).get('/api/health').expect(503);
  assert.equal(JSON.stringify(response.body).includes('secret'), false);
  await request(app).post('/api/login').type('json').send('{broken').expect(400);
});

test('procedure wrapper parameterizes values and rejects unknown procedure names', async () => {
  const calls = [];
  const call = createProcedures({ execute: async (...args) => {
    calls.push(args);
    return [[[{ id: '7' }], { affectedRows: 0 }]];
  } });
  const email = "' OR 1=1 --";
  assert.deepEqual(await call('sp_user_by_email', [email]), [{ id: '7' }]);
  assert.deepEqual(calls[0], ['CALL sp_user_by_email(?)', [email]]);
  await assert.rejects(call('users; DROP TABLE users'), /Unknown stored procedure/);
});
