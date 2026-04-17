# Revisión Técnica — Clase de Testing de Software (FIUBA)

Presentación: `Clase de Testing _standalone_.html`
Materia: TA045 — Taller de Programación, FIUBA
Fecha declarada: Abril 2026

---

## Veredicto general

La presentación es de muy buena calidad. El arco narrativo (fracaso real → cita de Dijkstra → técnicas de menor a mayor potencia → síntesis por costo de bug) está bien construido. Los ejemplos de código en Rust son correctos y relevantes para la materia. Los conceptos están bien explicados sin sobresimplificar. Encontré pocos errores técnicos propiamente dichos y varias oportunidades de mejora.

---

## Errores técnicos

### T1. Ariane 5 — la conversión no fue de f64 a i16 — 🔴 Alta

> "una conversión de un número de punto flotante de 64 bits a un entero con signo de 16 bits"

Esto es impreciso. Según el informe oficial de la comisión Ariane 501 (informe Lions, 1996), la conversión fue de un **float de 64 bits a un entero con signo de 16 bits**, pero el dato original era la **velocidad horizontal relativa (BH)** expresada como float de 64 bits en el SRI (Sistema de Referencia Inercial). El valor era ~32768, que excedía el rango de un int16 con signo (máx 32767).

El pseudocódigo del slide dice:

```
let horizontal_velocity: f64 = sensor.read();
let hv_int: i16 = horizontal_velocity as i16;
```

El `as i16` en Rust hace truncación silenciosa (wrapping), no lanza excepción. En Ada (el lenguaje real del Ariane), la conversión lanza una excepción `CONSTRAINT_ERROR` que no fue manejada — el SRI se apagó y el cohete perdió guía. El bug no fue un overflow silencioso sino una **excepción no manejada**. Si el público es de Rust, vale la pena aclarar que la semántica de `as` en Rust es diferente a Ada: en Rust el cast sería silencioso, en Ada crasheó el sistema.

**El comentario del código también tiene un error numérico:** dice `max ~3.2×10³` para Ariane 4 y `max ~3.2×10⁴` para Ariane 5. El valor real que causó el overflow fue ~32768 (2¹⁵), que está en el borde exacto del i16. El ~3.2×10⁴ es correcto pero sería más preciso decir 32768 o 2¹⁵, ya que el punto es que superó exactamente el máximo del tipo.

---

### T2. Cobertura de ramas — el ejemplo no tiene 100% de ramas — 🟡 Media

> "100.0% branches"

El slide dice que `es_mayor(10)` y `es_mayor(25)` dan 100% de cobertura de ramas. Esto es correcto para la función `es_mayor` que tiene una sola condición (`edad >= 18`) con dos outcomes (true/false), y los dos tests ejercitan ambos. La afirmación es técnicamente correcta.

Sin embargo, el slide inmediatamente argumenta que esto es insuficiente porque el borde `edad == 18` no se prueba. Esto es un excelente punto pedagógico, pero podría generar confusión: si la cobertura de ramas es 100% y aún así falta algo, ¿qué nivel de cobertura lo detectaría? La respuesta es **mutation testing** (cambiar `>=` por `>` y ver si algún test falla), que no se menciona en la presentación. Sería una buena oportunidad de introducir el concepto, ya que el ejemplo lo pide a gritos.

---

### T3. Dijkstra — cita correcta pero fecha imprecisa — 🟢 Baja

> "Edsger W. Dijkstra · EWD249, 1970"
> "Notes on Structured Programming"

EWD249 es efectivamente "Notes on Structured Programming" y la cita es correcta. Sin embargo, la versión publicada y más citada es de 1972 (en el libro "Structured Programming" de Dahl, Dijkstra y Hoare, Academic Press). El manuscrito EWD249 circuló desde ~1969-1970. Ambas fechas son defensibles; solo mencionarlo por si un estudiante busca la referencia y encuentra 1972.

---

### T4. Property-based testing — propiedades de sort incompletas — 🟢 Baja

> "Propiedades de una función de ordenar: el resultado está ordenado, es una permutación del input, sort(sort(v)) == sort(v) (idempotencia)"

Las dos primeras propiedades son las esenciales y juntas constituyen una especificación completa de sort. La tercera (idempotencia) es consecuencia de las dos primeras — no agrega poder de verificación. No es un error, pero si el objetivo es mostrar propiedades *independientes* que juntas especifican el comportamiento, la idempotencia es redundante. Una propiedad más útil como tercera sería `sort(v).len() == v.len()` (preservación de longitud), que es independiente y detecta bugs donde sort pierde o duplica elementos.

---

### T5. Fuzzing — falta mención de sanitizers — 🟡 Media

La sección de fuzzing describe bien el concepto de fuzzing guiado por cobertura con libFuzzer y `cargo fuzz`, pero no menciona los **sanitizers** (AddressSanitizer, UndefinedBehaviorSanitizer) que son lo que realmente convierte al fuzzer en una herramienta potente. Sin sanitizers, el fuzzer solo detecta crashes y panics. Con ASAN detecta buffer overflows, use-after-free, memory leaks. Con UBSAN detecta undefined behavior.

