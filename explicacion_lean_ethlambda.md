# Código Lean en ethlambda — Explicación

## Qué es ethlambda

ethlambda es un cliente de consenso para leanEthereum (una versión simplificada de Ethereum para investigación), escrito en Rust. El equipo de LambdaClass decidió verificar formalmente partes críticas del protocolo usando Lean 4 — un lenguaje que es a la vez un lenguaje de programación y un asistente de pruebas matemáticas.

## Qué verificaron

La primera pieza que verificaron es la **justifiability** del protocolo de consenso 3SF-mini. En este protocolo, no todos los slots (intervalos de tiempo de 4 segundos) pueden ser "justificados" (un paso intermedio hacia la finalización de un bloque). Los slots justificables siguen un patrón matemático específico:

Un slot a distancia `delta` del último slot finalizado es justificable si y solo si:

1. `delta ≤ 5` (los primeros 5 slots después de la finalización siempre son justificables), O
2. `delta` es un cuadrado perfecto (4, 9, 16, 25, ...), O  
3. `delta` es un número prónico: `n × (n+1)` para algún `n` (6, 12, 20, 30, ...)

Esta regla es central para el protocolo porque controla cuántos votos (attestations) se necesitan para avanzar la cadena. Si la implementación tiene un bug, el consenso se rompe.

---

## Arquitectura: dos bibliotecas Lean

El código se divide en dos proyectos Lean independientes:

### `EthLambda` (sin Mathlib) — se compila al binario

Contiene la implementación computable que se exporta a Rust via FFI. No depende de Mathlib (la biblioteca matemática de Lean) para que compile rápido y genere código C eficiente.

**Archivo: `formal/EthLambda/Justifiability.lean`** (55 líneas)

Este es el código que realmente corre en producción. Tiene tres funciones:

#### `isqrt` — raíz cuadrada entera

```lean
def isqrt (n : UInt64) : UInt64 :=
  if n <= 1 then n
  else
    let r := isqrtLoop n (n / 2 + 1) 64
    if r + 1 <= n / (r + 1) then r + 1 else r
```

Calcula ⌊√n⌋ usando el método de Newton (también llamado método babilónico o de Herón). Empieza en `n/2 + 1` (no en `n`, para evitar overflow) y refina iterativamente: dado un estimado `r`, el siguiente es `(r + n/r) / 2`. Converge en O(log log n) pasos — con 64 iteraciones de "fuel" alcanza para cualquier UInt64.

El paso de corrección final (`if r + 1 <= n / (r + 1)`) usa **división en lugar de multiplicación** para evitar overflow: verifica si `(r+1)² ≤ n` sin calcular `(r+1)²`.

#### `justifiable` — el check computable

```lean
def justifiable (delta : UInt64) : Bool :=
  delta <= 5
    || isqrt delta ^ 2 == delta              -- ¿es cuadrado perfecto?
    || (let val := 4 * delta + 1
        isqrt val ^ 2 == val && val % 2 == 1) -- ¿es prónico?
```

La detección de cuadrados es directa: `√d² = d` sii `d` es cuadrado perfecto. La detección de prónicos usa un truco algebraico: `d` es prónico sii `4d + 1` es un cuadrado perfecto impar. Esto viene de la identidad `4·n·(n+1) + 1 = (2n+1)²`.

#### Exports FFI

```lean
@[export lean_justifiable]
def leanJustifiable (delta : UInt64) : UInt8 :=
  if justifiable delta then 1 else 0
```

El `@[export lean_justifiable]` le dice a Lean que genere una función C con ese nombre, que Rust puede llamar directamente.

---

### `EthLambdaProofs` (con Mathlib) — solo verificación

Contiene las pruebas matemáticas que demuestran que la implementación de arriba es correcta. Este código nunca se compila al binario — solo se verifica con el compilador de Lean.

---

## Los archivos de prueba, paso a paso

### 1. `Defs.lean` — Definiciones matemáticas

```lean
def IsPronic (k : ℕ) : Prop := ∃ n : ℕ, k = n * (n + 1)

def Justifiable (delta : ℕ) : Prop :=
  delta ≤ 5 ∨ IsSquare delta ∨ IsPronic delta
```

Define lo que significa "justificable" a nivel matemático, usando números naturales (ℕ) sin restricciones de máquina. `IsSquare` viene de Mathlib. Estas definiciones son las que los humanos entienden y pueden razonar — la pregunta es si la implementación con UInt64 las computa correctamente.

