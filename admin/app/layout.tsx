import './globals.css';

import { AdminAuthProvider } from '../components/admin-auth-provider';
import { LocaleProvider } from '../components/locale-provider';

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
    <html lang="fr">
      <body>
        <LocaleProvider>
          <AdminAuthProvider>{children}</AdminAuthProvider>
        </LocaleProvider>
      </body>
    </html>
  );
}
