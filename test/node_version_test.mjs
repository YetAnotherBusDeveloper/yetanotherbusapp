import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import { requireSafeNode } from '../scripts/check-node-version.mjs';

test('accepts the patched releases and later patches in each supported line', () => {
  for (const version of ['22.23.4', '22.24.0', '24.22.1', '24.22.2', '26.12.1']) {
    assert.doesNotThrow(() => requireSafeNode(version));
  }
});

test('blocks vulnerable, EOL, unsupported and prerelease runtimes', () => {
  for (const version of [
    '20.20.0', '22.23.3', '24.2.0', '24.22.0', '25.9.0', '26.12.0',
    '24.22.1-rc.1', 'invalid',
  ]) {
    assert.throws(() => requireSafeNode(version), /CVE-2026-111497/);
  }
});

test('the checked-in default runtime passes the guard', () => {
  const version = readFileSync(new URL('../.node-version', import.meta.url), 'utf8').trim();
  assert.doesNotThrow(() => requireSafeNode(version));
});
