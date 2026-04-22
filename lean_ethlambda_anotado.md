# Código Lean de ethlambda — Anotado línea por línea

Recorrido por todos los archivos Lean del branch `lean-formalization`, con explicaciones intercaladas.

---

## Archivo 1: `formal/EthLambda/Justifiability.lean`

Este es el código que se compila al binario. No usa Mathlib. Se exporta a Rust via FFI.

```lean
/-!
# 3SF-mini Justifiability

Computable implementation of the justifiability check used in 3SF-mini consensus.
No Mathlib dependency; compiled into the Rust binary via FFI.
-/
```

> Comentario de documentación. "3SF-mini" es el nombre del protocolo de consenso.
> "No Mathlib dependency" es clave: este archivo tiene que compilar rápido y generar código C.

---

### `isqrtLoop` — el corazón del método de Newton

```lean
def isqrtLoop (n : UInt64) (r : UInt64) : (fuel : Nat) → UInt64
  | 0 => r
  | fuel + 1 =>
    let new_r := (r + n / r) / 2
    if new_r >= r then r
    else isqrtLoop n new_r fuel
```

> `def isqrtLoop` — define una función recursiva.
>
> **Parámetros:**
> - `n : UInt64` — el número al que queremos calcularle la raíz
> - `r : UInt64` — el estimado actual de √n
> - `fuel : Nat` — un contador que decrece en cada recursión (Lean lo necesita para probar que la función termina)
>
> **Caso base** `| 0 => r` — si se acabó el fuel, devuelve el estimado actual.
>
> **Caso recursivo** `| fuel + 1 =>` — si queda fuel:
> - `let new_r := (r + n / r) / 2` — esto es la iteración de Newton: el promedio entre `r` y `n/r`. Si `r` es mayor que √n, entonces `n/r` es menor, y su promedio se acerca más. Geométricamente es la media aritmética de un lado del rectángulo y el otro.
> - `if new_r >= r then r` — si el nuevo estimado no mejoró (es ≥ al anterior), paramos. Esto pasa cuando ya convergimos.
> - `else isqrtLoop n new_r fuel` — si mejoró, seguimos iterando con el nuevo estimado.

---

### `isqrt` — raíz cuadrada entera con corrección

```lean
def isqrt (n : UInt64) : UInt64 :=
  if n <= 1 then n
  else
    let r := isqrtLoop n (n / 2 + 1) 64
    if r + 1 <= n / (r + 1) then r + 1 else r
```

> `if n <= 1 then n` — √0 = 0, √1 = 1. Caso trivial.
>
> `let r := isqrtLoop n (n / 2 + 1) 64` — empieza Newton desde `n/2 + 1`.
> ¿Por qué `n/2 + 1` y no `n`? Porque si empezás en `n`, el primer paso calcula `(n + n/n)/2 = (n+1)/2`,
> y `n + n/n` puede hacer overflow en UInt64 para valores grandes. Empezar en `n/2 + 1` evita eso
> y sigue siendo ≥ √n (necesario para que Newton converja desde arriba).
> El `64` es el fuel — 64 iteraciones alcanzan para cualquier UInt64 porque cada paso reduce
> el error a la mitad (convergencia logarítmica).
>
> `if r + 1 <= n / (r + 1) then r + 1 else r` — paso de corrección.
> Newton puede parar un paso antes del valor correcto. Este check verifica si `(r+1)² ≤ n`
> usando **división** (`r+1 ≤ n/(r+1)`) en vez de multiplicación (`(r+1)*(r+1) ≤ n`)
> para evitar overflow. Si se cumple, la raíz es `r+1`; si no, es `r`.

---

### `justifiable` — el check de justificabilidad

```lean
def justifiable (delta : UInt64) : Bool :=
  delta <= 5
    || isqrt delta ^ 2 == delta
    || (let val := 4 * delta + 1
        isqrt val ^ 2 == val && val % 2 == 1)
```

