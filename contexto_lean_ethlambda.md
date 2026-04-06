# Contexto — Investigación Lean en ethlambda / LambdaClass

## Punto de partida

Un miembro del equipo de ethlambda dijo:
> "buenas, en #ethlambda empezamos con la iniciativa de implementar partes críticas en Lean (que están en Rust)"

Esto abrió la investigación sobre qué tiene LambdaClass en Lean y qué partes de ethlambda son candidatas a ser portadas.

---

## Repos relevantes

| Repo | URL | Qué es |
|---|---|---|
| ethlambda | https://github.com/lambdaclass/ethlambda | Cliente de consenso Ethereum post-cuántico en Rust |
| leanSpec | https://github.com/leanEthereum/leanSpec | Spec ejecutable del protocolo en Python |
| xmss-lean-notes | https://github.com/EdVeralli/xmss-lean-notes | Notas y presentaciones del tema (este repo) |
| AMO-Lean | https://github.com/lambdaclass/amo-lean | Compilador verificado, Lean 4 → C/Rust, criptografía |

---

## Estado actual de ethlambda

- **100% Rust, cero archivos .lean** — la iniciativa Lean está recién empezando
- 10 crates independientes con límites claros
- Tests driven por fixtures JSON generados desde leanSpec (Python)
- Issue #156: "ZK proving of the STF" — hay intención de probar formalmente la State Transition Function

### Estructura de crates

```
crates/
  common/
    crypto/src/lib.rs       ← XMSS, aggregate_signatures(), verify_aggregated_signature()
    types/                  ← State, Block, Attestation, AggregatedSignatureProof (961 líneas)
  blockchain/
    fork_choice/src/lib.rs  ← LMD-GHOST, compute_block_weights(), compute_lmd_ghost_head()
    state_transition/       ← process_slots(), process_block(), 3SF-mini finality (523 líneas)
    src/store.rs            ← ciclo de vida de attestations (1373 líneas)
```

---

## Módulos candidatos a portar a Lean (por prioridad)

### 1. ⭐⭐⭐⭐⭐ Crypto (`crates/common/crypto/`)
- `aggregate_signatures()` y `verify_aggregated_signature()`
- Un bug acá rompe la seguridad de todos los validadores
- Ya existe AMO-Lean que verifica Poseidon2 — se puede reutilizar

### 2. ⭐⭐⭐⭐⭐ Fork Choice (`crates/blockchain/fork_choice/`)
- LMD-GHOST: `compute_block_weights()`, `compute_lmd_ghost_head()`
- Debe ser determinístico y sin ambigüedad — ideal para verificación formal
- Tiene 498 líneas de spec tests contra leanSpec

### 3. ⭐⭐⭐⭐⭐ State Transition (`crates/blockchain/state_transition/`)
- El estado del protocolo completo: slots, bloques, finalidad 3SF-mini
- 523 líneas, con tests contra fixtures de leanSpec
- Directamente relacionado con Issue #156

### 4. ⭐⭐⭐⭐ Types (`crates/common/types/`)
- Sin dependencias externas → punto de entrada ideal para empezar
- Formalizar los tipos es la base para probar los algoritmos

---

## Lo que tiene LambdaClass en Lean

### AMO-Lean
- Compilador optimizador verificado: Lean 4 → C/Rust formalmente correcto
- Cubre: NTT, FRI, aritmética de campos (Goldilocks, BabyBear), **Poseidon2**, e-graph optimization
- Filosofía: escribís la spec una vez en Lean y obtenés código correcto por construcción

### Blog posts relevantes
- *"If It Compiles, It Is Correct"* — intro práctica a Lean 4 para sistemas ZK
- *"AMO-LEAN: Verified Code Optimization"* — equality saturation para código criptográfico
- *"The Hitchhiker's Guide to Reading Lean 4 Theorems"* — cómo leer pruebas Lean
- *"Ethereum Signature Schemes: ECDSA, BLS, XMSS, leanSig"*
- *"Fork Choice in leanConsensus: LMD-GHOST"*

