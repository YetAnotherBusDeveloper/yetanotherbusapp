// CVE-2026-111497 is in Node's bundled native Brotli decoder. Updating npm
// packages alone does not fix it; each supported release line has its own floor.
const patchedVersions = new Map([
  [22, [23, 4]],
  [24, [22, 1]],
  [26, [12, 1]],
]);

export function requireSafeNode(version = process.versions.node) {
  const match = /^(\d+)\.(\d+)\.(\d+)$/.exec(version);
  const [major, minor, patch] = match ? match.slice(1).map(Number) : [];
  const minimum = patchedVersions.get(major);
  if (
    !minimum ||
    minor < minimum[0] ||
    (minor === minimum[0] && patch < minimum[1])
  ) {
    throw new Error(
      `Node.js ${version} is unsupported for CVE-2026-111497 (HTTP2Shell). ` +
        'Use Node.js 22.23.4+, 24.22.1+, or 26.12.1+ within those release lines; ' +
        '.node-version selects the project default.',
    );
  }
}

requireSafeNode();
