// build.rs
//
// Paso 1: Lean compila a C (hacerlo manualmente antes de `cargo build`):
//   lean --c lean/slot_justifiable.c lean/SlotJustifiable.lean
//
// Paso 2: este build.rs compila el .c a librería estática y la linkea.
//
// Requiere:
//   - lean instalado (https://lean-lang.org)
//   - LEAN_SYSROOT definido, o lean en el PATH

use std::env;
use std::path::PathBuf;
use std::process::Command;

fn main() {
    // ── Detectar sysroot de Lean ──────────────────────────────────────────
    let lean_sysroot = env::var("LEAN_SYSROOT").unwrap_or_else(|_| {
        // Intentar obtenerlo de `lean --print-prefix`
        let output = Command::new("lean")
            .arg("--print-prefix")
            .output()
            .expect("No se encontró `lean` en el PATH. Instalalo desde https://lean-lang.org");
        String::from_utf8(output.stdout)
            .expect("Output de lean --print-prefix no es UTF-8")
            .trim()
            .to_string()
    });

    let lean_include = PathBuf::from(&lean_sysroot).join("include");
    let lean_lib     = PathBuf::from(&lean_sysroot).join("lib").join("lean");

    // ── Compilar el .c generado por Lean ────────────────────────────────
    let c_file = "lean/slot_justifiable.c";

    // Verificar que el .c existe (hay que generarlo con `lean --c` primero)
    if !std::path::Path::new(c_file).exists() {
        panic!(
            "\n\nNo se encontró {}.\n\
             Generalo con:\n\
             \t lean --c lean/slot_justifiable.c lean/SlotJustifiable.lean\n",
            c_file
        );
    }

    cc::Build::new()
        .file(c_file)
        .include(&lean_include)
        .flag("-w")              // suprimir warnings del C generado por Lean
        .compile("slot_justifiable");

    // ── Linkear runtime de Lean ──────────────────────────────────────────
    println!("cargo:rustc-link-search=native={}", lean_lib.display());
    println!("cargo:rustc-link-lib=dylib=leanshared");

    // ── Regenerar si el .lean cambia ────────────────────────────────────
    println!("cargo:rerun-if-changed=lean/SlotJustifiable.lean");
    println!("cargo:rerun-if-changed=lean/slot_justifiable.c");
}
