# Revisión Técnica — Artículo SAEI / 55 JAIIO

Análisis de errores técnicos, imprecisiones científicas y claims sin respaldo.
*(Los errores de forma están en `revision_articulo_jaiio.md`)*

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