> Tres condiciones con OR:
>
> 1. `delta <= 5` — los primeros 5 slots siempre son justificables. Regla del protocolo.
>
> 2. `isqrt delta ^ 2 == delta` — ¿es cuadrado perfecto? Si `(⌊√d⌋)² = d`, entonces d es
>    cuadrado perfecto. Ejemplo: `isqrt 25 = 5`, `5² = 25 = 25` ✓. Pero `isqrt 26 = 5`,
>    `5² = 25 ≠ 26` ✗.
>
> 3. `let val := 4 * delta + 1; isqrt val ^ 2 == val && val % 2 == 1` — ¿es prónico?
>    Un número prónico es `n×(n+1)` (ej: 6=2×3, 12=3×4, 20=4×5).
>    El truco: `d` es prónico ⟺ `4d+1` es un cuadrado perfecto impar.
>    Viene de la identidad `4·n·(n+1) + 1 = (2n+1)²`.
>    El `val % 2 == 1` verifica que sea impar (evita falsos positivos de cuadrados pares).

---

### `slotIsJustifiableAfter` — API a nivel de slot

```lean
def slotIsJustifiableAfter (slot finalizedSlot : UInt64) : Bool :=
  if slot < finalizedSlot then false
  else justifiable (slot - finalizedSlot)
```

> Si el slot es anterior al finalizado, no es justificable (no podés justificar el pasado).
> Si no, calcula el delta y delega a `justifiable`.

---

### Exports FFI — las funciones que Rust puede llamar

```lean
@[export lean_justifiable]
def leanJustifiable (delta : UInt64) : UInt8 :=
  if justifiable delta then 1 else 0

@[export lean_slot_is_justifiable_after]
def leanSlotIsJustifiableAfter (slot finalizedSlot : UInt64) : UInt8 :=
  if slotIsJustifiableAfter slot finalizedSlot then 1 else 0
```

> `@[export lean_justifiable]` — es un "atributo" que le dice al compilador de Lean:
> "cuando generes código C, exportá esta función con el nombre `lean_justifiable`".
> Rust después declara `extern "C" { fn lean_justifiable(delta: u64) -> u8; }` y la llama directamente.
>
> Devuelven `UInt8` (1 o 0) en vez de `Bool` porque `Bool` en Lean tiene un encoding interno
> que no es trivial de pasar por FFI, pero un byte sí.

---
---

## Archivo 2: `formal/EthLambdaProofs/Justifiability/Defs.lean`

Definiciones matemáticas puras. Esto es lo que "queremos que sea cierto" — la especificación.

```lean
import Mathlib
import EthLambda.Justifiability
```

> Importa Mathlib (biblioteca matemática enorme) y el archivo de implementación.
> Así este módulo puede hablar tanto de la matemática como de la implementación.

```lean
def IsPronic (k : ℕ) : Prop := ∃ n : ℕ, k = n * (n + 1)
```

> Define "número prónico" como una **proposición** (Prop): `k` es prónico si **existe** un `n`
> tal que `k = n × (n+1)`. Nótese la diferencia con la implementación — acá no dice *cómo*
> detectarlo, solo *qué significa*.

```lean
def Justifiable (delta : ℕ) : Prop :=
  delta ≤ 5 ∨ IsSquare delta ∨ IsPronic delta
```

> Define "justificable" con naturales (ℕ, sin límite de tamaño):
> es ≤5, o es cuadrado perfecto (`IsSquare` viene de Mathlib), o es prónico.
> Esta es la **especificación** que la implementación debe satisfacer.

---

## Archivo 3: `formal/EthLambdaProofs/Justifiability/Lemmas.lean`

Lemas auxiliares — herramientas que se usan en las pruebas más grandes.

```lean
theorem pronic_identity (n : ℕ) : 4 * (n * (n + 1)) + 1 = (2 * n + 1) ^ 2 := by
  ring
```

> La identidad algebraica que justifica la detección de prónicos.
> `by ring` le dice a Lean: "esto es pura álgebra de anillos, verificalo automáticamente".
> Lean expande ambos lados y confirma que son iguales. No requiere intervención humana.
>
> **¿Qué es `by ring`?** Es una *táctica* que resuelve automáticamente igualdades algebraicas.
> Internamente, normaliza ambos lados de la igualdad a una forma canónica de polinomio y
> verifica que son idénticos:
> - Lado izquierdo: `4 * (n * (n + 1)) + 1` → `4n² + 4n + 1`
> - Lado derecho: `(2 * n + 1) ^ 2` → `4n² + 4n + 1`
>
> Es como tener una calculadora simbólica adentro del compilador. Funciona para cualquier
> igualdad que se pueda resolver solo con las propiedades de suma, resta, multiplicación y
> potencias — las operaciones de un "anillo" en álgebra abstracta.
> No sirve para desigualdades ni para división — para eso hay otras tácticas:
> - `omega` — aritmética lineal entera (ej: `a + 1 > a`)
> - `nlinarith` — aritmética no lineal con hipótesis (ej: `a² ≥ 0`)

