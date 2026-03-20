# Cambios propuestos para XMSS_Post_Cuantica_posta.pptx

## Contexto

Agregar 5 slides nuevos después del slide 18 ("Lean Ethereum y la resistencia cuántica"), antes del slide 19 ("Conclusiones"). Estos slides amplían el tema con el contenido del paper "Hash-Based Multi-Signatures for Post-Quantum Ethereum" (Drake, Khovratovich, Kudinov, Wagner — Ethereum Foundation / TU Eindhoven).

Mantener el estilo visual existente: fondo oscuro (#0d1b2a o similar), títulos en blanco, texto en blanco/gris claro, destacados en naranja (#f5a623), verde (#00c48c) y azul (#4a90d9). Caja de nota al pie en gris oscuro.

---

## Slide nuevo 1 — Posición: entre slide 18 y slide 19

### Título
**El problema: agregar firmas XMSS a escala**

### Subtítulo / bajada
*El desafío central que enfrenta Lean Ethereum*

### Contenido

**Bloque izquierdo (problema):**

Con BLS (hoy):
- Agregar firmas = operación matemática simple y nativa
- 10.000 firmas → 1 firma compacta de ~96 bytes
- Tiempo: casi instantáneo

Con XMSS (post-cuántico):
- No existe agregación algebraica nativa
- Cada firma pesa ~2-3 KB
- 10.000 validadores → ~22 GB de firmas sin agregar ❌

**Bloque derecho (por qué importa):**

En cada slot de 4 segundos, el proposer necesita incluir en el bloque los votos de miles de validadores. Con firmas de ese tamaño, sin una solución de agregación, el sistema es inviable.

**Caja destacada al pie (naranja):**
> La solución no puede usar álgebra de curvas elípticas — eso rompería la resistencia cuántica. Necesita una alternativa basada en hash.

---

## Slide nuevo 2 — Posición: después del slide anterior

### Título
**La solución: pqSNARK para agregación**

### Subtítulo / bajada
*Pruebas sucintas post-cuánticas como reemplazo de la agregación BLS*

### Contenido

**Bloque A — ¿Qué es un pqSNARK?**
Una prueba criptográfica que demuestra que se ejecutó un programa correctamente, sin revelar los inputs. Es muy pequeña y rápida de verificar. La "pq" significa que también es resistente a computadoras cuánticas.

**Bloque B — El flujo de agregación:**

```
1. Cada validador firma con su XMSS → σ₁, σ₂, ..., σₖ

2. El Aggregator recibe todas las firmas y genera un pqSNARK
   que prueba: "Conozco k firmas XMSS válidas para este mensaje"

3. La firma agregada σ̄ = el argumento SNARK

4. Verificar = correr el verificador del SNARK (rápido)
```

**Tabla comparativa:**

| | Sin agregar | Con pqSNARK |
|---|---|---|
| 1.000 firmas | ~2,2 GB | ~2-3 MB |
| 10.000 firmas | ~22 GB | ~2-3 MB |
| Verificación | k verificaciones | 1 verificación |

**Caja destacada al pie (verde):**
> Con más de 1.000 firmantes, la firma agregada es más chica que cualquier firma individual. El tamaño del SNARK no crece con la cantidad de firmantes.

---

## Slide nuevo 3 — Posición: después del slide anterior

### Título
**El Random Oracle Paradox**

### Subtítulo / bajada
*Por qué no se puede tomar XMSS existente y meterlo en un SNARK directamente*

### Contenido

**Bloque izquierdo — El problema:**

Para probar que XMSS es seguro, las pruebas matemáticas clásicas asumen que la función hash se comporta como un **random oracle**: una caja negra mágica que devuelve valores completamente aleatorios.

Pero el SNARK necesita tratar la función hash como un **circuito explícito y concreto** con pasos definidos.

Son dos cosas contradictorias:

```
Prueba de seguridad de XMSS:
  "la función hash es una caja negra mágica"
              ↕ CONTRADICCIÓN
El SNARK necesita:
  "la función hash es un circuito con pasos concretos"
```

**Bloque derecho — La solución del paper:**

En vez de asumir random oracle, prueban la seguridad usando propiedades concretas de la función hash en el **modelo estándar**:

- **SM-TCR:** resistencia a colisiones multi-target
- **SM-PRE:** resistencia a preimagen multi-target
- **SM-UD:** indetectabilidad multi-target

Así la función hash puede ser un circuito concreto sin contradicción. Este es uno de los aportes más importantes del paper.

**Caja destacada al pie (azul):**
> Fuente: "Hash-Based Multi-Signatures for Post-Quantum Ethereum" — Drake, Khovratovich, Kudinov, Wagner (Ethereum Foundation / TU Eindhoven, 2025)

---

## Slide nuevo 4 — Posición: después del slide anterior

### Título
**Target Sum Winternitz (TSW)**

### Subtítulo / bajada
*La variante nueva que hace eficiente la agregación con SNARKs*

### Contenido

**Bloque izquierdo — El problema del Winternitz clásico:**

El número de hashes al verificar depende del mensaje:
- Varía en cada verificación
- El circuito del SNARK tiene **tamaño variable** → muy costoso

**Bloque derecho — La solución TSW:**

Exige que la **suma de todos los dígitos del encoding sea exactamente T** (un target fijo).

Si el hash del mensaje no suma T → se rehashea con nueva aleatoriedad hasta lograrlo.

**Ventajas:**

✅ **Sin checksum** → firma más pequeña (el Winternitz clásico necesitaba dígitos extra)

✅ **Verificación determinística** → siempre exactamente `v(2^w - 1) - T` hashes, sin importar el mensaje

✅ **Circuito SNARK de tamaño fijo** → eficiencia predecible

**Trade-off ajustable:**

```
T grande → menos hashes en verificación → más reintentos al firmar
T chico  → más hashes en verificación  → menos reintentos al firmar
```

**Caja destacada al pie (naranja):**
> TSW es una de las novedades principales del paper. Elimina el checksum y le da al circuito SNARK un tamaño fijo y predecible, clave para la eficiencia en producción.

---

## Slide nuevo 5 — Posición: después del slide anterior (antes de Conclusiones)

### Título
**Resultados concretos del paper**

### Subtítulo / bajada
*Parámetros: seguridad NIST Level 1 — 128 bits clásicos, 64 bits cuánticos*

### Contenido

**Tabla 1 — Firma individual con SHA-3 (TSW, w=2, L=2¹⁸ ≈ 260.000 slots):**

| Métrica | Valor |
|---|---|
| Tamaño de firma | ~2,22 KiB |
| Generación de claves | ~16 segundos |
| Tiempo de firma | ~55 µs |
| Tiempo de verificación | ~26 µs |
| Hashes en verificación | ~259 |

**Tabla 2 — Agregación (con Poseidon2, optimizado para SNARKs):**

| Métrica | Valor |
|---|---|
| Firmas agregadas por segundo | ~10.000 |
| Tamaño firma agregada (Plonky3/FRI) | 2-3 MB |
| Tamaño firma agregada (STIR/WHIR) | < 1 MB (estimado) |

**Nota sobre Poseidon2:**
Poseidon2 opera sobre elementos de campo primo, lo que lo hace ~10x más lento en CPU que SHA-3 pero mucho más eficiente dentro del circuito SNARK. Es la función hash recomendada para minimizar el costo de la prueba.

**Comparación con otros esquemas:**

| Esquema | Agrega | Tamaño individual |
|---|---|---|
| **Este paper** | ✅ Sí | ~1-4 KiB |
| Khaburzaniya et al. | ✅ Sí | ~8 KiB |
| Squirrel/Chipmunk | ✅ Sí | >32 KiB |
| SPHINCS+ | ❌ No | ~8-50 KiB |

**Caja destacada al pie (verde):**
> Este esquema tiene las firmas individuales más pequeñas de todos los que soportan agregación. Es la propuesta más eficiente para proof-of-stake post-cuántico a la fecha.

---

## Resumen de cambios

| # | Slide nuevo | Posición |
|---|---|---|
| 1 | El problema: agregar firmas XMSS a escala | Después de slide 18 |
| 2 | La solución: pqSNARK para agregación | Después del nuevo 1 |
| 3 | El Random Oracle Paradox | Después del nuevo 2 |
| 4 | Target Sum Winternitz (TSW) | Después del nuevo 3 |
| 5 | Resultados concretos del paper | Después del nuevo 4, antes de Conclusiones |

Total de slides final: 24 (19 existentes + 5 nuevos)