### 2. `Lemmas.lean` — Lemas auxiliares

Tres resultados que se usan más adelante:

```lean
theorem pronic_identity (n : ℕ) : 4 * (n * (n + 1)) + 1 = (2 * n + 1) ^ 2
```

La identidad algebraica fundamental que hace funcionar la detección de prónicos. Lean la verifica con `ring` (aritmética simbólica).

```lean
theorem isSquare_iff_sqrt (k : ℕ) : IsSquare k ↔ Nat.sqrt k ^ 2 = k
```

Establece que la función `Nat.sqrt` de Mathlib puede usarse para detectar cuadrados: `k` es cuadrado perfecto sii `(√k)² = k`.

```lean
theorem small_justifiable (d : ℕ) (h : d ≤ 5) : Justifiable d
```

Los deltas pequeños son trivialmente justificables.

### 3. `PronicDetection.lean` — Detección de prónicos

```lean
theorem isPronic_iff_sqrt (k : ℕ) :
    IsPronic k ↔
      Nat.sqrt (4 * k + 1) ^ 2 = 4 * k + 1 ∧
      (4 * k + 1) % 2 = 1
```

Demuestra formalmente que el truco `4k+1 es cuadrado impar ↔ k es prónico` es correcto. La prueba en dirección →  usa `pronic_identity`. En dirección ← reconstruye el `n` a partir de la raíz (que es impar, así que `n = raíz / 2`).

### 4. `Classification.lean` — El teorema de clasificación

```lean
theorem justifiable_iff (d : ℕ) :
    Justifiable d ↔
      (d ≤ 5 ∨ Nat.sqrt d ^ 2 = d ∨
        (Nat.sqrt (4 * d + 1) ^ 2 = 4 * d + 1 ∧ (4 * d + 1) % 2 = 1))
```

Conecta la definición matemática (existenciales, `IsSquare`, `IsPronic`) con el check computable basado en `Nat.sqrt`. Básicamente dice: "la forma con existenciales y la forma con raíces cuadradas son equivalentes". Combina los lemas anteriores.

### 5. `ImplEquivalence.lean` — El puente UInt64 ↔ ℕ (441 líneas)

Este es el archivo más largo y más importante. Demuestra que la implementación con aritmética de máquina (UInt64, que puede hacer overflow) produce exactamente el mismo resultado que la versión matemática con naturales infinitos.

**Estructura de la prueba:**

**Paso 1: Mirror a nivel Nat.** Define `natIsqrtLoop` y `natIsqrt` — versiones idénticas al código UInt64 pero operando sobre ℕ (sin overflow posible).

**Paso 2: Newton converge.** Demuestra que `natIsqrtLoop` calcula `Nat.sqrt`:

```lean
private theorem natIsqrtLoop_correct (n r : Nat) (fuel : Nat)
    (hn : n > 0) (hr_pos : r > 0) (hr_ge : r ≥ Nat.sqrt n)
    (hfuel : r - Nat.sqrt n < 2 ^ fuel) :
    natIsqrtLoop n r fuel = Nat.sqrt n
```

La clave es que cada iteración de Newton reduce a la mitad el exceso `r - √n` (demostrado en `newton_excess_halves`), así que con 64 iteraciones de fuel alcanza para cualquier input < 2⁶⁴ (porque el exceso inicial es < 2⁶³).

Los lemas auxiliares demuestran la desigualdad AM-GM entera: `r + n/r ≥ 2√n` cuando `r ≥ √n`, que garantiza que Newton nunca pasa por debajo de la raíz verdadera.

**Paso 3: Bridge UInt64 → Nat.** Demuestra que las operaciones UInt64 no hacen overflow:

```lean
private theorem isqrtLoop_bridge (n r : UInt64) (fuel : Nat) ... :
    (isqrtLoop n r fuel).toNat = natIsqrtLoop n.toNat r.toNat fuel
```

¿Cómo? Demuestra que en cada iteración, la suma `r + n/r` es < 2⁶⁴, así que la aritmética modular de UInt64 coincide con la aritmética natural. Usa el bound `r ≤ n/2 + 1` (invariante del loop) y `n/r ≤ √n + 2` (consecuencia de `r ≥ √n`).

**Resultado central:**

```lean
theorem isqrt_correct (n : UInt64) :
    (isqrt n).toNat = Nat.sqrt n.toNat
```

`isqrt` calcula correctamente `Nat.sqrt` para **todos** los UInt64 — sin restricción de rango. No hay un solo input que pueda hacer que falle.

