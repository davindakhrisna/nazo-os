#!/usr/bin/env bash
set -euo pipefail

EFI_BIN="${1:?Path ke binary .efi tidak diberikan}"
ESP_DIR="esp/EFI/BOOT"
OVMF_CODE="/opt/homebrew/share/qemu/edk2-x86_64-code.fd"

mkdir -p "$ESP_DIR"
cp "$EFI_BIN" "$ESP_DIR/BOOTX64.EFI"

exec qemu-system-x86_64 \
  -drive "if=pflash,format=raw,readonly=on,file=$OVMF_CODE" \
  -drive "format=raw,file=fat:rw:esp" \
  ${QEMU_ARGS:--serial stdio}