En Rust, los panics ya son bastante informativos, pero para código `unsafe` (que es común en parsers y protocolos), los sanitizers son esenciales. `cargo fuzz` los activa por defecto, así que técnicamente están ahí — pero no mencionarlos es perder la oportunidad de explicar *por qué* el fuzzer encuentra bugs que los tests no.

---

### T6. Verificación formal — Lean 4 ejemplo trivial — 🟢 Baja

```lean
theorem add_comm (a b : Nat) :
  a + b = b + a :=
by induction a with
| zero => simp
| succ n ih => simp [Nat.succ_add, ih]
```

El código Lean es correcto y compila. La conmutatividad de la suma es un buen primer ejemplo. La presentación dice "Si el compilador acepta la demostración, el teorema es cierto. No hay que volver a revisarlo." — esto es correcto y es el punto central de la verificación formal.

Una observación menor: en Lean 4 moderno, `Nat.add_comm` ya existe en la librería estándar y se puede usar directamente con `exact Nat.add_comm a b`. Pero para una presentación didáctica, mostrar la prueba por inducción es mejor.

---

### T7. Tabla de síntesis — "vectores de prueba estándar" sin explicar — 🟢 Baja

La tabla de §11 menciona "vectores NIST" y "vectores de prueba estándar" sin haber explicado qué son. Para un estudiante de Taller de Programación, esto puede ser opaco. Una línea aclaratoria ("inputs y outputs de referencia publicados por organismos de estandarización para verificar que una implementación criptográfica es correcta") ayudaría.

---

### T8. Mocking — la tabla de dobles omite una distinción sutil — 🟢 Baja

La tabla lista Stub, Mock, Fake y Spy. La clasificación sigue a Gerard Meszaros (xUnit Test Patterns, 2007) y es correcta. El término paraguas "dobles de prueba" (test doubles) también es de Meszaros. 

La distinción entre Mock y Spy es la que más confunde en la práctica: el slide dice que Spy "envuelve lo real y registra interacciones", lo cual es correcto pero podría ser más claro diciendo que un Spy llama al método real y además registra, mientras que un Mock no llama al método real.

---

## Errores de forma

### F1. Fuzz diferencial mencionado pero no explicado — 🟡 Media

La tabla de §11 dice "fuzz diferencial" para protocolos y criptografía. El concepto no se introdujo en ningún slide anterior. Fuzz diferencial (comparar el output de dos implementaciones independientes con los mismos inputs aleatorios) es una técnica potente y distinta del fuzzing estándar. Si se menciona en la síntesis, merece al menos una línea de definición.

---

### F2. Ausencia de tests de integración — 🟡 Media

La presentación va de tests de unidad a cobertura a mocking a property-based a fuzzing a verificación formal. Los **tests de integración** se mencionan tres veces de pasada ("un test con mocks no reemplaza a un test de integración", en la tabla de síntesis, y en el cierre) pero nunca se explican. Para una materia de Taller de Programación donde los estudiantes van a armar proyectos con múltiples módulos, la ausencia de una sección dedicada a tests de integración (y la distinción con tests de unidad) es una omisión significativa.

---

### F3. La simulación interactiva — no verificable — 🟢 Info

Los slides XI y XII mencionan figuras interactivas (simulación de proptest con `buggy_abs`, simulación del fuzzer buscando "FUZ"). Como el HTML es standalone con JavaScript embebido, no pude ejecutarlas para verificar que funcionan correctamente. Si las simulaciones tienen bugs, sería irónico en una presentación sobre testing.

---

## Resumen

| # | Tipo | Severidad | Problema |
|---|---|---|---|
| T1 | Técnico | 🔴 Alta | Ariane 5: fue excepción no manejada en Ada, no overflow silencioso |
| T2 | Técnico | 🟡 Media | Oportunidad perdida de introducir mutation testing |
| T3 | Técnico | 🟢 Baja | Dijkstra EWD249: 1970 vs 1972 |
| T4 | Técnico | 🟢 Baja | Idempotencia de sort es redundante como propiedad |
| T5 | Técnico | 🟡 Media | Fuzzing sin mencionar sanitizers (ASAN/UBSAN) |
| T6 | Técnico | 🟢 Baja | Ejemplo Lean correcto, observación menor |
| T7 | Técnico | 🟢 Baja | "Vectores NIST" sin explicar |
| T8 | Técnico | 🟢 Baja | Mock vs Spy podría ser más claro |
| F1 | Forma | 🟡 Media | Fuzz diferencial mencionado sin definir |
| F2 | Forma | 🟡 Media | Tests de integración ausentes como tema |
| F3 | Forma | 🟢 Info | Simulaciones interactivas no verificadas |

**Veredicto:** Presentación sólida y bien construida. El único error técnico que realmente importa es T1 (Ariane 5): el punto pedagógico es correcto (un bug de conversión de tipos destruyó un cohete) pero el mecanismo es impreciso — en Ada fue una excepción no manejada, no un overflow silencioso como sugiere el pseudocódigo Rust. El resto son oportunidades de mejora, no errores.
