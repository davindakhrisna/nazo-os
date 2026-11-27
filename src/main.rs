#![no_std]
#![no_main]

use core::panic::PanicInfo;
use core::time::Duration;
use uefi::prelude::*;
use uefi::proto::console::text::{Color, Key};

#[entry]
fn main() -> Status {
    uefi::helpers::init().unwrap();
    init_console();
    uefi::println!("Hello from nazo-os!");
    uefi::println!("UEFI bootloader berhasil dijalankan.");



    let mut buf = [0u8;64];

    uefi::print!("nazo> ");

    let len = read_line(&mut buf);

    if let Ok(input) = core::str::from_utf8(&buf[..len]) {
        uefi::println!("Kamu mengetik: {}", input);
    }

    // Tahan 5 detik agar pesan terbaca sebelum selesai.
    boot::stall(Duration::from_secs(5));
    Status::SUCCESS
}

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
fn read_key() -> Key {
    uefi::system::with_stdin(|stdin| loop {
        if let Ok(Some(key)) = stdin.read_key() {
            return key;
        }

        if let Ok(event) = stdin.wait_for_key_event() {
            let _ = boot::wait_for_event(&mut [event]);
        }
    })
}

fn read_line(buf: &mut [u8])-> usize{
    let mut len= 0;

    loop {
        if let Key::Printable(ch) = read_key(){
            match char::from(ch){
                '\r'|'\n' =>{
                    uefi::println!();
                    return len;
                }
                '\x08'=>{
                if len > 0 {
                   len -= 1;

                   uefi::print!("\x08 \x08");
                }
            }

            c if c.is_ascii_graphic() || c == ' ' =>{
                if  len < buf.len() {
                    buf[len] = c as u8;
                    len += 1;

                    uefi::print!("{}",c);
                }
            } 

            _ => {}
            }

            
        }
    }
}
#[panic_handler]
fn panic(_info: &PanicInfo) -> ! {
    loop {}
}