```lean
theorem isSquare_iff_sqrt (k : ℕ) : IsSquare k ↔ Nat.sqrt k ^ 2 = k := by
  rw [IsSquare, ← Nat.exists_mul_self']
  constructor
  · rintro ⟨r, rfl⟩; exact ⟨r, sq r⟩
  · rintro ⟨n, hn⟩; exact ⟨n, by nlinarith [hn]⟩
```

> Demuestra que `k` es cuadrado perfecto ⟺ `(Nat.sqrt k)² = k`.
> - `↔` significa "si y solo si" — hay que probar las dos direcciones.
> - `constructor` divide en las dos direcciones.
> - `→`: si existe `r` con `k = r²`, entonces `Nat.sqrt k = r` y `r² = k`. ✓
> - `←`: si `(Nat.sqrt k)² = k`, entonces `Nat.sqrt k` es el testigo de `IsSquare`. ✓
> - `rintro ⟨r, rfl⟩` es destructuring: "sea `r` ese testigo, y sustituí `k` por `r²`".
> - `nlinarith` es un solver de aritmética lineal/no-lineal.

```lean
theorem small_justifiable (d : ℕ) (h : d ≤ 5) : Justifiable d := Or.inl h
```

> Trivial: si `d ≤ 5`, es justificable por la primera cláusula del OR. `Or.inl` elige el lado izquierdo.

---

## Archivo 4: `formal/EthLambdaProofs/Justifiability/PronicDetection.lean`

Demuestra que el truco del `4k+1` funciona.

```lean
theorem isPronic_iff_sqrt (k : ℕ) :
    IsPronic k ↔
      Nat.sqrt (4 * k + 1) ^ 2 = 4 * k + 1 ∧
      (4 * k + 1) % 2 = 1 := by
```

> **Enunciado:** `k` es prónico ⟺ (`4k+1` es cuadrado perfecto Y `4k+1` es impar).
> Esto es exactamente lo que la implementación computa — pero a nivel matemático.

```lean
  constructor
  · rintro ⟨n, rfl⟩
    refine ⟨?_, by omega⟩
    have h1 : 4 * (n * (n + 1)) + 1 = (2 * n + 1) * (2 * n + 1) := by ring
    rw [h1, Nat.sqrt_eq, sq]
```

> **Dirección →** (si es prónico, entonces 4k+1 es cuadrado impar):
> - `rintro ⟨n, rfl⟩` — "sea n tal que k = n*(n+1), sustituyo"
> - `by omega` — demuestra que 4·n·(n+1)+1 es impar (Lean lo verifica aritméticamente)
> - `h1` usa `ring` para probar la identidad `4·n·(n+1)+1 = (2n+1)²`
> - `Nat.sqrt_eq` dice que `√(m²) = m` para cuadrados perfectos

```lean
  · intro ⟨hsq, hodd⟩
    set s := Nat.sqrt (4 * k + 1) with hs_def
    have s_odd : s % 2 = 1 := by
      rcases Nat.even_or_odd s with ⟨t, ht⟩ | ⟨t, ht⟩
      · exfalso
        have : s ^ 2 % 2 = 0 := by rw [ht]; ring_nf; omega
        omega
      · omega
    refine ⟨s / 2, ?_⟩
    have hm : s = 2 * (s / 2) + 1 := by omega
    have key : (2 * (s / 2) + 1) ^ 2 = 4 * k + 1 := by rw [← hm]; exact hsq
    nlinarith [key]
```

> **Dirección ←** (si 4k+1 es cuadrado impar, entonces k es prónico):
> - `set s := Nat.sqrt(4k+1)` — nombre la raíz `s`
> - Prueba que `s` es impar: si fuera par, `s²` sería par, pero `4k+1` es impar. Contradicción.
> - Como `s` es impar, `s = 2·(s/2) + 1`. Entonces `(2·(s/2)+1)² = 4k+1`.
> - Expandiendo: `4·(s/2)·(s/2 + 1) + 1 = 4k + 1`, de donde `k = (s/2)·(s/2 + 1)`.
> - Eso es exactamente la definición de prónico con `n = s/2`. ✓
> - `nlinarith` cierra la aritmética.

