#!/usr/bin/env node
// Run after flutter build web; exercise Wrangler's asset router, not just the
// Worker handler (which cannot simulate asset-first routing on its own).
import { spawn, execFileSync } from 'node:child_process';
import { setTimeout as delay } from 'node:timers/promises';

const port = 8793;
const base = `http://127.0.0.1:${port}`;
const server = spawn(
  process.execPath,
  ['node_modules/wrangler/bin/wrangler.js', 'dev', '--local', '--port', `${port}`, '--ip', '127.0.0.1'],
  { stdio: ['ignore', 'pipe', 'pipe'] },
);
let output = '';
server.stdout.on('data', (chunk) => { output += chunk; });
server.stderr.on('data', (chunk) => { output += chunk; });

try {
  let started = false;
  for (let attempt = 0; attempt < 80; attempt++) {
    if (server.exitCode !== null) break;
    try {
      const response = await fetch(`${base}/`);
      if (response.ok) {
        started = true;
        break;
      }
    } catch {
      // Wrangler is still starting.
    }
    await delay(300);
  }
  if (!started) throw new Error(`Wrangler did not start:\n${output}`);

  for (const [path, content] of [
    ['/', 'id="hero-title"'],
    ['/?utm_source=share', 'id="hero-title"'],
    ['/app', 'flutter_bootstrap.js'],
    ['/app/', 'flutter_bootstrap.js'],
    ['/route/tpe/123', 'flutter_bootstrap.js'],
    ['/landing.css', '--ink:'],
    ['/landing-assets/home.webp', null],
    ['/landing-assets/arrival.webp', null],
    ['/landing-assets/map.webp', null],
    ['/landing-assets/modes.webp', null],
    ['/landing-assets/metro.webp', null],
    ['/landing-assets/share.png', null],
    ['/manifest.json', '"start_url": "/app/"'],
    ['/.well-known/apple-app-site-association', 'applinks'],
  ]) {
    const response = await fetch(`${base}${path}`);
    if (response.status !== 200 ||
        (content && !(await response.text()).includes(content))) {
      throw new Error(`Unexpected response for ${path}: ${response.status}`);
    }
    console.log(`${response.status} ${path}`);
  }
} finally {
  if (process.platform === 'win32') {
    try {
      execFileSync('taskkill', ['/pid', `${server.pid}`, '/t', '/f'], { stdio: 'ignore' });
    } catch {
      // The server may have already exited.
    }
  } else {
    server.kill('SIGTERM');
  }
}
