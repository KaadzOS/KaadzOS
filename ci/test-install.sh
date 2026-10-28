#!/usr/bin/env bash
# Unattended-install test: install KaadzOS from the live ISO into a virtual
# disk with Calamares (driven by kaadzos-ci-install), then boot the installed
# disk and verify the same themed Sway session comes up with live-only state
# removed. Phases are separated on the serial console by markers.
#
#   phase 1 (install):    KAADZOS_INSTALLER_START -> KAADZOS_INSTALL_EXIT rc=0
#   phase 2 (installed):  KAADZOS_MODE installed  -> KAADZOS_DIAG_END (+ checks)
set -Eeuo pipefail

firmware=${1:?usage: test-install.sh <bios|uefi> <iso> <output-directory>}
iso=$(realpath "${2:?missing ISO path}")
output_dir=$(realpath -m "${3:?missing output directory}")

if [[ "$firmware" != "bios" && "$firmware" != "uefi" ]]; then
  echo "Unsupported firmware: $firmware" >&2
  exit 2
fi
if [[ ! -f "$iso" ]]; then
  echo "ISO not found: $iso" >&2
  exit 2
fi

mkdir -p "$output_dir"

disk="$output_dir/disk.qcow2"

install_serial="$output_dir/$firmware-install-serial.log"
install_qemu_log="$output_dir/$firmware-install-qemu.log"
install_monitor="$output_dir/$firmware-install-monitor.sock"
installed_serial="$output_dir/$firmware-installed-serial.log"
installed_qemu_log="$output_dir/$firmware-installed-qemu.log"
installed_monitor="$output_dir/$firmware-installed-monitor.sock"
calamares_tail="$output_dir/$firmware-calamares-tail.log"

install_window_ppm="$output_dir/$firmware-install-window.ppm"
install_window_png="$output_dir/$firmware-install-window.png"
install_exec_ppm="$output_dir/$firmware-install-exec.ppm"
install_exec_png="$output_dir/$firmware-install-exec.png"
installed_ppm="$output_dir/$firmware-installed.ppm"
installed_png="$output_dir/$firmware-installed.png"
failure_ppm="$output_dir/$firmware-failure.ppm"
failure_png="$output_dir/$firmware-failure.png"

qemu_pid=

acceleration=(-accel tcg,thread=multi -cpu max)
if [[ -c /dev/kvm && -r /dev/kvm && -w /dev/kvm ]]; then
  acceleration=(-accel kvm -cpu host)
fi

base_args=(
  -machine q35
  -smp 2
  "${acceleration[@]}"
  -device virtio-vga
  -display none
  -no-reboot
  # KAADZOS-CI-INSTALL selects the CI Calamares profile and the unattended
  # driver in the live session; in the installed system it only keeps the
  # QEMU-favoured pixman renderer path and is harmless.
  -smbios type=1,product=KAADZOS-CI-INSTALL
  -drive "file=$disk,if=virtio,format=qcow2"
)

if [[ "$firmware" == "uefi" ]]; then
  code=/usr/share/OVMF/OVMF_CODE_4M.fd
  vars=/usr/share/OVMF/OVMF_VARS_4M.fd

  if [[ ! -f "$code" || ! -f "$vars" ]]; then
    code=/usr/share/OVMF/OVMF_CODE.fd
    vars=/usr/share/OVMF/OVMF_VARS.fd
  fi

  if [[ ! -f "$code" || ! -f "$vars" ]]; then
    echo "OVMF firmware files were not found" >&2
    exit 1
  fi

  # One vars copy for both phases: the install boot writes the boot entry for
  # the installed disk, and the installed boot reuses it so OVMF does not try
  # to boot anything else.
  vars_copy="$output_dir/OVMF_VARS.fd"
  base_args+=(
    -drive "if=pflash,format=raw,readonly=on,file=$code"
    -drive "if=pflash,format=raw,file=$vars_copy"
  )
fi

screendump() { # <monitor> <ppm> <png>
  local monitor=$1 ppm=$2 png=$3
  if [[ -S "$monitor" && ! -f "$png" ]]; then
    printf 'screendump %s\n' "$ppm" | socat - "UNIX-CONNECT:$monitor" || true
    if [[ -s "$ppm" ]]; then
      pnmtopng "$ppm" > "$png" || true
    fi
  fi
}

dump_serial_tail() { # <file> [lines]
  local file=$1 lines=${2:-150}
  if [[ -s "$file" ]]; then
    echo "---- tail of $file ----" >&2
    tail -n "$lines" "$file" >&2 || true
    echo "---- end of tail ----" >&2
  fi
}

