// main.rs
// Ejemplo mínimo: Rust llamando a slot_is_justifiable_after verificada en Lean 4.
//
// La firma pública es idéntica a la función original de ethlambda.
// El caller no sabe ni le importa que adentro hay Lean.

mod ffi;

/// Wrapper con la misma firma que ethlambda usa hoy en Rust puro.
/// Drop-in replacement — podés copiar esto a state_transition/src/lib.rs
/// y nada más cambia.
pub fn slot_is_justifiable_after(slot: u64, finalized_slot: u64) -> bool {
    ffi::slot_is_justifiable_after(slot, finalized_slot)
}

fn main() {
    println!("=== slot_is_justifiable_after — implementación Lean 4 vía FFI ===\n");

    let casos = vec![
        // (slot, finalized, esperado, descripción)
        (10,  5,  true,  "delta=5  → regla 1 (≤5)"),
        (11,  5,  true,  "delta=6  → prónico (2×3)"),
        (14,  5,  true,  "delta=9  → cuadrado perfecto (3²)"),
        (17,  5,  true,  "delta=12 → prónico (3×4)"),
        (13,  5,  false, "delta=8  → ninguna regla"),
        (18,  5,  false, "delta=13 → ninguna regla"),
        (5,   5,  true,  "delta=0  → regla 1"),
        (4,   5,  false, "slot < finalized → false"),
        (100, 0,  true,  "delta=100=10² → cuadrado perfecto"),
        (110, 0,  true,  "delta=110 → prónico (10×11)"),
        (111, 0,  false, "delta=111 → ninguna regla"),
    ];

    let mut ok = 0;
    let mut fail = 0;

    for (slot, finalized, esperado, desc) in &casos {
        let resultado = slot_is_justifiable_after(*slot, *finalized);
        let pass = resultado == *esperado;
        let icono = if pass { "✅" } else { "❌" };
        println!("{} slot={:3} finalized={:3} → {:5}  (esperado {:5})  {}",
            icono, slot, finalized, resultado, esperado, desc);
        if pass { ok += 1; } else { fail += 1; }
    }

    println!("\n{}/{} tests pasaron", ok, ok + fail);

    if fail > 0 {
        std::process::exit(1);
    }
}

// Tests de Rust que también pueden correr con `cargo test`
#[cfg(test)]
mod tests {
    use super::slot_is_justifiable_after;

    #[test]
    fn regla1_primeros_cinco_slots() {
        for delta in 0u64..=5 {
            assert!(slot_is_justifiable_after(100 + delta, 100),
                "delta={delta} debería ser justificable");
        }
    }

    #[test]
    fn cuadrados_perfectos() {
        for k in 1u64..=20 {
            let delta = k * k;
            assert!(slot_is_justifiable_after(1000 + delta, 1000),
                "delta={delta} ({}²) debería ser justificable", k);
        }
    }

    #[test]
    fn pronicos() {
        for k in 1u64..=20 {
            let delta = k * (k + 1);
            assert!(slot_is_justifiable_after(1000 + delta, 1000),
                "delta={delta} ({}×{}) debería ser justificable", k, k+1);
        }
    }

    #[test]
    fn slot_anterior_a_finalized_es_false() {
        assert!(!slot_is_justifiable_after(4, 5));
        assert!(!slot_is_justifiable_after(0, 100));
    }

    #[test]
    fn no_justificables_conocidos() {
        // delta = 7, 8, 10, 11, 13, 14, 15 — no son ≤5, ni cuadrado, ni prónico
        for delta in [7u64, 8, 10, 11, 13, 14, 15, 17, 18, 19] {
            assert!(!slot_is_justifiable_after(1000 + delta, 1000),
                "delta={delta} NO debería ser justificable");
        }
    }
}
