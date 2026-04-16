# Revisión — articulo_saei_55jaiio_short_formatted.docx

Revisión del documento corregido, contrastando contra los errores detectados en las versiones anteriores (v3.pdf y short.pdf).

---

## Parte 1: Revisión de Forma

### Errores anteriores — estado en esta versión

| # | Error original | Estado | Detalle |
|---|---|---|---|
| 1 | Estado del proyecto contradictorio | ✅ Corregido | Ahora dice "currently under development" (EN) y "en desarrollo" (ES). Consistente. |
| 2 | DWSIM/Aspen en tabla inconsistente | ✅ Corregido | Tabla reescrita: DWSIM y PhET como entradas separadas, Aspen eliminado. DWSIM tiene "Sí (GPL)". |
| 3 | Trabajo futuro con items distintos | N/A | Versión única, no hay discrepancia entre versiones. |
| 4 | Diagrama de arquitectura distinto | N/A | Versión única. |
| 5 | Observaciones sin metodología | ✅ Corregido | Eliminadas las observaciones anecdóticas sin respaldo metodológico. |
| 6 | 4 issues no resueltos sin explicar | ✅ Eliminado | El dato de "15 issues / 11 resueltos" fue removido del texto. |
| 7 | Replicabilidad afirmada sin evidencia | ✅ Corregido | Ahora dice "potencial de replicabilidad" y agrega limitaciones explícitas: "la efectividad deberá ser validada en contextos distintos", "se limita a cuatro equipos en una única institución". |
| 8 | Nota de IA distinta | ⚠️ Ausente | No se encuentra la nota de uso de IA en el texto extraído. Si el formato del congreso la exige, hay que agregarla. |
| 9 | PhET sin justificación | ✅ Corregido | PhET ahora tiene "Sí" en código abierto, ya no "Parcial". |
| 10 | Registro narrativo inconsistente | ✅ Corregido | Registro impersonal consistente en todo el paper: "Se presenta...", "La suite ocupa...", "Se presentó...". Los abstracts no usan primera persona. |

### Errores nuevos detectados

#### F1. Escala del proyecto cambió sustancialmente — 🟡 Media

La versión anterior describía 2 equipos con 6 simuladores. Esta versión describe **4 equipos con 20 prácticas en 4 ejes temáticos**. Es un salto enorme de alcance. Si ambas versiones describen el mismo proyecto real, una de las dos es incorrecta. Si el proyecto creció, el paper no explica el cambio. Si un revisor vio la versión anterior, va a notar la discrepancia.

**Recomendación:** si se submitea esta versión como nueva, no hay problema. Si es una revisión de la anterior, hay que justificar el cambio de escala.

---

#### F2. Arquitectura de 5 capas — aparece sin antecedente — 🟢 Baja

La versión anterior describía una arquitectura modular (React + FastAPI + Docker) con módulos independientes. Esta versión describe una "arquitectura de cinco capas" completamente distinta (modelo fisicoquímico → ruido → instrumentos → eventos/gamificación → UI). No es una evolución sino un replanteamiento. Internamente consistente en esta versión, pero muy distinto a lo anterior.

---

#### F3. Nota de uso de IA ausente — 🟡 Media

La versión anterior incluía una nota explícita: "Durante la preparación de este trabajo se utilizaron herramientas de IA generativa para mejorar el lenguaje y la organización del manuscrito." Esta versión no la incluye. Si las normas de JAIIO/SAEI exigen declaración de uso de IA, su ausencia puede ser motivo de desk-reject.

**Recomendación:** verificar las normas del congreso y agregar la nota si es requerida.

---

#### F4. Referencias reducidas — 🟢 Baja

La versión anterior tenía 14 referencias. Esta tiene 5 (Denny, Kapici, Lehtola, López Rodríguez, Prather). Faltan varias que respaldaban claims importantes: Bazie (laboratorios virtuales), Shihab (GitHub Copilot), Tenhunen (capstone courses), Koster (Q-sort competencias), Wang (crecimiento publicaciones post-pandemia), Korpimies (LLMs irrestrictos), Lyu (tutor basado en LLM). La versión short tiene restricciones de espacio, pero eliminar 9 de 14 referencias debilita el respaldo bibliográfico del marco teórico — que también fue reducido o eliminado.