---

## Archivo 5: `formal/EthLambdaProofs/Justifiability/Classification.lean`

Conecta la definición con existenciales a la versión computable.

```lean
theorem justifiable_iff (d : ℕ) :
    Justifiable d ↔
      (d ≤ 5 ∨ Nat.sqrt d ^ 2 = d ∨
        (Nat.sqrt (4 * d + 1) ^ 2 = 4 * d + 1 ∧
         (4 * d + 1) % 2 = 1)) := by
  unfold Justifiable
  constructor
  · rintro (h | h | h)
    · exact Or.inl h
    · exact Or.inr (Or.inl ((isSquare_iff_sqrt d).mp h))
    · exact Or.inr (Or.inr ((isPronic_iff_sqrt d).mp h))
  · rintro (h | h | h)
    · exact Or.inl h
    · exact Or.inr (Or.inl ((isSquare_iff_sqrt d).mpr h))
    · exact Or.inr (Or.inr ((isPronic_iff_sqrt d).mpr h))
```

> `unfold Justifiable` — despliega la definición.
> Después es mecánico: para cada rama del OR, aplica el lema correspondiente
> (`isSquare_iff_sqrt` o `isPronic_iff_sqrt`) para convertir entre la forma existencial
> y la forma con `Nat.sqrt`.
>
> `.mp` = "modus ponens" (dirección →), `.mpr` = dirección ←.
>
> El resultado dice: la definición matemática de `Justifiable` es equivalente a
> un check con `Nat.sqrt` — que es lo que la implementación hace, pero con UInt64.

---

## Archivo 6: `formal/EthLambdaProofs/Justifiability/ImplEquivalence.lean`

El archivo más largo (441 líneas). Demuestra que UInt64 == ℕ para esta implementación.

### Mirror a nivel Nat

```lean
private def natIsqrtLoop (n r : Nat) : Nat → Nat
  | 0 => r
  | fuel + 1 =>
    let new_r := (r + n / r) / 2
    if new_r >= r then r
    else natIsqrtLoop n new_r fuel
```

> Copia exacta de `isqrtLoop` pero con `Nat` en vez de `UInt64`.
> Como Nat no tiene overflow, podemos razonar sobre esta versión sin preocuparnos
> por aritmética modular. Después demostramos que ambas dan lo mismo.

```lean
private def natIsqrt (n : Nat) : Nat :=
  if n ≤ 1 then n
  else
    let r := natIsqrtLoop n (n / 2 + 1) 64
    if r + 1 ≤ n / (r + 1) then r + 1 else r
```

> Idem para `isqrt`.

---

### Convergencia de Newton — la AM-GM entera

```lean
private lemma newton_amgm (n r s : Nat) (hr_ge : r ≥ s) (hs_sq : s * s ≤ n) (hr_pos : r > 0) :
    r + n / r ≥ 2 * s := by
```

> **Desigualdad AM-GM para enteros:** si `r ≥ s` y `s² ≤ n` y `r > 0`,
> entonces `r + n/r ≥ 2s`.
>
> Intuición: por AM-GM continua, `r + n/r ≥ 2√n`. Como `s ≤ √n`, tenemos `r + n/r ≥ 2s`.
> Pero en enteros hay que ser más cuidadoso con el redondeo de la división.
>
> Consecuencia crucial: `(r + n/r)/2 ≥ s = √n`. O sea, **Newton nunca pasa por debajo de la raíz**.

```lean
private theorem newton_step_ge_sqrt (n r : Nat) (hr_ge : r ≥ Nat.sqrt n) (hr_pos : r > 0) :
    (r + n / r) / 2 ≥ Nat.sqrt n := by
  have := newton_amgm n r (Nat.sqrt n) hr_ge (Nat.sqrt_le n) hr_pos; omega
```

> Corolario directo: si `r ≥ √n`, el siguiente estimado también es `≥ √n`.
> Newton converge **desde arriba** y nunca se pasa.

```lean
private lemma newton_excess_halves (n r : Nat) (hr : r > Nat.sqrt n) :
    (r + n / r) / 2 - Nat.sqrt n ≤ (r - Nat.sqrt n) / 2 := by
  have := div_le_sqrt n r hr; omega
```

