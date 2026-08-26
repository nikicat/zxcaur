# zxcaur

Prebuilt AUR packages as a pacman repository, for x86_64 and aarch64.
GitHub Actions checks the AUR daily, rebuilds what changed, and publishes
packages plus the repo database as GitHub release assets. Made for AUR
packages with long build times, so each host runs `pacman -S` instead of
compiling.

## Use it

Append to `/etc/pacman.conf`:

    [zxcaur]
    SigLevel = Optional TrustAll
    Server = https://github.com/nikicat/zxcaur/releases/download/repo-$arch

Then `pacman -Syu`.

## Add a package

Add the AUR package base name to `packages.txt` and push. The workflow
builds anything listed that is missing or outdated in the published repo.

- VCS packages (`-git` & co.) are first-class: the daily check runs their
  `pkgver()` against live upstream sources and compares with `vercmp`, so a
  new upstream commit triggers a rebuild without any AUR-side bump.
- Split packages: list the pkgbase; all split packages get published.
- `arch=any` packages are built once and published to both arches.
- AUR dependencies must be listed too. Build containers have this repo in
  their pacman.conf, so already-published packages resolve as dependencies.
  Adding a dependent and its AUR dep in one push makes the dependent's first
  build fail; it self-heals on the next run, once the dep is published.

## Rebuild on demand

    gh workflow run build -f package=<name>   # one package, forced
    gh workflow run build -f force=true       # everything, forced

## Notes

- Packages are unsigned (`SigLevel = Optional TrustAll`); the trust chain is
  the AUR PKGBUILD plus public GitHub Actions build logs.
- Removing a package from `packages.txt` stops updates but does not delete
  published files; clean its release assets and db entry (`repo-remove`)
  manually if it matters.
- aarch64 builds run natively on `ubuntu-24.04-arm` runners in an
  Arch Linux ARM container.
