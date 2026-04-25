'use client';

import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
} from 'react';
import { NextIntlClientProvider } from 'next-intl';

import frMessages from '../messages/fr.json';
import enMessages from '../messages/en.json';

export type Locale = 'fr' | 'en';
export const LOCALE_STORAGE_KEY = 'kpb_admin_locale';

const MESSAGES: Record<Locale, typeof frMessages> = {
  fr: frMessages,
  en: enMessages,
};

interface LocaleContextValue {
  locale: Locale;
  setLocale: (next: Locale) => void;
  /**
   * Legacy helper kept for components that still consume flat dotted keys
   * (e.g. `overview.title`). New components should use `useTranslations()`
   * from `next-intl` instead.
   */
  t: (key: string) => string;
}

const LocaleContext = createContext<LocaleContextValue | undefined>(undefined);

function resolveDotted(messages: Record<string, unknown>, key: string): string {
  const parts = key.split('.');
  let current: unknown = messages;
  for (const part of parts) {
    if (current && typeof current === 'object' && part in (current as object)) {
      current = (current as Record<string, unknown>)[part];
    } else {
      return key;
    }
  }
  return typeof current === 'string' ? current : key;
}

export function LocaleProvider({ children }: { children: React.ReactNode }) {
  const [locale, setLocaleState] = useState<Locale>('fr');

  useEffect(() => {
    const stored = window.localStorage.getItem(
      LOCALE_STORAGE_KEY,
    ) as Locale | null;
    if (stored === 'fr' || stored === 'en') {
      setLocaleState(stored);
    }
  }, []);

  const setLocale = useCallback((next: Locale) => {
    setLocaleState(next);
    window.localStorage.setItem(LOCALE_STORAGE_KEY, next);
  }, []);

  const messages = MESSAGES[locale];

  const t = useCallback(
    (key: string) => resolveDotted(messages, key),
    [messages],
  );

  const value = useMemo(
    () => ({ locale, setLocale, t }),
    [locale, setLocale, t],
  );

  return (
    <LocaleContext.Provider value={value}>
      <NextIntlClientProvider
        locale={locale}
        messages={messages}
        timeZone="Africa/Abidjan"
      >
        {children}
      </NextIntlClientProvider>
    </LocaleContext.Provider>
  );
}

export function useLocale(): LocaleContextValue {
  const ctx = useContext(LocaleContext);
  if (!ctx) {
    throw new Error('useLocale must be used inside LocaleProvider');
  }
  return ctx;
}
