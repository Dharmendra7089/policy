import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const PROJECT_ID = 'insurance-1178e';
const API_KEY = 'AIzaSyBt7a5e3CM8GwO4tNwHkvDMcw2JqAGbiQU';
const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const credentialsPath = path.join(scriptDir, 'employee_credentials_2026-07-17.csv');
const dryRun = !process.argv.includes('--execute');

const categories = ['Health', 'Life', 'General', 'Agricultural', 'ECGC'];
const categoryCodes = {
  Health: 'H',
  Life: 'L',
  General: 'G',
  Agricultural: 'A',
  ECGC: 'E',
};

function parseCsvLine(line) {
  const values = [];
  let current = '';
  let quoted = false;
  for (const char of line) {
    if (char === '"') {
      quoted = !quoted;
    } else if (char === ',' && !quoted) {
      values.push(current.trim());
      current = '';
    } else {
      current += char;
    }
  }
  values.push(current.trim());
  return values;
}

async function loadOperator() {
  const csv = await readFile(credentialsPath, 'utf8');
  const [headerLine, ...lines] = csv.trim().split(/\r?\n/);
  const header = parseCsvLine(headerLine);
  const rows = lines.map((line) => {
    const values = parseCsvLine(line);
    return Object.fromEntries(header.map((key, index) => [key, values[index] ?? '']));
  });
  return rows.find((row) => row.role === 'admin') ?? rows[0];
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
    throw new Error(body?.error?.message || `Identity request failed: ${response.status}`);
  }
  return body;
}

async function authenticate() {
  const operator = await loadOperator();
  return identityRequest('signInWithPassword', {
    email: operator.email,
    password: operator.password,
    returnSecureToken: true,
  });
}

function authHeaders(idToken) {
  return {
    authorization: `Bearer ${idToken}`,
    'content-type': 'application/json',
  };
}

function apiDocPath(collection, id = '') {
  return `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents/${collection}${id ? `/${id}` : ''}`;
}

function decodeValue(value) {
  if (!value) return null;
  if ('stringValue' in value) return value.stringValue;
  if ('integerValue' in value) return Number(value.integerValue);
  if ('doubleValue' in value) return Number(value.doubleValue);
  if ('booleanValue' in value) return value.booleanValue;
  if ('timestampValue' in value) return value.timestampValue;
  if ('arrayValue' in value) return (value.arrayValue.values ?? []).map(decodeValue);
  if ('mapValue' in value) {
    return Object.fromEntries(
      Object.entries(value.mapValue.fields ?? {}).map(([key, nested]) => [key, decodeValue(nested)]),
    );
  }
  return null;
}

function encodeValue(value) {
  if (value === null || value === undefined) return { nullValue: null };
  if (typeof value === 'string') return { stringValue: value };
  if (typeof value === 'number') {
    return Number.isInteger(value) ? { integerValue: String(value) } : { doubleValue: value };
  }
  if (typeof value === 'boolean') return { booleanValue: value };
  if (Array.isArray(value)) return { arrayValue: { values: value.map(encodeValue) } };
  return {
    mapValue: {
      fields: Object.fromEntries(Object.entries(value).map(([key, nested]) => [key, encodeValue(nested)])),
    },
  };
}

function decodeDoc(doc) {
  const id = doc.name.split('/').pop();
  const data = Object.fromEntries(
    Object.entries(doc.fields ?? {}).map(([key, value]) => [key, decodeValue(value)]),
  );
  return { id, path: doc.name, data };
}

async function listCollection(idToken, collection) {
  const out = [];
  let pageToken = '';
  do {
    const url = new URL(apiDocPath(collection));
    url.searchParams.set('pageSize', '300');
    if (pageToken) url.searchParams.set('pageToken', pageToken);
    const response = await fetch(url, { headers: authHeaders(idToken) });
    const body = await response.json();
    if (!response.ok) throw new Error(`${collection} list failed: ${JSON.stringify(body)}`);
    out.push(...(body.documents ?? []).map(decodeDoc));
    pageToken = body.nextPageToken ?? '';
  } while (pageToken);
  return out;
}

async function patchDoc(idToken, docPath, fields) {
  if (dryRun) return;
  const url = new URL(`https://firestore.googleapis.com/v1/${docPath}`);
  for (const key of Object.keys(fields)) url.searchParams.append('updateMask.fieldPaths', key);
  const response = await fetch(url, {
    method: 'PATCH',
    headers: authHeaders(idToken),
    body: JSON.stringify({
      fields: Object.fromEntries(Object.entries(fields).map(([key, value]) => [key, encodeValue(value)])),
    }),
  });
  if (!response.ok) {
    const body = await response.text();
    throw new Error(`Patch failed for ${docPath}: ${body}`);
  }
}

async function getDoc(idToken, collection, id) {
  const response = await fetch(apiDocPath(collection, id), { headers: authHeaders(idToken) });
  if (response.status === 404) return null;
  const body = await response.json();
  if (!response.ok) throw new Error(`Get failed for ${collection}/${id}: ${JSON.stringify(body)}`);
  return decodeDoc(body);
}