---

#### F5. Cuadro 1 — formato de tabla difícil de leer — 🟢 Baja

El Cuadro 1 lista las 20 prácticas como texto corrido en una columna. En un paper de 5 páginas donde la tabla es el elemento central de la contribución (muestra qué se implementó), el formato podría ser más legible: una fila por práctica o al menos separación clara entre los items de cada grupo.

---

### Resumen de forma

**Correcciones logradas:** 7 de 10 errores originales fueron corregidos o ya no aplican. Es una mejora sustancial.

**Errores nuevos:** 1 de severidad media (nota de IA ausente), 1 de severidad media condicional (cambio de escala, solo si es revisión de la versión anterior), y 2 menores.

**Veredicto de forma:** El documento está significativamente más limpio que las versiones anteriores. El registro narrativo es uniforme, los claims están condicionados, las tablas son coherentes. Si se agrega la nota de uso de IA (si es requerida), está listo para submitear desde el punto de vista formal.

---

## Parte 2: Revisión Técnica

### Errores anteriores — estado en esta versión

| # | Error original | Severidad final | Estado | Detalle |
|---|---|---|---|---|
| 1 | pH punto de equivalencia | ✅ No era error | N/A | El simulador de titulación ya no se describe en detalle. |
| 2 | VLE / Raoult sin azeótropos | 🟡 Media | ⚠️ Persiste parcialmente | El Cuadro 1 lista "equilibrio líquido-vapor (Raoult)" sin aclarar qué mezclas. La Discusión no menciona limitaciones del modelo ideal. |
| 3 | R² y heteroscedasticidad | 🟢 Baja | N/A | No se menciona R² ni comparación de linealizaciones en esta versión. |
| 4 | Citas sin DOI | 🟢 Baja | ✅ Corregido | Shihab y Bazie fueron eliminados del texto. Las 5 citas restantes tienen DOI (excepto López Rodríguez que no tiene, lo cual es aceptable para una revista española de 2012). |
| 5 | Ruido aditivo vs multiplicativo | 🟡 Media | ⚠️ Parcialmente corregido | El paper ahora describe "tres componentes: instrumental, error humano y bias sistemático" en la Capa 2. Es más preciso que "ruido gaussiano 1-5%" pero sigue sin especificar el modelo estadístico de cada componente (¿aditivo, multiplicativo, distribución?). |
| 6 | θ en Langmuir vs Freundlich | 🔴 Alta | ⚠️ No verificable | El Cuadro 1 lista "adsorción (Langmuir/Freundlich)" pero no da las ecuaciones. Si la implementación sigue usando θ para ambas isotermas, el error persiste. No se puede confirmar ni descartar desde el texto. |
| 7 | Balance calorímetro | 🟢 Baja | N/A | "Calorimetría de neutralización" aparece solo en el Cuadro 1, sin detalle de ecuaciones. |
| 8 | Regla IA sin verificación | 🟢 Baja | ✅ Mejorado | Ahora dice "con revisión obligatoria en pull requests de todo código generado por IA". Es un mecanismo concreto de verificación. |
| 9 | PRNG no especificado | ✅ No era error | ✅ Corregido igualmente | Ahora especifica "numpy.random.default_rng" — PRNG concreto documentado. |

### Errores técnicos nuevos

#### T1. Claim de 20 prácticas sin evidencia de completitud — 🟡 Media

El paper dice "cuatro equipos desarrollan 20 prácticas interactivas" y el Cuadro 1 lista exactamente 20. Pero las conclusiones dicen "Como trabajo futuro se prevé **completar las 20 prácticas**". Hay una tensión: ¿las 20 están desarrolladas o están pendientes de completar? El abstract dice "develop" (presente continuo), sugiriendo que están en desarrollo, no terminadas. El Cuadro 1 las lista como si existieran todas.

