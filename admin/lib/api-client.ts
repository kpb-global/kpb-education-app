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
    const text = await response.text();
    throw new Error(text || `Request failed with status ${response.status}`);
  }

  return (await response.json()) as T;
}
