const ALLOWED_HOSTS = new Set(['1drv.ms', 'onedrive.live.com']);
const SAFE_RESPONSE_HEADERS = [
  'accept-ranges',
  'content-length',
  'content-range',
  'content-type',
  'etag',
  'last-modified'
];

function text(message, status, extra = {}) {
  return new Response(message, {
    status,
    headers: {
      'cache-control': 'private, no-store',
      'content-type': 'text/plain; charset=utf-8',
      ...extra
    }
  });
}

export function oneDriveContentUrl(rawUrl) {
  const url = new URL(rawUrl);
  if (url.protocol !== 'https:' || !ALLOWED_HOSTS.has(url.hostname.toLowerCase())) {
    throw new Error('Unsupported OneDrive sharing URL.');
  }

  const bytes = new TextEncoder().encode(url.href);
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  const token = btoa(binary).replaceAll('/', '_').replaceAll('+', '-').replace(/=+$/, '');
  return `https://api.onedrive.com/v1.0/shares/u!${token}/root/content`;
}

export async function onRequest(context) {
  const method = context.request.method.toUpperCase();
  if (method !== 'GET' && method !== 'HEAD') {
    return text('Método no permitido.', 405, { allow: 'GET, HEAD' });
  }

  const key = context.params.key;
  if (typeof key !== 'string' || !/^[a-z0-9][a-z0-9-]{0,127}$/.test(key)) {
    return text('Clave de descarga no válida.', 400);
  }

  let links;
  try {
    links = JSON.parse(context.env.ONEDRIVE_LINKS || '{}');
  } catch (error) {
    console.error('Invalid ONEDRIVE_LINKS JSON.', { message: error.message });
    return text('La configuración de descargas no está disponible.', 500);
  }

  const shareUrl = links?.[key];
  if (typeof shareUrl !== 'string') return text('Descarga no configurada.', 404);

  let originUrl;
  try {
    originUrl = oneDriveContentUrl(shareUrl);
  } catch (error) {
    console.error('Rejected download origin.', { key, message: error.message });
    return text('El origen de la descarga no es válido.', 502);
  }

  const requestHeaders = new Headers();
  for (const name of ['range', 'if-range', 'if-none-match', 'if-modified-since']) {
    const value = context.request.headers.get(name);
    if (value) requestHeaders.set(name, value);
  }

  let origin;
  try {
    origin = await fetch(originUrl, { method, headers: requestHeaders, redirect: 'follow' });
  } catch (error) {
    console.error('OneDrive request failed.', { key, message: error.message });
    return text('OneDrive no respondió.', 502);
  }

  if (!(origin.ok || origin.status === 206 || origin.status === 304 || origin.status === 416)) {
    console.error('OneDrive returned an unexpected status.', { key, status: origin.status });
    return text('OneDrive rechazó la descarga.', 502);
  }

  const headers = new Headers({
    'cache-control': 'private, no-store',
    'content-security-policy': "default-src 'none'",
    'x-content-type-options': 'nosniff'
  });
  for (const name of SAFE_RESPONSE_HEADERS) {
    const value = origin.headers.get(name);
    if (value) headers.set(name, value);
  }

  const body = method === 'HEAD' || origin.status === 304 ? null : origin.body;
  return new Response(body, { status: origin.status, headers });
}
