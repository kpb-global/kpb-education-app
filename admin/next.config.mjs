/** @type {import('next').NextConfig} */

// Security headers for the admin console. Note: the CSP intentionally omits a
// script-src directive (Next.js relies on inline bootstrap scripts) and focuses
// on clickjacking + navigation hardening, which is safe to apply broadly.
const securityHeaders = [
  { key: 'X-Frame-Options', value: 'DENY' },
  { key: 'X-Content-Type-Options', value: 'nosniff' },
  { key: 'Referrer-Policy', value: 'no-referrer' },
  {
    key: 'Content-Security-Policy',
    value: "frame-ancestors 'none'; base-uri 'self'; form-action 'self'",
  },
  {
    key: 'Strict-Transport-Security',
    value: 'max-age=63072000; includeSubDomains; preload',
  },
];

const nextConfig = {
  reactStrictMode: true,
  // Emit a self-contained server bundle for the Docker image (see admin/Dockerfile).
  output: 'standalone',
  async headers() {
    return [{ source: '/:path*', headers: securityHeaders }];
  },
};

export default nextConfig;
