# Revisión Técnica — Artículo SAEI / 55 JAIIO

Análisis de errores técnicos, imprecisiones científicas y claims sin respaldo.
*(Los errores de forma están en `revision_forma_jaiio.md`)*

---

## 🔴 Errores de alta severidad

### 1. Química — Titulación: cálculo del punto de equivalencia impreciso

**Sección 4.1:**
> *"se calcula el pH en el punto de equivalencia a partir de la hidrólisis"*

La descripción es ambigua. El punto de equivalencia en una titulación ácido débil–base fuerte no se calcula "por hidrólisis genérica" — requiere calcular el pH de la solución del conjugado usando Kb, que se obtiene de Kw/Ka del ácido original.

- **Caso ácido débil–base fuerte:** pH = 7 + 0.5·(pKa + log Cb), donde Cb es la concentración del conjugado.
- **Caso base débil–ácido fuerte:** análogo con Kb.

Si el código implementa una fórmula genérica de "hidrólisis" sin diferenciar estos casos, el pH en el punto de equivalencia será incorrecto. El paper no especifica qué constante se usa.

---

### 2. Química — Equilibrio VLE: modelo ideal sin aclarar limitaciones

**Sección 4.2:**
> *"Se modela el equilibrio de una mezcla binaria ideal mediante la Ley de Raoult"*

Se afirma explícitamente "ideal", pero el simulador permite "seleccionar distintas mezclas". El problema: muchas mezclas binarias comunes presentan desviaciones importantes de Raoult:

- Etanol-agua → azeótropo a ~95.6% etanol
- Acetona-cloroformo → azeótropo mínimo (γ ≠ 1)
- Benceno-metanol → sistema azeótropo

Si el simulador incluye estas mezclas con el modelo de Raoult puro, los diagramas T-x-y y P-x-y serán **incorrectos**. El paper no dice qué mezclas están disponibles ni si aplica coeficientes de actividad para las no-ideales.

---

### 3. Estadística — R² en cinética linealizada: sesgo por heteroscedasticidad

**Sección 4.4:**
> *"Las tres representaciones linealizadas ([A] vs t, ln[A] vs t, 1/[A] vs t) con las rectas de ajuste, el coeficiente R²"*

Si el ruido en [A] es aditivo (como sugiere la descripción "1-5% del valor teórico"), entonces al transformar los datos:

- En `ln[A] vs t`: el ruido se propaga como ε_ln = ε_aditivo / [A]. Cuando [A] es pequeño (final de reacción), el error relativo explota → **heteroscedasticidad severa**.
- En `1/[A] vs t`: aún peor: ε_(1/[A]) = ε_aditivo / [A]². Varianza extrema en los puntos finales.

La regresión lineal ordinaria asume homocedasticidad. Usar R² para comparar las tres linealizaciones y determinar el orden correcto **da resultados sesgados hacia el orden 2**, porque la transformación 1/[A] concentra el error en los puntos de menor peso estadístico.

**La solución correcta** es regresión ponderada (WLS). El paper no la menciona.

---

### 4. Claims de IA — Citas sin referencia completa

**Citas problemáticas:**

> *"Shihab et al. (2025) mostraron que estudiantes usando GitHub Copilot completaron tareas un 35% más rápido y con un 50% más de progreso"*

> *"Bazie et al. (2024) mostraron que el grupo con laboratorios virtuales obtuvo 11,75 puntos más"*

Ambas citas son **no verificables** tal como están. Problemas:
- No se da DOI ni URL.
- "50% más de progreso" — ¿progreso en qué métrica? ¿Líneas de código, tareas completadas, correctness?
- "11,75 puntos más" — ¿sobre una escala de cuántos puntos? Sin el máximo, el número es sin contexto.
- Para Shihab et al. (2025): la referencia en la bibliografía es incompleta (solo ACM sin DOI).

En un paper académico, estos números concretos requieren referencia completa verificable.

---

### 5. Estadística — Ruido gaussiano: aditivo vs multiplicativo no especificado

**Sección 4.4:**
> *"Los datos de concentración vs. tiempo se contaminan con ruido gaussiano configurable (1-5% del valor teórico)"*

La descripción es ambigua sobre el modelo de ruido:

- **Ruido aditivo:** c_obs = c_teor + N(0, σ), con σ = (1-5%) · c_teor → amplitud fija en valor absoluto
- **Ruido multiplicativo:** c_obs = c_teor · (1 + N(0, σ)) → error relativo constante