extract_calamares_tail() {
  if grep -q 'KAADZOS_CI_LOG_BEGIN' "$install_serial" 2>/dev/null; then
    sed -n '/KAADZOS_CI_LOG_BEGIN/,/KAADZOS_CI_LOG_END/p' "$install_serial" 2>/dev/null \
      | grep -v -e 'KAADZOS_CI_LOG_BEGIN' -e 'KAADZOS_CI_LOG_END' \
      > "$calamares_tail" || true
  fi
}

cleanup() {
  if [[ -n "$qemu_pid" ]] && kill -0 "$qemu_pid" 2>/dev/null; then
    screendump "$install_monitor" "$failure_ppm" "$failure_png"
    screendump "$installed_monitor" "$failure_ppm" "$failure_png"
    kill "$qemu_pid" 2>/dev/null || true
    wait "$qemu_pid" 2>/dev/null || true
  fi
  rm -f "$install_monitor" "$installed_monitor"
}
trap cleanup EXIT

echo "Runner disk space before the install:"
df -h "$output_dir" | sed -n '1,2p'

# ---------------------------------------------------------------------------
# Phase 1: boot the live ISO and let the unattended driver install to disk.
# ---------------------------------------------------------------------------

# Sparse on purpose: a preallocated 12 GiB file is unnecessary on the runner.
qemu-img create -f qcow2 "$disk" 12G

install_args=(
  "${base_args[@]}"
  -name "KaadzOS-install-$firmware"
  -m 4096
  -serial "file:$install_serial"
  -monitor "unix:$install_monitor,server=on,wait=off"
  -boot order=d,menu=on
  -drive "file=$iso,media=cdrom,readonly=on"
)

if [[ "$firmware" == "uefi" ]]; then
  cp "$vars" "$vars_copy"
fi

qemu-system-x86_64 "${install_args[@]}" >"$install_qemu_log" 2>&1 &
qemu_pid=$!

# Debian Live boot menus wait for input, so select their default live entry.
for _ in {1..3}; do
  sleep 5
  if [[ -S "$install_monitor" ]]; then
    printf 'sendkey ret\n' | socat - "UNIX-CONNECT:$install_monitor" >/dev/null
  fi
done

