#!/usr/bin/env node
// ─────────────────────────────────────────────────────────────────────────────
// KPB Mautic MCP — exposes the self-hosted Mautic REST API as MCP tools so
// Claude can operate the newsletter (segments, contacts) conversationally.
//
// Auth (either mode, resolved in this order):
//   1. Basic:  MAUTIC_USERNAME + MAUTIC_PASSWORD (HTTP basic auth must be
//      enabled in Mautic → Configuration → API Settings — it is on the KPB
//      instance).
//   2. OAuth2: MAUTIC_CLIENT_ID + MAUTIC_CLIENT_SECRET (client_credentials
//      grant, Mautic 5+ "API Credentials" application).
//
// Credentials are read from the environment, or from a git-ignored `.env`
// file next to this script (KEY=value lines) so the MCP registration itself
// never embeds secrets.
// ─────────────────────────────────────────────────────────────────────────────

import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { z } from 'zod';

// ── Env: process env first, then tools/mautic-mcp/.env fallback ─────────────
const HERE = dirname(fileURLToPath(import.meta.url));
function loadDotEnv() {
  try {
    const raw = readFileSync(join(HERE, '.env'), 'utf8');
    for (const line of raw.split('\n')) {
      const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*?)\s*$/);
      if (m && process.env[m[1]] === undefined) process.env[m[1]] = m[2];
    }
  } catch {
    /* no .env file — env vars only */
  }
}
loadDotEnv();

const BASE_URL = (process.env.MAUTIC_BASE_URL ?? 'https://mautic.kpbeducation.cloud')
  .replace(/\/+$/, '');

// ── Auth ─────────────────────────────────────────────────────────────────────
let cachedToken = null; // { value, expiresAt }

async function authHeader() {
  const user = process.env.MAUTIC_USERNAME?.trim();
  const pass = process.env.MAUTIC_PASSWORD?.trim();
  if (user && pass) {
    return `Basic ${Buffer.from(`${user}:${pass}`).toString('base64')}`;
  }
  const clientId = process.env.MAUTIC_CLIENT_ID?.trim();
  const clientSecret = process.env.MAUTIC_CLIENT_SECRET?.trim();
  if (clientId && clientSecret) {
    if (cachedToken && cachedToken.expiresAt > Date.now() + 30_000) {
      return `Bearer ${cachedToken.value}`;
    }
    const res = await fetch(`${BASE_URL}/oauth/v2/token`, {
      method: 'POST',
      headers: { 'content-type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        grant_type: 'client_credentials',
        client_id: clientId,
        client_secret: clientSecret,
      }),
    });
    if (!res.ok) {
      throw new Error(`OAuth token request failed (${res.status}): ${await res.text()}`);
    }
    const json = await res.json();
    cachedToken = {
      value: json.access_token,
      expiresAt: Date.now() + (json.expires_in ?? 3600) * 1000,
    };
    return `Bearer ${cachedToken.value}`;
  }
  throw new Error(
    'No Mautic credentials: set MAUTIC_USERNAME+MAUTIC_PASSWORD (basic) or ' +
      'MAUTIC_CLIENT_ID+MAUTIC_CLIENT_SECRET (OAuth2) in the environment or ' +
      'in tools/mautic-mcp/.env',
  );
}

async function api(method, path, body) {
  const res = await fetch(`${BASE_URL}${path}`, {
    method,
    headers: {
      authorization: await authHeader(),
      'content-type': 'application/json',
    },
    ...(body ? { body: JSON.stringify(body) } : {}),
  });
  const text = await res.text();
  let json;
  try {
    json = JSON.parse(text);
  } catch {
    json = { raw: text.slice(0, 500) };
  }
  if (!res.ok) {
    throw new Error(`Mautic ${method} ${path} → ${res.status}: ${JSON.stringify(json).slice(0, 500)}`);
  }
  return json;
}

const ok = (data) => ({
  content: [{ type: 'text', text: JSON.stringify(data, null, 2) }],
});

// ── Server & tools ───────────────────────────────────────────────────────────
const server = new McpServer({ name: 'kpb-mautic', version: '1.0.0' });

server.tool(
  'mautic_test_auth',
  'Verify the configured Mautic credentials by fetching the authenticated user. Returns who you are connected as.',
  {},
  async () => {
    const me = await api('GET', '/api/users/self');
    return ok({
      connected: true,
      baseUrl: BASE_URL,
      user: { id: me.id, username: me.username, email: me.email, role: me.role?.name },
    });
  },
);

server.tool(
  'mautic_list_segments',
  'List Mautic segments (id, name, alias, contact count).',
  {},
  async () => {
    const res = await api('GET', '/api/segments?limit=100');
    const segments = Object.values(res.lists ?? {}).map((s) => ({
      id: s.id,
      name: s.name,
      alias: s.alias,
      isPublished: s.isPublished,
    }));
    return ok({ total: res.total ?? segments.length, segments });
  },
);

server.tool(
  'mautic_create_segment',
  'Create a Mautic segment. Returns the new segment id (use it as MAUTIC_SEGMENT_ID).',
  {
    name: z.string().min(1).describe('Segment display name, e.g. "Nouvelles bourses"'),
    description: z.string().optional().describe('Optional description'),
  },
  async ({ name, description }) => {
    const res = await api('POST', '/api/segments/new', {
      name,
      ...(description ? { description } : {}),
      isPublished: true,
    });
    const s = res.list ?? {};
    return ok({ created: true, id: s.id, name: s.name, alias: s.alias });
  },
);

server.tool(
  'mautic_segment_contacts',
  'List contacts inside a segment (email, name, date added). For verifying that app opt-ins land.',
  {
    segmentId: z.number().int().positive().describe('Segment id'),
    limit: z.number().int().min(1).max(200).default(30),
  },
  async ({ segmentId, limit }) => {
    const res = await api(
      'GET',
      `/api/contacts?search=segment:${segmentId}&limit=${limit}&orderBy=date_added&orderByDir=DESC`,
    );
    const contacts = Object.values(res.contacts ?? {}).map((c) => ({
      id: c.id,
      email: c.fields?.core?.email?.value ?? null,
      firstname: c.fields?.core?.firstname?.value ?? null,
      lastname: c.fields?.core?.lastname?.value ?? null,
      dateAdded: c.dateAdded,
    }));
    return ok({ total: res.total ?? contacts.length, contacts });
  },
);

server.tool(
  'mautic_search_contact',
  'Find a Mautic contact by email.',
  { email: z.string().email() },
  async ({ email }) => {
    const res = await api(
      'GET',
      `/api/contacts?search=email:${encodeURIComponent(email)}&limit=5`,
    );
    const contacts = Object.values(res.contacts ?? {}).map((c) => ({
      id: c.id,
      email: c.fields?.core?.email?.value ?? null,
      firstname: c.fields?.core?.firstname?.value ?? null,
      dateAdded: c.dateAdded,
      doNotContact: (c.doNotContact ?? []).length > 0,
    }));
    return ok({ total: res.total ?? contacts.length, contacts });
  },
);

server.tool(
  'mautic_add_contact_to_segment',
  'Add an existing contact to a segment (manual fix-up; the app backend does this automatically on opt-in).',
  {
    segmentId: z.number().int().positive(),
    contactId: z.number().int().positive(),
  },
  async ({ segmentId, contactId }) => {
    const res = await api('POST', `/api/segments/${segmentId}/contact/${contactId}/add`);
    return ok({ success: res.success === 1 || res.success === true });
  },
);

const transport = new StdioServerTransport();
await server.connect(transport);
