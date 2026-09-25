#!/bin/bash
# Usage: clone-pkgbuild.sh <entry> <dir> -> clones into <dir>/<pkgbase>, prints pkgbase.
# <entry> is an AUR pkgbase, or a git URL of a PKGBUILD kept outside the AUR; a URL
# does not name the package, so its pkgbase comes from the repo's .SRCINFO.
set -euo pipefail
entry=$1 dir=$2

case "$entry" in
  *://*)
    rm -rf "$dir/.clone"
    git clone --depth=1 "$entry" "$dir/.clone" </dev/null >&2
    pkgbase=$(sed -n 's/^pkgbase = //p' "$dir/.clone/.SRCINFO" 2>/dev/null) || true
    [ -n "$pkgbase" ] || { echo "::error::$entry: no pkgbase in .SRCINFO" >&2; exit 1; }
    rm -rf "${dir:?}/$pkgbase" && mv "$dir/.clone" "$dir/$pkgbase"
    ;;
  *)
    pkgbase=$entry
    # aur.archlinux.org drops connections from cloud IPs at times; prefer the
    # official GitHub mirror (branch per package), fall back to the AUR itself
    git clone --depth=1 -b "$pkgbase" https://github.com/archlinux/aur.git "$dir/$pkgbase" </dev/null >&2 2>/dev/null \
      || git clone --depth=1 "https://aur.archlinux.org/$pkgbase.git" "$dir/$pkgbase" </dev/null >&2
    [ -f "$dir/$pkgbase/PKGBUILD" ] || { echo "::error::$pkgbase: no such package on AUR" >&2; exit 1; }
    ;;
esac
printf '%s\n' "$pkgbase"
