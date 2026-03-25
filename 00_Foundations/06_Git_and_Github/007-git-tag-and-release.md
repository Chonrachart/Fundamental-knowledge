# Git Tags and Releases

- **Tags** are named pointers to specific commits — they mark important points in history like releases
- **Lightweight tags** are simple pointers; **annotated tags** are full Git objects with metadata (tagger, date, message, optional GPG signature)
- **GitHub Releases** build on tags to provide downloadable artifacts, release notes, and a user-facing changelog

# Architecture

```text
  Commit History                          Tag Types
  --------------                          ----------

  a1b2c3 <-- main (HEAD)                 Lightweight Tag        Annotated Tag
    |                                     ---------------        --------------
  d4e5f6 <-- v1.1.0 (tag)               ref: refs/tags/v1.0    ref: refs/tags/v1.1
    |                                       |                       |
  g7h8i9                                    v                       v
    |                                     commit d4e5f6           tag object {
  j0k1l2 <-- v1.0.0 (tag)                (just a pointer)          tagger: Jane
    |                                                               date: 2026-01-15
  m3n4o5                                                            message: "Release 1.1"
                                                                    commit: d4e5f6
                                                                  }

  GitHub Release
  ---------------
  +-----------------------------+
  | v1.1.0 - Production Ready  |
  |-----------------------------|
  | Release notes / changelog   |
  | Attached: app-v1.1.0.tar.gz|
  | Attached: checksums.txt     |
  | Based on tag: v1.1.0        |
  +-----------------------------+
```

# Mental Model

```text
TAGGING WORKFLOW:
  develop --> reach milestone --> tag the commit --> push tag --> create release

  1. Finish work, merge to main
  2. git tag -a v1.2.0 -m "Release 1.2.0: new auth module"
  3. git push origin v1.2.0
  4. gh release create v1.2.0 --title "v1.2.0" --generate-notes

SEMVER DECISION:
  Is it a breaking API change?  --> bump MAJOR  (1.x.x -> 2.0.0)
  Is it a new feature?          --> bump MINOR  (1.1.x -> 1.2.0)
  Is it a bug fix?              --> bump PATCH  (1.2.0 -> 1.2.1)
  Pre-release?                  --> append label (2.0.0-rc.1)
```

```bash
# Tag and release example
$ git log --oneline -3
a1b2c3d Add payment gateway integration
f4e5d6c Fix session timeout bug
b7a8c9d Update dependencies

$ git tag -a v2.1.0 -m "Release 2.1.0: payment gateway"
$ git push origin v2.1.0
$ gh release create v2.1.0 --title "v2.1.0" --generate-notes
```

# Core Building Blocks

### Lightweight tags

- `git tag v1.0` — create a lightweight tag at current HEAD
- `git tag v1.0 <commit-hash>` — tag a specific commit
- Stored as a simple ref in `.git/refs/tags/` pointing directly to a commit
- No metadata — no tagger name, no date, no message
- Use case: local/temporary bookmarks, not recommended for releases

Related notes: [004-git-remote-repository](./004-git-remote-repository.md)

### Annotated tags

- `git tag -a v1.0 -m "Release 1.0"` — create annotated tag with message
- `git tag -a v1.0 <commit-hash> -m "Late tag"` — annotate a past commit
- Stored as a full Git object — includes tagger identity, timestamp, message, and pointer to commit
- `git tag -s v1.0 -m "Signed release"` — GPG-sign the tag for verification
- **Always use annotated tags for releases** — they carry provenance information

Related notes: [004-git-remote-repository](./004-git-remote-repository.md)
- `gh release create v1.0 --prerelease` — mark as pre-release
- `gh release view v1.0` — view release details
- `gh release delete v1.0 --yes` — delete a release (does not delete the tag)

### Listing, inspecting, and deleting tags

- `git tag` — list all tags alphabetically
- `git tag -l "v1.*"` — filter tags by pattern
- `git tag -l --sort=-version:refname "v*"` — list tags sorted by version descending
- `git show v1.0` — show tag metadata + the tagged commit
- `git tag -d v1.0` — delete tag locally
- `git push origin --delete v1.0` — delete tag from remote
- `git fetch --tags` — fetch all tags from remote
- `git fetch --prune-tags` — sync local tags with remote (remove deleted ones)

Related notes: [004-git-remote-repository](./004-git-remote-repository.md)

### Pushing tags to remote

- Tags are **not** pushed by `git push` by default
- `git push origin v1.0` — push a single tag
- `git push origin --tags` — push all tags (lightweight + annotated)
- `git push origin --follow-tags` — push only annotated tags that are reachable from pushed commits
- Set default: `git config --global push.followTags true`

Related notes: [004-git-remote-repository](./004-git-remote-repository.md)

### Semantic Versioning (SemVer)

- Format: `MAJOR.MINOR.PATCH` (e.g., `2.1.3`)
- **MAJOR** — incompatible API changes (breaking changes)
- **MINOR** — new functionality, backward compatible
- **PATCH** — bug fixes, backward compatible
- Pre-release labels: `1.0.0-alpha`, `1.0.0-beta.2`, `1.0.0-rc.1`
- Build metadata: `1.0.0+build.123` (ignored in version precedence)
- Precedence: `1.0.0-alpha < 1.0.0-alpha.1 < 1.0.0-beta < 1.0.0-rc.1 < 1.0.0`
- Start at `0.1.0` for initial development; `1.0.0` defines the public API

Related notes: [005-git-pull-request](./005-git-pull-request.md)

### GitHub Releases
Related notes: [005-git-pull-request](./005-git-pull-request.md)
- Built on top of Git tags — every release references a tag
- Provide a UI for release notes, changelogs, and downloadable assets (binaries, archives)
- `gh release create v1.0 --title "v1.0" --notes "Release notes here"` — create release
- `gh release create v1.0 --generate-notes` — auto-generate notes from merged PRs
- `gh release create v1.0 ./build/app.tar.gz` — attach binary artifacts
- `gh release create v1.0 --draft` — create as draft (not visible publicly until published)
- `gh release list` — list all releases

---

# Troubleshooting Guide

```text
Tag not showing on remote?
  |
  +-> Did you push it? --> git push origin <tag-name>
  |
  +-> Pushed with git push (no --tags)? --> tags require explicit push

Wrong commit tagged?
  |
  +-> Delete + retag: git tag -d v1.0 --> git tag -a v1.0 <correct-hash> -m "msg"
  |
  +-> Already pushed? --> git push origin --delete v1.0 --> retag --> push again

Release without a tag?
  |
  +-> gh release create auto-creates a tag if it doesn't exist
  |
  +-> Want to control the tag? --> create tag first, then create release

Tag name conflicts?
  |
  +-> "fatal: tag 'v1.0' already exists" --> delete old tag first or use a different name
```
