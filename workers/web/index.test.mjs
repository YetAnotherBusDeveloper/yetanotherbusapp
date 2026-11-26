import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import { runInNewContext } from 'node:vm';

import worker from './index.mjs';

const origin = 'https://busapp.avianjay.sbs';

function mockEnv() {
  const paths = [];
  return {
    paths,
    env: {
      ASSETS: {
        async fetch(request) {
          const path = new URL(request.url).pathname;
          paths.push(path);
          return new Response(path === '/landing' ? 'marketing' : 'flutter', {
            headers: { 'content-type': 'text/html' },
          });
        },
      },
    },
  };
}

test('site root serves the landing asset; web entry and deep links keep the Flutter shell', async () => {
  const { env, paths } = mockEnv();
  for (const [path, expectedAsset] of [
    ['/', '/landing'],
    ['/?utm_source=share', '/landing'],
    ['/app/', '/app/'],
    ['/route/tpe/123?routeId=TPE123', '/route/tpe/123'],
  ]) {
    const response = await worker.fetch(new Request(`${origin}${path}`), env);
    assert.equal(response.status, 200);
    assert.equal(await response.text(), expectedAsset === '/landing' ? 'marketing' : 'flutter');
    assert.equal(paths.at(-1), expectedAsset);
  }
});

test('Apple association is returned before static routing', async () => {
  const { env, paths } = mockEnv();
  const response = await worker.fetch(
    new Request(`${origin}/.well-known/apple-app-site-association`),
    env,
  );
  const payload = await response.json();
  assert.equal(response.status, 200);
  assert.ok(payload.applinks.details[0].components.some((entry) => entry['/'] === '/route/*'));
  assert.deepEqual(paths, []);
});

const landing = readFileSync(new URL('../../web/landing.html', import.meta.url), 'utf8');
const compatibilityScript = landing.match(/<script>([\s\S]*?)<\/script>/)?.[1];
assert.ok(compatibilityScript, 'landing page must contain the legacy redirect script');

function redirectFromRoot(search, hash) {
  let target = null;
  runInNewContext(compatibilityScript, {
    URLSearchParams,
    window: {
      location: {
        search,
        hash,
        replace(value) { target = value; },
      },
    },
  });
  return target;
}

test('legacy OAuth fragments reach the App without putting the token in the request path', () => {
  assert.equal(redirectFromRoot('', '#token=secret&account_id=123'), '/app/#token=secret&account_id=123');
  assert.equal(redirectFromRoot('', '#link_status=linked'), '/app/#link_status=linked');
  assert.equal(redirectFromRoot('', '#/route/tpe/123'), '/route/tpe/123');
  assert.equal(redirectFromRoot('?utm_source=friend', ''), null);
});
