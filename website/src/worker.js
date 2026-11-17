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

export default {
  async fetch(req, env) {
    const url = new URL(req.url);
    if (url.hostname !== 'nukkadkart.in' && url.hostname.endsWith('nukkadkart.in')) {
      url.hostname = 'nukkadkart.in';
      return Response.redirect(url.toString(), 301);
    }
    if (url.pathname === '/index.html') return Response.redirect(new URL('/', url).toString(), 301);
    const res = await env.ASSETS.fetch(req);
    const h = new Headers(res.headers);
    h.set('content-security-policy', CSP);
    h.set('strict-transport-security', 'max-age=31536000; includeSubDomains');
    h.set('x-content-type-options', 'nosniff');
    h.set('referrer-policy', 'strict-origin-when-cross-origin');
    h.set('permissions-policy', 'camera=(), microphone=(), geolocation=(), payment=()');
    h.set('x-frame-options', 'DENY');
    if (url.pathname.startsWith('/assets/')) h.set('cache-control', 'public, max-age=86400');
    return new Response(res.body, { status: res.status, statusText: res.statusText, headers: h });
  },
};
