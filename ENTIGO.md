# Entigo fork

This is a fork of [argoproj-labs/mcp-for-argocd](https://github.com/argoproj-labs/mcp-for-argocd)
that publishes a patched image to Docker Hub as `entigolabs/mcp-for-argocd`.

## Branches

| Branch | Purpose |
| --- | --- |
| `main` | Mirror of upstream `main`. Never commit here; only fast-forward it from upstream. |
| `entigo` | What we build and release: `main` plus our fixes plus the fork-only files (`.github/workflows/entigo-image.yml`, this file). |
| topic branches (e.g. `fix-cves`) | One change each, branched from `main` and free of fork-only files, so the same branch can be opened as a pull request upstream. Merged into `entigo`. |

## Syncing with upstream

```sh
git remote add upstream https://github.com/argoproj-labs/mcp-for-argocd.git   # once
git fetch upstream
git checkout main && git merge --ff-only upstream/main && git push origin main
git checkout entigo && git merge main && git push origin entigo
```

Once upstream has merged or superseded a topic branch, the merge into `entigo`
resolves in favour of upstream and the topic branch can be deleted.

## Releasing an image

Tags are `v<upstream version>-entigo.<n>`. Pushing one builds the multi-arch
image, fails on fixable HIGH/CRITICAL vulnerabilities, and publishes
`entigolabs/mcp-for-argocd:<upstream version>-entigo.<n>`.

```sh
git checkout entigo && git pull
git tag v0.9.0-entigo.1 && git push origin v0.9.0-entigo.1
```

Do not create GitHub Releases in this fork: a published release triggers the
upstream `docker.yml` and `release.yml` workflows, which need credentials the
fork does not have.
