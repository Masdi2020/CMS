-- Imported by the migration owner; runtime account receives EXECUTE only.
DELIMITER $$
CREATE PROCEDURE sp_health()
SQL SECURITY DEFINER
BEGIN
  SELECT 1 AS healthy;
END$$

CREATE PROCEDURE sp_user_by_email(IN p_email VARCHAR(254))
SQL SECURITY DEFINER
BEGIN
  SELECT id, name, email, password_hash, role FROM users WHERE email = p_email LIMIT 1;
END$$

CREATE PROCEDURE sp_user_create(
  IN p_name VARCHAR(150), IN p_email VARCHAR(254),
  IN p_password_hash VARCHAR(255), IN p_role VARCHAR(10)
)
SQL SECURITY DEFINER
BEGIN
  INSERT INTO users (name, email, password_hash, role)
  VALUES (p_name, p_email, p_password_hash, p_role);
  SELECT id, name, email, role FROM users WHERE id = LAST_INSERT_ID();
END$$

CREATE PROCEDURE sp_session_create(
  IN p_user_id BIGINT UNSIGNED, IN p_token_hash CHAR(64), IN p_expires_at DATETIME
)
SQL SECURITY DEFINER
BEGIN
  DELETE FROM sessions WHERE expires_at <= UTC_TIMESTAMP();
  INSERT INTO sessions (user_id, token_hash, expires_at) VALUES (p_user_id, p_token_hash, p_expires_at);
  SELECT 1 AS created;
END$$

CREATE PROCEDURE sp_session_user(IN p_token_hash CHAR(64))
SQL SECURITY DEFINER
BEGIN
  SELECT u.id, u.name, u.email, u.role
  FROM sessions s JOIN users u ON u.id = s.user_id
  WHERE s.token_hash = p_token_hash AND s.expires_at > UTC_TIMESTAMP() LIMIT 1;
END$$

CREATE PROCEDURE sp_session_delete(IN p_token_hash CHAR(64))
SQL SECURITY DEFINER
BEGIN
  DELETE FROM sessions WHERE token_hash = p_token_hash;
  SELECT 1 AS deleted;
END$$

CREATE PROCEDURE sp_events_for_user(IN p_user_id BIGINT UNSIGNED, IN p_all BOOLEAN)
SQL SECURITY DEFINER
BEGIN
  SELECT e.*, u.name AS ketua_panitia_name,
    CASE WHEN e.ketua_panitia_id = p_user_id THEN 'ketua'
      WHEN EXISTS (SELECT 1 FROM members m JOIN divisions d ON d.id = m.division_id
        WHERE d.event_id = e.id AND m.user_id = p_user_id) THEN 'anggota'
      ELSE 'admin' END AS event_role
  FROM events e JOIN users u ON u.id = e.ketua_panitia_id
  WHERE (p_all AND EXISTS (SELECT 1 FROM users WHERE id = p_user_id AND role = 'admin'))
    OR e.ketua_panitia_id = p_user_id
    OR EXISTS (SELECT 1 FROM members m JOIN divisions d ON d.id = m.division_id
      WHERE d.event_id = e.id AND m.user_id = p_user_id)
  ORDER BY e.start_date DESC, e.id DESC;
END$$

CREATE PROCEDURE sp_event_access(IN p_user_id BIGINT UNSIGNED, IN p_event_id BIGINT UNSIGNED)
SQL SECURITY DEFINER
BEGIN
  SELECT e.*, u.name AS ketua_panitia_name,
    CASE WHEN e.ketua_panitia_id = p_user_id THEN 'ketua'
      WHEN EXISTS (SELECT 1 FROM members m JOIN divisions d ON d.id = m.division_id
        WHERE d.event_id = e.id AND m.user_id = p_user_id) THEN 'anggota'
      ELSE 'admin' END AS event_role
  FROM events e JOIN users u ON u.id = e.ketua_panitia_id
  WHERE e.id = p_event_id AND (
    EXISTS (SELECT 1 FROM users WHERE id = p_user_id AND role = 'admin')
    OR e.ketua_panitia_id = p_user_id
    OR EXISTS (SELECT 1 FROM members m JOIN divisions d ON d.id = m.division_id
      WHERE d.event_id = e.id AND m.user_id = p_user_id)
  );
END$$

CREATE PROCEDURE sp_event_dashboard(IN p_event_id BIGINT UNSIGNED)
SQL SECURITY DEFINER
BEGIN
  SELECT
    (SELECT COUNT(*) FROM divisions WHERE event_id = p_event_id) AS total_divisions,
    (SELECT COUNT(DISTINCT m.user_id) FROM members m JOIN divisions d ON d.id = m.division_id
      WHERE d.event_id = p_event_id) AS total_members,
    COUNT(*) AS total_tasks,
    COALESCE(SUM(t.status = 'to_do'), 0) AS to_do,
    COALESCE(SUM(t.status = 'in_progress'), 0) AS in_progress,
    COALESCE(SUM(t.status = 'done'), 0) AS done,
    COALESCE(ROUND(SUM(t.status = 'done') / NULLIF(COUNT(*), 0) * 100, 2), 0) AS progress
  FROM tasks t JOIN divisions d ON d.id = t.division_id WHERE d.event_id = p_event_id;
END$$

CREATE PROCEDURE sp_event_divisions(IN p_event_id BIGINT UNSIGNED)
SQL SECURITY DEFINER
BEGIN
  SELECT d.id, d.event_id, d.name, COUNT(m.id) AS total_members
  FROM divisions d LEFT JOIN members m ON m.division_id = d.id
  WHERE d.event_id = p_event_id GROUP BY d.id ORDER BY d.name;
END$$

CREATE PROCEDURE sp_event_members(IN p_event_id BIGINT UNSIGNED)
SQL SECURITY DEFINER
BEGIN
  SELECT m.id, m.user_id, m.division_id, u.name, u.email, u.phone, d.name AS division_name
  FROM members m JOIN users u ON u.id = m.user_id JOIN divisions d ON d.id = m.division_id
  WHERE d.event_id = p_event_id ORDER BY d.name, u.name;
END$$

CREATE PROCEDURE sp_event_tasks(IN p_event_id BIGINT UNSIGNED)
SQL SECURITY DEFINER
BEGIN
  SELECT t.*, d.name AS division_name, u.name AS assigned_to_name
  FROM tasks t JOIN divisions d ON d.id = t.division_id JOIN users u ON u.id = t.assigned_to
  WHERE d.event_id = p_event_id ORDER BY t.deadline, t.id;
END$$
DELIMITER ;
