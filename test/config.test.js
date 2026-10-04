const test = require('node:test');
const assert = require('node:assert/strict');
const { resolveConfig, toShell, shellQuote } = require('../lib/config');

const appJson = {
  expo: {
    slug: 'box-signal',
    version: '0.2.6',
    android: { package: 'com.example.box' },
    plugins: ['expo-router', ['expo-build-kit/plugins/dev-variant', { suffix: '.debug' }]],
  },
};
const packageJson = { dependencies: { expo: '57', 'expo-dev-client': '57' }, devDependencies: {} };

test('monorepo app: paths resolve relative to the app folder', () => {
  const { vars, warnings } = resolveConfig({
    config: { buildsDir: '../builds', checks: ['npm test'], requiredFiles: ['google-services.json'] },
    appDir: '/repo/frontend',
    repoRoot: '/repo',
    appJson,
    packageJson,
  });
  assert.deepEqual(warnings, []);
  assert.equal(vars.APP_REL, 'frontend');
  assert.equal(vars.BUILDS_DIR, '/repo/builds');
  assert.deepEqual(vars.REQUIRED_FILES, ['/repo/frontend/google-services.json']);
  assert.equal(vars.ENV_FILE, '/repo/frontend/.env.local');
  assert.ok(vars.NATIVE_PATHS.includes('frontend/package.json'));
  assert.ok(vars.NATIVE_PATHS.includes('frontend/plugins'));
  assert.equal(vars.ARTIFACT_NAME, 'box-signal');
  assert.equal(vars.DEV_SUFFIX, '.debug');
  assert.equal(vars.HAS_DEV_CLIENT, 1);
  assert.equal(vars.HAS_UPDATES, 0);
});

test('root app: defaults', () => {
  const { vars } = resolveConfig({
    config: {},
    appDir: '/repo',
    repoRoot: '/repo',
    appJson: { expo: { slug: 's', version: '1.0.0', android: { package: 'p' } } },
    packageJson: { dependencies: { 'expo-updates': '1', '@sentry/react-native': '1' } },
  });
  assert.equal(vars.APP_REL, '.');
  assert.equal(vars.BUILDS_DIR, '/repo/builds');
  assert.equal(vars.TAG_PREFIX, 'v');
  assert.deepEqual(vars.CHECKS, []);
  assert.equal(vars.DEV_SUFFIX, '');
  assert.equal(vars.HAS_UPDATES, 1);
  assert.equal(vars.HAS_SENTRY, 1);
  assert.ok(vars.NATIVE_PATHS.includes('app.json'));
});

test('unknown config keys produce a warning', () => {
  const { warnings } = resolveConfig({
    config: { check: ['typo'] },
    appDir: '/r', repoRoot: '/r',
    appJson: { expo: { slug: 's', version: '1.0.0' } },
    packageJson: {},
  });
  assert.equal(warnings.length, 1);
  assert.match(warnings[0], /"check"/);
});

test('shell output quotes safely, including arrays', () => {
  assert.equal(shellQuote("it's"), `'it'\\''s'`);
  assert.equal(toShell({ A: 'x y', B: ['npm test', "echo 'hi'"] }), `A='x y'\nB=('npm test' 'echo '\\''hi'\\''')`);
  // Round-trip through a real shell.
  const { execFileSync } = require('child_process');
  const out = execFileSync('bash', ['-c', `${toShell({ B: ['npm test', "echo 'hi'"] })}\nprintf '%s|' "\${B[@]}"`], { encoding: 'utf8' });
  assert.equal(out, "npm test|echo 'hi'|");
});
