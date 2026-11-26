#![no_std]
#![no_main]

use core::panic::PanicInfo;
use core::time::Duration;
use uefi::prelude::*;

#[entry]
fn main() -> Status {
    uefi::helpers::init().unwrap();
    uefi::println!("Hello from nazo-os!");
    uefi::println!("UEFI bootloader berhasil dijalankan.");

    // Tahan 5 detik agar pesan terbaca sebelum selesai.
    boot::stall(Duration::from_secs(5));
    Status::SUCCESS
}

#[panic_handler]
fn panic(_info: &PanicInfo) -> ! {
    loop {}
}
