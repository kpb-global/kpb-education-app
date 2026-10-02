import './globals.css';

import localFont from 'next/font/local';

import { AdminAuthProvider } from '../components/admin-auth-provider';
import { LocaleProvider } from '../components/locale-provider';

// Polices embarquées dans app/fonts/ (licences SIL OFL 1.1 à côté) : le build
// ne télécharge plus rien chez Google Fonts. Fichiers variables, sous-ensemble
// latin, style normal, repris de @fontsource-variable/inter et
// @fontsource-variable/plus-jakarta-sans 5.3.0 ; un caractère hors de ce
// sous-ensemble (latin étendu, etc.) s'affiche dans la police de secours. Le
// nom de famille reste celui que servait next/font/google.
const inter = localFont({
  src: './fonts/inter-latin-wght-normal.woff2',
  weight: '100 900',
  style: 'normal',
  declarations: [{ prop: 'font-family', value: 'Inter' }],
  variable: '--font-inter',
  display: 'swap',
});

// Le fichier variable couvre 200 à 800 : les graisses 600, 700 et 800 en font partie.
const jakarta = localFont({
  src: './fonts/plus-jakarta-sans-latin-wght-normal.woff2',
  weight: '200 800',
  style: 'normal',
  declarations: [{ prop: 'font-family', value: 'Plus Jakarta Sans' }],
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
