import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const PROJECT_ID = 'insurance-1178e';
const API_KEY = 'AIzaSyBt7a5e3CM8GwO4tNwHkvDMcw2JqAGbiQU';
const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const credentialsPath = path.join(
  scriptDir,
  'employee_credentials_2026-07-17.csv',
);

function parseCsvLine(line) {
  return line.split(',').map((value) => value.trim());
}

async function identityRequest(method, payload) {
  const response = await fetch(
    `https://identitytoolkit.googleapis.com/v1/accounts:${method}?key=${API_KEY}`,
    {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify(payload),
    },
  );
  const body = await response.json();
  if (!response.ok) {
    const error = new Error(body?.error?.message || `Identity request failed: ${response.status}`);
    error.code = body?.error?.message || String(response.status);
    throw error;
  }
  return body;
}

async function authenticate(employee) {
  try {
    const created = await identityRequest('signUp', {
      email: employee.email,
      password: employee.password,
      returnSecureToken: true,
    });
    return { ...created, accountStatus: 'created' };
  } catch (error) {
    if (error.code !== 'EMAIL_EXISTS') throw error;
    const signedIn = await identityRequest('signInWithPassword', {
      email: employee.email,
      password: employee.password,
      returnSecureToken: true,
    });
    return { ...signedIn, accountStatus: 'existing' };
  }
}

async function updateAuthDisplayName(employee, auth) {
  await identityRequest('update', {
    idToken: auth.idToken,
    displayName: employee.name,
    returnSecureToken: false,
  });
}

function stringValue(value) {
  return { stringValue: value };
}

async function upsertProfile(employee, auth) {
  const now = new Date().toISOString();
  const roleLabels = {
    telecaller: 'Telecaller',
    executive: 'Executive',
    team_leader: 'Team Leader',
    manager: 'Manager',
  };
  const username = employee.email.split('@')[0];
  const document = {
    fields: {
      uid: stringValue(auth.localId),
      name: stringValue(employee.name),
      email: stringValue(employee.email),
      username: stringValue(username),
      phone: stringValue(''),
      role: stringValue(employee.role),
      roleLabel: stringValue(roleLabels[employee.role]),
      is_active: { booleanValue: true },
      status: stringValue('Active'),
      last_login: { nullValue: null },
      createdAt: { timestampValue: now },
      createdBy: stringValue('bulk-setup-2026-07-17'),
      updatedAt: { timestampValue: now },
    },
  };
  const fieldPaths = Object.keys(document.fields)
    .map((field) => `updateMask.fieldPaths=${encodeURIComponent(field)}`)
    .join('&');
  const url =
    `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}` +
    `/databases/(default)/documents/agents/${auth.localId}?${fieldPaths}`;
  const response = await fetch(url, {
    method: 'PATCH',
    headers: {
      authorization: `Bearer ${auth.idToken}`,
      'content-type': 'application/json',
    },
    body: JSON.stringify(document),
  });
  const body = await response.json();
  if (!response.ok) {
    throw new Error(body?.error?.message || `Firestore write failed: ${response.status}`);
  }
}

const text = await readFile(credentialsPath, 'utf8');
const lines = text.trim().split(/\r?\n/);
const employees = lines.slice(1).map((line) => {
  const [role, name, email, password] = parseCsvLine(line);
  return { role, name, email, password };
});

const results = [];
for (const employee of employees) {
  try {
    const auth = await authenticate(employee);
    await updateAuthDisplayName(employee, auth);
    await upsertProfile(employee, auth);
    results.push({
      email: employee.email,
      role: employee.role,
      auth: auth.accountStatus,
      firestore: 'written',
    });
  } catch (error) {
    results.push({
      email: employee.email,
      role: employee.role,
      auth: 'failed',
      firestore: 'not-written',
      error: error.message,
    });
  }
}

const successful = results.filter((result) => result.firestore === 'written');
const failed = results.filter((result) => result.firestore !== 'written');
const counts = successful.reduce((summary, result) => {
  summary[result.role] = (summary[result.role] || 0) + 1;
  return summary;
}, {});

console.log(JSON.stringify({ successful: successful.length, failed: failed.length, counts, failures: failed }, null, 2));
if (failed.length > 0) process.exitCode = 1;
