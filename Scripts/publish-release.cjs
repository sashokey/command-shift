const { createHash } = require('node:crypto');

async function find(request) {
    try {
        return (await request()).data;
    } catch (error) {
        if (error.status === 404) return null;
        throw error;
    }
}

module.exports = async function publishRelease({ github, context, config, archive, appVersion }) {
    if (!config || typeof config.version !== 'string'
        || !/^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$/.test(config.version)
        || typeof config.draft !== 'boolean' || typeof config.prerelease !== 'boolean') {
        throw new Error('Release parameters must contain version X.Y.Z and boolean draft/prerelease flags');
    }
    if (appVersion !== config.version) throw new Error('App version does not match the requested release');
    if (!Buffer.isBuffer(archive) || archive.length === 0) throw new Error('App archive is empty or missing');
    const tag = 'v' + config.version;
    const ref = await find(() => github.rest.git.getRef({ ...context.repo, ref: 'tags/' + tag }));
    if (ref && (ref.object.type !== 'commit' || ref.object.sha !== context.sha)) {
        throw new Error('The release tag already points to another commit');
    }
    let release = await find(() => github.rest.repos.getReleaseByTag({ ...context.repo, tag }));
    if (release && (!release.draft || release.target_commitish !== context.sha || release.prerelease !== config.prerelease)) {
        throw new Error('This version already belongs to another release; use a new version');
    }
    const name = `CommandShift-${tag}-macos-arm64.zip`;
    const checksum = createHash('sha256').update(archive).digest('hex');
    const files = [
        { name, data: archive, type: 'application/zip' },
        { name: 'SHA256SUMS.txt', data: Buffer.from(`${checksum}  ${name}\n`), type: 'text/plain' }
    ];
    if (!release) release = (await github.rest.repos.createRelease({
        ...context.repo, tag_name: tag, target_commitish: context.sha,
        name: 'CommandShift ' + config.version, draft: true, prerelease: config.prerelease,
        body: [
            'Native Swift input-source switching with the fixed Shift + Command shortcut.',
            'Apple silicon, macOS 13 or later. Ad-hoc signed with Hardened Runtime; not notarized.',
            'Requires Input Monitoring only. No network code or third-party runtime dependencies.',
            'The ProperWM-style menu includes Open at Login, Hide Status Bar Icon, and Quit. Reopen the running app from Applications to restore its icon.',
            'Automated tests, app-bundle checks, and code-signature verification passed in CI. Manual permission, cross-application switching, and login-launch checks remain documented in README.md.',
            `Source commit: ${context.sha}. The app archive and SHA-256 checksum are attached.`
        ].join('\n\n')
    })).data;
    for (const file of files) {
        const expectedDigest = 'sha256:' + createHash('sha256').update(file.data).digest('hex');
        const existing = release.assets.find(asset => asset.name === file.name);
        const asset = existing ?? (await github.rest.repos.uploadReleaseAsset({
            ...context.repo, release_id: release.id, name: file.name,
            headers: { 'content-type': file.type }, data: file.data
        })).data;
        if (asset.state !== 'uploaded' || asset.digest !== expectedDigest || asset.size !== file.data.length) {
            throw new Error('Could not verify uploaded asset: ' + file.name);
        }
    }
    if (config.draft) return release;
    return (await github.rest.repos.updateRelease({
        ...context.repo, release_id: release.id, draft: false,
        prerelease: config.prerelease, make_latest: config.prerelease ? 'false' : 'true'
    })).data;
};
