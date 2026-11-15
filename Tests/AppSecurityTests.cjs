const assert = require('node:assert/strict');
const { execFileSync, spawnSync } = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const sourceApp = process.env.COMMANDSHIFT_TEST_APP;
if (!sourceApp) throw new Error('Set COMMANDSHIFT_TEST_APP to the built app bundle');

function verify(app) {
    return spawnSync('bash', ['Tests/check-app.sh', app], { encoding: 'utf8' });
}

function signedCopy(t, entitlements, runtime = true) {
    const directory = fs.mkdtempSync(path.join('.build', 'app-security-'));
    t.after(() => fs.rmSync(directory, { recursive: true, force: true }));
    const app = path.join(directory, 'CommandShift.app');
    const plist = path.join(directory, 'entitlements.plist');
    fs.cpSync(sourceApp, app, { recursive: true });
    execFileSync('/usr/bin/plutil', ['-convert', 'xml1', '-o', plist, '-'], { input: JSON.stringify(entitlements) });
    execFileSync('/usr/bin/codesign', [
        '--force', '--sign', '-', '--options', runtime ? 'runtime' : '0',
        '--timestamp=none', '--entitlements', plist, app
    ], { stdio: 'pipe' });
    return app;
}

test('accepts the shipped app bundle', () => {
    const result = verify(sourceApp);
    assert.equal(result.status, 0, result.stderr + result.stdout);
});

test('accepts only App Sandbox with Hardened Runtime', t => {
    const app = signedCopy(t, { 'com.apple.security.app-sandbox': true });
    const result = verify(app);
    assert.equal(result.status, 0, result.stderr + result.stdout);
});

for (const [name, entitlements] of [
    ['missing sandbox', {}],
    ['disabled sandbox', { 'com.apple.security.app-sandbox': false }],
    ['outgoing network access', { 'com.apple.security.app-sandbox': true, 'com.apple.security.network.client': true }],
    ['incoming network access', { 'com.apple.security.app-sandbox': true, 'com.apple.security.network.server': true }],
    ['additional file access', { 'com.apple.security.app-sandbox': true, 'com.apple.security.files.user-selected.read-only': true }],
    ['debugging access', { 'com.apple.security.app-sandbox': true, 'com.apple.security.get-task-allow': true }],
    ['runtime exceptions', { 'com.apple.security.app-sandbox': true, 'com.apple.security.cs.disable-library-validation': true }],
    ['unnecessary false entitlements', { 'com.apple.security.app-sandbox': true, 'com.apple.security.network.client': false }]
]) {
    test('rejects ' + name, t => {
        const app = signedCopy(t, entitlements);
        const result = verify(app);
        assert.notEqual(result.status, 0, 'The bundle verifier accepted ' + name);
    });
}

test('rejects a sandboxed app without Hardened Runtime', t => {
    const app = signedCopy(t, { 'com.apple.security.app-sandbox': true }, false);
    const result = verify(app);
    assert.notEqual(result.status, 0, 'The bundle verifier accepted missing Hardened Runtime');
});
