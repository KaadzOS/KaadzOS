#!/bin/sh
# Functional checks for kaadzos-file-action without touching the host session.
# Fakes record every command call, XDG_CONFIG_HOME points at a throwaway
# directory, and a fake gvfsd-admin lets the admin-open success path run.
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
helper="$root/config/includes.chroot/usr/local/bin/kaadzos-file-action"
uca="$root/config/includes.chroot/etc/skel/.config/Thunar/uca.xml"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
bin="$tmp/bin"
home="$tmp/home"
config="$tmp/config"
log="$tmp/commands.log"
mkdir -p "$bin" "$home" "$config"

export HOME="$home"
export XDG_CONFIG_HOME="$config"
export PATH="$bin:$PATH"
export KAADZOS_TEST_LOG="$log"

write_logger() {
  name=$1
  cat > "$bin/$name" <<EOF
#!/bin/sh
{
  printf '%s' '$name'
  for arg in "\$@"; do printf ' [%s]' "\$arg"; done
  printf '\\n'
} >> "\$KAADZOS_TEST_LOG"
EOF
  chmod +x "$bin/$name"
}

for command in swaymsg notify-send foot thunar kaadzos-settings kaadzos-packages; do
  write_logger "$command"
done

cat > "$bin/wl-copy" <<'EOF'
#!/bin/sh
cat > "$KAADZOS_TEST_LOG.copy"
EOF
chmod +x "$bin/wl-copy"

cat > "$bin/gvfsd-admin" <<'EOF'
#!/bin/sh
exit 0
EOF
chmod +x "$bin/gvfsd-admin"
export KAADZOS_GVFSD_ADMIN="$bin/gvfsd-admin"

failed=0
fail() {
  echo "FAIL: $*" >&2
  failed=1
}

run() {
  : > "$log"
  rm -f "$log.copy"
  "$helper" "$@" >/dev/null 2>&1 || fail "kaadzos-file-action $* exited nonzero"
}

run_fail() {
  : > "$log"
  rm -f "$log.copy"
  if "$helper" "$@" >/dev/null 2>&1; then
    fail "kaadzos-file-action $* should have failed"
  fi
}

expect_log() {
  grep -Fq -- "$1" "$log" || {
    fail "expected command: $1"
    sed 's/^/  got: /' "$log" >&2
  }
}

sh -n "$helper" || fail "kaadzos-file-action does not parse as POSIX sh"
if grep -Eq '^[[:space:]]*eval[[:space:]]' "$helper"; then
  fail "kaadzos-file-action must not use eval"
fi

override="$config/sway/config.d/10-wallpaper.conf"

plain="$tmp/wall paper.png"
printf 'png' > "$plain"
run wallpaper "$plain"
expect_log "swaymsg [output * bg \"$plain\" fill]"
grep -Fq "output * bg \"$plain\" fill" "$override" \
  || fail "wallpaper override does not contain the plain path"

