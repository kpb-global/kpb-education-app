'use client';

import {
  createContext,
  useContext,
  useEffect,
  useMemo,
  useState,
} from 'react';

import {
  AdminSession,
  clearLegacySession,
  fetchSession,
  loginAdmin,
  logoutAdmin,
} from '../lib/api-client';

interface AdminAuthContextValue {
  isReady: boolean;
  session: AdminSession | null;
  login: (email: string, password?: string) => Promise<AdminSession>;
  logout: () => Promise<void>;
}

const AdminAuthContext = createContext<AdminAuthContextValue | null>(null);

export function AdminAuthProvider({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  const [session, setSession] = useState<AdminSession | null>(null);
  const [isReady, setIsReady] = useState(false);

  useEffect(() => {
    let cancelled = false;

    async function restoreSession() {
      // Purge any token persisted by older (localStorage-based) builds.
      clearLegacySession();
      try {
        // Validate the httpOnly session cookie server-side.
        const user = await fetchSession();
        if (!cancelled) {
          setSession({ user });
        }
      } catch {
        if (!cancelled) {
          setSession(null);
        }
      } finally {
        if (!cancelled) {
          setIsReady(true);
        }
      }
    }

    void restoreSession();

    return () => {
      cancelled = true;
    };
  }, []);

  const value = useMemo<AdminAuthContextValue>(
    () => ({
      isReady,
      session,
      async login(email: string, password?: string) {
        const nextSession = await loginAdmin(email, password);
        setSession(nextSession);
        return nextSession;
      },
      async logout() {
        await logoutAdmin();
        setSession(null);
      },
    }),
    [isReady, session],
  );

  return (
    <AdminAuthContext.Provider value={value}>
      {children}
    </AdminAuthContext.Provider>
  );
}

export function useAdminAuth() {
  const context = useContext(AdminAuthContext);
  if (!context) {
    throw new Error('useAdminAuth must be used inside AdminAuthProvider.');
  }

  return context;
}
