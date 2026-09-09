// Nama procedure tidak pernah berasal dari input HTTP.
const allowed = new Set([
  'sp_health', 'sp_user_by_email', 'sp_user_create',
  'sp_session_create', 'sp_session_user', 'sp_session_delete',
  'sp_events_for_user', 'sp_event_access', 'sp_event_dashboard',
  'sp_event_divisions', 'sp_event_members', 'sp_event_tasks',
]);

export function createProcedures(pool) {
  return async function call(name, parameters = []) {
    if (!allowed.has(name)) throw new Error('Unknown stored procedure');
    const placeholders = parameters.map(() => '?').join(',');
    const [result] = await pool.execute(`CALL ${name}(${placeholders})`, parameters);
    return result[0];
  };
}