> Cada paso de Newton reduce el exceso (`r - √n`) a la mitad o menos.
> Esto da convergencia **logarítmica**: si empezamos con exceso < 2⁶⁴,
> en 64 pasos el exceso llega a 0.

---

### Convergencia del loop

```lean
private theorem natIsqrtLoop_correct (n r : Nat) (fuel : Nat)
    (hn : n > 0) (hr_pos : r > 0) (hr_ge : r ≥ Nat.sqrt n)
    (hfuel : r - Nat.sqrt n < 2 ^ fuel) :
    natIsqrtLoop n r fuel = Nat.sqrt n := by
  induction fuel generalizing r with
  | zero =>
    simp only [Nat.pow_zero] at hfuel
    simp [natIsqrtLoop]; omega
  | succ k ih =>
    simp only [natIsqrtLoop]
    split
    · -- Stopped: new_r >= r. Must have r = sqrt(n).
      rename_i hstop
      by_contra hne
      have hr_gt : r > Nat.sqrt n := by omega
      have : n < r * r := Nat.sqrt_lt.mp hr_gt
      have : n / r < r := by rwa [Nat.div_lt_iff_lt_mul (by omega)]
      omega
    · -- Continued: new_r < r. Recurse with halved excess.
      rename_i hcont
      push Not at hcont
      have hr_gt : r > Nat.sqrt n := by ...
      exact ih _ ... (newton_step_ge_sqrt ...) (by
          have := newton_excess_halves n r hr_gt; omega)
```

> **Prueba por inducción en el fuel:**
>
> - **Fuel = 0:** si el exceso es < 2⁰ = 1, entonces `r = √n`. Devolver `r` es correcto.
>
> - **Fuel = k+1, el loop para** (new_r ≥ r): probamos que esto solo pasa si `r = √n`.
>   Si `r > √n`, entonces `n < r²`, entonces `n/r < r`, entonces `(r + n/r)/2 < r`.
>   Contradicción con "new_r ≥ r". Así que `r = √n`. ✓
>
> - **Fuel = k+1, el loop continúa** (new_r < r): el nuevo exceso es ≤ exceso/2 < 2^k.
>   Aplicamos la hipótesis inductiva. ✓

---

### Corrección de `natIsqrt`

```lean
private theorem natIsqrt_eq_sqrt (n : Nat) (hn : n < 2 ^ 64) :
    natIsqrt n = Nat.sqrt n := by
```

> Demuestra que `natIsqrt` (la versión Nat) calcula `Nat.sqrt` para todo n < 2⁶⁴.
> Usa `natIsqrtLoop_correct` para el loop, y después verifica que el paso de corrección
> final no cambia nada (porque Newton ya convergió al valor exacto).

---

### El bridge UInt64 → Nat

```lean
private theorem isqrtLoop_bridge (n r : UInt64) (fuel : Nat)
    (hn_pos : n.toNat > 0)
    (hge : r.toNat ≥ Nat.sqrt n.toNat)
    (hr_le : r.toNat ≤ n.toNat / 2 + 1)
    (hr_pos : r.toNat > 0) :
    (isqrtLoop n r fuel).toNat = natIsqrtLoop n.toNat r.toNat fuel := by
```

> **El puente central.** Demuestra que `isqrtLoop` en UInt64 da lo mismo que `natIsqrtLoop` en Nat.
>
> ¿Cómo? Demostrando que **nunca hay overflow**. En cada iteración:
> - `r + n/r < 2⁶⁴` (así la suma no desborda)
>
> Esto se garantiza porque `r ≤ n/2 + 1` y `n/r ≤ √n + 2`, y su suma es < 2⁶³ + 2³² + 3 < 2⁶⁴.

```lean
    have hsum_lt : r.toNat + n.toNat / r.toNat < 2 ^ 64 :=
      newton_sum_lt_pow64 n.toNat r.toNat hn64 hge hr_le hr_pos hn_pos
    have hsum_eq : (r + n / r).toNat = r.toNat + n.toNat / r.toNat := by
      rw [UInt64.toNat_add, hdiv_eq, Nat.mod_eq_of_lt hsum_lt]
```

> `UInt64.toNat_add` dice que `(a + b).toNat = (a.toNat + b.toNat) % 2⁶⁴`.
> Como probamos que la suma es < 2⁶⁴, el `% 2⁶⁴` no hace nada (es la identidad).
> Ergo, la aritmética UInt64 coincide con la natural. Sin overflow.

