import assert from 'node:assert/strict';
import test from 'node:test';
import { onRequest, oneDriveContentUrl } from '../functions/download/[key].js';

const shareUrl = 'https://1drv.ms/u/s!example?e=abc';

test('encodes only approved OneDrive links', () => {
  assert.match(oneDriveContentUrl(shareUrl), /^https:\/\/api\.onedrive\.com\/v1\.0\/shares\/u!/);
  assert.throws(() => oneDriveContentUrl('https://example.com/file.zip'));
});

test('streams an approved download without origin headers', async () => {
  const originalFetch = globalThis.fetch;
  let fetched;
  globalThis.fetch = async (url, options) => {
    fetched = { url, options };
    return new Response('archive', {
      status: 206,
      headers: {
        'content-type': 'application/zip',
        'content-range': 'bytes 0-6/7',
        location: 'https://origin.example/private',
        'set-cookie': 'origin=secret'
      }
    });
  };

  try {
    const response = await onRequest({
      request: new Request('https://athena.example/download/framework', { headers: { range: 'bytes=0-6' } }),
      params: { key: 'framework' },
      env: { ONEDRIVE_LINKS: JSON.stringify({ framework: shareUrl }) }
    });

    assert.equal(response.status, 206);
    assert.equal(await response.text(), 'archive');
    assert.equal(fetched.options.headers.get('range'), 'bytes=0-6');
    assert.equal(response.headers.get('content-type'), 'application/zip');
    assert.equal(response.headers.get('location'), null);
    assert.equal(response.headers.get('set-cookie'), null);
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test('rejects writes, invalid keys, and unknown downloads', async () => {
  const base = { params: { key: 'missing' }, env: { ONEDRIVE_LINKS: '{}' } };
  assert.equal((await onRequest({ ...base, request: new Request('https://athena.example/download/missing', { method: 'POST' }) })).status, 405);
  assert.equal((await onRequest({ ...base, params: { key: '../bad' }, request: new Request('https://athena.example/download/bad') })).status, 400);
  assert.equal((await onRequest({ ...base, request: new Request('https://athena.example/download/missing') })).status, 404);
});
