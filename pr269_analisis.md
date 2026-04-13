# Análisis — PR #269 ethlambda: Lean 4 en producción

Análisis del PR oficial del equipo de LambdaClass que introduce verificación formal
en Lean 4 al repo ethlambda.

PR: https://github.com/lambdaclass/ethlambda/pull/269

---

## Qué hace el PR

Introduce un paquete Lean 4 bajo `formal/` que formaliza `slot_is_justifiable_after`
— la misma función que nosotros formalizamos en `SlotJustifiable.lean` — y la conecta
al código Rust de producción vía FFI, activable con un feature flag.

---

## Estructura que eligió el equipo

```
formal/
  EthLambda/
    Justifiability.lean         ← implementación computable (UInt64, sin Mathlib)
  EthLambdaProofs/
    Justifiability/
      ImplEquivalence.lean      ← teoremas formales (con Mathlib)
  lean-ffi/
    src/lib.rs                  ← crate Rust con el bridge FFI
    src/lean_glue.c             ← glue code C para interop
    build.rs                    ← compila el C de Lean, linkea leanrt
  README.md
  CLAUDE.md
```

### Decisión arquitectónica clave: dos bibliotecas separadas

| Biblioteca | Contenido | Mathlib | Compila a C |
|---|---|---|---|
| `EthLambda` | Implementación computable | ❌ | ✅ |
| `EthLambdaProofs` | Teoremas y pruebas | ✅ | ❌ |

Esta separación es importante: el código que va a producción (vía FFI) no depende
de Mathlib — usa solo tipos primitivos `UInt64`. Las pruebas formales viven aparte
y no afectan el binario de producción.

---

## Feature flag en Rust

El equipo no reemplazó la función Rust directamente. Usaron un feature flag:

```
ethlambda --features lean-ffi
  → ethlambda-blockchain
    → ethlambda-state-transition (usa ethlambda-lean-ffi)
```

Sin el flag, se usa la implementación Rust original — no se necesita Lean instalado.
Con el flag, la función verificada en Lean reemplaza a la Rust transparentemente.

En `state_transition/src/lib.rs`:
```rust
#[cfg(feature = "lean-ffi")]
pub use lean_ffi::slot_is_justifiable_after;

#[cfg(not(feature = "lean-ffi"))]
pub fn slot_is_justifiable_after(slot: u64, finalized_slot: u64) -> bool {
    // ... implementación Rust original
}
```

---

## CI agregado

Dos jobs nuevos en GitHub Actions:

- `lean-build` — construye ambas bibliotecas Lean con Lake
- `lean-ffi-test` — prueba la integración Rust↔Lean

También verifica que no haya `sorry` en las pruebas — cualquier prueba incompleta
rompe el CI.

Un Makefile target:
```bash
make formally-verify   # equivale a: cd formal && lake build
```

---

## Problemas que encontraron los revisores

### 1. Overflow en UInt64 para delta ≥ 2^62 ⚠️

El cálculo `4 * delta + 1` puede hacer overflow en UInt64 cuando `delta >= 2^62`.
Por ejemplo, con `delta = 2^62` el valor envuelto es `1`, que pasa la prueba de
cuadrado perfecto, retornando `true` erróneamente.

El teorema `justifiable_equiv` documenta este límite (`d < 2^62`) pero las funciones
FFI no validan el input. En la práctica es irrelevante — ninguna blockchain tendrá
diferencias de slots de esa magnitud — pero la documentación decía "correcto para
todos los naturales" cuando en realidad solo vale para `delta < 2^62`.

**Lo que nosotros hicimos diferente:** en nuestro `SlotJustifiable.lean` usamos
`Nat` (naturales sin límite) en vez de `UInt64`, lo que evita este problema
completamente a nivel de las pruebas. La conversión a `UInt64` para la FFI queda
como responsabilidad del wrapper.

### 2. Documentación imprecisa

- Ruta incorrecta en comentarios (`formal/ffi/LeanFFI/` vs `formal/EthLambda/`)
- La afirmación "correcto para todos los números naturales" no era exacta dado el
  límite de `2^62`

### 3. Build system incompleto

Los triggers de `rerun-if-changed` en `build.rs` no incluían `lakefile.toml` ni
`lean-toolchain`, así que cambios en la configuración de Lean no disparaban
reconstrucción.

### 4. El grep de `sorry` era demasiado amplio

El CI buscaba la string `sorry` literalmente, lo que podría dar falsos positivos
(por ejemplo, un comentario que diga "sorry for the mess"). La recomendación fue
usar `\bsorry\b`.

---

## Comparación con nuestro trabajo

| Aspecto | PR #269 (equipo lambda) | Nuestro trabajo |
|---|---|---|
| Función formalizada | `slot_is_justifiable_after` | `slot_is_justifiable_after` + `is_valid_vote` |
| Tipos en Lean | `UInt64` | `Nat` (sin límite) |
| Mathlib | Separado en EthLambdaProofs | Directo en el mismo archivo |
| FFI | Sí, con feature flag | Sí, en `lean-ffi-example/` |
| Overflow u64 | Problema identificado en revisión | Evitado usando `Nat` |
| Integración CI | Sí (lake build + lean-ffi-test) | No (es un ejemplo standalone) |
| Estado | PR abierto, en revisión | Branch `lean-ffi-example` en xmss-lean-notes |

---

## Lección principal

La arquitectura que el equipo eligió valida exactamente la dirección que tomamos:

1. **Lean para la spec matemática** — con Mathlib para los teoremas
2. **Lean sin Mathlib para el código ejecutable** — tipos primitivos, compila a C
3. **FFI con feature flag** — la función Lean reemplaza a la Rust, el caller no cambia
4. **CI que verifica zero sorry** — si hay una prueba incompleta, el build falla

