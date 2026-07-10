import './globals.css';

import { Inter, Plus_Jakarta_Sans } from 'next/font/google';

import { AdminAuthProvider } from '../components/admin-auth-provider';
import { LocaleProvider } from '../components/locale-provider';

const inter = Inter({
  subsets: ['latin'],
  variable: '--font-inter',
  display: 'swap',
});

const jakarta = Plus_Jakarta_Sans({
  subsets: ['latin'],
  weight: ['600', '700', '800'],
  variable: '--font-jakarta',
  display: 'swap',
});

export const metadata = {
  title: 'KPB Education Admin',
  description: 'Espace conseillers et admins KPB Education',
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="fr" className={`${inter.variable} ${jakarta.variable}`}>
      <body>
        <LocaleProvider>
          <AdminAuthProvider>{children}</AdminAuthProvider>
        </LocaleProvider>
      </body>
    </html>
  );
}
