-- IsValidVote.lean
-- Formalización en Lean 4 de la función is_valid_vote
-- del protocolo 3SF-mini (ethlambda / leanEthereum)
--
-- Referencia Rust:
--   ethlambda/crates/blockchain/state_transition/src/lib.rs (línea 344)
--   ethlambda/crates/blockchain/state_transition/src/justified_slots_ops.rs
--
-- Depende de: SlotJustifiable.lean (slot_is_justifiable_after)

import Mathlib.Data.Nat.Sqrt
import Mathlib.Tactic

namespace IsValidVote

/-!
## Tipos base

Espejo de los tipos Rust de ethlambda.
En Lean usamos estructuras simples — sin SSZ, sin serialización.
-/

/-- Raíz de un bloque (H256 en Rust — 32 bytes).
    Modelado como Nat para simplificar las pruebas. -/
abbrev Root := Nat

/-- Slot vacío / cero hash. En Rust es H256::ZERO. -/
def ROOT_ZERO : Root := 0

/-- Un checkpoint identifica un bloque por (slot, root). -/
structure Checkpoint where
  slot : Nat
  root : Root
  deriving Repr, DecidableEq

/-- El estado relevante para is_valid_vote.
    Solo incluimos los campos que la función necesita. -/
structure ConsensusState where
  /-- Bitlist relativo: índice 0 = finalized_slot + 1 -/
  justifiedSlots    : Array Bool
  /-- Último slot finalizado -/
  latestFinalizedSlot : Nat
  /-- Tabla histórica de bloques: slot → root -/
  historicalBlockHashes : Array Root
  deriving Repr

/-!
## justified_slots_ops — espejo exacto del Rust
-/

/-- Calcula el índice relativo de un slot respecto al boundary finalizado.
    Rust: target.checked_sub(finalized)?.checked_sub(1)
    Retorna none si slot ≤ finalized_slot (implícitamente justificado). -/
def relativeIndex (targetSlot : Nat) (finalizedSlot : Nat) : Option Nat :=
  if targetSlot ≤ finalizedSlot then none
  else some (targetSlot - finalizedSlot - 1)

/-- Un slot está justificado si:
    - está en el bitlist y marcado true, O
    - es ≤ finalized_slot (implícitamente justificado). -/
def isSlotJustified (slots : Array Bool) (finalizedSlot : Nat) (targetSlot : Nat) : Bool :=
  match relativeIndex targetSlot finalizedSlot with
  | none     => true   -- slot ≤ finalized → implícitamente justificado
  | some idx => slots.getD idx false

/-- Un checkpoint existe en la cadena si su root coincide con
    el hash histórico en ese slot. -/
def checkpointExists (state : ConsensusState) (cp : Checkpoint) : Bool :=
  state.historicalBlockHashes.getD cp.slot 0 == cp.root

/-!
## is_valid_vote — espejo exacto del Rust

Las 6 condiciones que deben cumplirse para que un voto sea válido.
-/

/-- Condición 1: el source ya está justificado. -/
def cond1_sourceJustified (state : ConsensusState) (source : Checkpoint) : Bool :=
  isSlotJustified state.justifiedSlots state.latestFinalizedSlot source.slot

/-- Condición 2: el target NO está aún justificado. -/
def cond2_targetNotYetJustified (state : ConsensusState) (target : Checkpoint) : Bool :=
  !isSlotJustified state.justifiedSlots state.latestFinalizedSlot target.slot

/-- Condición 3: ningún root es zero hash. -/
def cond3_noZeroRoots (source target : Checkpoint) : Bool :=
  source.root != ROOT_ZERO && target.root != ROOT_ZERO

/-- Condición 4: ambos checkpoints existen en la cadena histórica. -/
def cond4_bothExist (state : ConsensusState) (source target : Checkpoint) : Bool :=
  checkpointExists state source && checkpointExists state target

/-- Condición 5: el tiempo avanza — target.slot > source.slot. -/
def cond5_timeForward (source target : Checkpoint) : Bool :=
  target.slot > source.slot

/-- Condición 6: el target cae en un slot justificable (usa SlotJustifiable). -/
def isPerfectSquareBool (n : Nat) : Bool := Nat.sqrt n ^ 2 == n
def isPronicBool (n : Nat) : Bool :=
  let val := 4 * n + 1
  Nat.sqrt val ^ 2 == val && val % 2 == 1

def slotIsJustifiableAfter (slot finalizedSlot : Nat) : Bool :=
  if slot < finalizedSlot then false
  else
    let δ := slot - finalizedSlot
    δ ≤ 5 || isPerfectSquareBool δ || isPronicBool δ

def cond6_targetJustifiable (state : ConsensusState) (target : Checkpoint) : Bool :=
  slotIsJustifiableAfter target.slot state.latestFinalizedSlot

/-- Función principal: is_valid_vote.
    Equivalente exacto del Rust — todas las condiciones deben ser true. -/
def isValidVote (state : ConsensusState) (source target : Checkpoint) : Bool :=
  cond1_sourceJustified state source    &&
  cond2_targetNotYetJustified state target &&
  cond3_noZeroRoots source target       &&
  cond4_bothExist state source target   &&
  cond5_timeForward source target       &&
  cond6_targetJustifiable state target

