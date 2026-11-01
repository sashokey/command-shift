const assert = require('node:assert/strict');
const { createHash } = require('node:crypto');
const test = require('node:test');
const publishRelease = require('../Scripts/publish-release.cjs');

function fixture(overrides = {}) {
    const events = [];
    const release = {
        id: 42, tag_name: 'v1.0.0', target_commitish: 'a'.repeat(40),
        name: 'CommandShift 1.0.0', draft: true, prerelease: false,
        html_url: 'https://github.com/example/app/releases/tag/v1.0.0', assets: []
    };
    const missing = () => Promise.reject(Object.assign(new Error('Not found'), { status: 404 }));
    const github = {
        rest: {
            git: { getRef: missing },
            repos: {
                getReleaseByTag: missing,
                createRelease: async input => {
                    events.push({ type: 'create', ...input });
                    Object.assign(release, input);
                    return { data: release };
                },
                uploadReleaseAsset: async input => {
                    events.push({ type: 'upload', ...input });
                    const asset = {
                        id: release.assets.length + 1, name: input.name,
                        state: 'uploaded', content_type: input.headers['content-type'],
                        size: input.data.length,
                        digest: 'sha256:' + createHash('sha256').update(input.data).digest('hex')
                    };
                    release.assets.push(asset);
                    return { data: asset };
                },
                updateRelease: async input => {
                    events.push({ type: 'publish', ...input });
                    Object.assign(release, input);
                    return { data: release };
                },
                ...overrides
            }
        }
    };
    return {
        events, release, github,
        options: {
            github,
            context: { repo: { owner: 'example', repo: 'app' }, sha: 'a'.repeat(40) },
            config: { version: '1.0.0', draft: false, prerelease: false },
            archive: Buffer.from('abc'), appVersion: '1.0.0'
        }
    };
}

test('publishes a stable release only after both assets are uploaded', async () => {
    const state = fixture();
    const result = await publishRelease(state.options);
    assert.deepEqual(state.events.map(event => event.type), ['create', 'upload', 'upload', 'publish']);
    assert.equal(state.events[0].tag_name, 'v1.0.0');
    assert.equal(state.events[0].target_commitish, 'a'.repeat(40));
    assert.equal(state.events[0].draft, true);
    assert.equal(state.events[0].prerelease, false);
    assert.equal(state.events[1].name, 'CommandShift-v1.0.0-macos-arm64.zip');
    assert.deepEqual(state.events[1].data, Buffer.from('abc'));
    assert.equal(state.events[2].name, 'SHA256SUMS.txt');
    assert.equal(state.events[2].data.toString(), 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad  CommandShift-v1.0.0-macos-arm64.zip\n');
    assert.equal(state.events[3].make_latest, 'true');
    assert.equal(result.draft, false);
});

test('honors draft and prerelease flags without marking a prerelease as latest', async () => {
    for (const draft of [true, false]) {
        const state = fixture();
        state.options.config = { version: '1.0.0', draft, prerelease: true };
        const result = await publishRelease(state.options);
        assert.equal(result.draft, draft);
        assert.equal(result.prerelease, true);
        const publications = state.events.filter(event => event.type === 'publish');
        assert.equal(publications.length, draft ? 0 : 1);
        if (!draft) assert.equal(publications[0].make_latest, 'false');
    }
});

test('rejects invalid release parameters before changing GitHub', async () => {
    const invalid = [
        { config: { version: '../1.0.0', draft: false, prerelease: false } },
        { config: { version: '01.0.0', draft: false, prerelease: false } },
        { config: { version: '1.0.0', draft: 'false', prerelease: false } },
        { config: { version: '1.0.0', draft: false } },
        { appVersion: '0.9.0' },
        { archive: Buffer.alloc(0) }
    ];
    for (const change of invalid) {
        const state = fixture();
        await assert.rejects(publishRelease({ ...state.options, ...change }));
        assert.deepEqual(state.events, []);
    }
});

test('leaves the release in draft when an asset cannot be verified', async () => {
    for (const failure of ['upload', 'digest', 'state']) {
        const state = fixture();
        const upload = state.github.rest.repos.uploadReleaseAsset;
        state.github.rest.repos.uploadReleaseAsset = async input => {
            if (failure === 'upload') throw new Error('Upload failed');
            const response = await upload(input);
            if (failure === 'digest') response.data.digest = 'sha256:incorrect';
            if (failure === 'state') response.data.state = 'starter';
            return response;
        };
        await assert.rejects(publishRelease(state.options));
        assert.equal(state.release.draft, true);
        assert.equal(state.events.some(event => event.type === 'publish'), false);
    }
});

test('refuses an existing tag that points to another commit', async () => {
    const state = fixture();
    state.github.rest.git.getRef = async () => ({ data: { object: { type: 'commit', sha: 'b'.repeat(40) } } });
    await assert.rejects(publishRelease(state.options));
    assert.deepEqual(state.events, []);
});

test('propagates GitHub lookup errors without creating a release', async () => {
    const state = fixture();
    state.github.rest.git.getRef = async () => { throw Object.assign(new Error('Forbidden'), { status: 403 }); };
    await assert.rejects(publishRelease(state.options), /Forbidden/);
    assert.deepEqual(state.events, []);
});

test('resumes a matching draft without replacing an already verified asset', async () => {
    const state = fixture();
    state.release.assets.push({
        id: 9, name: 'CommandShift-v1.0.0-macos-arm64.zip', state: 'uploaded',
        content_type: 'application/zip', size: 3,
        digest: 'sha256:ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad'
    });
    state.github.rest.repos.getReleaseByTag = async () => ({ data: state.release });
    const result = await publishRelease(state.options);
    assert.deepEqual(state.events.map(event => event.type), ['upload', 'publish']);
    assert.equal(state.events[0].name, 'SHA256SUMS.txt');
    assert.equal(result.draft, false);
});

test('refuses to overwrite a published release or a draft for another commit', async () => {
    for (const change of [{ draft: false }, { target_commitish: 'b'.repeat(40) }]) {
        const state = fixture();
        Object.assign(state.release, change);
        state.github.rest.repos.getReleaseByTag = async () => ({ data: state.release });
        await assert.rejects(publishRelease(state.options));
        assert.deepEqual(state.events, []);
    }
});