**Resultado final:**

```lean
theorem justifiable_equiv (d : UInt64) (h : d.toNat < 2 ^ 62) :
    justifiable d = true ↔ Justifiable d.toNat
```

La función `justifiable` de UInt64 produce `true` exactamente cuando el delta es matemáticamente `Justifiable`. La única restricción es `d < 2⁶²` (≈ 4.6 × 10¹⁸) — necesaria para que `4*d+1` no haga overflow. En la práctica, con slots de 4 segundos, 2⁶² slots equivalen a ~585 mil millones de años. Sobra.

### 6. `Density.lean` — Densidad O(√N)

```lean
theorem justifiable_density (N : ℕ) :
    ((Finset.range N).filter (fun d => Justifiable d)).card ≤ 2 * Nat.sqrt N + 8
```

Los slots justificables hasta N son como máximo 2√N + 8. Esto importa para el protocolo: significa que los votos se "funnelean" — no se dispersan en infinitos slots posibles, sino que se concentran en O(√N) puntos. Esto garantiza que el consenso progresa eficientemente.

La prueba descompone los justificables en tres conjuntos (≤5, cuadrados, prónicos), acota cada uno por separado (≤6, ≤√N+1, ≤√N+1) y suma.

### 7. `Infinite.lean` — Infinitud (liveness)

```lean
theorem justifiable_unbounded : ∀ N : ℕ, ∃ d, d > N ∧ Justifiable d
```

Para cualquier N, existe un slot justificable mayor que N. Prueba trivial: `(N+1)²` siempre es justificable (es cuadrado perfecto). Esto garantiza **liveness** — el protocolo nunca se queda sin slots donde justificar.

---

## El glue Rust: `formal/lean-ffi/src/lib.rs`

Este archivo conecta todo con el binario de ethlambda:

```rust
static INIT: Once = Once::new();

fn init_lean() {
    INIT.call_once(|| unsafe {
        lean_initialize_runtime_module();
        let res = initialize_EthLambda_EthLambda(1);
        lean_ffi_dec_ref(res);
        lean_io_mark_end_initialization();
    });
}

pub fn justifiable(delta: u64) -> bool {
    init_lean();
    unsafe { lean_justifiable(delta) != 0 }
}
```

Inicializa el runtime de Lean una sola vez (`std::sync::Once`) y luego cada llamada a `justifiable()` ejecuta directamente el código Lean compilado a C. El resultado es un `u8` (0 o 1) que se convierte a `bool`.

Los tests verifican los casos conocidos: deltas pequeños, cuadrados perfectos, prónicos, y no-justificables.

---

## La cadena de confianza completa

```
Definición matemática (Justifiable)
    ↕  justifiable_iff (Classification.lean)
Check con Nat.sqrt
    ↕  isqrt_correct + justifiable_equiv (ImplEquivalence.lean)
Código UInt64 (justifiable)
    ↕  @[export] FFI
Función Rust (lean_ffi::justifiable)
    ↕  llamada directa
Binario ethlambda en producción
```

Cada eslabón está verificado formalmente por Lean. Si el compilador acepta todas las pruebas sin `sorry` (placeholders), la cadena es inquebrantable: el código que corre en producción **necesariamente** implementa la especificación matemática.

---

## ¿Por qué esto importa?

Un bug en justifiability podría causar:

- **Si acepta slots inválidos:** la cadena se fragmenta, el consenso se rompe.
- **Si rechaza slots válidos:** el protocolo se atasca, no puede finalizar bloques.
- **Si la densidad fuera mayor a O(√N):** los votos se dispersan demasiado, la finalización se vuelve improbable.

Con la verificación formal, estas categorías de bugs quedan eliminadas **para siempre**, no "hasta que alguien encuentre un edge case". Es la diferencia entre testear y probar.

---

## Estado actual y próximos pasos

La branch `lean-formalization` tiene todo funcionando pero no se mergeó a `main` todavía. Los últimos commits (10 de abril) son de infraestructura: CI, linking en Linux, auto-discovery de archivos C.

Las próximas piezas a verificar podrían ser:
- Fork choice (LMD GHOST) — el algoritmo que elige la cabeza de la cadena
- Reglas de finalización — cuándo un bloque pasa de justificado a finalizado
- State transition — el proceso completo de aplicar un bloque al estado

Pero por ahora el equipo está enfocado en el networking para devnet-4 y no hay commits nuevos de Lean desde hace 10 días.
