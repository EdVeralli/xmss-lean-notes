# Hash-Based Multi-Signatures for Post-Quantum Ethereum

**Autores:** Justin Drake, Dmitry Khovratovich, Mikhail Kudinov, Benedikt Wagner
**Institución:** Ethereum Foundation / TU Eindhoven
**Publicado en:** IACR Communications in Cryptology, Vol. 2, Issue 1
**DOI:** 10.62056/aey7qjp10

---

## Motivación

Ethereum usa BLS signatures para el consenso proof-of-stake: los validadores firman bloques individualmente y esas firmas se agregan en una única firma compacta. BLS es vulnerable a computadoras cuánticas (se basa en el problema del logaritmo discreto en curvas elípticas). Si Ethereum no migra a tiempo, un adversario con una computadora cuántica podría comprometer el consenso.

El paper propone una familia de esquemas de **multi-firmas basadas en hashes** como reemplazo post-cuántico de BLS. Las firmas basadas en hashes son atractivas porque:
- Sus suposiciones de seguridad son mínimas (solo propiedades de funciones hash)
- Son conceptualmente simples
- No usan álgebra compleja

El desafío central es que las firmas basadas en hashes **no tienen estructura algebraica**, por lo que no soportan agregación nativa como BLS. La solución propuesta es agregar usando **pqSNARKs** (argumentos sucintos post-cuánticos).

---

## El Problema del Random Oracle Paradox

Este es uno de los puntos más importantes del paper y la razón por la que no se puede simplemente tomar XMSS existente y meterlo en un SNARK.

Cuando se usa un pqSNARK para agregar firmas, el verificador del esquema de firma se convierte en un **circuito** que el SNARK tiene que probar. El problema surge si la prueba de seguridad del esquema de firma modela las funciones hash como **random oracles**: en ese caso, el SNARK estaría probando un circuito que contiene llamadas a un random oracle, lo cual es una contradicción — no se puede modelar una función como random oracle y a la vez tratarla como un circuito explícito.

**Solución del paper:** probar la seguridad del esquema asumiendo propiedades concretas del **modelo estándar** sobre las funciones hash (resistencia a colisiones, resistencia a preimagen, indetectabilidad), sin usar random oracles. Esto elimina la paradoja y además le da a los criptanalistas objetivos concretos para analizar.

---

## El Esquema: XMSS Generalizado

El esquema sigue el paradigma clásico de XMSS (eXtended Merkle Signature Scheme):

### Estructura básica

1. **Firmas one-time (OTS):** cada clave secreta solo puede usarse una vez de forma segura. Se usan variantes de Winternitz OTS.
2. **Árbol de Merkle:** el firmante construye un árbol de Merkle comprometiendo a una secuencia larga de claves públicas OTS. La raíz del árbol es la clave pública many-time.
3. **Firma del i-ésimo mensaje:** se firma con la i-ésima clave OTS y se incluye el camino de Merkle que vincula esa clave OTS con la raíz.

Esto produce un **synchronized signature scheme**: cada clave tiene un lifetime `L` y se usa exactamente una firma por época (slot). Esto es ideal para proof-of-stake, donde cada validador firma exactamente un bloque por época.

### Hash Chains

El mecanismo interno de Winternitz usa **cadenas de hash**: dado un valor secreto `x`, se aplica la función hash `w` veces para obtener la clave pública correspondiente. Para firmar un dígito `d` (en base `2^w`), se revelan los primeros `d` pasos de la cadena. El verificador completa el resto de la cadena para llegar a la clave pública.

---

## Concepto Nuevo: Incomparable Encodings

Este es uno de los aportes más novedosos del paper.

Para unificar múltiples variantes de XMSS en un solo framework con una única prueba de seguridad, los autores introducen la noción de **incomparable encoding schemes**.

### Intuición

En Winternitz, el mensaje se convierte en una secuencia de dígitos `x = (x_1, ..., x_v)`. La propiedad clave es que el código es **incomparable**: para dos codewords distintos `x` y `x'`, ninguno puede dominar al otro coordinada a coordinada. Es decir, siempre existe algún índice donde `x_i < x'_i` y otro donde `x'_j < x_j`. Sin esta propiedad, un adversario podría falsificar firmas "subiendo" valores en las cadenas.

### Definición formal

Un incomparable encoding `IncEnc: P × {0,1}^lmsg × R × [L] → C ∪ {⊥}` mapea mensajes a codewords en un código `C ⊆ {0,...,2^w-1}^v` tal que cualesquiera dos codewords distintos son incomparables.

