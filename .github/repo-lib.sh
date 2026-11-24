# Sourced by the build workflow and the justfile, so both speak one protocol for
# packages.txt and the published repo. Expects REPO=owner/name.

parse_line() { # $1=packages.txt line -> sets pkg, pkgenv, arch_override, pkgbuild_url
  local line=$1
  # optional trailing "VAR=VAL ..." goes into makepkg's environment for
  # that package -- the knob some build scripts need to stay unattended.
  # Split before the @arch suffix, which it follows
  pkgenv=""
  case "$line" in *' '*) pkgenv=${line#* }; line=${line%% *} ;; esac
  # optional "pkg@arch1,arch2" forces those build targets regardless of the
  # declared arch= (wrongly-any packages, or x86_64-only labels that build
  # fine elsewhere); paired with --ignorearch at makepkg time
  arch_override=""
  case "$line" in *@*) arch_override=${line#*@}; line=${line%@*} ;; esac
  # a git URL instead of a pkgbase builds a PKGBUILD kept outside the AUR;
  # pkg stays empty until the clone reads the pkgbase from its .SRCINFO
  pkgbuild_url="" pkg=$line
  case "$line" in *://*) pkgbuild_url=$line pkg="" ;; esac
}

# Takes the publish lock of arch $1 at commit $2. Waits forever when GitHub
# does not have that commit.
# Creating a ref is atomic, so at most one publisher per arch edits the db.
# ponytail: takeover treats our wait as lock age; wrong only if the publish
# queue is deeper than ~30 one-minute publishes, and a lost entry self-heals
# on the next scheduled run
lock_db() {
  local waited=0
  until gh api -X POST "repos/$REPO/git/refs" -f ref="refs/heads/locks/publish-$1" -f sha="$2" >/dev/null; do
    sleep 15
    waited=$((waited+15))
    if [ "$waited" -ge 1800 ]; then
      echo "::warning::taking over stale publish lock for $1"
      unlock_db "$1"
      waited=0
    fi
  done
}
unlock_db() { gh api -X DELETE "repos/$REPO/git/refs/heads/locks/publish-$1" >/dev/null 2>&1 || true; }

# Uploads the db in dir $2, and any further files given, to release $1.
# pacman fetches zxcaur.db and zxcaur.files, so the archives go up under both names.
publish_db() {
  local tag=$1 dir=$2; shift 2
  rm -f "$dir/zxcaur.db" "$dir/zxcaur.files"
  cp "$dir/zxcaur.db.tar.gz" "$dir/zxcaur.db"
  cp "$dir/zxcaur.files.tar.gz" "$dir/zxcaur.files"
  gh release upload "$tag" -R "$REPO" --clobber "$@" \
    "$dir/zxcaur.db" "$dir/zxcaur.db.tar.gz" "$dir/zxcaur.files" "$dir/zxcaur.files.tar.gz"
}
