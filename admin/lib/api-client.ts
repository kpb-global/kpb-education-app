'use client';

export interface AdminSessionUser {
  id: string;
  fullName: string;
  email: string;
  role: string;
  languageScope: string[];
}

export interface AdminSession {
  token: string;
  user: AdminSessionUser;
}

interface ApiOptions {
  method?: 'GET' | 'POST' | 'PATCH' | 'DELETE';
  body?: unknown;
  token?: string;
}

const STORAGE_KEY = 'kpb-admin-session';
const API_BASE_URL =
  process.env.NEXT_PUBLIC_KPB_API_BASE_URL ?? 'http://127.0.0.1:4000/api';

export function readStoredSession(): AdminSession | null {
  if (typeof window === 'undefined') {
    return null;
  }

  const raw = window.localStorage.getItem(STORAGE_KEY);
  if (!raw) {
    return null;
  }

  try {
    return JSON.parse(raw) as AdminSession;
  } catch (_) {
    window.localStorage.removeItem(STORAGE_KEY);
    return null;
  }
}

export function storeSession(session: AdminSession) {
  if (typeof window !== 'undefined') {
    window.localStorage.setItem(STORAGE_KEY, JSON.stringify(session));
  }
}

export function clearStoredSession() {
  if (typeof window !== 'undefined') {
    window.localStorage.removeItem(STORAGE_KEY);
  }
}

export async function loginAdmin(email: string, password?: string): Promise<AdminSession> {
  return apiFetch<AdminSession>('/auth/admin/login', {
    method: 'POST',
    body: { email, password },
  });
}

export async function fetchSession(token: string) {
  const response = await apiFetch<{ user: AdminSessionUser }>(
    '/auth/admin/session',
    { token },
  );
  return response.user;
}

export async function apiFetch<T>(
  path: string,
  options: ApiOptions = {},
): Promise<T> {
  const token = options.token ?? readStoredSession()?.token ?? undefined;
  const response = await fetch(`${API_BASE_URL}${path}`, {
    method: options.method ?? 'GET',
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body:
      options.body === undefined ? undefined : JSON.stringify(options.body),
  });

  if (!response.ok) {
    const raw = await response.text().catch(() => '');
    // NestJS errors come back as {statusCode, message, ...} where message is a
    // string or string[]. Surface that clean message instead of the raw JSON
    // blob (operators were seeing `{"statusCode":503,"message":...}`).
    let message = raw;
    if (raw) {
      try {
        const parsed = JSON.parse(raw) as { message?: unknown };
        if (Array.isArray(parsed.message)) {
          message = parsed.message.filter(Boolean).join(', ');
        } else if (typeof parsed.message === 'string' && parsed.message) {
          message = parsed.message;
        }
      } catch {
        // Body was not JSON — keep the raw text as-is.
      }
    }
    const error = new Error(
      message || `Request failed with status ${response.status}`,
    ) as Error & { status?: number };
    error.status = response.status;
    throw error;
  }

  // Mutations frequently return 204 No Content or an empty body; calling
  // response.json() on those throws and surfaces as a false failure even
  // though the write succeeded.
  if (response.status === 204) {
    return undefined as T;
  }
  const text = await response.text();
  if (!text) {
    return undefined as T;
  }
  return JSON.parse(text) as T;
}
