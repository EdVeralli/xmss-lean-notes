# Revisión v2 — Clase de Testing de Software (FIUBA)

Comparación de la versión actualizada (`Clase de Testing _standalone_ (1).html`, 19 de abril) contra la revisión unificada de la versión original.

---

## Cambios estructurales

La nueva versión tiene **18 slides** (vs 16 en la original). Se agregan:

- **Slide 2 (Agenda):** Itinerario completo de la clase. Buena adición — orienta al estudiante desde el inicio.
- **Slide 17 (Bibliografía):** Referencias formales con citas completas: Dijkstra (1972), Myers (2011), Meszaros (2007), Claessen & Hughes (2000), Zeller et al. (2024), Thomkins et al. (2024 — GhostWrite), Klein et al. (2009 — seL4). Excelente adición — le da respaldo académico a toda la presentación.

---

## Estado de cada hallazgo de la revisión original

### T1. Ariane 5 — `as i16` no reproduce el bug real — 🔴 PERSISTE

El slide 3 sigue **idéntico** a la versión original:

```rust
let hv_int: i16 = horizontal_velocity as i16;
```

- Sigue usando `as i16` (saturación silenciosa en Rust ≥1.45), no `try_from().expect()` (pánico, análogo al `CONSTRAINT_ERROR` de Ada).
- Los valores siguen diciendo `max ~3.2×10⁴` cuando el valor real era ~32768 (exactamente 2¹⁵, justo excediendo `i16::MAX = 32767`).
- No se aclara que el lenguaje real era Ada.

**Veredicto:** Error de alta severidad sin corregir. Es la corrección más importante pendiente.

---

### T2. Mutation testing ausente — 🟡 PERSISTE

No hay mención de mutation testing en ningún slide. La oportunidad pedagógica sigue perdida: el slide de cobertura demuestra que 100% de branch coverage no detecta `>=` vs `>`, pero no responde qué técnica sí lo detectaría.

---

### T3. `#[should_panic]` sin `expected` — 🟡 PERSISTE

El slide 5 sigue listando `#[should_panic]` sin mencionar la variante `#[should_panic(expected = "mensaje")]`. Sin cambios.

---

### T4. Fuzzing sin sanitizers — 🟡 PERSISTE (parcialmente compensado)

No hay mención de sanitizers (ASAN, UBSAN, MSAN). Sin embargo, la adición del ejemplo **GhostWrite** (2024) en el slide de fuzzing es valiosa: muestra fuzzing aplicado a hardware (RISC-V), lo que amplía la perspectiva más allá del software. Pero sigue faltando la explicación de *por qué* el fuzzer encuentra lo que encuentra (sanitizers + instrumentación).

---

### T5. Tests de integración — ✅ CORREGIDO

El slide 6 ahora incluye un párrafo dedicado:

> *"Tests de integración — Una vez que cada unidad está cubierta, suben un nivel: verifican que varias unidades juntas —módulos, capas, servicios— respeten su contrato de interacción. En Rust viven en `tests/`, no en `#[cfg(test)]`, y se ejecutan también con `cargo test`."*

Esto resuelve la omisión más importante señalada en la revisión. La distinción `tests/` vs `#[cfg(test)]` es exactamente lo que los estudiantes de Taller necesitan saber. No es un slide completo, pero la definición y la distinción práctica en Rust están presentes.

---

### T6. Fuzz diferencial mencionado sin definir — 🟡 PERSISTE

La tabla de síntesis (slide 15) sigue mencionando "fuzz diferencial" sin haberlo definido en ningún slide previo.

---

### T7. TDD no mencionado — ⚠️ ESTADO INCIERTO

La cadena "TDD" aparece en el archivo, pero está dentro de datos codificados (base64/minificados), no en el contenido visible de ningún slide. En el texto de las slides extraídas no se menciona Test-Driven Development como metodología.

**Veredicto:** Probablemente persiste la omisión, a menos que haya una mención en contenido que no se renderiza como texto (notas del presentador, por ejemplo).

---

### T8. Propiedades de sort — idempotencia redundante — 🟢 PERSISTE (baja severidad)

El slide 12 sigue listando las mismas tres propiedades: (1) resultado ordenado, (2) permutación del input, (3) idempotencia. Sin cambios.

---

### T9. Verificación formal — imprecisiones en la tabla — 🟢 PERSISTE

El slide 14 sigue con las mismas descripciones:
- CompCert: "compilador de C que no miscompila" (es un subconjunto de C)
- seL4: "microkernel libre de ciertos bugs" (tiene prueba de correctitud funcional completa)
- HACL*: "criptografía en Firefox y Linux" (correcto pero no menciona F*)

La adición de la referencia Klein et al. (2009) en la bibliografía es un buen complemento para seL4.

---

### T10. Dijkstra — fecha — 🟢 SIN CAMBIOS (no era error)

