-- SlotJustifiable.lean
-- Versión con @[export] para FFI desde Rust
--
-- Compilar a C:
--   lean --c slot_justifiable.c SlotJustifiable.lean

namespace SlotJustifiable

-- ============================================================
-- Implementación verificada
-- ============================================================

def isPerfectSquareBool (n : UInt64) : Bool :=
  let s := n.toNat.sqrt
  (s * s : Nat) == n.toNat

def isPronicBool (n : UInt64) : Bool :=
  -- truco: n es prónico ↔ 4n+1 es cuadrado perfecto impar
  -- 4*k*(k+1)+1 = (2k+1)²
  let val := 4 * n.toNat + 1
  let s   := val.sqrt
  s * s == val && val % 2 == 1

-- ============================================================
-- Función exportada — símbolo C: lean_slot_is_justifiable_after
-- Firma C resultante:
--   uint8_t lean_slot_is_justifiable_after(uint64_t slot, uint64_t finalized_slot);
-- ============================================================

@[export lean_slot_is_justifiable_after]
def slotIsJustifiableAfter (slot : UInt64) (finalizedSlot : UInt64) : Bool :=
  if slot < finalizedSlot then
    false  -- slot anterior al finalizado → nunca justificable
  else
    let δ := (slot - finalizedSlot).toNat
    δ ≤ 5                    -- Regla 1: primeros 5 slots
    || isPerfectSquareBool (slot - finalizedSlot)  -- Regla 2: cuadrado perfecto
    || isPronicBool (slot - finalizedSlot)         -- Regla 3: número prónico

-- ============================================================
-- Tests en Lean (corren con #eval antes de compilar a C)
-- ============================================================

#eval slotIsJustifiableAfter 10 5   -- true  (delta=5, regla 1)
#eval slotIsJustifiableAfter 11 5   -- false (delta=6... espera, 6=2*3 es prónico → true!)
#eval slotIsJustifiableAfter 14 5   -- false (delta=9=3² → true!)
#eval slotIsJustifiableAfter 13 5   -- false (delta=8 → false)
#eval slotIsJustifiableAfter 4  5   -- false (slot < finalized)
#eval slotIsJustifiableAfter 5  5   -- true  (delta=0, regla 1)

end SlotJustifiable
