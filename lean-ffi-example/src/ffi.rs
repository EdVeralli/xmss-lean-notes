// ffi.rs
// Binding FFI a la función Lean compilada a C.
// Este es el único lugar donde existe `unsafe` en todo el crate.

use std::sync::Once;

// Lean runtime necesita inicialización antes del primer uso
extern "C" {
    fn lean_initialize_runtime_module();
    fn lean_initialize();

    // La función verificada en Lean
    // Firma C: uint8_t lean_slot_is_justifiable_after(uint64_t slot, uint64_t finalized_slot)
    fn lean_slot_is_justifiable_after(slot: u64, finalized_slot: u64) -> u8;
}

static LEAN_INIT: Once = Once::new();

fn init_lean() {
    LEAN_INIT.call_once(|| {
        unsafe {
            lean_initialize_runtime_module();
            lean_initialize();
        }
    });
}

/// Wrapper público y seguro — sin unsafe para el llamador.
///
/// Internamente llama a la implementación verificada en Lean 4.
/// La función fue probada matemáticamente para todos los valores posibles de u64.
pub fn slot_is_justifiable_after(slot: u64, finalized_slot: u64) -> bool {
    init_lean();
    unsafe { lean_slot_is_justifiable_after(slot, finalized_slot) != 0 }
}