### Concrete (lenguaje)
- LambdaClass está desarrollando un lenguaje de sistemas cuyo kernel se formaliza en Lean 4
- Filosofía de diseño: cada decisión debe responder "¿puede una máquina razonar sobre esto?"

---

## Conexión con el paper 055

El paper *"Hash-Based Multi-Signatures for Post-Quantum Ethereum"* (Drake et al., 2024) es la base teórica de leanSig / ethlambda. Las partes del paper que son candidatas a verificación formal en Lean:

- **Incomparable Encodings** → verificar que las instancias (Winternitz, TSW) satisfacen la definición
- **Teorema 1** (seguridad de XMSS en modelo estándar) → reducción a SM-TCR, SM-PRE, SM-UD
- **SUF-CMA** → la prueba de strong unforgeability
- **Adaptive Knowledge Soundness** → el gap abierto más crítico (Plonky3/stwo no lo tienen probado)

---

## Repos clonados en la máquina (necesarios para continuar)

| Repo | Path local |
|---|---|
| ethlambda | `/Users/eduardoveralli/ethlambda` |
| leanMultisig | `/Users/eduardoveralli/leanMultisig` |
| xmss-lean-notes | `/Users/eduardoveralli/xmss-lean-notes` |

---

## Análisis del código — lo que encontramos

### ethlambda — `crates/common/crypto/src/lib.rs`

Este archivo es un **wrapper delgado** sobre `lean-multisig`. Las dos funciones clave:

- `aggregate_signatures(pubkeys, sigs, message, slot)` — convierte tipos de ethlambda a lean-multisig y llama `xmss_aggregate_signatures()`
- `verify_aggregated_signature(proof, pubkeys, message, slot)` — deserializa el proof SSZ y llama `xmss_verify_aggregated_signatures()`

Hallazgos importantes:
- Tests marcados `#[ignore = "too slow"]` — la generación de claves XMSS es tan lenta que no corre en CI
- Hay **cross-client tests con `ream`** (otro cliente) — vectores de test hardcodeados para verificar interoperabilidad
- **El trabajo real está en `lean-multisig`**, no en ethlambda

Dependencia: `lean-multisig = { git = "https://github.com/leanEthereum/leanMultisig.git", rev = "e4474138..." }`

---

### leanMultisig — `crates/xmss/src/wots.rs` — EL CORAZÓN DEL SISTEMA

Este es el archivo más importante que vimos. Implementa **TSW (Target Sum Winternitz)** exactamente como describe el paper 055.

**Parámetros concretos del sistema:**
```
V = 42          dígitos por firma
W = 3           bits por dígito (base 8, CHAIN_LENGTH = 8)
TARGET_SUM = 110  suma fija de los dígitos (42×7 - 110 = 184 hashes en verificación, siempre fijo)
V_GRINDING = 2  dígitos extra de grinding (los últimos 2 deben ser máximos)
LOG_LIFETIME = 32  → 2³² slots (~544 años con slots de 4s)
Campo: KoalaBear (primo ~2³¹, NO BabyBear ni Goldilocks)
Hash: Poseidon16 (comprime 16 elementos de campo en 8)
```

**Funciones clave:**

`wots_encode(message, slot, truncated_merkle_root, randomness)`:
- Hashea mensaje + aleatoriedad con Poseidon → A
- Hashea A + slot + raíz Merkle truncada → compressed
- Verifica que la suma de dígitos = TARGET_SUM
- Si falla → retorna `None` (el llamador reintenta con nueva aleatoriedad)
- Implementa exactamente el encoding TSW del paper

`is_valid_encoding(encoding)`:
- Todos los índices < CHAIN_LENGTH (base 8)
- Los primeros V índices suman exactamente TARGET_SUM
- Los últimos V_GRINDING son CHAIN_LENGTH-1 (grinding)

`iterate_hash(a, n)`: aplica `poseidon16_compress_pair` n veces

`find_randomness_for_wots_encoding(...)`: loop de reintentos hasta encontrar randomness válida

**Conexión con el paper:**
- `wots_encode` implementa el Incomparable Encoding TSW
- `is_valid_encoding` es la verificación de que el codeword es válido
- La incomparabilidad viene de la restricción de suma constante = TARGET_SUM