Estas dos implementaciones tienen consecuencias **opuestas**. Con ruido aditivo, al final de la reacción donde [A] → 0, el error relativo puede ser del 500%. Con ruido multiplicativo, el error relativo es siempre 1-5%. El paper no especifica cuál se implementó, lo que impide que los estudiantes interpreten correctamente sus resultados.

---

## 🟡 Errores de severidad media

### 6. Química — Adsorción: notación θ ambigua

**Sección 4.3:**
> *"isotermas de Langmuir (θ = KP/(1+KP)) y Freundlich (θ = kP^(1/n))"*

El símbolo θ se usa para ambas isotermas, pero hay una inconsistencia:

- En Langmuir, θ es la **fracción de cobertura** (0 ≤ θ ≤ 1) → acotada y con sentido físico.
- En Freundlich, si θ también es fracción de cobertura, la función θ = kP^(1/n) **no está acotada** cuando P → ∞, lo que es físicamente incorrecto.

En la literatura estándar, Freundlich se escribe como **q = kP^(1/n)** donde q es la cantidad adsorbida [mol/g o mg/g], sin límite superior. Usar θ para Freundlich confunde a los estudiantes.

La linealización que menciona el paper ("1/θ vs 1/P") es correcta solo si θ es la de Langmuir. Si se aplica a Freundlich con la misma variable, el resultado es incorrecto.

---

### 7. Química — Calorimetría: balance energético no especificado

**Sección 4.5:**
> *"Se calcula la variación de temperatura considerando la capacidad calorífica del calorímetro, las masas de reactivos y las pérdidas de calor configurables"*

No se escribe la ecuación de balance. Ambigüedad técnica:

- ¿Se usa Q = (m·c_solución + C_calorímetro) · ΔT?
- ¿Cómo se modelan las pérdidas de calor? ¿Modelo exponencial dT/dt = -k·(T - T_amb)?
- ¿Modelo de Dickinson para corrección de pérdidas?

Si el código usa Q = m·c·ΔT sin el término C_calorímetro, el resultado es incorrecto cuando las masas de reactivos son pequeñas.

---

### 8. Metodología — Regla de IA sin mecanismo de verificación

**Sección 3.3:**
> *"Regla explícita: todo fragmento generado por IA debe ser leído, comprendido y documentado antes de integrarse al repositorio"*

El paper no describe cómo se **verifica** esta regla. No se menciona:
- Revisión de código en pull requests con evidencia de comprensión
- Git hooks o linting que detecte código sin documentar
- Evaluación docente de la comprensión del código IA

Sin mecanismo de verificación, es una norma declarada pero no auditable.

---

### 9. Software — Sistema de semillas: PRNG no especificado

**Sección 3.2 / short:**
> *"un generador pseudoaleatorio determinista produce concentraciones iniciales, constantes cinéticas, niveles de ruido y otros parámetros"*

No se especifica:
- ¿Qué algoritmo PRNG? (MT19937 de numpy, PCG, etc.)
- ¿Cómo se asignan semillas distintas a cada grupo para garantizar unicidad?
- ¿La semilla = hash(group_id) o se generan al azar con archivo de mapeo?

Si dos grupos reciben accidentalmente la misma semilla, la ventaja pedagógica desaparece.

---

## Resumen ejecutivo

| # | Sección | Tipo | Severidad | Problema |
|---|---|---|---|---|
| 1 | 4.1 | Química | 🔴 Alta | pH en punto equivalencia sin especificar Kb/Ka |
| 2 | 4.2 | Química | 🔴 Alta | Modelo ideal sin aclarar mezclas disponibles (azeótropos) |
| 3 | 4.4 | Estadística | 🔴 Alta | R² en ln[A] y 1/[A] sesgado por heteroscedasticidad |
| 4 | Stats | Claims | 🔴 Alta | Shihab y Bazie citados sin DOI ni contexto de escala |
| 5 | 4.4 | Estadística | 🔴 Alta | Ruido aditivo vs multiplicativo no especificado |
| 6 | 4.3 | Química | 🟡 Media | θ ambigua en Langmuir vs Freundlich |
| 7 | 4.5 | Química | 🟡 Media | Balance energético calorímetro no escrito |
| 8 | 3.3 | Metodología | 🟡 Media | Regla de IA sin mecanismo de verificación |
| 9 | Seeds | Software | 🟡 Media | PRNG no especificado |

