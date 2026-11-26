# nazo-os

Proyek OS eksperimental berbasis Rust (`#![no_std]`) untuk arsitektur `x86_64` menggunakan UEFI (`x86_64-unknown-uefi`) dan QEMU.

## Prasyarat

### macOS (Apple Silicon / Intel)

1. Pasang `rustup` dan `qemu` via Homebrew:
   ```zsh
   brew install rustup qemu
   ```
2. Inisialisasi Rust toolchain dan tambahkan target UEFI `x86_64`:
   ```zsh
   $(brew --prefix rustup)/bin/rustup-init -y
   source "$HOME/.cargo/env"
   rustup target add x86_64-unknown-uefi
   ```

### Linux

1. Pasang `qemu-system-x86_64` dan firmware `ovmf` sesuai distro Anda:
   - **Ubuntu / Debian**:
     ```bash
     sudo apt install qemu-system-x86 ovmf
     ```
   - **Arch Linux**:
     ```bash
     sudo pacman -S qemu-system-x86 edk2-ovmf
     ```
2. Pastikan `rustup` terpasang, lalu tambahkan target UEFI `x86_64`:
   ```bash
   rustup target add x86_64-unknown-uefi
   ```
3. Sesuaikan variabel `OVMF_CODE` di [`scripts/run-qemu.sh`](scripts/run-qemu.sh) dengan lokasi file `OVMF_CODE.fd` di distro Anda (misalnya `/usr/share/OVMF/OVMF_CODE.fd` atau `/usr/share/edk2/x64/OVMF_CODE.4m.fd`).

> [!NOTE]
> Jika menggunakan Homebrew `rustup` di macOS dan `cargo` belum ada di `PATH` shell Anda, tambahkan `/opt/homebrew/opt/rustup/bin` ke `PATH`.

## Menjalankan Proyek

- **Build saja:**
  ```zsh
  cargo build
  ```

- **Build dan jalankan di QEMU (dengan jendela GUI):**
  ```zsh
  cargo run
  ```

- **Build dan jalankan di QEMU langsung di terminal (headless):**
  ```zsh
  QEMU_ARGS="-nographic" cargo run
  ```
  *(Untuk keluar dari QEMU mode `-nographic`, tekan `Ctrl+A` lalu `X`.)*

## Struktur Proyek

```text
.
├── .cargo/config.toml     # Target default (x86_64-unknown-uefi) & QEMU runner
├── Cargo.toml             # Konfigurasi paket & dependensi (uefi)
├── flake.nix              # Konfigurasi environment Nix Flake
├── scripts/run-qemu.sh    # Script untuk menyiapkan ESP & menjalankan QEMU
└── src/main.rs            # Entry point UEFI (#![no_std], #![no_main])
```
