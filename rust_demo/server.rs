// server.rs — the Rust equivalent of the vulnerable C socket server.
//
// Same shape: listen on 8888, read a packet, copy it into a FIXED 64-byte
// buffer. But the naive "port" of strcpy(buffer, input) is bounds-checked by
// the language at runtime: an oversized packet triggers a SAFE PANIC
// (process aborts, exit 101) instead of silently smashing the stack.
//
// There is no `unsafe` block here, so memory corruption is impossible.

use std::io::Read;
use std::net::TcpListener;

fn handle_request(input: &[u8]) {
    let mut buffer = [0u8; 64];                 // fixed 64-byte buffer
    // Direct analog of strcpy(buffer, input): copy the input in.
    buffer[..input.len()].copy_from_slice(input); // BOUNDS-CHECKED by Rust
    println!("[rust] stored {} bytes safely", input.len());
    let _ = &buffer;
}

fn main() {
    let listener = TcpListener::bind("0.0.0.0:8888").expect("bind failed");
    println!("[rust] listening on port 8888 (buffer size = 64 bytes)");
    for stream in listener.incoming() {
        let mut s = match stream { Ok(s) => s, Err(_) => continue };
        let mut buf = [0u8; 4096];
        let n = s.read(&mut buf).unwrap_or(0);
        if n == 0 { continue; }
        println!("[rust] received {} bytes", n);
        handle_request(&buf[..n]);   // oversized -> safe panic, not corruption
    }
}