---

### El teorema estrella

```lean
theorem isqrt_correct (n : UInt64) :
    (isqrt n).toNat = Nat.sqrt n.toNat := by
```

> **`isqrt` calcula correctamente `Nat.sqrt` para TODO UInt64.**
> Sin restricción de rango. Todo input posible da el resultado correcto.
>
> La prueba conecta: `isqrt` (UInt64) = `natIsqrt` (Nat) = `Nat.sqrt` (Mathlib).

---

### El teorema final de equivalencia

```lean
theorem justifiable_equiv (d : UInt64) (h : d.toNat < 2 ^ 62) :
    justifiable d = true ↔ Justifiable d.toNat := by
```

> **La función UInt64 `justifiable` devuelve `true` ⟺ delta es matemáticamente `Justifiable`.**
>
> Restricción: `d < 2⁶²`. ¿Por qué? Porque `justifiable` calcula `4 * d + 1`, y si
> `d ≥ 2⁶²`, ese `4*d+1` desborda UInt64. Para d < 2⁶² no hay overflow.
>
> En la práctica: 2⁶² slots × 4 segundos/slot = 585 mil millones de años. No es una restricción real.

```lean
  -- Bridge each UInt64 condition to Nat
  have h_le5 : (d ≤ 5) ↔ (d.toNat ≤ 5) := UInt64.le_iff_toNat_le_toNat
  have h_sq_d : (isqrt d ^ 2 = d) ↔ (Nat.sqrt d.toNat ^ 2 = d.toNat) := by
    rw [UInt64.ext_iff, uint64_sq_toNat _ hsqrt_d_lt, hisqrt_d]
```

> Cada sub-condición de `justifiable` se traduce a su equivalente en Nat:
> - `d ≤ 5` en UInt64 ⟺ `d.toNat ≤ 5` en Nat
> - `isqrt d ^ 2 == d` en UInt64 ⟺ `Nat.sqrt d ^ 2 = d` en Nat (usando `isqrt_correct`)
> - Lo mismo para la condición del prónico
>
> Después combina todo con `justifiable_iff` (de Classification.lean) para cerrar.

---

## Archivo 7: `formal/EthLambdaProofs/Justifiability/Density.lean`

Demuestra que los justificables crecen como O(√N).

```lean
private theorem squares_count_le (N : ℕ) :
    ((Finset.range N).filter (fun d => IsSquare d)).card ≤ Nat.sqrt N + 1 := by
```

> Cuadrados perfectos hasta N: hay como máximo √N + 1.
> Porque los cuadrados son {0², 1², 2², ..., (√N)²}, que son √N + 1 elementos.
> La prueba muestra que el conjunto filtrado es un subconjunto de `{r² : r ≤ √N}`,
> y ese conjunto tiene cardinalidad ≤ √N + 1.

```lean
private theorem pronics_count_le (N : ℕ) :
    ((Finset.range N).filter (fun d => IsPronic d)).card ≤ Nat.sqrt N + 1 := by
```

> Lo mismo para prónicos: {0×1, 1×2, 2×3, ..., n×(n+1)} donde n×(n+1) < N
> implica n ≤ √N. Máximo √N + 1 prónicos hasta N.

```lean
theorem justifiable_density (N : ℕ) :
    ((Finset.range N).filter (fun d => Justifiable d)).card
      ≤ 2 * Nat.sqrt N + 8 := by
```

> **Resultado:** a lo sumo `2√N + 8` slots justificables entre 0 y N-1.
>
> Prueba: los justificables ⊆ (d≤5) ∪ (cuadrados) ∪ (prónicos).
> Cardinalidad ≤ 6 + (√N+1) + (√N+1) = 2√N + 8. ✓
>
> **¿Por qué importa?** Si hubiera demasiados slots justificables, los votos
> del protocolo se dispersarían y nunca habría suficiente concentración para finalizar.
> O(√N) garantiza que los votos se "funnelean" en pocos puntos.

---

## Archivo 8: `formal/EthLambdaProofs/Justifiability/Infinite.lean`

Demuestra que siempre hay más slots justificables adelante (liveness del protocolo).

```lean
theorem justifiable_of_sq (n : ℕ) : Justifiable (n ^ 2) :=
  Or.inr (Or.inl ⟨n, by ring⟩)
```