/-!
## Spec matemática

La spec dice exactamente cuándo un voto es válido, sin depender
de estructuras de datos — solo en términos de propiedades.
-/

/-- Spec de is_valid_vote: las 6 condiciones en lenguaje matemático. -/
def isValidVoteSpec (state : ConsensusState) (source target : Checkpoint) : Prop :=
  -- 1. source está justificado
  isSlotJustified state.justifiedSlots state.latestFinalizedSlot source.slot = true
  -- 2. target NO está justificado aún
  ∧ isSlotJustified state.justifiedSlots state.latestFinalizedSlot target.slot = false
  -- 3. roots no son zero
  ∧ source.root ≠ ROOT_ZERO
  ∧ target.root ≠ ROOT_ZERO
  -- 4. ambos existen en la cadena
  ∧ checkpointExists state source = true
  ∧ checkpointExists state target = true
  -- 5. tiempo avanza
  ∧ target.slot > source.slot
  -- 6. target slot es justificable
  ∧ slotIsJustifiableAfter target.slot state.latestFinalizedSlot = true

/-!
## Teorema central de equivalencia
-/

/-- TEOREMA CENTRAL:
    isValidVote implementación ↔ isValidVoteSpec matemática.
    Para todo estado y todo par (source, target). -/
theorem isValidVote_iff_spec (state : ConsensusState) (source target : Checkpoint) :
    isValidVote state source target = true ↔ isValidVoteSpec state source target := by
  simp [isValidVote, isValidVoteSpec,
        cond1_sourceJustified, cond2_targetNotYetJustified,
        cond3_noZeroRoots, cond4_bothExist,
        cond5_timeForward, cond6_targetJustifiable,
        Bool.and_eq_true, Bool.not_eq_true']
  tauto

/-!
## Corolarios — propiedades que salen gratis del teorema central
-/

/-- Si el voto es válido, el source siempre está justificado. -/
theorem validVote_source_justified (state : ConsensusState) (source target : Checkpoint)
    (h : isValidVote state source target = true) :
    isSlotJustified state.justifiedSlots state.latestFinalizedSlot source.slot = true := by
  rw [isValidVote_iff_spec] at h
  exact h.1

/-- Si el voto es válido, el target nunca está justificado (todavía). -/
theorem validVote_target_not_justified (state : ConsensusState) (source target : Checkpoint)
    (h : isValidVote state source target = true) :
    isSlotJustified state.justifiedSlots state.latestFinalizedSlot target.slot = false := by
  rw [isValidVote_iff_spec] at h
  exact h.2.1

/-- Si el voto es válido, el tiempo siempre avanza. -/
theorem validVote_time_forward (state : ConsensusState) (source target : Checkpoint)
    (h : isValidVote state source target = true) :
    target.slot > source.slot := by
  rw [isValidVote_iff_spec] at h
  exact h.2.2.2.2.2.1

/-- Un voto con roots zero nunca es válido. -/
theorem vote_with_zero_root_invalid (state : ConsensusState) (target : Checkpoint) :
    isValidVote state { slot := 0, root := ROOT_ZERO } target = false := by
  simp [isValidVote, cond1_sourceJustified, cond3_noZeroRoots, ROOT_ZERO]

/-- Source y target no pueden ser el mismo slot. -/
theorem vote_same_slot_invalid (state : ConsensusState) (source target : Checkpoint)
    (h : source.slot = target.slot) :
    isValidVote state source target = false := by
  simp [isValidVote, cond5_timeForward, h]

/-!
## Propiedad crítica: no puede justificarse el mismo slot dos veces

Esta es la propiedad de seguridad más importante de is_valid_vote:
condiciones 1 y 2 son mutuamente excluyentes para el mismo slot.
-/

/-- Si source.slot == target.slot, cond1 y cond2 no pueden ser
    verdaderas al mismo tiempo → el voto es inválido. -/
theorem no_double_justification (state : ConsensusState) (cp : Checkpoint) :
    isValidVote state cp cp = false := by
  simp [isValidVote, cond1_sourceJustified, cond2_targetNotYetJustified,
        cond5_timeForward]

/-!
## Ejemplos evaluables
-/

-- Estado de ejemplo: slot 10 finalizado, slots 11 y 12 en la cadena
def exampleState : ConsensusState := {
  justifiedSlots         := #[true, false, false]  -- slot 11 justificado, 12 y 13 no
  latestFinalizedSlot    := 10
  historicalBlockHashes  := Array.mkArray 20 1      -- todos con root=1
}

def srcCheckpoint  : Checkpoint := { slot := 11, root := 1 }  -- justificado ✓
def tgtCheckpoint  : Checkpoint := { slot := 12, root := 1 }  -- no justificado ✓

#eval isValidVote exampleState srcCheckpoint tgtCheckpoint
-- Esperado: true (todas las condiciones pasan)

#eval isValidVote exampleState tgtCheckpoint srcCheckpoint
-- Esperado: false (tiempo no avanza: 12 > 11 pero source=12, target=11)

#eval isValidVote exampleState srcCheckpoint { slot := 12, root := ROOT_ZERO }
-- Esperado: false (root zero)

end IsValidVote
