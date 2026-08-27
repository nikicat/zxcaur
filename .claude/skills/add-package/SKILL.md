---
name: add-package
description: Vet and add AUR package(s) to this zxcaur pacman repo — check .SRCINFO, handle arch quirks and AUR-only deps, update packages.txt, push, watch the build. Use whenever asked to add a package to the repo.
---

# Add AUR package(s) to zxcaur

## 1. Vet each package first

```
curl -fsSL "https://aur.archlinux.org/cgit/aur.git/plain/.SRCINFO?h=<pkgbase>"
```
404 = no such pkgbase (find the right name before proceeding). Collect:
`arch =` lines, `depends`/`makedepends`, `pkgname` lines (split packages),
`source*` lines. For suspicious cases fetch the PKGBUILD too.

## 2. Decide the packages.txt entry

- Dep not in official repos (`pacman -Si <dep>` fails on a stock-repo host) →
  it's an AUR dep: list it in packages.txt as well. The dependent's first
  build fails until the dep publishes; re-dispatch afterwards.
- `arch=any` but `build()` compiles native code (cargo/go/cmake/cc) →
  mislabeled upstream: use `pkg@x86_64,aarch64` (per-arch native builds via
  `--ignorearch`). Worth an AUR comment to the maintainer.
- `arch=x86_64`-only but sources are arch-neutral (built from source, not
  `source_x86_64` prebuilt binaries) → `pkg@x86_64,aarch64` usually works;
  skip the annotation when sources are x86-only binaries.
- Genuinely `any` (scripts, jars, pure python), or both arches declared →
  bare name.
- VCS packages (`pkgver()` in PKGBUILD) → bare name; the daily check computes
  live pkgver, no AUR-side bump needed.

## 3. Ship

Append entries to packages.txt, show the diff, commit (`add <pkgs>`), push.
The user's request to add a package is the approval for that commit.

## 4. Watch and verify

```
rid=$(gh api "repos/OWNER/zxcaur/actions/runs?head_sha=$(git rev-parse HEAD)" -q '.workflow_runs[0].id')
gh run watch "$rid" --exit-status
gh release view repo-x86_64 --json assets -q '.assets[].name'   # and repo-aarch64
```
If the push spawned no run (GitHub occasionally drops events; daily cron
self-heals): `gh workflow run build` (add `-f package=<pkg>` to force one).

## Known failure modes

- "dependency not found" on first run → AUR dep published seconds later:
  `gh workflow run build -f package=<pkg>`.
- makepkg exit 4 inside `package_*()` on aarch64 → often a split with a
  per-split `arch = x86_64`; the check already tolerates its absence — do
  NOT annotate such packages with `@`.
- OOM at link or "relocation truncated to fit" → normally prevented by the
  global `!lto !debug` makepkg options; a package that still OOMs needs the
  workflow's TODO (`-flto=1`) or a bigger runner.
- Packages with `epoch=` get `:` in their filename; the build job renames
  `:` to `.` before upload (GitHub rejects colons) — nothing to do.
- AUR clone SSL EOF → runner-IP blocking; the archlinux/aur GitHub mirror
  fallback covers it, retries are pointless.