> Todo cuadrado perfecto es justificable. Prueba: `n²` es cuadrado (testigo: `n`). ✓

```lean
theorem justifiable_unbounded : ∀ N : ℕ, ∃ d, d > N ∧ Justifiable d := by
  intro N
  refine ⟨(N + 1) ^ 2, ?_, justifiable_of_sq (N + 1)⟩
  nlinarith [Nat.zero_le N]
```

> **Para todo N, existe un delta justificable mayor que N.**
> Testigo: `(N+1)²`, que es > N (porque `(N+1)² ≥ N+1 > N`) y es justificable (es cuadrado).
>
> **¿Por qué importa?** Garantiza **liveness**: el protocolo nunca se queda atascado
> esperando un slot justificable que nunca llega. Siempre hay uno más adelante.

---

## Archivo 9: `formal/lean-ffi/src/lib.rs` (Rust)

El pegamento que conecta las pruebas con el mundo real.

```rust
unsafe extern "C" {
    fn lean_initialize_runtime_module();
    fn lean_io_mark_end_initialization();
    fn initialize_EthLambda_EthLambda(builtin: u8) -> LeanObj;
    fn lean_ffi_dec_ref(o: LeanObj);
    fn lean_justifiable(delta: u64) -> u8;
    fn lean_slot_is_justifiable_after(slot: u64, finalized_slot: u64) -> u8;
}
```

> Declaraciones `extern "C"` — le dice a Rust que estas funciones existen en código C
> (generado por el compilador de Lean) y que se van a linkear al binario.

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
```

> Inicializa el runtime de Lean exactamente una vez (`std::sync::Once`).
> `lean_initialize_runtime_module()` prepara el GC y las estructuras internas de Lean.
> `initialize_EthLambda_EthLambda(1)` ejecuta los inicializadores del módulo.
> `lean_io_mark_end_initialization()` cierra la fase de init.

```rust
pub fn justifiable(delta: u64) -> bool {
    init_lean();
    unsafe { lean_justifiable(delta) != 0 }
}
```

> La API pública. Inicializa Lean si no se hizo, y llama a la función Lean.
> El `unsafe` es inevitable en FFI pero el código Lean que ejecuta está verificado,
> así que el único riesgo es en la inicialización, no en la lógica.

---

## Resumen visual de la cadena de pruebas

```
┌─────────────────────────────────────────────────────────┐
│  Justifiable (d : ℕ) : Prop                             │  ← Especificación humana
│  "d ≤ 5 ∨ IsSquare d ∨ IsPronic d"                     │
└───────────────────────────┬─────────────────────────────┘
                            │ justifiable_iff
                            │ (usa isSquare_iff_sqrt, isPronic_iff_sqrt)
                            ▼
┌─────────────────────────────────────────────────────────┐
│  Check con Nat.sqrt                                     │  ← Computable sobre ℕ
│  "d ≤ 5 ∨ Nat.sqrt d ^ 2 = d ∨ ..."                   │
└───────────────────────────┬─────────────────────────────┘
                            │ justifiable_equiv
                            │ (usa isqrt_correct + no-overflow proofs)
                            ▼
┌─────────────────────────────────────────────────────────┐
│  justifiable (d : UInt64) : Bool                        │  ← Código de máquina
│  "d <= 5 || isqrt d ^ 2 == d || ..."                   │
└───────────────────────────┬─────────────────────────────┘
                            │ @[export lean_justifiable]
                            │ (compilación Lean → C)
                            ▼
┌─────────────────────────────────────────────────────────┐
│  pub fn justifiable(delta: u64) -> bool                 │  ← Rust en producción
│  (llama a lean_justifiable via FFI)                     │
└─────────────────────────────────────────────────────────┘
```

Cada flecha es un teorema verificado por Lean. Si alguno fuera falso, el compilador rechazaría el código.

---

## Propiedades adicionales demostradas

| Propiedad | Qué garantiza | Para el protocolo |
|---|---|---|
| `justifiable_density` | ≤ 2√N + 8 justificables hasta N | Los votos se concentran, el consenso avanza |
| `justifiable_unbounded` | Siempre hay un justificable más adelante | Liveness: nunca se atasca |
| `isqrt_correct` | √ funciona para TODO UInt64 | No hay edge case que pueda romper el check |
| `justifiable_equiv` | UInt64 == ℕ para d < 2⁶² | El binario implementa la especificación |
