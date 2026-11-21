// The kirana web panel (nukkadkart.in/partner) and the founders' LOI form (nukkadkart.in/loi) call a few API routes from the browser.
// Only that origin, only these routes; everything else answers browsers without CORS (so a page can't read it).
// Sign-in is a Bearer token, never a cookie, so allowing this origin adds no cross-site request risk.
export const WEB_ORIGIN = 'https://nukkadkart.in';

const WEB_ROUTES = [
  [/^\/v1\/auth\/google$/, 'POST'],
  [/^\/v1\/me\/logout$/, 'POST'],
  [/^\/v1\/partner\/me$/, 'GET'],
  [/^\/v1\/partner\/categories$/, 'GET'],
  [/^\/v1\/partner\/products$/, 'GET, POST'],
  [/^\/v1\/partner\/products\/bulk$/, 'POST'],
  [/^\/v1\/partner\/products\/pr_\w+\/stock$/, 'PATCH'],
  [/^\/v1\/partner\/orders$/, 'GET'],
  [/^\/v1\/admin\/loi$/, 'GET, POST'],
  [/^\/v1\/admin\/loi\/loi_[a-f0-9]{16}\/sign$/, 'GET'],
];

/** Allowed methods for this browser request, or null when the panel may not call it. */
export function webMethods(req, path) {
  if (req.headers.get('origin') !== WEB_ORIGIN) return null;
  const hit = WEB_ROUTES.find(([re]) => re.test(path));
  return hit ? hit[1] : null;
}

export function preflight(methods) {
  return new Response(null, {
    status: 204,
    headers: {
      'access-control-allow-origin': WEB_ORIGIN,
      'access-control-allow-methods': methods,
      'access-control-allow-headers': 'authorization, content-type, x-loi-key',
      'access-control-max-age': '86400',
      vary: 'origin',
    },
  });
}

export function withWebCors(res) {
  const h = new Headers(res.headers);
  h.set('access-control-allow-origin', WEB_ORIGIN);
  h.append('vary', 'origin');
  return new Response(res.body, { status: res.status, statusText: res.statusText, headers: h });
}
