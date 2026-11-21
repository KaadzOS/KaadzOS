#!/bin/sh
# Functional checks for kaadzos-packages. apt, pkexec, zenity, Synaptic and
# kaadzos are fakes first in PATH, so no package is installed and no polkit
# prompt is shown.
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
helper="$root/config/includes.chroot/usr/local/bin/kaadzos-packages"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
bin="$tmp/bin"
log="$tmp/commands.log"
mkdir -p "$bin"

export PATH="$bin:$PATH"
export KAADZOS_TEST_LOG="$log"
export KAADZOS_OS_RELEASE="$tmp/os-release"
export XDG_CACHE_HOME="$tmp/cache"

cat > "$tmp/os-release" <<'EOF'
PRETTY_NAME="KaadzOS 0.4 test"
EOF

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

for command in notify-send foot synaptic-pkexec synaptic; do
  write_logger "$command"
done

cat > "$bin/pkexec" <<'EOF'
#!/bin/sh
{
  printf 'pkexec'
  for arg in "$@"; do printf ' [%s]' "$arg"; done
  printf '\n'
} >> "$KAADZOS_TEST_LOG"
exec "$@"
EOF
chmod +x "$bin/pkexec"

cat > "$bin/apt-get" <<'EOF'
#!/bin/sh
{
  printf 'apt-get'
  for arg in "$@"; do printf ' [%s]' "$arg"; done
  printf '\n'
} >> "$KAADZOS_TEST_LOG"
case ${FAKE_APT_MODE:-ok} in
  lock)
    echo 'E: Could not get lock /var/lib/dpkg/lock-frontend. It is held by process 1234' >&2
    exit 100
    ;;
  offline)
    echo 'E: Temporary failure resolving deb.debian.org' >&2
    exit 100
    ;;
  fail)
    echo 'E: simulated apt failure' >&2
    exit 100
    ;;
esac
exit 0
EOF
chmod +x "$bin/apt-get"

cat > "$bin/zenity" <<'EOF'
#!/bin/sh
line=zenity
for arg in "$@"; do line="$line [$arg]"; done
printf '%s\n' "$line" >> "$KAADZOS_TEST_LOG"
if [ "${FAKE_ZENITY_CANCEL:-0}" = 1 ]; then
  exit 1
fi
for arg in "$@"; do
  case $arg in
    --list) printf '%s\n' "${FAKE_ZENITY_CHOICE:-}"; exit 0 ;;
    --question) exit "${FAKE_ZENITY_ANSWER:-0}" ;;
    --text-info) cat >> "$KAADZOS_TEST_LOG"; exit 0 ;;
    --info) exit 0 ;;
  esac
done
exit 0
EOF
chmod +x "$bin/zenity"

cat > "$bin/kaadzos" <<'EOF'
#!/bin/sh
line=kaadzos
for arg in "$@"; do line="$line [$arg]"; done
printf '%s\n' "$line" >> "$KAADZOS_TEST_LOG"
case ${1:-} in
  list) printf 'PACK         STATUS     DESCRIPTION\n'
        printf 'admin        available  Package tools\n' ;;
esac
EOF
chmod +x "$bin/kaadzos"

failed=0
fail() {
  echo "FAIL: $*" >&2
  failed=1
}

run() {
  : > "$log"
  if ! "$helper" "$@" >/dev/null 2>"$tmp/helper.err"; then
    fail "kaadzos-packages $* exited nonzero"
    sed 's/^/  err: /' "$tmp/helper.err" >&2
  fi
}

expect() {
  grep -Fq -- "$1" "$log" || {
    fail "expected command: $1"
    sed 's/^/  got: /' "$log" >&2
  }
}

dash -n "$helper" || fail "kaadzos-packages does not parse as POSIX sh"
if grep -Eq '^[[:space:]]*eval[[:space:]]' "$helper"; then
  fail "kaadzos-packages must not use eval"
fi

run refresh
expect 'pkexec [env] [DEBIAN_FRONTEND=noninteractive] [apt-get] [update]'
expect 'notify-send [-a] [KaadzOS] [Packages] [Package lists refreshed.]'

FAKE_APT_MODE=lock
export FAKE_APT_MODE
: > "$log"
if "$helper" refresh >/dev/null 2>"$tmp/helper.err"; then
  fail "a locked apt must be reported as a failure"
fi
grep -Fq 'Another package manager is running' "$tmp/helper.err" \
  || fail "a locked apt must explain the lock"

FAKE_APT_MODE=offline
export FAKE_APT_MODE
: > "$log"
if "$helper" refresh >/dev/null 2>"$tmp/helper.err"; then
  fail "an offline apt must be reported as a failure"
fi
grep -Fq 'package archive is unreachable' "$tmp/helper.err" \
  || fail "an offline apt must explain the network"
unset FAKE_APT_MODE

FAKE_ZENITY_ANSWER=1
export FAKE_ZENITY_ANSWER
run install hello
expect 'zenity [--question] [--title=Install hello]'
if grep -Fq 'apt-get [install]' "$log"; then
  fail "a cancelled install still reached apt-get"
fi

FAKE_ZENITY_ANSWER=0
export FAKE_ZENITY_ANSWER
run install hello
expect 'apt-get [install] [-y] [hello]'
expect 'notify-send [-a] [KaadzOS] [Packages] [Installed hello.]'

FAKE_ZENITY_ANSWER=1
export FAKE_ZENITY_ANSWER
run remove hello
if grep -Fq 'apt-get [remove]' "$log"; then
  fail "a cancelled remove still reached apt-get"
fi
expect 'zenity [--question] [--title=Remove hello]'

