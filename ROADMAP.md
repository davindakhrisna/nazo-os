# Roadmap Pengembangan `nazo-os`

Saat ini, kode di [`src/main.rs`](src/main.rs) masih berjalan sebagai **aplikasi UEFI** yang menumpang pada *UEFI Boot Services* (firmware masih mengendalikan layar, memori, dan interrupt). Untuk menjadikannya sebuah OS sungguhan, `nazo-os` perlu mengambil alih kontrol hardware dari UEFI secara bertahap.

---

## 1. Pilih Arsitektur Proyek

Ada dua pendekatan umum untuk membangun OS berbasis UEFI di Rust:

- **Opsi A — Single Binary (Disarankan untuk mulai cepat)**  
  Tetap di 1 crate (`x86_64-unknown-uefi`). Setelah mengambil data hardware dari UEFI lalu memanggil `exit_boot_services()`, kode langsung masuk ke fungsi `kernel_main()` di binary yang sama. Tidak perlu membuat ELF loader di awal.
- **Opsi B — Bootloader + Kernel Terpisah (Cargo Workspace)**  
  Pisahkan `bootloader` (`x86_64-unknown-uefi`) dan `kernel` (`x86_64-unknown-none`). Bootloader membaca file ELF kernel dari partisi ESP, mengatur *higher-half paging*, lalu melompat ke entry point kernel. Lebih rapi untuk jangka panjang, tetapi setup awalnya lebih panjang.

---

## 2. Tahapan Membangun `nazo-os`

### Tahap 1: Ambil Info Hardware dari UEFI (Sebelum Keluar dari UEFI)
Sebelum melepas kontrol firmware, kumpulkan data penting berikut:
1. **Graphics Output Protocol (GOP):** Mendapatkan alamat **Framebuffer**, resolusi layar, dan format piksel agar bisa menggambar teks/grafis sendiri nanti.
2. **Memory Map:** Daftar area RAM yang tersedia dan yang sudah terpakai.
3. **ACPI RSDP:** Alamat tabel ACPI (berguna untuk timer APIC, multicore, dan shutdown).

### Tahap 2: Keluar dari UEFI & Bikin Output Sendiri
1. Panggil `uefi::boot::exit_boot_services(...)`. Setelah titik ini, `uefi::println!` **tidak bisa dipakai lagi** — OS sekarang 100% mengendalikan CPU.
2. **Serial Port Driver (COM1 / `0x3F8`):** Karena [`scripts/run-qemu.sh`](scripts/run-qemu.sh) sudah memakai `-serial stdio`, log debug dan pesan `panic!` bisa langsung dikirim ke terminal host.
3. **Framebuffer Writer:** Menggambar piksel dan merender font bitmap (misal crate `noto-sans-mono-bitmap` atau font 8x8) ke layar QEMU sebagai pengganti `uefi::println!`.

### Tahap 3: Pondasi CPU `x86_64`
Agar CPU tidak langsung *triple fault* (reboot) saat terjadi error atau input:
1. **GDT & TSS** (*Global Descriptor Table* & *Task State Segment*).
2. **IDT & Interrupts** (*Interrupt Descriptor Table*): menangani *CPU exceptions* (Breakpoint, Page Fault, Double Fault) serta *hardware interrupts* (PIC/APIC, Timer, Keyboard).
   > Tip: Crate `x86_64` di [`Cargo.toml`](Cargo.toml) sangat membantu untuk tahap ini.

### Tahap 4: Manajemen Memori
1. **Physical Frame Allocator:** Mengelola halaman RAM 4KiB berdasarkan Memory Map dari UEFI.
2. **Paging / Virtual Memory:** Memetakan alamat virtual ke fisik (4-level page table `x86_64`).
3. **Heap Allocator:** Mengaktifkan crate `alloc` (misal dengan `linked_list_allocator`) agar di `#![no_std]` bisa memakai `Vec`, `String`, `Box`, `BTreeMap`, dll.

### Tahap 5: Fitur OS yang Terlihat & Interaktif
Setelah pondasi di atas siap, mulai bangun fitur OS:
- **Keyboard Driver + Shell Interaktif:** Bisa mengetik perintah seperti `help`, `clear`, `meminfo`, `panic`, `shutdown`.
- **Timer & Multitasking:** Menjalankan beberapa task secara bergantian (*cooperative* / *preemptive* dengan `async` atau *context switch*).
- **Storage & Filesystem:** Driver disk (`virtio-blk` di QEMU atau AHCI/NVMe) + membaca filesystem (FAT32 / ext2).
- **Userspace (Ring 3) & Syscalls:** Menjalankan program terpisah di luar kernel.

---

## 3. Langkah Awal yang Disarankan

Jika ingin langsung lanjut coding:
1. **Ambil Framebuffer (GOP) + keluar dari UEFI (`exit_boot_services`)**, lalu gambar layar warna/teks sendiri + output log ke serial QEMU, **atau**
2. **Buat menu/shell sederhana dulu di dalam UEFI** (baca keyboard + tampilkan info RAM/layar) sebelum masuk ke bare-metal kernel.
