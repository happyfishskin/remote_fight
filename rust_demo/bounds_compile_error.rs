// bounds_compile_error.rs
// Compile-time memory safety: a CONSTANT out-of-bounds index into a fixed
// 64-byte array. rustc refuses to compile this (the `unconditional_panic`
// lint is deny-by-default) and produces NO binary.
//
// This is the "red compile error" counterpart to C's silent strcpy overflow.

fn main() {
    let buffer = [0u8; 64];   // fixed 64-byte buffer, like the C demo
    let x = buffer[200];      // index 200 into length 64  -> COMPILE ERROR
    println!("{}", x);
}