async function reserveLeadId(idToken, category, lead) {
  const year = new Date().getFullYear();
  const counter = await getDoc(idToken, 'system_counters', `lead_serial_${year}`);
  const current = Number(counter?.data?.lastSequence ?? 0);
  const next = current + 1;
  const leadUniqueId = `M${categoryCodes[category]}${year}${String(next).padStart(5, '0')}`;
  const existing = await getDoc(idToken, 'lead_serial_registry', leadUniqueId);
  if (existing) throw new Error(`Lead ID already exists: ${leadUniqueId}`);
  if (!dryRun) {
    await patchDoc(idToken, `projects/${PROJECT_ID}/databases/(default)/documents/system_counters/lead_serial_${year}`, {
      year,
      lastSequence: next,
      lastLeadUniqueId: leadUniqueId,
    });
    await patchDoc(idToken, `projects/${PROJECT_ID}/databases/(default)/documents/lead_serial_registry/${leadUniqueId}`, {
      leadUniqueId,
      sequence: next,
      year,
      category,
      categoryCode: categoryCodes[category],
      leadId: lead.id,
      leadName: lead.data.name ?? 'Unnamed',
      status: 'Allocated',
    });
  }
  return {
    leadUniqueId,
    uniqueLeadId: leadUniqueId,
    leadSerialNumber: leadUniqueId,
    leadSerialSequence: next,
    leadSerialYear: year,
    leadSerialCategoryCode: categoryCodes[category],
  };
}

function existingLeadId(data) {
  return data.leadUniqueId || data.uniqueLeadId || data.leadSerialNumber || '';
}

function primaryCategory(data) {
  const source = Array.isArray(data.interestCategories) ? data.interestCategories : [];
  const normalized = new Set(source.map((value) => String(value).trim().toLowerCase()));
  for (const category of categories) {
    const key = category.toLowerCase();
    if (normalized.has(key) || (key === 'agricultural' && normalized.has('agriculture'))) {
      return category;
    }
  }
  const customerCategory = String(data.customerCategory || '').trim().toLowerCase();
  return categories.find((category) => category.toLowerCase() === customerCategory) ?? null;
}

function sortDate(data) {
  return Date.parse(data.returnedAt || data.createdAt || data.assignedAt || '1970-01-01T00:00:00Z') || 0;
}

async function main() {
  const auth = await authenticate();
  const idToken = auth.idToken;
  const leads = (await listCollection(idToken, 'telecaller_leads')).sort((a, b) => sortDate(a.data) - sortDate(b.data));
  const customers = await listCollection(idToken, 'customers');
  const policies = await listCollection(idToken, 'customer_policies');
  const revenue = await listCollection(idToken, 'revenue');

  let allocated = 0;
  let copiedCustomers = 0;
  let copiedPolicies = 0;
  let copiedRevenue = 0;

  async function copyFieldsToCustomerGraph(customerId, fields) {
    const customer = customers.find((doc) => doc.id === customerId);
    if (customer) {
      await patchDoc(idToken, customer.path, {
        ...fields,
        searchKey: `${customer.data.searchKey || ''} ${fields.leadUniqueId}`.trim(),
      });
      customer.data = { ...customer.data, ...fields };
      copiedCustomers++;
    }
    for (const policy of policies.filter((doc) => doc.data.customerId === customerId)) {
      await patchDoc(idToken, policy.path, fields);
      policy.data = { ...policy.data, ...fields };
      copiedPolicies++;
    }
    for (const row of revenue.filter((doc) => doc.data.customerId === customerId)) {
      await patchDoc(idToken, row.path, fields);
      row.data = { ...row.data, ...fields };
      copiedRevenue++;
    }
  }

  for (const lead of leads) {
    const category = primaryCategory(lead.data);
    if (!category) continue;
    let fields = existingLeadId(lead.data)
      ? {
          leadUniqueId: existingLeadId(lead.data),
          uniqueLeadId: existingLeadId(lead.data),
          leadSerialNumber: existingLeadId(lead.data),
        }
      : await reserveLeadId(idToken, category, lead);
    if (!existingLeadId(lead.data)) allocated++;
    await patchDoc(idToken, lead.path, fields);

    const customerIds = new Set([
      ...(Array.isArray(lead.data.executiveCustomerIds) ? lead.data.executiveCustomerIds : []),
    ]);
    for (const customer of customers) {
      if (customer.data.telecallerLeadId === lead.id) customerIds.add(customer.id);
    }

    for (const customerId of customerIds) {
      await copyFieldsToCustomerGraph(customerId, fields);
    }
  }

  for (const customer of customers.sort((a, b) => sortDate(a.data) - sortDate(b.data))) {
    const category = primaryCategory(customer.data);
    if (!category) continue;
    const existing = existingLeadId(customer.data);
    const fields = existing
      ? {
          leadUniqueId: existing,
          uniqueLeadId: existing,
          leadSerialNumber: existing,
        }
      : await reserveLeadId(idToken, category, {
          id: customer.id,
          data: { name: customer.data.fullName || customer.data.customerName || 'Unnamed' },
        });
    if (!existing) allocated++;
    await copyFieldsToCustomerGraph(customer.id, fields);
  }

  console.log(`${dryRun ? 'Dry run' : 'Executed'} lead unique ID backfill`);
  console.log(`Allocated missing IDs: ${allocated}`);
  console.log(`Copied to customers: ${copiedCustomers}`);
  console.log(`Copied to customer_policies: ${copiedPolicies}`);
  console.log(`Copied to revenue: ${copiedRevenue}`);
  if (dryRun) console.log('Run with --execute to write changes.');
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
