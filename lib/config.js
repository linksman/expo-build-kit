// Reads <app>/expo-build.config.json plus app.json / package.json, and prints
// shell assignments for lib/common.sh to `eval`. All paths in the config file
// are relative to the folder it's in (the Expo app's folder).
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

const KNOWN_KEYS = new Set([
  '$schema', 'buildsDir', 'artifactName', 'checks', 'ciWorkflow', 'requiredFiles', 'nativePaths', 'tagPrefix', 'envFile',
]);

// Files/folders inside the app whose change means the installed binary is out of
// date, so a JS-only OTA hotfix must be refused.
const DEFAULT_NATIVE_PATHS = [
  'package.json', 'package-lock.json', 'yarn.lock', 'pnpm-lock.yaml', 'bun.lockb',
  'app.json', 'app.config.js', 'app.config.ts', 'eas.json', 'expo-build.config.json',
  'plugins', 'patches', 'modules',
];

const PLUGIN = 'expo-build-kit/plugins/';

function pluginEntry(appJson, name) {
  const plugins = appJson.expo?.plugins ?? [];
  for (const entry of plugins) {
    const [ref, options] = Array.isArray(entry) ? entry : [entry, undefined];
    if (ref === `${PLUGIN}${name}`) return { options: options ?? {} };
  }
  return null;
}

/** Pure resolution, exported for tests. */
function resolveConfig({ config, appDir, repoRoot, appJson, packageJson }) {
  const warnings = [];
  for (const key of Object.keys(config)) {
    if (!KNOWN_KEYS.has(key)) warnings.push(`unknown key "${key}" in expo-build.config.json (ignored)`);
  }
  const deps = { ...packageJson.dependencies, ...packageJson.devDependencies };
  const fromApp = (p) => path.resolve(appDir, p);
  const appRel = path.relative(repoRoot, appDir) || '.';
  const repoRel = (p) => path.relative(repoRoot, fromApp(p)) || '.';
  const devVariant = pluginEntry(appJson, 'dev-variant');

  return {
    warnings,
    vars: {
      APP_DIR: appDir,
      REPO_ROOT: repoRoot,
      APP_REL: appRel,
      BUILDS_DIR: fromApp(config.buildsDir ?? 'builds'),
      ARTIFACT_NAME: config.artifactName ?? appJson.expo.slug,
      CHECKS: config.checks ?? [],
      CI_WORKFLOW: config.ciWorkflow ?? '',
      REQUIRED_FILES: (config.requiredFiles ?? []).map(fromApp),
      NATIVE_PATHS: [...DEFAULT_NATIVE_PATHS, ...(config.nativePaths ?? [])].map(repoRel),
      TAG_PREFIX: config.tagPrefix ?? 'v',
      ENV_FILE: fromApp(config.envFile ?? '.env.local'),
      APP_VERSION: appJson.expo.version,
      SLUG: appJson.expo.slug,
      ANDROID_PACKAGE: appJson.expo.android?.package ?? '',
      DEV_SUFFIX: devVariant ? (devVariant.options.suffix ?? '.dev') : '',
      HAS_UPDATES: deps['expo-updates'] ? 1 : 0,
      HAS_DEV_CLIENT: deps['expo-dev-client'] ? 1 : 0,
      HAS_SENTRY: deps['@sentry/react-native'] ? 1 : 0,
    },
  };
}

function shellQuote(value) {
  return `'${String(value).replace(/'/g, `'\\''`)}'`;
}

function toShell(vars) {
  return Object.entries(vars)
    .map(([name, value]) =>
      Array.isArray(value) ? `${name}=(${value.map(shellQuote).join(' ')})` : `${name}=${shellQuote(value)}`,
    )
    .join('\n');
}

function main() {
  const appDir = process.cwd();
  const read = (file) => JSON.parse(fs.readFileSync(path.join(appDir, file), 'utf8'));
  const repoRoot = execFileSync('git', ['rev-parse', '--show-toplevel'], { cwd: appDir, encoding: 'utf8' }).trim();
  const { warnings, vars } = resolveConfig({
    config: read('expo-build.config.json'),
    appDir,
    repoRoot,
    appJson: read('app.json'),
    packageJson: read('package.json'),
  });
  for (const w of warnings) console.error(`expo-build: ${w}`);
  process.stdout.write(`${toShell(vars)}\n`);
}

if (require.main === module) main();

module.exports = { resolveConfig, toShell, shellQuote, DEFAULT_NATIVE_PATHS };