El único punto donde divergimos es `UInt64` vs `Nat`. Usar `Nat` en las pruebas
y `UInt64` solo en la capa FFI es probablemente la decisión más correcta.

---

## El código Lean que escribió el equipo

### `formal/EthLambda/Justifiability.lean` — la implementación computable

Este es el código que realmente va a producción vía FFI. Sin Mathlib, solo tipos primitivos `UInt64`.

```lean
/-- Integer square root via Newton's method (bounded iteration).
    Devuelve el mayor r tal que r * r ≤ n.
    Arranca desde n/2 + 1 (no desde n) para evitar overflow en el primer paso. -/
def isqrtLoop (n : UInt64) (r : UInt64) : (fuel : Nat) → UInt64
  | 0 => r
  | fuel + 1 =>
    let new_r := (r + n / r) / 2
    if new_r >= r then r
    else isqrtLoop n new_r fuel

def isqrt (n : UInt64) : UInt64 :=
  if n <= 1 then n
  else
    let r := isqrtLoop n (n / 2 + 1) 64
    -- Usa división en vez de multiplicación para evitar overflow en la corrección:
    -- r+1 ≤ n/(r+1) ↔ (r+1)*(r+1) ≤ n (cuando r+1 > 0)
    if r + 1 <= n / (r + 1) then r + 1 else r

/-- Predicado de justificabilidad — espejo de la implementación Rust. -/
def justifiable (delta : UInt64) : Bool :=
  delta <= 5
  || isqrt delta ^ 2 == delta
  || (let val := 4 * delta + 1
      isqrt val ^ 2 == val && val % 2 == 1)

/-- Función completa — misma API que el Rust slot_is_justifiable_after. -/
def slotIsJustifiableAfter (slot finalizedSlot : UInt64) : Bool :=
  if slot < finalizedSlot then false
  else justifiable (slot - finalizedSlot)

-- Exports FFI para Rust (devuelven UInt8 porque C no tiene Bool nativo)
@[export lean_justifiable]
def leanJustifiable (delta : UInt64) : UInt8 :=
  if justifiable delta then 1 else 0

@[export lean_slot_is_justifiable_after]
def leanSlotIsJustifiableAfter (slot finalizedSlot : UInt64) : UInt8 :=
  if slotIsJustifiableAfter slot finalizedSlot then 1 else 0
```

**Decisiones de diseño importantes:**

**`isqrt` usa división en vez de multiplicación.** Para verificar si `r+1` es mejor raíz, el código natural sería `(r+1)*(r+1) <= n`, pero eso puede hacer overflow en `UInt64`. La versión del equipo usa `r+1 <= n/(r+1)` que es matemáticamente equivalente pero sin overflow.

**64 iteraciones de Newton.** El `fuel` que limita el loop es 64. El equipo probó formalmente que 64 iteraciones son suficientes para converger en cualquier `UInt64` (porque log₂(2⁶⁴) = 64).

**Los exports FFI devuelven `UInt8` en vez de `Bool`.** En C no existe un tipo `Bool` estándar — un `bool` de C es en realidad un entero. Por eso Lean exporta `UInt8` (0 o 1) y Rust lo convierte a `bool` con `!= 0`.

---

### `formal/EthLambdaProofs/Justifiability/ImplEquivalence.lean` — los teoremas

Este archivo es el puente entre la implementación `UInt64` y las definiciones matemáticas puras en `Nat`. No genera código ejecutable — solo existe para la verificación formal.

**Teoremas principales:**

`nat_sqrt_unique` — la raíz cuadrada entera es única. Si `r² ≤ n < (r+1)²`, entonces `r` es el único natural que satisface eso.

`natIsqrtLoop_correct` — el loop de Newton converge a `Nat.sqrt n` cuando tiene suficiente combustible (≥ log₂ del exceso inicial).

`isqrt_correct` — el teorema central de corrección del `isqrt`:
```lean
theorem isqrt_correct (n : UInt64) :
    (isqrt n).toNat = Nat.sqrt n.toNat
```
Para toda entrada `UInt64`, la función computable `isqrt` produce exactamente el mismo resultado que `Nat.sqrt` (la raíz cuadrada matemática de Mathlib).

`justifiable_equiv` — equivalencia entre la función booleana y la proposición matemática:
```lean
theorem justifiable_equiv (d : UInt64) (hd : d.toNat < 2^62) :
    justifiable d = true ↔ Justifiable d.toNat
```
Donde `Justifiable` es la definición matemática pura: `delta ≤ 5 ∨ ∃ k, delta = k² ∨ ∃ k, delta = k*(k+1)`.

**La restricción `d < 2^62`:** este teorema vale solo para `delta < 2^62` porque el cálculo `4 * delta + 1` hace overflow en `UInt64` para valores más grandes. En la práctica nunca va a pasar (ninguna blockchain tendrá diferencias de slots de esa magnitud), pero la prueba es honesta sobre su dominio de validez.

**Estrategia de prueba en 3 pasos:**
1. Espejo del algoritmo en `Nat` (sin límites de overflow)
2. Prueba de convergencia del método de Newton usando desigualdad AM-GM entera
3. Puente entre la aritmética `UInt64` y `Nat` — prueba que los resultados coinciden dentro del dominio válido

---

## Próximo paso lógico

Con este PR en revisión, las siguientes funciones candidatas para el mismo tratamiento
(según el análisis de Pablo Deymonnaz en `notas01.md`) son:

1. `justified_slots_ops.rs` — aritmética de ventana, off-by-one risk
2. `try_finalize` — espacio combinatorial, imposible testear exhaustivamente
3. `compute_block_weights` + `compute_lmd_ghost_head` — LMD-GHOST, termination proof
