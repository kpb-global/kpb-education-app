'use client';

export interface AdminSessionUser {
  id: string;
  fullName: string;
  email: string;
  role: string;
  languageScope: string[];
}

export interface AdminSession {
  user: AdminSessionUser;
}

export interface ApiOptions {
  method?: 'GET' | 'POST' | 'PATCH' | 'DELETE';
  body?: unknown;
  headers?: Readonly<Record<string, string>>;
  signal?: AbortSignal;
}

const API_BASE_URL =
  process.env.NEXT_PUBLIC_KPB_API_BASE_URL ?? 'http://127.0.0.1:4000/api';

// Session tokens now live in httpOnly cookies set by the backend. This key is
// only kept to purge any token left in localStorage by older builds.
const LEGACY_STORAGE_KEY = 'kpb-admin-session';

export function clearLegacySession() {
  if (typeof window !== 'undefined') {
    window.localStorage.removeItem(LEGACY_STORAGE_KEY);
  }
}

export async function loginAdmin(
  email: string,
  password?: string,
): Promise<AdminSession> {
  return apiFetch<AdminSession>('/auth/admin/login', {
    method: 'POST',
    body: { email, password },
  });
}

export async function fetchSession(): Promise<AdminSessionUser> {
  const response = await apiFetch<{ user: AdminSessionUser }>(
    '/auth/admin/session',
  );
  return response.user;
}

export async function logoutAdmin(): Promise<void> {
  try {
    await apiFetch('/auth/admin/logout', { method: 'POST' });
  } catch {
    // Best-effort: clearing the local UI state matters more than the network call.
  }
}

export async function apiFetch<T>(
  path: string,
  options: ApiOptions = {},
): Promise<T> {
  const response = await fetch(`${API_BASE_URL}${path}`, {
    method: options.method ?? 'GET',
    cache: 'no-store',
    // Send/receive the httpOnly session cookie on every request.
    credentials: 'include',
    headers: {
      'Content-Type': 'application/json',
      ...options.headers,
    },
    signal: options.signal,
    body:
      options.body === undefined ? undefined : JSON.stringify(options.body),
  });

  if (!response.ok) {
    const text = await response.text().catch(() => '');
    const error = new Error(
      text || `Request failed with status ${response.status}`,
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
