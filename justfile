repo := "nikicat/zxcaur"

# Drops pkgbases from packages.txt and from the published repo of both arches
[positional-arguments]
remove +pkgbases:
    #!/usr/bin/env bash
    set -euo pipefail
    REPO={{repo}}; . .github/repo-lib.sh
    bases=("$@")
    # ponytail: a git-URL entry names no pkgbase until cloned; remove those by hand
    while IFS= read -r line || [ -n "$line" ]; do
      case "$line" in ''|'#'*) ;; *) parse_line "$line"; [[ " ${bases[*]} " != *" $pkg "* ]] || continue ;; esac
      printf '%s\n' "$line"
    done < packages.txt > packages.txt.new
    mv packages.txt.new packages.txt
    # a local HEAD may be unpushed
    sha=$(gh api repos/$REPO/commits/HEAD -q .sha)
    work=$(mktemp -d -p .) locked=
    trap '[ -z "$locked" ] || unlock_db "$locked"; rm -rf "$work"' EXIT
    for arch in x86_64 aarch64; do
      tag=repo-$arch
      lock_db "$arch" "$sha"; locked=$arch
      d=$work/$arch; mkdir -p "$d/db"
      gh release download "$tag" -R "$REPO" -D "$d" -p zxcaur.db.tar.gz -p zxcaur.files.tar.gz
      tar -xzf "$d/zxcaur.db.tar.gz" -C "$d/db"
      # pkgname + filename of every split package whose %BASE% is one of ours
      mapfile -t hits < <(for desc in "$d"/db/*/desc; do
        awk -v bases="${bases[*]}" '
          BEGIN { split(bases, a, " "); for (i in a) want[a[i]] }
          /^%/ { k=$0; next } NF { v[k]=$0 }
          END { if (v["%BASE%"] in want) print v["%NAME%"], v["%FILENAME%"] }' "$desc"
      done)
      if [ ${#hits[@]} -eq 0 ]; then
        echo "$arch: nothing to remove"
      else
        names=() files=()
        for h in "${hits[@]}"; do names+=("${h% *}"); files+=("${h#* }"); done
        (cd "$d" && repo-remove zxcaur.db.tar.gz "${names[@]}")
        publish_db "$tag" "$d"
        for f in "${files[@]}"; do
          gh release delete-asset "$tag" "$f" -R "$REPO" -y || echo "warning: $f stays on $tag, delete it by hand" >&2
        done
      fi
      unlock_db "$arch"; locked=
    done
    echo "done; commit packages.txt so CI doesn't rebuild them"