**Prioridad antes de submitear:** los errores 3 y 5 son los más graves académicamente porque afectan la validez del análisis estadístico que los estudiantes aprenden. Los errores 1 y 2 afectan la corrección matemática de los simuladores. Las citas (4) son las más fáciles de corregir.

---

## 🔄 Re-validación independiente (segunda opinión — modelo Opus)

Se realizó una segunda revisión independiente de los 9 errores listados arriba, con el objetivo de calibrar su severidad real en el contexto de un paper de herramienta educativa para JAIIO.

### Veredicto global

> **El revisor anterior fue demasiado severo, pero la segunda opinión fue demasiado indulgente.** Este paper no es "solo una herramienta educativa" — es una contribución académica seria con marco teórico, revisiones sistemáticas y metodología formal, presentada en JAIIO/SAEI ante pares que incluyen docentes de química. Eso exige una barra técnica más alta que la de un poster informal. La calibración correcta está en el medio: 1 error técnico real grave, 2 observaciones técnicas que merecen corrección (severidad media), y el resto son recomendaciones editoriales menores o no-errores.

---

### Error 1 — pH en punto de equivalencia (🔴 → ✅ NO es error)

**Veredicto re-validación: INCORRECTO. No es un error.**

La descripción "se calcula el pH por hidrólisis" es la terminología estándar en libros de química analítica de nivel universitario (Chang, Skoog). El nivel de detalle del paper (tool educativa, no paper de química) no requiere especificar qué constante se usa. Exigir que el paper documente la distinción Ka/Kb/Kw es aplicar criterios de un paper de química pura a un trabajo de ingeniería de software educativo.

---

### Error 2 — VLE / Ley de Raoult sin azeótropos (🔴 → 🟡 MEDIA)

**Veredicto re-validación: PARCIALMENTE VÁLIDO. Severidad media.**

La observación técnica sobre los azeótropos es correcta en abstracto, y el paper declara explícitamente que modela mezclas **ideales**. Sin embargo, al ser un paper académico serio con docentes de química como coautores/clientes, la omisión de qué mezclas están disponibles es relevante: si un revisor de química lee que el simulador usa Raoult y "permite seleccionar distintas mezclas" sin más aclaración, va a preguntar legítimamente si incluye sistemas no-ideales. Una nota al pie aclarando qué mezclas están implementadas resuelve el problema.

---

### Error 3 — R² y heteroscedasticidad (🔴 → 🟡 SOBREDIMENSIONADO)

**Veredicto re-validación: PARCIALMENTE VÁLIDO pero sobredimensionado.**

La observación estadística sobre WLS es técnicamente correcta. Sin embargo, el uso de R² en cursos de cinética química está completamente estandarizado en libros universitarios de nivel intro. Ningún curso de química general usa WLS — se usa OLS y R² para elegir el orden de reacción. Pedir WLS en un paper de herramienta educativa de nivel introductorio aplica estándares de un paper de estadística aplicada. La recomendación correcta sería una nota aclaratoria, no marcarlo como error grave.

---

### Error 4 — Citas sin DOI (🔴 → 🟡 SOBREDIMENSIONADO)

**Veredicto re-validación: PARCIALMENTE VÁLIDO.**

La observación sobre las citas incompletas es válida como recomendación editorial. Sin embargo, "no verificables" es excesivo: están citados con autor, año y congreso. La métrica "35% más rápido" y "11,75 puntos más" son datos de los papers citados, no del paper en revisión — si los autores confían en esos datos, es su responsabilidad verificarlos. La recomendación es agregar DOIs, no desacreditar los claims.

---

### Error 5 — Ruido aditivo vs multiplicativo (🔴 → 🟡 MEDIA)

**Veredicto re-validación: PARCIALMENTE VÁLIDO. Severidad media.**

La distinción es técnicamente correcta, y en un paper académico serio que describe la arquitectura de simuladores de laboratorio, el modelo de ruido es una decisión de diseño que merece estar documentada. No es un error que invalide la herramienta, pero sí una omisión técnica que un revisor con background estadístico va a notar, especialmente porque el paper dedica una sección entera (4.4) a describir cómo se genera el ruido y cómo los estudiantes deben analizarlo. Si el paper describe la funcionalidad con ese nivel de detalle, debería especificar si el ruido es aditivo o multiplicativo.

---

### Error 6 — Notación θ en Langmuir vs Freundlich (🟡 → 🔴 CONFIRMADO)

**Veredicto re-validación: CONFIRMADO. Este es un error real.**

