# Revisión Técnica — Clase de Testing de Software (FIUBA)

Presentación: `Clase de Testing _standalone_.html`
Materia: TA045 — Taller de Programación, FIUBA
Fecha declarada: Abril 2026

*Revisión unificada a partir de dos análisis independientes (Opus).*

---

## Veredicto general

La presentación es sólida en estructura y narrativa. El arco desde un caso histórico motivador (Ariane 5), pasando por la cita de Dijkstra, técnicas incrementalmente más potentes, hasta la reflexión sobre cuándo parar, es pedagógicamente efectivo. Los ejemplos de código Rust son relevantes para la materia y están bien elegidos. Los errores técnicos propiamente dichos son pocos y concentrados; las oportunidades de mejora son varias y elevarían significativamente el valor de la clase.

---

## 🔴 Errores de alta severidad

### T1. Ariane 5 — el pseudocódigo no reproduce el bug real

> "una conversión de un número de punto flotante de 64 bits a un entero con signo de 16 bits"

La descripción general es correcta, pero el pseudocódigo Rust es engañoso en dos aspectos:

**Problema 1: semántica de `as i16` en Rust.**
El código muestra `let hv_int: i16 = horizontal_velocity as i16;`. En Rust moderno (≥1.45), `f64 as i16` hace **saturación**: valores fuera de rango se clampean a `i16::MAX` (32767) o `i16::MIN` (-32768). No paniquea, no lanza excepción, no produce overflow — simplemente devuelve un valor incorrecto y sigue ejecutando silenciosamente. Antes de Rust 1.45, era **undefined behavior**.

Pero en el Ariane 5 real, el código era **Ada**, y Ada lanza una excepción `CONSTRAINT_ERROR` en la conversión fuera de rango. Esa excepción no fue manejada, lo que apagó el Sistema de Referencia Inercial (SRI) y dejó al cohete sin guía. El bug fue una **excepción no manejada**, no un overflow silencioso ni un truncamiento.

**Problema 2: los valores numéricos son ambiguos.**
El comentario dice `max ~3.2×10³` para Ariane 4 y `max ~3.2×10⁴` para Ariane 5. Pero `3.2×10⁴ = 32000` cabe en un i16 (máximo 32767). El valor real de la velocidad horizontal (BH) que causó el overflow fue ~32768 (exactamente 2¹⁵), justo excediendo el límite. Sería más preciso decir `>32767` o `~2¹⁵`.

**Corrección sugerida:** Para representar fielmente el crash en Rust:
```rust
let hv_int = i16::try_from(horizontal_velocity as i64)
    .expect("overflow — SRI apagado");
```
Esto sí paniquea, análogamente a la excepción Ada. Y agregar una nota aclarando que el lenguaje real era Ada y que la semántica de `as` en Rust es diferente — lo que convierte el ejemplo en una lección adicional sobre cómo el mismo bug se manifiesta distinto según el lenguaje.

---

## 🟡 Errores / omisiones de severidad media

### T2. Cobertura + mutation testing — oportunidad perdida

El slide de cobertura demuestra brillantemente que 100% de branch coverage no detecta cambiar `>=` por `>`. Pero no responde la pregunta obvia del estudiante: "¿y entonces qué técnica lo detectaría?" La respuesta es **mutation testing** — mutar el código (`>=` → `>`, `+` → `-`, etc.) y ver si algún test falla. Herramientas como `cargo-mutants` en Rust son accesibles y directamente relevantes.

Esto sería un puente natural entre el slide de cobertura y el de property-based testing: la cobertura mide ejecución, mutation testing mide observación, y property-based testing automatiza la generación de inputs para atrapar mutantes.

---

### T3. `#[should_panic]` sin `expected` — mala práctica implícita

El slide IV lista `#[should_panic]` como atributo de test pero no menciona la variante `#[should_panic(expected = "mensaje")]`. Sin `expected`, el test pasa con **cualquier** pánico — incluyendo pánicos por razones completamente distintas a la esperada. Para una clase que enseña buenas prácticas, recomendar solo `#[should_panic]` sin `expected` es enseñar una práctica débil.

---

### T4. Fuzzing sin sanitizers

La sección de fuzzing describe bien el concepto de fuzzing guiado por cobertura, pero no menciona los **sanitizers** (AddressSanitizer, UndefinedBehaviorSanitizer, MemorySanitizer) que son lo que realmente potencia al fuzzer. Sin sanitizers, el fuzzer solo detecta crashes y panics visibles. Con ASAN detecta buffer overflows, use-after-free, memory leaks. `cargo fuzz` los activa por defecto — mencionarlo explica por qué el fuzzer encuentra bugs que los tests no.

En Rust puro (sin `unsafe`) esto es menos crítico, pero para estudiantes que verán C/C++ en otras materias de FIUBA, es valioso que sepan que el fuzzer no trabaja solo.

---

### T5. Tests de integración — ausencia como tema

Los tests de integración se mencionan tres veces de pasada ("un test con mocks no reemplaza a un test de integración", en la tabla de síntesis, y en el cierre) pero nunca se definen, nunca se muestra un ejemplo, y nunca se explica la distinción práctica en Rust (`tests/` directory vs `mod tests`). Para Taller de Programación donde los estudiantes arman proyectos con múltiples módulos, esta es la omisión más importante de la presentación.

---

### T6. Fuzz diferencial mencionado sin definir

