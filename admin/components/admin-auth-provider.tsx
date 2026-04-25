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
  clearStoredSession,
  fetchSession,
  loginAdmin,
  readStoredSession,
  storeSession,
} from '../lib/api-client';

interface AdminAuthContextValue {
  isReady: boolean;
  session: AdminSession | null;
  login: (email: string) => Promise<AdminSession>;
  logout: () => void;
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
      const storedSession = readStoredSession();
      if (!storedSession) {
        if (!cancelled) {
          setIsReady(true);
        }
        return;
      }

      try {
        const user = await fetchSession(storedSession.token);
        if (!cancelled) {
          setSession({ ...storedSession, user });
        }
      } catch (_) {
        clearStoredSession();
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
      async login(email: string) {
        const nextSession = await loginAdmin(email);
        storeSession(nextSession);
        setSession(nextSession);
        return nextSession;
      },
      logout() {
        clearStoredSession();
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
