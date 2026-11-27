# Panduan Membuat Terminal Halaman Penuh di `nazo-os` (UEFI)

## Apakah Bisa Tanpa Tampilan/Stuck di TianoCore?

**Bisa!** Ada dua alasan kenapa sebelumnya terasa masih menempel atau kembali ke TianoCore:

1. **Sisa teks TianoCore masih di layar:** Saat QEMU menyala, firmware OVMF (TianoCore) mencetak logo dan status boot terlebih dahulu sebelum menjalankan `BOOTX64.EFI` milikmu. Solusinya: langsung panggil `out.clear()` di awal `main()`.
2. **Program selesai (`return Status::SUCCESS`):** Begitu `main()` selesai, UEFI mengembalikan kendali ke menu TianoCore / EFI Shell. Solusinya: gunakan `loop { ... }` agar terminal terus berjalan, dan gunakan `uefi::runtime::reset(...)` untuk perintah `shutdown` atau `reboot` sehingga tidak pernah kembali ke TianoCore.

> **Catatan:** Logo TianoCore tetap akan muncul sekilas (~1 detik) saat QEMU pertama kali menyalakan firmware UEFI, lalu otomatis masuk ke halaman terminal `nazo-os` secara penuh.

---

## Langkah 1: Inisialisasi Layar Penuh & Bersihkan TianoCore

Di awal `main()`, tepat setelah `uefi::helpers::init().unwrap();`, atur console `stdout` agar:
1. Memilih mode teks terbesar yang didukung layar (bukan `80x25` yang sempit).
2. Mengatur warna background (misalnya `Color::Black`).
3. Membersihkan seluruh sisa tampilan TianoCore dengan `clear()`.
4. Mengaktifkan kursor ketik.

Import yang dibutuhkan:
```rust
use uefi::proto::console::text::Color;
```

Konsep fungsi `init_console()`:
```rust
fn init_console() {
    uefi::system::with_stdout(|out| {
        if let Some(best_mode) = out.modes().max_by_key(|m| m.columns() * m.rows()) {
            let _ = out.set_mode(best_mode);
        }
        let _ = out.set_color(Color::White, Color::Black);
        let _ = out.clear();
        let _ = out.enable_cursor(true);
    });
}
```

---

## Langkah 2: Buat Helper Warna Teks

Agar tampilan terminal rapi dan tidak monoton, buat helper kecil untuk mengganti warna teks tanpa menulis `with_stdout` berulang kali:

```rust
fn set_fg(color: Color) {
    uefi::system::with_stdout(|out| {
        let _ = out.set_color(color, Color::Black);
    });
}
```

Contoh pemakaian:
- `Color::LightCyan` → Judul / banner `nazo-os`
- `Color::LightGreen` → Prompt `nazo> `
- `Color::White` → Ketikan user dan output normal
- `Color::LightRed` → Pesan error

---

## Langkah 3: Baca Input Keyboard (`read_key` & `read_line`)

Di `#![no_std]`, kita memakai array statis `[u8; 64]` di stack (tanpa `String` atau `Vec`):

1. **`read_key()`**:
   - Gunakan `uefi::system::with_stdin(|stdin| loop { ... })`.
   - Coba `stdin.read_key()`. Jika `Ok(Some(key))`, kembalikan `key`.
   - Jika belum ada tombol ditekan, tunggu event dari `if let Ok(event) = stdin.wait_for_key_event()` dengan `let _ = boot::wait_for_event(&mut [event]);` agar CPU tidak 100%.
2. **`read_line(buf: &mut [u8]) -> usize`**:
   - Tangkap `Key::Printable(ch)` lalu ubah dengan `char::from(ch)`.
   - `'\r' | '\n'` → cetak baris baru (`uefi::println!()`), lalu `return len`.
   - `'\x08'` (Backspace) → jika `len > 0`, kurangi `len -= 1` dan cetak `"\x08 \x08"` untuk menghapus karakter di layar.
   - `c if c.is_ascii_graphic() || c == ' '` → simpan `c as u8` ke `buf[len]`, naikkan `len += 1`, dan cetak `c` ke layar.

---

## Langkah 4: Loop Terminal (REPL) & Parser Perintah

Di `main()`:
1. Panggil `init_console()`.
2. Cetak banner startup yang ringkas.
3. Jalankan `loop { ... }` tanpa `boot::stall(...)` dan tanpa keluar ke `Status::SUCCESS`.

Alur di dalam `loop`:
```rust
let mut buf = [0u8; 64];

loop {
    set_fg(Color::LightGreen);
    uefi::print!("nazo> ");
    set_fg(Color::White);

    let len = read_line(&mut buf);
    let Ok(raw) = core::str::from_utf8(&buf[..len]) else {
        continue;
    };

    let input = raw.trim();
    if input.is_empty() {
        continue;
    }

    let (cmd, arg) = input.split_once(' ').unwrap_or((input, ""));

    match cmd {
        "help" => { /* cetak daftar perintah */ }
        "clear" => { /* panggil init_console() atau out.clear() */ }
        "echo" => uefi::println!("{}", arg),
        "mem" => { /* tampilkan info RAM */ }
        "screen" => { /* tampilkan info layar GOP */ }
        "reboot" => uefi::runtime::reset(uefi::runtime::ResetType::COLD, Status::SUCCESS, None),
        "shutdown" => uefi::runtime::reset(uefi::runtime::ResetType::SHUTDOWN, Status::SUCCESS, None),
        _ => {
            set_fg(Color::LightRed);
            uefi::println!("Perintah tidak dikenal: '{}' (ketik 'help')", cmd);
            set_fg(Color::White);
        }
    }
}
```

---

## Langkah 5: Implementasi Perintah `mem` & `screen`

### Perintah `mem` (Info RAM)
Import yang dibutuhkan:
```rust
use uefi::mem::memory_map::{MemoryMap, MemoryType};
```
Logika:
1. Ambil map: `let map = boot::memory_map(MemoryType::LOADER_DATA).unwrap();`
2. Loop `for desc in map.entries()`:
   - Hitung ukuran: `let bytes = desc.page_count * 4096;`
   - Jumlahkan `total_bytes += bytes;`
   - Jika `desc.ty == MemoryType::CONVENTIONAL`, jumlahkan `free_bytes += bytes;`
3. Cetak dalam MiB (`bytes / (1024 * 1024)`).

### Perintah `screen` (Info Layar GOP)
Import yang dibutuhkan:
```rust
use uefi::proto::console::gop::GraphicsOutput;
```
Logika:
1. Cari handle: `let handle = boot::get_handle_for_protocol::<GraphicsOutput>().unwrap();`
2. Buka protokol: `let mut gop = unsafe { boot::open_protocol_exclusive::<GraphicsOutput>(handle).unwrap() };`
3. Ambil resolusi dari `let info = gop.current_mode_info();` → `info.resolution()` mengembalikan `(width, height)`.
4. Ambil info framebuffer dari `let mut fb = gop.frame_buffer();` → `fb.as_mut_ptr()` dan `fb.size()`.

---

## Langkah 6: Uji Coba di QEMU

Jalankan salah satu perintah berikut dari root proyek:
- **Mode Jendela GUI:**
  ```zsh
  cargo run
  ```
- **Mode Terminal Langsung (headless):**
  ```zsh
  QEMU_ARGS="-nographic" cargo run
  ```
  *(Untuk keluar paksa dari QEMU mode `-nographic`, tekan `Ctrl+A` lalu `X` — atau cukup ketik `shutdown` di terminal `nazo-os` kamu!)*