FAKE_ZENITY_ANSWER=0
export FAKE_ZENITY_ANSWER
run remove hello
expect 'apt-get [remove] [-y] [hello]'
expect 'notify-send [-a] [KaadzOS] [Packages] [Removed hello.]'

deb="$tmp/hello world.deb"
printf 'deb' > "$deb"
run install-deb "$deb"
expect 'zenity [--question] [--title=Install local package]'
expect "apt-get [install] [-y] [$deb]"
expect 'notify-send [-a] [KaadzOS] [Packages] [Installed hello world.deb.]'

FAKE_ZENITY_ANSWER=1
export FAKE_ZENITY_ANSWER
run install-deb "$deb"
expect 'zenity [--question] [--title=Install local package]'
if grep -Fq 'apt-get [install]' "$log"; then
  fail "a cancelled local package install still reached apt-get"
fi

FAKE_ZENITY_ANSWER=0
export FAKE_ZENITY_ANSWER

notdeb="$tmp/not-a-package.txt"
printf 'text' > "$notdeb"
: > "$log"
if "$helper" install-deb "$notdeb" >/dev/null 2>&1; then
  fail "a non-.deb path was accepted"
fi
if grep -Fq 'apt-get [install]' "$log"; then
  fail "a non-.deb path reached apt-get"
fi

: > "$log"
if (cd "$tmp" && "$helper" install-deb "hello world.deb") >/dev/null 2>&1; then
  fail "a relative package path was accepted"
fi
if grep -Fq 'apt-get [install]' "$log"; then
  fail "a relative package path reached apt-get"
fi

printf 'deb' > "$tmp/-evil.deb"
: > "$log"
if (cd "$tmp" && "$helper" install-deb "-evil.deb") >/dev/null 2>&1; then
  fail "a leading-dash package path was accepted"
fi
if grep -Fq 'apt-get [install]' "$log"; then
  fail "a leading-dash package path reached apt-get"
fi

bad=$(printf 'bad\nname.deb')
printf 'deb' > "$tmp/$bad"
: > "$log"
if "$helper" install-deb "$tmp/$bad" >/dev/null 2>&1; then
  fail "a newline in the package path was accepted"
fi
if grep -Fq 'apt-get [install]' "$log"; then
  fail "a newline package path reached apt-get"
fi

dollar="$tmp/price\$5.deb"
printf 'deb' > "$dollar"
: > "$log"
if "$helper" install-deb "$dollar" >/dev/null 2>&1; then
  fail "a '\$' package path was accepted"
fi
if grep -Fq 'apt-get [install]' "$log"; then
  fail "a '\$' package path reached apt-get"
fi

tick="$tmp/back\`tick.deb"
printf 'deb' > "$tick"
: > "$log"
if "$helper" install-deb "$tick" >/dev/null 2>&1; then
  fail "a backtick package path was accepted"
fi
if grep -Fq 'apt-get [install]' "$log"; then
  fail "a backtick package path reached apt-get"
fi

: > "$log"
if "$helper" install-deb "$tmp/missing.deb" >/dev/null 2>&1; then
  fail "a missing package was accepted"
fi
if grep -Fq 'apt-get [install]' "$log"; then
  fail "a missing package reached apt-get"
fi

for bad in '-rf' 'bad name' 'UPPER'; do
  : > "$log"
  if "$helper" install "$bad" >/dev/null 2>&1; then
    fail "invalid package name was accepted: $bad"
  fi
  if grep -Fq 'apt-get [install]' "$log"; then
    fail "invalid package name reached apt-get: $bad"
  fi
done

run packs
expect 'kaadzos [list]'
expect 'PACK         STATUS     DESCRIPTION'
expect 'admin        available  Package tools'

run archive
expect 'zenity [--info] [--no-markup] [--title=KaadzOS APT archive]'
grep -Fq 'https://iso.kaadzos.pages.dev/apt' "$log" \
  || fail "archive information is missing the public origin"

run about
expect 'zenity [--info] [--no-markup] [--title=About packages]'
grep -Fq 'KaadzOS 0.4 test' "$log" \
  || fail "About did not read the os-release fixture"

run synaptic
expect 'synaptic-pkexec'

rm -f "$bin/synaptic-pkexec" "$bin/synaptic"
FAKE_ZENITY_CHOICE='Install admin tools'
export FAKE_ZENITY_CHOICE
run menu
expect 'zenity [--list] [--title=KaadzOS Packages]'
expect 'foot [-T] [Install admin tools] [-e] [kaadzos] [add] [admin]'

FAKE_ZENITY_CANCEL=1
export FAKE_ZENITY_CANCEL
: > "$log"
"$helper" menu >/dev/null 2>&1 || fail "cancelled package menu exited nonzero"
if grep -Fq 'foot [' "$log"; then
  fail "a cancelled package menu still launched an action"
fi

cat > "$bin/sudo" <<'EOF'
#!/bin/sh
{
  printf 'sudo'
  for arg in "$@"; do printf ' [%s]' "$arg"; done
  printf '\n'
} >> "$KAADZOS_TEST_LOG"
while [ "${1:-}" = -n ] || [ "${1:-}" = -E ]; do shift; done
[ "${1:-}" = true ] && exit 0
exec "$@"
EOF
chmod +x "$bin/sudo"

mv "$bin/pkexec" "$bin/pkexec.disabled"
unset FAKE_ZENITY_CANCEL
FAKE_ZENITY_ANSWER=0
export FAKE_ZENITY_ANSWER
: > "$log"
run refresh
if ! grep -Fq 'sudo [-n] [-E]' "$log"; then
  fail "the sudo fallback was not used when pkexec is absent"
fi
expect 'apt-get [update]'

[ "$failed" -eq 0 ] || exit 1
echo "package actions are valid"