**Recomendación:** aclarar cuántas prácticas están operativas vs cuántas están planificadas. Un revisor va a preguntar.

---

#### T2. Modelo de consecuencias de error — claim sin especificación — 🟡 Media

La Capa 4 describe un "motor de consecuencias de error" que "genera datos incorrectos cuando el estudiante omite pasos del protocolo" y "gamificación con puntuación y badges". Esto es un claim técnico fuerte pero no se da ningún ejemplo concreto. ¿Qué pasa si el estudiante no calibra el instrumento? ¿Qué tipo de datos incorrectos se generan? ¿Cómo se calcula la puntuación? En un paper que describe una arquitectura de 5 capas, la capa más innovadora (consecuencias de error + gamificación) es la menos especificada.

**Recomendación:** un ejemplo concreto de una consecuencia de error en una práctica específica fortalecería mucho el claim.

---

#### T3. Voltamperometría cíclica y Butler-Volmer — complejidad no trivial — 🟢 Baja

El Cuadro 1 lista prácticas de alta complejidad técnica: voltamperometría cíclica, ecuación de Butler-Volmer/Tafel, cinética enzimática (Michaelis-Menten), difusión en gel (Fick). Simular estas correctamente requiere resolver ecuaciones diferenciales parciales (Fick) o implementar modelos electroquímicos no lineales (Butler-Volmer). Si el paper afirma que se implementan y no se implementan, es un problema serio. El paper no distingue entre prácticas implementadas y planificadas.

**Recomendación:** vinculado con T1 — aclarar el estado de completitud de cada práctica.

---

#### T4. Tres componentes de ruido sin modelo formal — 🟢 Baja

La Capa 2 describe tres componentes de ruido: "instrumental, error humano y bias sistemático". Esta es una mejora respecto a "ruido gaussiano 1-5%", pero sigue sin especificar:
- ¿Qué distribución tiene cada componente?
- ¿Cómo se combinan? ¿Aditivos? ¿Multiplicativos?
- ¿El bias es constante o varía con el tiempo?

Para un paper de 5 páginas esto puede ser aceptable — el detalle podría ir en la versión larga o en documentación del código.

---

### Resumen técnico

**Error real confirmado que persiste:** La notación θ en Freundlich (error #6 original) no se puede verificar desde el texto porque las ecuaciones fueron removidas, pero el error podría seguir en la implementación.

**Errores técnicos nuevos:** El más importante es T1 — la tensión entre "20 prácticas" en el Cuadro 1 y "completar las 20 prácticas" en el trabajo futuro. Un revisor va a preguntar cuántas existen realmente.

**Veredicto técnico:** El paper mejoró significativamente al eliminar detalles técnicos que generaban errores verificables. La estrategia de describir la arquitectura sin entrar en ecuaciones específicas reduce la superficie de error, pero crea claims que no se pueden verificar (ni refutar). Los errores nuevos son de consistencia interna (T1) y falta de especificación (T2), no de incorreción técnica.

---

## Veredicto general

Esta versión es sustancialmente mejor que las anteriores. La mayoría de los errores de forma fueron corregidos, el registro narrativo es uniforme, los claims de replicabilidad están condicionados, y la bibliografía (aunque reducida) tiene DOIs.

Los problemas que quedan son:

1. **T1 (media):** Ambigüedad sobre cuántas de las 20 prácticas existen realmente — el Cuadro las lista todas pero las conclusiones dicen "completar". Esto es lo más urgente de corregir.
2. **F3 (media):** Nota de uso de IA ausente — verificar normas JAIIO y agregar si es requerido.
3. **Error #6 original:** La notación θ en Freundlich podría persistir en la implementación, pero no es verificable desde este texto.
4. **T2 (media):** El motor de consecuencias de error, siendo la feature más innovadora, merece al menos un ejemplo concreto.

**Recomendación final:** con las correcciones de T1 (aclarar estado de las 20 prácticas) y F3 (nota de IA), el paper está en condiciones de submitear.