La tabla de síntesis recomienda "fuzz diferencial" para parsers y criptografía, pero el concepto no se introdujo en ningún slide. Fuzz diferencial = comparar el output de dos implementaciones independientes con los mismos inputs aleatorios, buscando divergencias. Una línea de definición resolvería el problema.

---

### T7. Ausencia de TDD como metodología

Para una materia de programación donde los estudiantes desarrollan proyectos, no mencionar Test-Driven Development (escribir el test antes del código) es una omisión notable. No requiere un capítulo entero — una mención en la síntesis de que los tests pueden guiar el diseño (no solo verificarlo) sería suficiente.

---

## 🟢 Observaciones de baja severidad

### T8. Propiedades de sort — la idempotencia es redundante

Las propiedades listadas son: (1) resultado ordenado, (2) es permutación del input, (3) `sort(sort(v)) == sort(v)`. La propiedad (3) es consecuencia lógica de (1)+(2): si sort produce un resultado ordenado que es permutación del input, aplicar sort de nuevo no puede cambiar nada. No es incorrecta, pero es una oportunidad pedagógica perdida para hablar de **propiedades débiles vs fuertes**: (1) sola es débil (una función que devuelve `[1]` siempre la cumple), (2) sola es débil (la función identidad la cumple), pero (1)+(2) juntas son una especificación completa de sort.

---

### T9. Verificación formal — imprecisiones menores en la tabla

| Sistema | Dice | Precisión |
|---|---|---|
| CompCert | "compilador de C que no miscompila" | Es un compilador verificado de un **subconjunto** de C (Clight), no de todo C |
| seL4 | "microkernel libre de ciertos bugs" | Subestima el logro: seL4 tiene prueba de **correctitud funcional completa** (el binario implementa la especificación), integridad e information flow |
| HACL* | "criptografía en Firefox y Linux" | Correcto, pero HACL* está escrito en F*, no en Lean/Coq — vale mencionar la diversidad de herramientas |

---

### T10. Dijkstra — fecha correcta pero potencialmente confusa

EWD249 es "Notes on Structured Programming" y la cita es correcta. El manuscrito circuló desde ~1969-1970, pero la publicación más citada es de 1972 (libro "Structured Programming" de Dahl, Dijkstra, Hoare, Academic Press). Ambas fechas son defensibles; mencionarlo solo porque un estudiante que busque la referencia encontrará 1972.

---

### T11. Mocking — Mock vs Spy más claro

La tabla define Spy como "envuelve lo real y registra interacciones". La distinción clave con Mock (según Meszaros) es que el Spy **llama al método real** y además registra, mientras que el Mock **no llama al método real** — solo simula. En `mockall` (la librería que usan en la materia) se generan mocks con `expect_*` y `.times()`, no spies.

---

### T12. "Vectores NIST" sin explicar

La tabla de síntesis menciona "vectores NIST" y "vectores de prueba estándar" sin haberlos definido. Para estudiantes de Taller: "inputs y outputs de referencia publicados por organismos de estandarización para verificar que una implementación criptográfica es correcta."

---

### T13. Ejemplo Lean 4 — correcto

El código Lean compila y es un buen ejemplo introductorio. `Nat.add_comm` ya existe en la librería estándar, pero para una presentación didáctica mostrar la prueba por inducción es la elección correcta. La frase "si el compilador acepta la demostración, el teorema es cierto" es el punto central de la verificación formal y está bien expresada.

---

## Tabla resumen

| # | Severidad | Problema |
|---|---|---|
| T1 | 🔴 Alta | Ariane 5: `as i16` en Rust satura silenciosamente, no crashea como en Ada. Valores numéricos ambiguos. |
| T2 | 🟡 Media | Mutation testing ausente — es la respuesta natural a la limitación de cobertura demostrada |
| T3 | 🟡 Media | `#[should_panic]` sin `expected` es práctica débil |
| T4 | 🟡 Media | Fuzzing sin mencionar sanitizers (ASAN/UBSAN) |
| T5 | 🟡 Media | Tests de integración mencionados pero nunca definidos ni ejemplificados |
| T6 | 🟡 Media | Fuzz diferencial mencionado en síntesis sin haberlo definido |
| T7 | 🟡 Media | TDD no mencionado como metodología |
| T8 | 🟢 Baja | Propiedades de sort: idempotencia redundante, oportunidad pedagógica |
| T9 | 🟢 Baja | CompCert (subconjunto de C), seL4 (subestimado), HACL* (escrito en F*) |
| T10 | 🟢 Baja | Dijkstra 1970 vs 1972 |
| T11 | 🟢 Baja | Mock vs Spy: Spy llama al método real, Mock no |
| T12 | 🟢 Baja | "Vectores NIST" sin explicar |
| T13 | 🟢 Info | Ejemplo Lean correcto |

---

## Correcciones prioritarias

**Imprescindible:**
1. T1 — Corregir el pseudocódigo del Ariane 5 (usar `try_from().expect()` en vez de `as i16`, aclarar que el lenguaje era Ada, precisar el valor ~32768)

**Recomendables (elevan significativamente la clase):**
2. T2 — Agregar mención a mutation testing como puente desde el slide de cobertura
3. T5 — Agregar una sección o al menos un slide sobre tests de integración
4. T3 — Recomendar `#[should_panic(expected = "...")]` en vez de `#[should_panic]`
5. T4 — Mencionar sanitizers en la sección de fuzzing

**Opcionales (mejoran pero no son críticas):**
6. T6 — Definir fuzz diferencial en una línea
7. T7 — Mencionar TDD como metodología
8. T9 — Precisar CompCert y seL4 en la tabla de verificación formal
