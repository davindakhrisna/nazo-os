#!/usr/bin/env bash
set -euo pipefail

EFI_BIN="${1:?Path ke binary .efi tidak diberikan}"
ESP_DIR="esp/EFI/BOOT"

if [ -z "${OVMF_CODE:-}" ]; then
	qemu_bin="$(command -v qemu-system-x86_64)"
	qemu_share="$(dirname "$qemu_bin")/../share/qemu/edk2-x86_64-code.fd"
	for candidate in \
		"$qemu_share" \
		"/opt/homebrew/share/qemu/edk2-x86_64-code.fd" \
		"/usr/share/OVMF/OVMF_CODE.fd" \
		"/usr/share/edk2/x64/OVMF_CODE.4m.fd" \
		"/usr/share/qemu/edk2-x86_64-code.fd"; do
		if [ -r "$candidate" ]; then
			OVMF_CODE="$candidate"
			break
		fi
	done
fi

if [ -z "${OVMF_CODE:-}" ] || [ ! -r "$OVMF_CODE" ]; then
	echo "Error: OVMF firmware not found. Set OVMF_CODE to your OVMF_CODE.fd / edk2-x86_64-code.fd path." >&2
	exit 1
fi

mkdir -p "$ESP_DIR"
cp "$EFI_BIN" "$ESP_DIR/BOOTX64.EFI"

if [ -n "${QEMU_ARGS:-}" ]; then
	read -r -a qemu_args <<<"$QEMU_ARGS"
else
	qemu_args=(-serial stdio)
fi

exec qemu-system-x86_64 \
	-drive "if=pflash,format=raw,readonly=on,file=$OVMF_CODE" \
	-drive "format=raw,file=fat:rw:esp" \
	"${qemu_args[@]}"
