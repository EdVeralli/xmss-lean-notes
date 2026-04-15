# Revisión — Artículo SAEI / 55 JAIIO

Análisis de inconsistencias, errores y puntos difusos detectados en:
- `articulo_saei_55jaiio_v3.pdf` (versión larga, 10 páginas)
- `articulo_saei_55jaiio_short.pdf` (versión corta, 5 páginas)

---

## 🔴 Problemas de alta severidad (1, 3, 7)

### 1. Estado del proyecto — contradictorio entre versiones

Las dos versiones describen el estado del proyecto de forma incompatible:

| Versión | Frase | Tiempo verbal |
|---|---|---|
| v3 abstract | *"project **developed** during the first semester of 2026"* | Pasado → suena terminado |
| short abstract | *"**ongoing** integrator project"* | Presente → claramente en curso |
| v3 body | *"al momento de la redacción..."* | En curso |

Un revisor que lea el abstract de v3 va a asumir que el proyecto ya terminó. El body contradice eso. La versión short es más honesta pero inconsistente con v3.

**Corrección sugerida:** unificar en ambos abstracts con *"an integrator project currently under development during the first semester of 2026"*.

---

### 3. Trabajo futuro — listas distintas entre versiones

**v3 lista:**
- Ampliar suite con reactores CSTR/PFR y transferencia de calor
- Incorporar gamificación con niveles de dificultad progresivos
- Diseñar estudio cuasi-experimental
- Formalizar el vínculo interdepartamental como línea permanente

**short lista:**
- Completar y desplegar los 6 simuladores ← *no está en v3*
- Probar con estudiantes de ingeniería química en Q2 2026 ← *no está en v3*
- Ampliar suite con CSTR/PFR
- Niveles de dificultad controlados por semillas
- Diseñar estudio cuasi-experimental

La short agrega dos items que no están en v3 y omite "formalizar el vínculo interdepartamental". Si son el mismo trabajo, el trabajo futuro debería ser idéntico o la diferencia debería estar justificada.

**Corrección sugerida:** unificar las dos listas. La versión corta puede resumir pero no puede agregar ni quitar items sustanciales.

---

### 7. Claim de replicabilidad sin evidencia 🔴

> *"El modelo es replicable: cualquier cátedra de programación puede establecer un vínculo análogo"*

Esta afirmación aparece en ambas versiones, pero el proyecto todavía no terminó. En un paper académico serio con marco teórico y revisiones sistemáticas, afirmar replicabilidad de algo en curso y sin validación externa es un claim que no se sostiene. Un revisor de SAEI lo va a cuestionar — es exactamente el tipo de afirmación que distingue un paper maduro de uno prematuro.

**Corrección sugerida:** condicionar la afirmación: *"El modelo tiene potencial de replicabilidad: la estructura de tres ejes (cliente real, software libre, IA supervisada) es transferible a otras cátedras de programación, aunque su efectividad deberá ser validada en contextos distintos."*

---

## 🟡 Problemas de severidad media (2, 4, 5, 6)

### 2. Tabla de comparación — DWSIM / código abierto

*(movido de alta a media — es inconsistencia de presentación, no error de contenido)*

| Versión | Columna | Código abierto |
|---|---|---|
| v3 | "Aspen/DWSIM" | Parcial |
| short | "DWSIM" | Sí |

Aspen Plus es software comercial. DWSIM es genuinamente open source (licencia MIT/GPL). Agruparlos en v3 y marcarlos como "Parcial" es impreciso. La short los separó pero sin explicar el cambio. Es una inconsistencia de presentación entre versiones, no un error de contenido.

**Corrección sugerida:** usar solo DWSIM (open source = Sí) y eliminar Aspen de la tabla, o listarlos por separado con sus propias columnas.

---

### 4. Diagrama de arquitectura — módulos inconsistentes

| Versión | Módulos mostrados explícitamente |
|---|---|
| v3 | Cinética \| Titulación \| Equilibrio \| Adsorción \| +2 más |
| short | Cinética \| Titulación \| VLE \| +3 más |

Distintos módulos explícitos, distinto conteo implícito. Ambos suman 6 en total, pero el diagrama debería ser el mismo en las dos versiones.

---

### 5. Observaciones preliminares sin metodología

La sección de observaciones del short dice:

> *"los estudiantes reportan que la IA fue más útil en la fase de investigación de dominio que en la de implementación"*

No se especifica cómo se recolectó esta información. ¿Encuesta formal? ¿Comentarios informales en clase? ¿Cuántos estudiantes? Sin metodología, es una anécdota presentada como observación académica.

> *"La confianza para formular preguntas precisas creció a lo largo del cuatrimestre"*

No hay métrica. ¿Cómo se midió "confianza"? ¿Qué se considera una "pregunta precisa"?

**Corrección sugerida:** o agregar la metodología de recolección ("en comentarios escritos al final de cada sprint...") o cambiar el registro a primera persona explícita ("observamos informalmente que...").

---

### 6. Los 4 issues no resueltos quedan en el aire

