const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { test } = require('node:test');

// Execute the actual inline action script, so tests cannot drift from the workflow.
const workflow = fs.readFileSync(path.join(__dirname, '../workflows/update-aas-web-ui.yml'), 'utf8');
const script = workflow.match(/^          script: \|\n((?:            .*\n|\n)+)/m)?.[1];
assert.ok(script, 'Cannot locate inline updater script');
const AsyncFunction = Object.getPrototypeOf(async function () {}).constructor;
const update = new AsyncFunction('github', 'core', 'require', 'fetch', script.replace(/^ {12}/gm, ''));

const release = (tag, extra = {}) => ({ tag_name: tag, published_at: '2026-10-21T10:00:00Z', ...extra });
const fixture = () => ({
  'charts/basyx/values.yaml': [
    'other:\n  image:\n    tag: keep-me',
    'aasWebGui:\n  enabled: false\n  image:',
    '    repository: eclipsebasyx/aas-gui\n    pullPolicy: Always\n    tag: v2-261013',
    '\n  imagePullSecrets: []\nnext:\n  image:\n    tag: also-keep-me\n',
  ].join('\n'),
  'charts/basyx/Chart.yaml': 'name: basyx\nversion: 3.16.9\nappVersion: "1.1.2"\n',
  'README.md': '# BaSyx\n\n### Upgrading to chart 3.16.9\n\nOld note.\n',
});

async function run({ releases = [release('v2-261020')], files = fixture(), manifestStatus = 200, authStatus = 200, token = 'pull-token' } = {}) {
  const outputs = {};
  const calls = [];
  const github = {
    rest: { repos: { listReleases() {} } },
    async paginate(method, options) {
      assert.equal(method, this.rest.repos.listReleases);
      assert.deepEqual(options, { owner: 'eclipse-basyx', repo: 'basyx-aas-web-ui', per_page: 100 });
      return releases;
    },
  };
  await update(github, {
    info() {},
    setOutput(key, value) { outputs[key] = value; },
  }, name => {
    assert.equal(name, 'node:fs');
    return {
      readFileSync: name => { assert.ok(Object.hasOwn(files, name)); return files[name]; },
      writeFileSync: (name, text) => { files[name] = text; },
    };
  }, async (url, options) => {
    calls.push({ url, options });
    const status = url.startsWith('https://auth.docker.io/') ? authStatus : manifestStatus;
    return { status, ok: status >= 200 && status < 300, json: async () => ({ token }) };
  });
  return { files, outputs, calls };
}

test('selects the newest eligible published release, independent of API ordering', async () => {
  const { outputs } = await run({ releases: [
    release('v2-261020'), release('v2-261013'), release('v2-260924'),
    release('v2-261022', { draft: true }), release('v2-261023', { prerelease: true }),
    release('v2-261024-rc1'), release('v3-261025'), release('v2-261032'),
    release('v2-261026', { published_at: null }), release('latest'),
    release('v2-261019'), release('v2-260229'),
  ] });
  assert.equal(outputs.tag, 'v2-261020');
});

test('changes exactly the UI tag, chart patch version and upgrade note', async () => {
  const before = fixture();
  const { files, outputs, calls } = await run();
  assert.deepEqual(outputs, { changed: 'true', tag: 'v2-261020', 'previous-tag': 'v2-261013', 'chart-version': '3.16.10' });
  assert.equal(files['charts/basyx/values.yaml'], before['charts/basyx/values.yaml'].replace('v2-261013', 'v2-261020'));
  assert.equal(files['charts/basyx/Chart.yaml'], before['charts/basyx/Chart.yaml'].replace('3.16.9', '3.16.10'));
  assert.equal(files['README.md'], before['README.md'].replace(
    '### Upgrading to chart 3.16.9',
    '### Upgrading to chart 3.16.10\n\nChart 3.16.10 updates the default AAS Web UI image to `v2-261020`.\n\n### Upgrading to chart 3.16.9',
  ));
  assert.equal(calls[1].url, 'https://registry-1.docker.io/v2/eclipsebasyx/aas-gui/manifests/v2-261020');
  assert.equal(calls[1].options.method, 'HEAD');
  assert.equal(calls[1].options.headers.Authorization, 'Bearer pull-token');
  const again = await run({ files });
  assert.deepEqual(again.outputs, { changed: 'false' });
  assert.equal(again.calls.length, 0);
});

test('equal and older releases leave all files unchanged', async () => {
  const { files, outputs, calls } = await run({ releases: [release('v2-261013'), release('v2-260924')] });
  assert.deepEqual(files, fixture());
  assert.deepEqual(outputs, { changed: 'false' });
  assert.equal(calls.length, 0);
});

test('waits for the newest release image instead of choosing an older release', async () => {
  const { files, outputs, calls } = await run({ releases: [release('v2-261019'), release('v2-261020')], manifestStatus: 404 });
  assert.deepEqual(files, fixture());
  assert.deepEqual(outputs, { changed: 'false' });
  assert.ok(calls[1].url.endsWith('/v2-261020'));
});

test('authentication, rate-limit and server errors fail without editing files', async () => {
  for (const status of [401, 403, 429, 500]) {
    for (const field of ['authStatus', 'manifestStatus']) {
      const files = fixture();
      await assert.rejects(run({ files, [field]: status }), new RegExp(`HTTP ${status}`));
      assert.deepEqual(files, fixture());
    }
  }
  await assert.rejects(run({ token: null }), /no pull token/);
});

test('invalid configuration causes no partial edits', async () => {
  for (const [file, from, to] of [
    ['charts/basyx/values.yaml', 'eclipsebasyx/aas-gui', 'custom/image'],
    ['charts/basyx/values.yaml', 'v2-261013', 'latest'],
    ['charts/basyx/values.yaml', 'v2-261013', 'v2-260229'],
    ['charts/basyx/Chart.yaml', '3.16.9', '3.16.9-rc1'],
    ['README.md', '### Upgrading to chart ', 'Missing heading '],
  ]) {
    const files = fixture();
    files[file] = files[file].replace(from, to);
    const before = { ...files };
    await assert.rejects(run({ files }));
    assert.deepEqual(files, before);
  }
});

test('updates the actual chart file structure without changing unrelated content', async () => {
  const root = path.join(__dirname, '../..');
  const files = Object.fromEntries(Object.keys(fixture()).map(name => [name, fs.readFileSync(path.join(root, name), 'utf8')]));
  const before = { ...files };
  const oldTag = /^aasWebGui:\n[\s\S]*?^    tag: (v[1-9][0-9]*-[0-9]{6})$/m.exec(files['charts/basyx/values.yaml'])[1];
  const newTag = `${oldTag.split('-')[0]}-991231`;
  const { outputs } = await run({ files, releases: [release(newTag)] });
  assert.equal(outputs.changed, 'true');
  assert.equal(files['charts/basyx/values.yaml'], before['charts/basyx/values.yaml'].replace(oldTag, newTag));
  assert.ok(files['README.md'].includes(`default AAS Web UI image to \`${newTag}\``));
});