# The guest's own watchdog is 40 minutes; the extra slack covers the boot menu,
# the live boot and the driver's exit wait.
deadline=$((SECONDS + 3000))
driver_deadline=
while (( SECONDS < deadline )); do
  # Fail fast when the driver never started. The Sway autostart spawns it
  # within seconds of the session becoming ready, so a ready session without
  # the start marker means the driver died or was never launched; waiting out
  # the full deadline would only hide the error.
  if [[ -z "$driver_deadline" ]] \
    && grep -q 'KAADZOS_SWAY_READY' "$install_serial" 2>/dev/null; then
    driver_deadline=$((SECONDS + 300))
  fi
  if [[ -n "$driver_deadline" ]] && (( SECONDS >= driver_deadline )) \
    && ! grep -q 'KAADZOS_INSTALLER_START' "$install_serial" 2>/dev/null; then
    dump_serial_tail "$install_serial"
    echo "The live session is up but the unattended driver never started under $firmware" >&2
    exit 1
  fi

  # Progress screenshots, one attempt each. The window marker is anchored so
  # the WINDOW_TIMEOUT line does not match it.
  if [[ ! -f "$install_window_png" ]] \
    && tr -d '\r' < "$install_serial" | grep -qx 'KAADZOS_INSTALLER_WINDOW'; then
    sleep 8
    screendump "$install_monitor" "$install_window_ppm" "$install_window_png"
  fi
  if [[ ! -f "$install_exec_png" ]] \
    && grep -q 'KAADZOS_INSTALL_EXEC_BEGIN' "$install_serial" 2>/dev/null; then
    sleep 3
    screendump "$install_monitor" "$install_exec_ppm" "$install_exec_png"
  fi

  if grep -q 'KAADZOS_INSTALL_WATCHDOG' "$install_serial" 2>/dev/null; then
    extract_calamares_tail
    dump_serial_tail "$install_serial"
    echo "The unattended install hit its in-guest watchdog under $firmware" >&2
    exit 1
  fi

  if grep -q 'KAADZOS_INSTALLER_WINDOW_TIMEOUT' "$install_serial" 2>/dev/null; then
    extract_calamares_tail
    dump_serial_tail "$install_serial"
    echo "The Calamares window never appeared under $firmware" >&2
    exit 1
  fi

  if grep -q 'KAADZOS_INSTALL_EXIT rc=' "$install_serial" 2>/dev/null; then
    rc_line=$(grep 'KAADZOS_INSTALL_EXIT rc=' "$install_serial" | tail -1)
    rc=${rc_line##*rc=}
    rc=${rc%$'\r'}
    sleep 10 # let the driver finish its log tail before we cut it out
    extract_calamares_tail
    if [[ "$rc" != "0" ]]; then
      dump_serial_tail "$install_serial"
      echo "Calamares exited with rc=$rc under $firmware (see $calamares_tail)" >&2
      exit 1
    fi
    echo "Unattended install finished with rc=0 under $firmware"
    break
  fi

  if ! kill -0 "$qemu_pid" 2>/dev/null; then
    extract_calamares_tail
    dump_serial_tail "$install_serial"
    echo "QEMU exited before the install completed under $firmware" >&2
    exit 1
  fi

  sleep 5
done

if ! grep -q 'KAADZOS_INSTALL_EXIT rc=0' "$install_serial" 2>/dev/null; then
  extract_calamares_tail
  dump_serial_tail "$install_serial"
  echo "Timed out waiting for the unattended install under $firmware" >&2
  exit 1
fi

extract_calamares_tail

# The guest powers off; give it a bounded chance to exit, then drop it.
exit_deadline=$((SECONDS + 120))
while (( SECONDS < exit_deadline )); do
  kill -0 "$qemu_pid" 2>/dev/null || break
  sleep 2
done
if kill -0 "$qemu_pid" 2>/dev/null; then
  echo "Guest did not power off after the install; killing QEMU" >&2
  kill "$qemu_pid" 2>/dev/null || true
  wait "$qemu_pid" 2>/dev/null || true
fi
qemu_pid=
rm -f "$install_monitor"

if [[ ! -s "$install_window_png" ]]; then
  echo "Install ran but no Calamares window screenshot was captured under $firmware" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Phase 2: boot the installed disk and verify the cleaned-up system.
# ---------------------------------------------------------------------------

installed_args=(
  "${base_args[@]}"
  -name "KaadzOS-installed-$firmware"
  -m 2048
  -serial "file:$installed_serial"
  -monitor "unix:$installed_monitor,server=on,wait=off"
  -boot order=c
)

qemu-system-x86_64 "${installed_args[@]}" >"$installed_qemu_log" 2>&1 &
qemu_pid=$!

deadline=$((SECONDS + 600))
while (( SECONDS < deadline )); do
  # Hard failures: live-only state must be gone, the desktop must be clean.
  if grep -q 'KAADZOS_SWAY_CONFIG_WARNINGS' "$installed_serial" 2>/dev/null; then
    dump_serial_tail "$installed_serial"
    echo "The installed system reported Sway config warnings under $firmware" >&2
    exit 1
  fi
  if grep -q 'KAADZOS_FIRSTBOOT_PENDING' "$installed_serial" 2>/dev/null; then
    dump_serial_tail "$installed_serial"
    echo "First-boot cleanup did not complete on the installed system under $firmware" >&2
    exit 1
  fi
  if grep -q 'KAADZOS_LIVE_SUDOERS_PRESENT' "$installed_serial" 2>/dev/null; then
    dump_serial_tail "$installed_serial"
    echo "The installed system still has the live NOPASSWD sudoers under $firmware" >&2
    exit 1
  fi
  if grep -q 'KAADZOS_CALAMARES_PRESENT' "$installed_serial" 2>/dev/null; then
    dump_serial_tail "$installed_serial"
    echo "Calamares is still present on the installed system under $firmware" >&2
    exit 1
  fi

  # Success: the same readiness path as the live boot test, in installed mode.
  if grep -q 'KAADZOS_DIAG_END' "$installed_serial" 2>/dev/null \
    && grep -q 'KAADZOS_SWAY_READY' "$installed_serial" 2>/dev/null \
    && grep -q 'KAADZOS_MODE installed' "$installed_serial" 2>/dev/null \
    && grep -q 'KAADZOS_FIRSTBOOT_DONE' "$installed_serial" 2>/dev/null \
    && grep -q 'KAADZOS_LIVE_SUDOERS_ABSENT' "$installed_serial" 2>/dev/null \
    && grep -q 'KAADZOS_CALAMARES_ABSENT' "$installed_serial" 2>/dev/null; then
    sleep 8
    screendump "$installed_monitor" "$installed_ppm" "$installed_png"
    if [[ ! -s "$installed_png" ]]; then
      echo "Installed system reached Sway but no screenshot was captured under $firmware" >&2
      exit 1
    fi
    echo "KaadzOS reached a clean, running Sway session on the installed system under $firmware"
    exit 0
  fi

  if ! kill -0 "$qemu_pid" 2>/dev/null; then
    dump_serial_tail "$installed_serial"
    echo "QEMU exited before the installed system was ready under $firmware" >&2
    exit 1
  fi

  sleep 5
done

dump_serial_tail "$installed_serial"
echo "Timed out waiting for the installed system under $firmware" >&2
exit 1