El paper dice: *"se identificaron 15 issues de modelado, de los cuales 11 fueron resueltos"*.

No se dice nada sobre los 4 restantes. ¿Son menores? ¿Afectan la validez de los simuladores? ¿Están en el backlog? Un revisor puede preguntar si esos 4 issues comprenden la corrección matemática de los modelos.

**Corrección sugerida:** agregar una oración aclarando el estado de los 4 issues pendientes ("los 4 restantes corresponden a mejoras de interfaz no críticas para la validez del modelo").

---

### 10. Registro narrativo inconsistente — primera persona vs impersonal

El paper alterna entre registro impersonal y primera persona plural sin criterio uniforme:

| Ubicación | Registro | Ejemplo |
|---|---|---|
| Abstract EN (v3 y short) | Primera persona | *"We describe the methodology..."* |
| Abstract ES (v3 y short) | Impersonal | *"Se describen los fundamentos..."* |
| Body secciones 1-5 | Impersonal | *"Se modelan...", "La experiencia se desarrolla...", "Se implementan..."* |
| Discusión (v3) | Primera persona posesiva | *"Nuestra suite ofrece..."* |
| Conclusiones (v3) | Impersonal | *"Este artículo presentó la metodología..."* |

El body mantiene un tono impersonal coherente durante casi todo el paper, pero los abstracts en inglés usan "We" y la Discusión se desliza hacia "Nuestra suite". En español académico ambos registros son aceptables, pero hay que elegir uno y mantenerlo. La mezcla da impresión de falta de revisión final.

**Corrección sugerida:** unificar todo el paper a un mismo registro. Lo más natural para el tono del paper sería impersonal en español ("Se describe...", "La suite ofrece...") y primera persona plural en el abstract en inglés ("We describe..."), que es la convención más común en papers bilingües. Pero lo importante es la consistencia interna: si la Discusión dice "Nuestra suite", entonces las Conclusiones no deberían decir "Este artículo presentó" como si fuera otro autor.

---

## 🟢 Problemas de baja severidad (8, 9)

### 8. Nota de IA — diferencia menor entre versiones

| Versión | Texto |
|---|---|
| v3 | *"para mejorar el lenguaje **y la organización** del manuscrito"* |
| short | *"para mejorar el lenguaje del manuscrito"* |

Pequeño pero inconsistente. Si se usó IA también para organizar, ambas versiones deberían decirlo.

---

### 9. PhET clasificado como "Código abierto: Parcial" sin explicación

PhET Interactive Simulations (Universidad de Colorado) es mayoritariamente open source. Marcarlo como "Parcial" sin aclarar qué parte no lo es puede ser cuestionado por revisores que conocen la plataforma. Si la clasificación es correcta, hay que justificarla brevemente en una nota al pie.

---

## Resumen ejecutivo

| # | Problema | Severidad | Versiones afectadas |
|---|---|---|---|
| 1 | Estado del proyecto contradictorio | 🔴 Alta | Ambas |
| 2 | DWSIM/Aspen en tabla inconsistente | 🟡 Media | Ambas |
| 3 | Trabajo futuro con items distintos | 🔴 Alta | Ambas |
| 4 | Diagrama de arquitectura distinto | 🟡 Media | Ambas |
| 5 | Observaciones sin metodología | 🟡 Media | Short |
| 6 | 4 issues no resueltos sin explicar | 🟡 Media | Ambas |
| 7 | Replicabilidad afirmada sin evidencia | 🔴 Alta | Ambas |
| 8 | Nota de IA distinta | 🟢 Baja | Ambas |
| 9 | PhET sin justificación | 🟢 Baja | Ambas |
| 10 | Registro narrativo inconsistente (1ra persona vs impersonal) | 🟡 Media | Ambas (peor en v3) |

### Nota sobre la calibración

Este paper es una contribución académica seria — con marco teórico, revisiones sistemáticas y metodología formal — no un borrador informal ni un poster. Los errores de forma se evalúan con esa barra.

**Correcciones imprescindibles antes de submitear:**
- **Error 1** (abstract contradictorio): es lo primero que lee un revisor y la contradicción es inmediata.
- **Error 3** (trabajo futuro distinto): dos versiones del mismo paper con items de futuro distintos es inaceptable.
- **Error 7** (replicabilidad sin evidencia): afirmar que un modelo es replicable cuando aún no terminó y nadie más lo ha probado es un claim que un revisor de SAEI va a cuestionar. En un paper serio esto necesita condicionarse.

**Correcciones recomendables:**
- Errores 2, 4, 5, 6: inconsistencias entre versiones que un revisor atento va a notar. Todas son fáciles de resolver unificando ambos documentos.
- Error 10: el registro narrativo mezclado (impersonal en el body, "We" en el abstract EN, "Nuestra suite" en Discusión) da impresión de falta de revisión final. Se resuelve con una pasada de unificación.

**Menores:**
- Errores 8, 9: no van a determinar la aceptación o rechazo, pero limpiarlos mejora la presentación.