quoted="$tmp/quote\"name.png"
printf 'png' > "$quoted"
quoted_cmd=$(printf '%s' "$quoted" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')
run wallpaper "$quoted"
expect_log "swaymsg [output * bg \"$quoted_cmd\" fill]"
grep -Fq 'quote\"name.png' "$override" \
  || fail "wallpaper override does not escape the double quote"

unicode="$tmp/naïve.png"
printf 'png' > "$unicode"
run wallpaper "$unicode"
expect_log "swaymsg [output * bg \"$unicode\" fill]"
grep -Fq "$unicode" "$override" \
  || fail "wallpaper override does not preserve Unicode"

ln -s "$plain" "$tmp/link.png"
run wallpaper "$tmp/link.png"
expect_log "swaymsg [output * bg \"$tmp/link.png\" fill]"

bad=$(printf 'bad\nname.png')
printf 'png' > "$tmp/$bad"
: > "$log"
if "$helper" wallpaper "$tmp/$bad" >/dev/null 2>&1; then
  fail "a newline in the path must be rejected"
fi
if grep -Fq 'swaymsg' "$log"; then
  fail "a rejected newline path still reached swaymsg"
fi

printf 'png' > "$tmp/-rf"
: > "$log"
if (cd "$tmp" && "$helper" wallpaper -rf) >/dev/null 2>&1; then
  fail "a path beginning with '-' must be rejected"
fi
if grep -Fq 'swaymsg' "$log"; then
  fail "a rejected leading-dash path still reached swaymsg"
fi

dollar="$tmp/price\$5.png"
printf 'png' > "$dollar"
run_fail wallpaper "$dollar"
if grep -Fq 'swaymsg' "$log"; then
  fail "a path containing '\$' still reached swaymsg"
fi

tick="$tmp/back\`tick.png"
printf 'png' > "$tick"
run_fail wallpaper "$tick"
if grep -Fq 'swaymsg' "$log"; then
  fail "a path containing a backtick still reached swaymsg"
fi

mkdir "$tmp/dir"
run_fail wallpaper "$tmp/dir"
run_fail wallpaper "$tmp/missing.png"
run_fail wallpaper
run_fail nonsense "$plain"

copy_path="$tmp/copy me.txt"
printf 'text' > "$copy_path"
run copy-path "$copy_path"
expect_log "notify-send [-a] [KaadzOS] [Path copied] [$copy_path]"
[ -f "$log.copy" ] || fail "copy-path did not call wl-copy"
copied=$(cat "$log.copy" 2>/dev/null || true)
[ "$copied" = "$copy_path" ] \
  || fail "copy-path sent the wrong value to wl-copy"

unicopy="$tmp/naïve copy.txt"
printf 'text' > "$unicopy"
run copy-path "$unicopy"
copied=$(cat "$log.copy" 2>/dev/null || true)
[ "$copied" = "$unicopy" ] \
  || fail "copy-path did not preserve Unicode"

run_fail copy-path "$dollar"
if [ -f "$log.copy" ]; then
  fail "a rejected '\$' path still reached wl-copy"
fi

term_dir="$tmp/dir with space"
mkdir "$term_dir"
run open-terminal "$term_dir"
expect_log "foot [--working-directory=$term_dir]"
run open-terminal "$plain"
expect_log "foot [--working-directory=$tmp]"
run_fail open-terminal "$tmp/missing"

run admin-open "$term_dir"
expect_log "thunar [admin://$term_dir]"
run_fail admin-open "$plain"

hash_dir="$tmp/dir#hash"
mkdir "$hash_dir"
run_fail admin-open "$hash_dir"
if grep -Fq 'thunar' "$log"; then
  fail "a '#' path still reached Thunar"
fi

query_dir="$tmp/dir?query"
mkdir "$query_dir"
run_fail admin-open "$query_dir"
if grep -Fq 'thunar' "$log"; then
  fail "a '?' path still reached Thunar"
fi

percent_dir="$tmp/dir%percent"
mkdir "$percent_dir"
run_fail admin-open "$percent_dir"
if grep -Fq 'thunar' "$log"; then
  fail "a '%' path still reached Thunar"
fi

: > "$log"
if (cd "$tmp" && "$helper" admin-open "dir with space") >/dev/null 2>&1; then
  fail "a relative admin path must be rejected"
fi
if grep -Fq 'thunar' "$log"; then
  fail "a relative admin path still reached Thunar"
fi

: > "$log"
if KAADZOS_GVFSD_ADMIN="$tmp/missing-gvfsd-admin" \
   "$helper" admin-open "$term_dir" >/dev/null 2>&1; then
  fail "admin-open without gvfsd-admin should fail"
fi
if grep -Fq 'thunar' "$log"; then
  fail "admin-open without gvfsd-admin still reached Thunar"
fi

deb="$tmp/hello world.deb"
printf 'deb' > "$deb"
run install-package "$deb"
expect_log "kaadzos-packages [install-deb] [$deb]"
run_fail install-package "$plain"
run_fail install-package "$tmp/missing.deb"

: > "$log"
if (cd "$tmp" && "$helper" install-package "hello world.deb") >/dev/null 2>&1; then
  fail "a relative package path must be rejected"
fi
if grep -Fq 'kaadzos-packages' "$log"; then
  fail "a relative package path still reached kaadzos-packages"
fi

: > "$log"
if (cd "$tmp" && "$helper" install-package "-evil.deb") >/dev/null 2>&1; then
  fail "a package path beginning with '-' must be rejected"
fi
if grep -Fq 'kaadzos-packages' "$log"; then
  fail "a leading-dash package path still reached kaadzos-packages"
fi

run open-settings
expect_log "kaadzos-settings"
run_fail open-settings "$plain"
run_fail open-settings extra extra

[ -f "$uca" ] || fail "Thunar uca.xml is missing"
if [ -f "$uca" ]; then
  grep -Fq '<actions>' "$uca" || fail "uca.xml has no actions root"
  grep -Fq '</actions>' "$uca" || fail "uca.xml has no closing actions tag"
  for name in 'Open Terminal Here' 'Copy Path' 'Set as Wallpaper' \
              'Open as Administrator' 'Install Local Package' 'Open Settings'; do
    grep -Fq "<name>$name</name>" "$uca" \
      || fail "uca.xml is missing action: $name"
  done
  grep -Fq '<command>kaadzos-file-action open-terminal %f</command>' "$uca" \
    || fail "uca.xml terminal command is not wired to the helper"
  grep -Fq '<command>kaadzos-file-action copy-path %f</command>' "$uca" \
    || fail "uca.xml copy command is not wired to the helper"
  grep -Fq '<command>kaadzos-file-action wallpaper %f</command>' "$uca" \
    || fail "uca.xml wallpaper command is not wired to the helper"
  grep -Fq '<command>kaadzos-file-action admin-open %f</command>' "$uca" \
    || fail "uca.xml admin command is not wired to the helper"
  grep -Fq '<command>kaadzos-file-action install-package %f</command>' "$uca" \
    || fail "uca.xml package command is not wired to the helper"
  grep -Fq '<command>kaadzos-file-action open-settings</command>' "$uca" \
    || fail "uca.xml settings command is not wired to the helper"
  if grep -Fq '"%f"' "$uca" || grep -Fq "'%f'" "$uca"; then
    fail "uca.xml must leave field codes unquoted; Thunar quotes them"
  fi
  if grep -Eq 'eval|sh -c|bash -c' "$uca"; then
    fail "uca.xml must not wrap commands in a shell"
  fi
  duplicates=$(grep -o '<unique-id>[^<]*' "$uca" | sort | uniq -d)
  [ -z "$duplicates" ] || fail "uca.xml has duplicate unique-id values"
  grep -Fq '<patterns>*.deb</patterns>' "$uca" \
    || fail "uca.xml does not limit the package action to .deb files"
  grep -Fq '<directories/>' "$uca" \
    || fail "uca.xml does not limit directory actions"

  if command -v python3 >/dev/null 2>&1; then
    if ! python3 - "$uca" <<'PY'
import sys
import xml.etree.ElementTree as ET

root = ET.parse(sys.argv[1]).getroot()
assert root.tag == "actions", root.tag
actions = root.findall("action")
assert len(actions) == 6, len(actions)
ids = [action.findtext("unique-id") or "" for action in actions]
assert all(ids), ids
assert len(ids) == len(set(ids)), ids
for action in actions:
    command = action.findtext("command") or ""
    assert command.startswith("kaadzos-file-action "), command
PY
    then
      fail "Thunar uca.xml is not well-formed or has the wrong actions"
    fi
  fi
fi

[ "$failed" -eq 0 ] || exit 1
echo "file actions are valid"
