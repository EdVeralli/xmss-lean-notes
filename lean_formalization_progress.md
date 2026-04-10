# Lean 4 Formalization — ethlambda / 3SF-mini

Progreso de la formalización en Lean 4 de las funciones críticas del protocolo de consenso de ethlambda.

## Contexto

Un miembro del equipo de ethlambda (Pablo Deymonnaz) mencionó la iniciativa de portar partes críticas del cliente Rust a Lean 4. Al revisar el repo, **no había ningún archivo `.lean` en ninguna branch**. Este trabajo es el primer intento concreto de formalización del protocolo.

La estrategia elegida es la de **AMO-Lean** (LambdaClass): escribir la spec en Lean 4 y extraer código correcto por construcción, en vez de solo verificar el Rust desde afuera.

---

## Archivos creados

### 1. `SlotJustifiable.lean` ✅

**Función Rust:** `slot_is_justifiable_after` en `state_transition/src/lib.rs`

**Qué hace:** determina si un slot puede ser justificado según las reglas 3SF-mini. Un slot es justificable si su distancia (`delta`) al último slot finalizado es:
- ≤ 5 (los primeros 5 siempre justificables)
- Un cuadrado perfecto (1, 4, 9, 16, 25...)
- Un número prónico (2, 6, 12, 20, 30... — de la forma k*(k+1))

**Por qué importa en Lean:** el código Rust usa un truco matemático para detectar prónicos sin búsqueda lineal — `4*delta+1 = (2k+1)²`. Si ese truco tiene un error de overflow o de lógica, ningún test lo detecta para todos los valores posibles de u64. Lean lo prueba para todos los valores.

**Contenido del archivo:**
- `IsPerfectSquare`, `IsPronic` — definiciones matemáticas puras (de libro)
- `isPerfectSquareBool`, `isPronicBool` — implementación booleana, espejo del Rust
- `slotIsJustifiableAfter` — función principal
- `pronic_trick` — lema: `4*k*(k+1)+1 = (2k+1)²`
- `isPronicBool_iff`, `isPerfectSquareBool_iff` — corrección de las implementaciones
- `slotIsJustifiableAfter_spec` — **teorema central**: implementación ↔ spec matemática
- Corolarios: delta=0, delta=1, delta=3 no justificable, slot antes de finalized
- `#eval` — ejemplos verificados en tiempo de compilación

---

### 2. `IsValidVote.lean` ✅

**Función Rust:** `is_valid_vote` en `state_transition/src/lib.rs`

**Qué hace:** decide si un voto (attestation) debe contarse para el fork choice. Es el gate principal del consenso — si esta función es incorrecta, el protocolo acepta votos inválidos o rechaza votos válidos, rompiendo la finalización.

**Las 6 condiciones** (todas deben cumplirse):
1. El `source` ya está justificado
2. El `target` todavía no está justificado
3. Ningún root es zero hash
4. Ambos checkpoints existen en `historical_block_hashes`
5. `target.slot > source.slot` (el tiempo avanza)
6. `target.slot` es justificable después del slot finalizado

**Por qué importa en Lean:** las condiciones 1 y 2 juntas garantizan que no puede haber "double justification" — no podés justificar el mismo slot dos veces. Eso es una propiedad de seguridad crítica. Con tests solo cubrís casos conocidos; con Lean lo probás para todo estado posible.

**Contenido del archivo:**
- `Checkpoint`, `ConsensusState` — tipos base (espejo de los structs Rust, sin SSZ)
- `relativeIndex`, `isSlotJustified`, `checkpointExists` — espejo de `justified_slots_ops.rs`
- `cond1_` a `cond6_` — cada condición como función separada
- `isValidVote` — función principal (AND de las 6 condiciones)
- `isValidVoteSpec` — spec matemática en `Prop`
- `isValidVote_iff_spec` — **teorema central**: implementación ↔ spec
- Corolarios:
  - `validVote_source_justified` — source siempre justificado si el voto es válido
  - `validVote_target_not_justified` — target nunca justificado si el voto es válido
  - `validVote_time_forward` — el tiempo siempre avanza
  - `vote_with_zero_root_invalid` — root zero siempre inválido
  - `vote_same_slot_invalid` — mismo slot → inválido
  - `no_double_justification` — no podés votar el mismo checkpoint como source y target
- `#eval` — ejemplos con estado concreto

---

## Relación entre los archivos

```
SlotJustifiable.lean
    └─ define slotIsJustifiableAfter
           ↓
IsValidVote.lean
    └─ usa slotIsJustifiableAfter en cond6_targetJustifiable
    └─ usa isSlotJustified (de justified_slots_ops)
           ↓
  (próximo) TryFinalize.lean
    └─ usa isValidVote
    └─ usa slotIsJustifiableAfter
```

---

## Pendiente

| Función | Archivo Rust | Por qué |
|---|---|---|
| `justified_slots_ops` completo | `state_transition/src/justified_slots_ops.rs` | Aritmética de ventana, off-by-one risk en `shift_window` |
| `try_finalize` | `state_transition/src/lib.rs` | Espacio de estados combinatorial, imposible de testear exhaustivamente |
| `serialize_justifications` | `state_transition/src/lib.rs` | Orden determinístico para cross-client consensus |
| `compute_block_weights` + `compute_lmd_ghost_head` | `fork_choice/src/lib.rs` | Termination, weight monotonicity |
| Attestation validation en `store.rs` | `blockchain/src/store.rs` (líneas ~197–262) | Gate de gossip |
| Block building loop | `blockchain/src/store.rs` (líneas ~967–1076) | Determinismo, consensus split |
| Varint encode/decode | `net/req_resp/encoding.rs` | Roundtrip: `decode(encode(x)) == x` |
| Message ID | `net/p2p/src/lib.rs` | Cross-client consistency en gossipsub |

**Total identificado:** ~1,094 líneas de lógica pura en todo el codebase.

---

## Estrategia: AMO-Lean

El objetivo final no es solo tener pruebas Lean que verifican el Rust desde afuera. La estrategia de LambdaClass con AMO-Lean es:

1. Escribir la spec en Lean 4
2. Pasar por el pipeline de AMO-Lean (e-graph optimization)
3. Extraer código Rust/C optimizado y correcto por construcción
4. Ese código **reemplaza** la implementación Rust manual

AMO-Lean ya tiene verificados: FRI, NTT, aritmética de campos (Goldilocks, BabyBear), Poseidon2. Lo que falta para ethlambda: KoalaBear, Poseidon16, y toda la lógica de consenso 3SF-mini (que es exactamente lo que estamos formalizando).

---

## Branch y commits

```bash
# Repo: EdVeralli/xmss-lean-notes
# Branch: lean-formalization

git log --oneline
4059ea4 Add Lean 4 formalization of is_valid_vote
974eb31 Add Lean 4 formalization of slot_is_justifiable_after + notas Pablo
```

Para pushear desde tu máquina:
```bash
cd ~/xmss-lean-notes
git push -u origin lean-formalization
```