Sigue diciendo "EWD249, 1970". La bibliografía nueva dice "Dijkstra, E. W. (1972). Notes on Structured Programming. Academic Press." — esto es correcto: el manuscrito circuló en 1970, la publicación fue en 1972. Ambas fechas presentes ahora, lo cual es ideal.

---

### T11. Mock vs Spy — ✅ CORREGIDO

La tabla de mocking (slide 10) ahora dice:

| Nombre | Función |
|---|---|
| Mock | stub + verifica cómo fue llamado; **no invoca al real, sólo lo simula** |
| Spy | envuelve lo real —**sí lo invoca**— y registra sus interacciones |

La distinción clave (Spy llama al método real, Mock no) está explícita. Corrección perfecta.

---

### T12. "Vectores NIST" sin explicar — 🟢 PERSISTE

La tabla de síntesis sigue mencionando "vectores NIST" y "vectores de prueba estándar" sin definirlos.

---

### T13. Ejemplo Lean 4 — ✅ SIN CAMBIOS (estaba correcto)

El ejemplo `add_comm` sigue idéntico. Seguía siendo correcto.

---

## Mejoras nuevas no anticipadas por la revisión

### N1. Cobertura: "Caminos" → "Funciones"

El tercer nivel de cobertura cambió de "Caminos" (path coverage) a "Funciones" (function coverage). La versión anterior era técnicamente más ambiciosa (path coverage es el nivel más fuerte), pero "Funciones" es más práctico y realista para el nivel de la materia. `cargo tarpaulin` no mide path coverage realmente; sí mide function coverage. **Cambio justificado.**

### N2. Ejemplo GhostWrite (2024)

Adición en el slide de fuzzing: un caso real de fuzzing aplicado a hardware (RISC-V T-Head C910) que descubrió instrucciones que escriben memoria física arbitraria desde userspace. Con referencia a USENIX Security 2024 y `ghostwriteattack.com`. Excelente elección — muestra que fuzzing va más allá de parsers de software.

### N3. Bibliografía completa

Slide nuevo con 7 referencias formales organizadas en "Fundamentos" y "Técnicas avanzadas". Incluye los clásicos (Dijkstra, Myers, Meszaros, Claessen/Hughes) y papers recientes (GhostWrite, seL4). Le da rigor académico a la presentación.

### N4. Cierre mejorado

El slide final ahora lista la cadena completa:

> *"Unidad → cobertura → mocking → integración → property-based → fuzzing → vectores de prueba → verificación formal."*

La adición de "integración" en la cadena es coherente con la corrección T5.

---

## Tabla resumen

| # | Severidad | Problema | Estado en v2 |
|---|---|---|---|
| T1 | 🔴 Alta | Ariane 5: `as i16` no reproduce el bug de Ada | ❌ Persiste |
| T2 | 🟡 Media | Mutation testing ausente | ❌ Persiste |
| T3 | 🟡 Media | `#[should_panic]` sin `expected` | ❌ Persiste |
| T4 | 🟡 Media | Fuzzing sin sanitizers | ❌ Persiste (GhostWrite agrega valor pero no resuelve) |
| T5 | 🟡 Media | Tests de integración ausentes | ✅ Corregido |
| T6 | 🟡 Media | Fuzz diferencial sin definir | ❌ Persiste |
| T7 | 🟡 Media | TDD no mencionado | ❌ Probablemente persiste |
| T8 | 🟢 Baja | Idempotencia redundante en sort | — Sin cambios |
| T9 | 🟢 Baja | Imprecisiones en tabla de verificación formal | — Sin cambios |
| T10 | 🟢 Baja | Dijkstra fecha | ✅ Ambas fechas presentes |
| T11 | 🟢 Baja | Mock vs Spy confuso | ✅ Corregido |
| T12 | 🟢 Baja | Vectores NIST sin explicar | — Sin cambios |
| T13 | 🟢 Info | Ejemplo Lean correcto | — Sin cambios |

---

## Veredicto

La versión 2 incorpora **3 correcciones** de la revisión original (T5, T10, T11) y agrega **4 mejoras nuevas** (Agenda, GhostWrite, Bibliografía, cobertura por funciones). Es una mejora significativa en estructura y rigor académico.

Sin embargo, el **error de alta severidad (T1)** sigue sin corregir. El pseudocódigo del Ariane 5 sigue usando `as i16`, que en Rust satura silenciosamente — lo opuesto a lo que ocurrió en Ada (excepción no manejada). Esto es lo más urgente.

De los errores de severidad media, **T5 y T11 fueron corregidos**, pero **T2, T3, T4, T6 y T7 persisten**. Las correcciones prioritarias siguen siendo:

1. **T1** — Cambiar `as i16` por `i16::try_from().expect()` y aclarar que el lenguaje era Ada
2. **T3** — Agregar `expected = "..."` al `#[should_panic]`
3. **T2** — Mencionar mutation testing como puente desde cobertura
4. **T4** — Mencionar sanitizers en fuzzing
5. **T6** — Definir fuzz diferencial en una línea