Usar θ (fracción de cobertura, acotada entre 0 y 1) para representar la isoterma de Freundlich (q = kP^(1/n), no acotada) es una inconsistencia conceptual genuina en la nomenclatura estándar de adsorción. Puede generar confusión real en estudiantes que luego lean bibliografía de adsorción. La linearización "1/θ vs 1/P" también es incorrecta para Freundlich con esa notación. **Corrección recomendada:** usar `q` (cantidad adsorbida en mol/g o mg/g) para Freundlich, reservar θ solo para Langmuir.

---

### Error 7 — Balance energético calorímetro (🟡 → 🟢 SOBREDIMENSIONADO)

**Veredicto re-validación: PARCIALMENTE VÁLIDO pero sobredimensionado.**

No escribir la ecuación completa Q = (m·c + C_cal)·ΔT en el paper es una simplificación editorial típica en papers de herramientas educativas. Si el simulador la implementa correctamente (lo cual no se puede determinar desde el paper), no hay error. La recomendación es agregar la ecuación completa en el paper para claridad, no marcarlo como error.

---

### Error 8 — Regla de IA sin verificación (🟡 → 🟢 SOBREDIMENSIONADO)

**Veredicto re-validación: OBSERVACIÓN VÁLIDA, severidad sobredimensionada.**

La observación es válida como reflexión pedagógica — un paper de educación en CS podría discutir los mecanismos de enforcement. Sin embargo, la mayoría de los papers de prácticas docentes no detallan los mecanismos de verificación de reglas de aula. Es una sugerencia de mejora, no un error técnico.

---

### Error 9 — PRNG no especificado (🟡 → ✅ NO es error)

**Veredicto re-validación: INCORRECTO. No es un error significativo.**

No especificar si el PRNG es MT19937 o PCG es una observación de nivel de implementación irrelevante para un paper de herramienta educativa. La unicidad de semillas por grupo es una preocupación operativa, no técnica. Ningún paper de este tipo especifica el algoritmo PRNG. Esta observación no pertenece a una revisión académica de este nivel.

---

### Tabla re-validada

| # | Error original | Severidad original | Severidad final | Estado |
|---|---|---|---|---|
| 1 | pH punto de equivalencia | 🔴 Alta | ✅ Sin severidad | No es error |
| 2 | VLE / Raoult sin azeótropos | 🔴 Alta | 🟡 Media | Omisión técnica legítima |
| 3 | R² y heteroscedasticidad | 🔴 Alta | 🟢 Baja | Sobredimensionado (estándar pedagógico) |
| 4 | Citas sin DOI | 🔴 Alta | 🟢 Baja | Editorial, no técnico |
| 5 | Ruido aditivo vs multiplicativo | 🔴 Alta | 🟡 Media | Omisión técnica legítima |
| **6** | **θ en Langmuir vs Freundlich** | **🟡 Media** | **🔴 Alta** | **ERROR REAL CONFIRMADO** |
| 7 | Balance calorímetro | 🟡 Media | 🟢 Baja | Simplificación editorial |
| 8 | Regla IA sin verificación | 🟡 Media | 🟢 Baja | Sugerencia, no error |
| 9 | PRNG no especificado | 🟡 Media | ✅ Sin severidad | No aplica al nivel del paper |

### Recomendación final

El paper es una contribución académica seria — no solo una herramienta educativa — y merece una revisión proporcionada a ese nivel. Tiene **1 error técnico real** (notación θ en Freundlich), **2 omisiones técnicas que merecen corrección** (mezclas VLE y modelo de ruido), y varias mejoras editoriales menores. En conjunto, es un paper sólido con defectos corregibles.

La primera revisión (9 errores, 5 de alta severidad) fue excesiva: aplicó estándares de papers de química pura a un trabajo de ingeniería de software. La segunda revisión (1 solo error) fue demasiado indulgente: minimizó omisiones legítimas bajo el argumento de "es solo educativo". La calibración correcta está entre ambas.

**Correcciones imprescindibles antes de submitear:**
1. 🔴 Corregir la notación θ → q en la isoterma de Freundlich (error conceptual genuino)
2. 🟡 Especificar el modelo de ruido (aditivo o multiplicativo) en sección 4.4
3. 🟡 Aclarar qué mezclas binarias están disponibles en el simulador VLE (nota al pie)

**Mejoras editoriales recomendables:**
4. Agregar DOIs a las citas de Shihab y Bazie
5. Incluir la ecuación completa del balance calorimétrico
6. Describir brevemente cómo se verifica la regla de uso de IA
