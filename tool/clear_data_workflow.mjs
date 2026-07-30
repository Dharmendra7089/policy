import { readFile } from 'node:fs/promises';

const PROJECT_ID = 'insurance-1178e';
const API_KEY = 'AIzaSyBt7a5e3CM8GwO4tNwHkvDMcw2JqAGbiQU';
const BASE = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents`;
const execute = process.argv.includes('--execute');

const csv = await readFile(new URL('./employee_credentials_2026-07-17.csv', import.meta.url), 'utf8');
const rows = csv.trim().split(/\r?\n/).slice(1).map((line) => line.split(',').map((v) => v.trim()));
const operator = rows.find(([role]) => role === 'manager') ?? rows[0];
if (!operator) throw new Error('No employee credential is available for authenticated cleanup.');
const [, , email, password] = operator;

const authResponse = await fetch(
  `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${API_KEY}`,
  {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ email, password, returnSecureToken: true }),
  },
);
const auth = await authResponse.json();
if (!authResponse.ok) throw new Error(auth?.error?.message ?? 'Authentication failed.');
const headers = { authorization: `Bearer ${auth.idToken}` };

async function listCollection(collectionId) {
  const documents = [];
  let pageToken = '';
  do {
    const url = new URL(`${BASE}/${collectionId}`);
    url.searchParams.set('pageSize', '1000');
    if (pageToken) url.searchParams.set('pageToken', pageToken);
    const response = await fetch(url, { headers });
    if (response.status === 404) break;
    const body = await response.json();
    if (!response.ok) throw new Error(body?.error?.message ?? `Could not list ${collectionId}.`);
    documents.push(...(body.documents ?? []));
    pageToken = body.nextPageToken ?? '';
  } while (pageToken);
  return documents;
}

async function generatedCustomers() {
  const response = await fetch(
    `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents:runQuery`,
    {
      method: 'POST',
      headers: { ...headers, 'content-type': 'application/json' },
      body: JSON.stringify({
        structuredQuery: {
          from: [{ collectionId: 'customers' }],
          where: {
            fieldFilter: {
              field: { fieldPath: 'source' },
              op: 'EQUAL',
              value: { stringValue: 'Executive Lead Assignment' },
            },
          },
        },
      }),
    },
  );
  const body = await response.json();
  if (!response.ok) throw new Error(body?.error?.message ?? 'Could not query generated customers.');
  return body.map((row) => row.document).filter(Boolean);
}

async function remove(documents) {
  for (let start = 0; start < documents.length; start += 25) {
    await Promise.all(documents.slice(start, start + 25).map(async (document) => {
      const response = await fetch(`https://firestore.googleapis.com/v1/${document.name}`, {
        method: 'DELETE',
        headers,
      });
      if (!response.ok && response.status !== 404) {
        const body = await response.json();
        throw new Error(body?.error?.message ?? `Delete failed for ${document.name}.`);
      }
    }));
  }
}

const collectionIds = [
  'data_transfer_directories',
  'data_transfer_contacts',
  'data_transfer_batches',
  'telecaller_leads',
];
const before = {};
const documentsByCollection = {};
for (const id of collectionIds) {
  documentsByCollection[id] = await listCollection(id);
  before[id] = documentsByCollection[id].length;
}
documentsByCollection.generated_customers = await generatedCustomers();
before.generated_customers = documentsByCollection.generated_customers.length;

if (!execute) {
  console.log(JSON.stringify({ mode: 'dry-run', before }, null, 2));
  process.exit(0);
}

for (const documents of Object.values(documentsByCollection)) await remove(documents);

const after = {};
for (const id of collectionIds) after[id] = (await listCollection(id)).length;
after.generated_customers = (await generatedCustomers()).length;
console.log(JSON.stringify({ mode: 'executed', before, after }, null, 2));