**¿Qué habría que probar en Lean?**
1. Que `is_valid_encoding()` garantiza incomparabilidad (teorema central del paper)
2. Que `iterate_hash(x, k)` seguido de `iterate_hash(result, CHAIN_LENGTH-1-k)` = clave pública
3. Que `wots_encode()` produce encodings con suma exactamente TARGET_SUM

---

### leanMultisig — estructura de crates

El repo tiene **mucho más** de lo esperado — es un sistema completo:

```
crates/
  xmss/          ← XMSS + WOTS + TSW (lo que vimos)
  rec_aggregation/ ← agregación recursiva de firmas
  lean_vm/       ← VM propia con ISA, memoria, ejecución
  lean_compiler/ ← compilador con parser, IR, bytecode (3 fases)
  lean_prover/   ← generación y verificación de proofs
  air/           ← Algebraic Intermediate Representation (circuito del SNARK)
  backend/       ← campo KoalaBear, Poseidon, sumcheck, FRI
  whir/          ← implementación de WHIR (alternativa a FRI, proofs más pequeños)
  sub_protocols/ ← LogUp, GKR
```

**Sorpresa:** tiene su **propia VM y compilador** — no usa Plonky3 ni stwo directamente. Es un sistema ZK propio.

**También tiene WHIR implementado** — el sistema que reduce los proofs de 2-3 MB a <1 MB. Ya está en el código, no es solo trabajo futuro.

---

## Próximos pasos sugeridos

1. **[DECIDIDO — empezar acá]** Profundizar en `crates/common/crypto/src/lib.rs` — ver el código Rust de `aggregate_signatures()` y `verify_aggregated_signature()`, entender qué hace, y razonar qué teoremas habría que probar en Lean
2. Ver cómo AMO-Lean ya verifica Poseidon2 y si se puede reutilizar directamente para ethlambda
3. Buscar si hay issues o discusiones internas sobre por dónde arrancar el port
4. Mapear qué partes de los fixtures de leanSpec ya cubren los módulos candidatos

### Siguiente paso concreto: leer `crates/xmss/src/xmss.rs`

Ya vimos WOTS. El siguiente archivo natural es `xmss.rs` para ver el árbol de Merkle, cómo se construye la clave pública XMSS y cómo se genera/verifica la firma completa (WOTS + path Merkle).

Después: `crates/rec_aggregation/src/lib.rs` para ver cómo se agrega recursivamente.

### Razonamiento para empezar por crypto

Es el punto más concreto para entender qué significa portar a Lean en la práctica. Ahí está el corazón criptográfico: XMSS, la agregación y la verificación. Si entendemos qué hace ese código Rust, podemos razonar sobre qué teoremas habría que probar en Lean y cómo se conecta con AMO-Lean (que ya tiene Poseidon2 verificado). Es el hilo que une todo: el paper 055, las slides, y la iniciativa del equipo.

---

## Archivos en este repo relacionados

| Archivo | Descripción |
|---|---|
| `055.pdf` | Paper original — Hash-Based Multi-Signatures for Post-Quantum Ethereum |
| `055-hash-based-multisig-pq-ethereum.md` | Resumen del paper |
| `XMSS_Post_Cuantica_fusionada.pptx` | Presentación principal (22 slides, incluye Incomparable Encodings, SUF-CMA, Adaptive K. Soundness) |
| `XMSS_PQ_complemento.pptx` | Presentación complementaria (11 slides: Random Oracle Paradox, ecosistema repos, gossipsub, 3SF-mini) |
| `XMSS_analisis_critico.pptx` | Análisis crítico (10 slides, 12 gaps identificados) |
| `XMSS_PQ_complemento_resumen.md` | Resumen detallado slide por slide de la complemento |
| `XMSS_diagrama_flujo.html` | Diagrama visual de todos los conceptos (abrir en browser) |
| `xmss_explicacion.md` | Explicación base de XMSS |
| `pq-devnet-4.md` | Spec del devnet-4 |
