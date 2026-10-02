#!/usr/bin/env bash
set -Eeuo pipefail

firmware=${1:?usage: test-boot.sh <bios|uefi> <iso> <output-directory>}
iso=$(realpath "${2:?missing ISO path}")
output_dir=$(realpath -m "${3:?missing output directory}")

if [[ "$firmware" != "bios" && "$firmware" != "uefi" ]]; then
  echo "Unsupported firmware: $firmware" >&2
  exit 2
fi

mkdir -p "$output_dir"
serial_log="$output_dir/$firmware-serial.log"
qemu_log="$output_dir/$firmware-qemu.log"
monitor="$output_dir/$firmware-monitor.sock"
screenshot_ppm="$output_dir/$firmware.ppm"
screenshot_png="$output_dir/$firmware.png"

acceleration=(-accel tcg,thread=multi -cpu max)
if [[ -c /dev/kvm && -r /dev/kvm && -w /dev/kvm ]]; then
  acceleration=(-accel kvm -cpu host)
fi

qemu_args=(
  -name "KaadzOS-$firmware"
  -machine q35
  -m 2048
  -smp 2
  "${acceleration[@]}"
  -device virtio-vga
  -display none
  -serial "file:$serial_log"
  -monitor "unix:$monitor,server=on,wait=off"
  -no-reboot
  -boot order=d,menu=on
  -drive "file=$iso,media=cdrom,readonly=on"
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

  vars_copy="$output_dir/OVMF_VARS.fd"
  cp "$vars" "$vars_copy"
  qemu_args+=(
    -drive "if=pflash,format=raw,readonly=on,file=$code"
    -drive "if=pflash,format=raw,file=$vars_copy"
  )
fi

qemu-system-x86_64 "${qemu_args[@]}" >"$qemu_log" 2>&1 &
qemu_pid=$!

capture_screenshot() {
  if [[ -S "$monitor" && ! -f "$screenshot_png" ]]; then
    printf 'screendump %s\n' "$screenshot_ppm" | socat - "UNIX-CONNECT:$monitor" || true
    if [[ -s "$screenshot_ppm" ]]; then
      pnmtopng "$screenshot_ppm" > "$screenshot_png" || true
    fi
  fi
}

cleanup() {
  capture_screenshot
  kill "$qemu_pid" 2>/dev/null || true
  wait "$qemu_pid" 2>/dev/null || true
}
trap cleanup EXIT

deadline=$((SECONDS + 480))
while (( SECONDS < deadline )); do
  if grep -q 'KAADZOS_SWAY_READY' "$serial_log" 2>/dev/null; then
    sleep 3
    capture_screenshot
    test -s "$screenshot_png"
    echo "KaadzOS reached a running Sway session under $firmware"
    exit 0
  fi

  if ! kill -0 "$qemu_pid" 2>/dev/null; then
    echo "QEMU exited before Sway became ready under $firmware" >&2
    exit 1
  fi

  sleep 5
done

echo "Timed out waiting for Sway under $firmware" >&2
exit 1