### Por qué es útil

Permite abstraer la prueba de seguridad de XMSS de forma que cualquier encoding incomparable válido produce un esquema seguro. Los autores luego instancian este concepto de dos maneras:

1. **Winternitz clásico** — hashing del mensaje + checksum
2. **Target Sum Winternitz** — sin checksum, con control explícito sobre la cantidad de hashes en verificación

---

## Dos Instanciaciones de Incomparable Encodings

### 1. Winternitz Clásico (W)

- El mensaje se hashea a `n0` dígitos en base `2^w`.
- Se agrega un **checksum** de `n1` dígitos que garantiza la incomparabilidad.
- Error `δ = 0` (nunca falla, siempre produce un codeword válido).
- Desventaja: el número de hashes en verificación varía según el mensaje → un adversario podría enviar una firma con máximo costo de verificación.

### 2. Target Sum Winternitz (TSW) — más novedoso

- El mensaje se hashea a `v` dígitos en base `2^w`.
- Se exige que la suma de los dígitos sea exactamente igual a un target `T`.
- Si no se cumple, se rehashea con nueva aleatoriedad hasta lograrlo (hasta `K` intentos).
- **Sin checksum** → firma más chica.
- La incomparabilidad se garantiza por la restricción de suma constante.
- **Ventaja clave:** el número de hashes en verificación es **determinístico** (siempre exactamente `v(2^w - 1) - T`), lo que hace que el costo del circuito SNARK sea predecible.
- Se puede ajustar `T > v(2^w-1)/2` para reducir hashes en verificación a cambio de más reintentos en firma.

---

## Framework de Análisis Unificado (Teorema Principal)

El Teorema 1 del paper prueba que la seguridad del esquema XMSS generalizado se reduce a:

- **SM-TCR** (Multi-Target Collision Resistance) de la función hash `Th`
- **T-COLL-RES** (Target Collision Resistance) del encoding `IncEnc`
- **SM-UD** (Multi-Target Undetectability) de `Th`
- **SM-PRE** (Multi-Target Preimage Resistance) de `Th`

Todo en el **modelo estándar**, sin random oracles. La prueba sigue una secuencia de juegos (game-based proof) que va descartando distintos tipos de falsificaciones.

---

## Strong Unforgeability

Otro aporte novedoso: el paper prueba **strong unforgeability** (SUF-CMA), no solo existential unforgeability.

- **Existential unforgeability:** el adversario no puede producir una firma válida para un mensaje que nunca fue firmado.
- **Strong unforgeability:** el adversario no puede producir **ninguna** firma válida nueva, ni siquiera para un mensaje que ya fue firmado (con una firma diferente).

Esto es importante en sistemas complejos como Ethereum donde la firma pasa por múltiples capas. Trabajos previos sobre XMSS solo probaban existential unforgeability.

---

## Construcción de Multi-Firmas

Para pasar de firmas individuales a multi-firmas, se usa el siguiente approach:

1. Cada validador firma independientemente con su XMSS → produce `σ_i`.
2. Un **agregador** recoge todas las firmas y compute un pqSNARK que prueba conocimiento de `k` firmas individuales válidas.
3. La firma agregada `σ̄` es simplemente el string del argumento SNARK.
4. Verificar: correr el verificador del SNARK.

La prueba de seguridad (Teorema 2) reduce la seguridad de la multi-firma a:
- Knowledge soundness del pqSNARK (en forma **adaptiva y straight-line**)
- Seguridad del esquema de firma individual

### Requisito crítico: Adaptive Knowledge Soundness

El paper identifica que el pqSNARK debe ser **adaptive** knowledge-sound: el statement (lista de claves públicas + mensaje) puede depender de consultas al random oracle. Los SNARKs existentes generalmente prueban solo la versión no-adaptiva. Verificar la versión adaptiva en el modelo cuántico es trabajo futuro abierto.

---

## Instanciaciones de Tweakable Hash Functions

Las funciones hash se instancian como **tweakable hash functions**: `Th: P × T × M → H`, donde:
- `P` es un parámetro público aleatorio (compartido por el usuario)
- `T` es un tweak (identificador único de la llamada, para domain separation)
- `M` es el mensaje

Esto permite reutilizar una sola función hash para todos los roles (cadenas, árbol de Merkle, hashing de mensajes) con separación de dominio garantizada.

### SHA-3 (opción conservadora)
- `ThSHA3(P, T, M) = Truncate_n(SHA-3(P || T || M))`
- Bien analizado, sin ataques conocidos.

