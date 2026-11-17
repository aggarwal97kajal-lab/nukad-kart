// nukkadkart.in: serves public/ and adds security headers. www.nukkadkart.in redirects to nukkadkart.in.
const CSP = [
  "default-src 'self'",
  "script-src 'self' 'unsafe-inline'",
  "style-src 'self' 'unsafe-inline'",
  "img-src 'self' data:",
  "font-src 'self'",
  "connect-src https://api.nukkadkart.in",
  "frame-ancestors 'none'",
  "base-uri 'self'",
  "form-action 'self'",
  "object-src 'none'",
].join('; ');

// The kirana web panel (/partner): Google sign-in runs in a Google script and frame; data comes from the API.
const PANEL_CSP = [
  "default-src 'self'",
  "script-src 'self' 'unsafe-inline' https://accounts.google.com/gsi/client",
  "style-src 'self' 'unsafe-inline' https://accounts.google.com/gsi/style",
  "frame-src https://accounts.google.com/gsi/",
  "img-src 'self' data: https://api.nukkadkart.in https://*.googleusercontent.com",
  "font-src 'self'",
  "connect-src https://api.nukkadkart.in https://accounts.google.com/gsi/",
  "frame-ancestors 'none'",
  "base-uri 'self'",
  "form-action 'self'",
  "object-src 'none'",
].join('; ');

const SECTIONS = ['/join', '/how-it-works', '/thelas', '/your-privacy', '/partners'];

export default {
  async fetch(req, env) {
    const url = new URL(req.url);
    if (url.hostname !== 'nukkadkart.in' && url.hostname.endsWith('nukkadkart.in')) {
      url.hostname = 'nukkadkart.in';
      return Response.redirect(url.toString(), 301);
    }
    if (url.pathname === '/index.html') return Response.redirect(new URL('/', url).toString(), 301);
    // Sections of the home page have their own addresses (nukkadkart.in/join); they all serve the home page.
    const section = SECTIONS.includes(url.pathname.replace(/\/$/, ''));
    // Panel pages (/partner, /partner/products…) are one page; its files (xlsx-lite.js) are served as they are.
    const panel = url.pathname === '/partner' || url.pathname.startsWith('/partner/');
    const panelPage = panel && !/\.[a-z0-9]+$/i.test(url.pathname);
    const res = await env.ASSETS.fetch(section ? new Request(new URL('/', url), req) : panelPage ? new Request(new URL('/partner/', url), req) : req);
    const h = new Headers(res.headers);
    h.set('content-security-policy', panel ? PANEL_CSP : CSP);
    if (panel) h.set('cache-control', 'no-cache');
    if (panel) h.set('x-robots-tag', 'noindex');
    h.set('strict-transport-security', 'max-age=31536000; includeSubDomains');
    h.set('x-content-type-options', 'nosniff');
    h.set('referrer-policy', 'strict-origin-when-cross-origin');
    h.set('permissions-policy', 'camera=(), microphone=(), geolocation=(), payment=()');
    h.set('x-frame-options', 'DENY');
    if (url.pathname.startsWith('/assets/')) h.set('cache-control', 'public, max-age=86400');
    return new Response(res.body, { status: res.status, statusText: res.statusText, headers: h });
  },
};
