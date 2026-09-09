// Supports the DELIMITER directives used by these versioned SQL files.
export function sqlStatements(source) {
  let delimiter = ';';
  let buffer = '';
  const statements = [];
  for (const line of source.split(/\r?\n/)) {
    const directive = /^DELIMITER\s+(\S+)\s*$/i.exec(line.trim());
    if (directive) {
      if (buffer.trim()) throw new Error('Unexpected DELIMITER inside SQL statement');
      delimiter = directive[1];
      continue;
    }
    if (!buffer.trim() && (line.trim().startsWith('--') || !line.trim())) continue;
    buffer += line + '\n';
    if (buffer.trimEnd().endsWith(delimiter)) {
      statements.push(buffer.trimEnd().slice(0, -delimiter.length).trim());
      buffer = '';
    }
  }
  if (buffer.trim()) throw new Error('Unterminated SQL statement');
  return statements;
}
