#!/bin/sh
# Post-install hook for the printing pack: start CUPS and mDNS discovery, and
# grant the invoking desktop user the lp/scanner groups. Group grants made by
# this hook are recorded so removing the pack only drops those memberships.
set -eu

action=${1:-add}
state_dir=${KAADZOS_STATE_DIR:-/var/lib/kaadzos}
state_file=$state_dir/printing-groups
user=${SUDO_USER:-${PKEXEC_UID:-}}

if [ "$user" = root ]; then
  user=
fi
if [ -n "${PKEXEC_UID:-}" ] && [ -z "${SUDO_USER:-}" ]; then
  user=$(getent passwd "$PKEXEC_UID" 2>/dev/null | cut -d: -f1 || true)
fi

enable_service() {
  if command -v systemctl >/dev/null 2>&1; then
    if ! systemctl enable --now "$1" >/dev/null 2>&1; then
      echo "kaadzos: could not enable $1; it may need a reboot" >&2
    fi
  fi
}

disable_service() {
  if command -v systemctl >/dev/null 2>&1; then
    systemctl disable --now "$1" >/dev/null 2>&1 || true
  fi
}

group_add() {
  [ -n "$user" ] || return 0
  command -v getent >/dev/null 2>&1 || return 0
  command -v gpasswd >/dev/null 2>&1 || return 0
  getent group "$1" >/dev/null 2>&1 || return 0
  id "$user" >/dev/null 2>&1 || return 0
  if id -nG "$user" 2>/dev/null | tr ' ' '\n' | grep -qx "$1"; then
    return 0
  fi
  if gpasswd -a "$user" "$1" >/dev/null 2>&1; then
    mkdir -p "$state_dir"
    printf '%s %s\n' "$user" "$1" >> "$state_file"
    sort -u "$state_file" -o "$state_file"
  else
    echo "kaadzos: could not add $user to the $1 group" >&2
  fi
}

group_remove() {
  [ -f "$state_file" ] || return 0
  while read -r old_user old_group; do
    [ -n "$old_user" ] && [ -n "$old_group" ] || continue
    if command -v gpasswd >/dev/null 2>&1; then
      gpasswd -d "$old_user" "$old_group" >/dev/null 2>&1 || true
    fi
  done < "$state_file"
  rm -f "$state_file"
}

case $action in
  add)
    enable_service cups.service
    enable_service cups-browsed.service
    enable_service avahi-daemon.service
    group_add lp
    group_add scanner
    ;;
  remove)
    group_remove
    disable_service cups-browsed.service
    disable_service cups.service
    disable_service avahi-daemon.service
    ;;
  *)
    echo "printing hook: unknown action '$action'" >&2
    exit 1
    ;;
esac