### Poseidon2 (opción moderna, optimizada para SNARKs)
- Opera sobre elementos de un campo primo `F_p`.
- Mucho más eficiente dentro de circuitos aritméticos (SNARKs).
- Usa modo compresión para cadenas y árbol, modo esponja para hashing de hojas.
- ~10x más lento en software que SHA-3, pero ideal para minimizar el costo del SNARK.

---

## Resultados de Eficiencia

Parámetros usados: seguridad NIST Level 1 (`k_C = 128` bits clásicos, `k_Q = 64` bits cuánticos).

### Con SHA-3 (mejor balance: TSW, w=2, δ=1.1, L=2^18)

| Métrica | Valor |
|---|---|
| Tamaño de firma | ~2.22 KiB |
| Tiempo de generación de claves | ~16 s |
| Tiempo de firma | ~55 µs |
| Tiempo de verificación | ~26 µs |
| Hashes en verificación (avg) | ~259 |

### Con Poseidon2

- Firmas ligeramente más grandes (~2.65 KiB para los mismos parámetros).
- ~10x más lento en CPU.
- Pero permite minimizar el costo del SNARK, que es lo que importa para agregación.

### Estimado de agregación

- Usando ~160 operaciones hash por firma (TSW, w=2, δ=1.1 con Poseidon2).
- Se estima factible agregar hasta **10,000 firmas por segundo**.
- Tamaño del aggregate signature con Plonky3 (FRI): **2–3 MB** (viable cuando hay >1000 signers).
- Con STIR/WHIR en lugar de FRI, potencialmente por debajo de **1 MB**.

---

## Comparación con Trabajos Relacionados

| Trabajo | Tipo | Agrega | Tamaño individual | Rigor |
|---|---|---|---|---|
| Este paper | XMSS many-time + pqSNARK | Sí, no-interactivo | ~1–4 KiB | Formal completo |
| Khaburzaniya et al. [KCLM22] | OTS + STARKs | Sí | ~8 KiB | Proof sketches |
| Squirrel/Chipmunk [FSZ22, FHSZ23] | Lattice XMSS | Sí | >32 KiB | Formal |
| SPHINCS+ | Many-time stateless | No | ~8–50 KiB | Formal |

---

## Propiedades Estándar Requeridas de las Funciones Hash

El paper especifica exactamente qué propiedades necesitan satisfacer las funciones hash, dándole a los criptanalistas objetivos concretos:

- **SM-TCR** (Single-function Multi-Target Collision Resistance): difícil encontrar colisiones en múltiples targets simultáneos.
- **SM-PRE** (Single-function Multi-Target Preimage Resistance): difícil encontrar preimágenes de múltiples targets.
- **SM-UD** (Single-function Multi-Target Undetectability): las salidas de la función hash son indistinguibles de aleatorio.
- **SM-rTCR** (Multi-Target Collision Resistance with Random Sampling): variante nueva del paper para manejar encodings aleatorizados que pueden fallar.

Para cada propiedad se dan cotas en los modelos ROM clásico y cuántico (algunas son nuevas aportaciones del paper, ver Tabla 1 y apéndices).

---

## Resumen de Novedades Principales

1. **Framework de incomparable encodings** — nueva abstracción que unifica múltiples variantes de XMSS en una sola prueba de seguridad genérica y ajustada.

2. **Target Sum Winternitz** — instanciación que elimina el checksum y da control determinístico sobre el costo de verificación, clave para eficiencia en SNARKs.

3. **Prueba de seguridad en modelo estándar** — sin random oracles en el verificador, resolviendo el Random Oracle Paradox.

4. **Strong unforgeability** — primer análisis de XMSS con esta noción más fuerte.

5. **SM-rTCR** — nueva noción de seguridad para funciones hash que captura encodings aleatorizados con posibilidad de fallo.

6. **Nuevas cotas en ROM/QROM** — para preimage resistance sin conjeturas, y para collision resistance con `|P|` arbitrario (no potencia de 2).

7. **Characterización precisa del pqSNARK requerido** — adaptive straight-line knowledge soundness, y discusión de por qué las construcciones existentes no la satisfacen formalmente todavía.

---

## Trabajo Futuro Abierto

- Verificar que pqSNARKs concretos (Plonky3, stwo) satisfacen adaptive knowledge soundness en el modelo cuántico.
- Benchmarks concretos de agregación con implementaciones reales de pqSNARKs.
- Lifetimes más largos (`L = 2^32`) con manejo de memoria eficiente (multi-tree XMSS).
- Combinación con optimizaciones de circuitos del trabajo de Khaburzaniya et al.
