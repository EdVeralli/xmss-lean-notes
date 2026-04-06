# Resumen — XMSS_PQ_complemento.pptx

## Slide 1: Título
Hash-Based PQ Ethereum — Lo que no estaba en las slides. Cubre los temas teóricos y de arquitectura que no entraron en la presentación principal: Random Oracle Paradox, Incomparable Encodings, Strong Unforgeability, el ecosistema de repos, los roles de red, gossipsub, y el consenso 3SF-mini.

---

## Slide 2: El Random Oracle Paradox
XMSS prueba su seguridad asumiendo que las funciones hash son "cajas negras" perfectas (modelo Random Oracle). Pero para meter la verificación de XMSS dentro de un SNARK, necesitás tratar la función hash como un circuito aritmético concreto — una lista de operaciones paso a paso. Esas dos cosas son incompatibles: no podés decir que algo es una caja negra y a la vez describir todo lo que hace por dentro. La solución del paper es probar la seguridad de XMSS en el "modelo estándar" — sin asumir cajas negras, usando propiedades concretas de la función hash (Poseidon2) que sí se pueden verificar dentro de un circuito.

---

## Slide 3: Propiedades del modelo estándar
En vez de asumir que el hash es perfecto, el paper define 4 propiedades concretas que la función hash debe cumplir:

- **SM-TCR (Multi-Target Collision Resistance):** Es difícil encontrar dos inputs distintos que den el mismo output, incluso si podés atacar muchos targets a la vez. Se usa en el árbol de Merkle y en las cadenas Winternitz.

- **SM-PRE (Multi-Target Preimage Resistance):** Dado un output del hash, es difícil encontrar el input que lo generó, incluso atacando muchos outputs a la vez. Protege las claves privadas OTS — que nadie pueda recuperarlas desde las claves públicas.

- **SM-UD (Multi-Target Undetectability):** Las salidas del hash son indistinguibles de valores aleatorios. Garantiza que la clave pública no revela información sobre la clave privada.

- **SM-rTCR (nueva, aporte del paper):** Una variante de TCR para encodings que pueden fallar con cierta probabilidad (como el TSW que retorna None y reintenta). Primera vez que se formaliza en la literatura.

---

## Slide 4: Incomparable Encodings
Es el framework teórico que unifica todas las variantes de XMSS en una sola prueba de seguridad.

La idea: cuando codificás un mensaje para firmarlo con Winternitz, el código resultante tiene que ser "incomparable" con cualquier otro código. Dos códigos x y x' son incomparables si en alguna posición x es mayor que x', y en otra posición x' es mayor que x. Ninguno domina al otro en todas las posiciones.

¿Por qué importa? Si un código x' dominara a x (fuera mayor o igual en todas las posiciones), un atacante podría tomar la firma de x y simplemente aplicar hashes extra para obtener una firma válida de x'. Sería falsificación trivial.

Winternitz clásico logra esto con un checksum — pero el checksum hace que el costo de verificación varíe según el mensaje (malo para SNARKs). TSW lo logra fijando la suma de los dígitos a un valor constante T: si x domina a x', su suma sería mayor que T, lo cual es imposible. Resultado: verificación siempre con la misma cantidad de hashes = circuito SNARK de costo fijo.

---

## Slide 5: Strong Unforgeability (SUF-CMA)
Hay dos niveles de seguridad para firmas:

- **EU-CMA (Existential Unforgeability):** Nadie puede crear una firma válida para un mensaje que nunca fue firmado. Es la garantía básica. Pero si el firmante ya firmó un mensaje M con firma σ, un adversario podría producir otra firma σ' distinta que también sea válida para M. EU-CMA no protege contra eso.

- **SUF-CMA (Strong Unforgeability):** Nadie puede producir ninguna firma nueva válida — ni para mensajes nuevos, ni una firma distinta para un mensaje ya firmado. Es más fuerte.

¿Por qué importa en Ethereum? Las firmas pasan por varias capas: validador → agregador → bloque → verificador. Sin SUF-CMA, alguna capa intermedia podría modificar la firma sin invalidarla. El paper es el primero en probar SUF-CMA para XMSS.

---

## Slide 6: Ecosistema leanEthereum (4 repos)
El sistema está dividido en 4 repositorios, cada uno con una responsabilidad:

- **leanSig:** Firmas individuales. Implementa XMSS con TSW + Poseidon2. Genera el par de claves del validador (attestation + proposal). Es la capa más baja.

- **leanMultisig:** Base de agregación. Construye partial aggregates a partir de firmas individuales y define el bitfield (qué validadores firmaron).

- **leanVm:** Pruebas recursivas. Genera pqSNARK proofs que representan N firmas. Puede probar sobre otros proofs (recursión). Tiene el parámetro log_inv_rate (1-4) que controla tamaño vs velocidad del proof.

- **leanSpec:** Spec ejecutable del protocolo completo. Orquesta todo: containers SSZ, fork choice (3SF-mini), validator service, networking. Sus tests generan vectores JSON que los 5 clientes del devnet usan para validar sus implementaciones. Python 3.12+.

---

## Slide 7: Roles en pq-devnet-4
La separación de roles es más explícita que en Ethereum clásico porque generar los pqSNARK proofs es computacionalmente caro:

- **Aggregator:** El nodo pesado. Recolecta attestations del gossip, llama a leanVm para fusionarlas recursivamente. Configurable con log_inv_rate (1=rápido/grande, 4=lento/pequeño).

- **Proposer:** Arma el bloque. Espera el mejor aggregate coalesced (el que tenga más cobertura de validadores), firma el bloque con su proposal_key (clave XMSS separada), e incluye exactamente 1 aggregate por mensaje.

- **Verifier:** Toda la red. Valida el pqSNARK proof contra el bitfield + mensaje. Opera en O(1) independiente de cuántos firmaron. Rechaza bloques con aggregates duplicados.

- **Regla nueva en devnet-4:** Bloques con más de 1 aggregate para el mismo mensaje se rechazan. Antes (devnet-3) se permitían múltiples aggregates con diferentes participantes.

---

## Slide 8: Gossipsub — flujo de firmas
Las firmas viajan por 3 topics de gossipsub con prefijo `/leanconsensus` y encoding SSZ+Snappy:

- **attestation_{subnet_id}:** Cada validador firma su attestation con su attestation_key y la publica en su subnet. El aggregator recolecta desde acá.

- **aggregated_attestation:** El aggregator publica su partial aggregate. Otros aggregators pueden recibirlo y fusionarlo recursivamente con leanVm (coalescing).

- **block:** El proposer publica el bloque final con exactamente 1 aggregate ya coalesced por mensaje. Todos los nodos verifican y actualizan el fork choice.

Cada topic incluye un fork_digest en su nombre, lo que separa automáticamente las redes de distintos devnets/forks.

---

## Slide 9: 3SF-mini — consenso
Mecanismo de consenso adaptado de ethereum/research/3sf-mini para firmas post-cuánticas con slots de 4 segundos:

- **Estructura del slot:** Interval 0 → el proposer produce el bloque. Interval 1+ → los validadores crean attestations. El validator service duerme entre intervalos.

- **Fork choice:** Los aggregates coalesced determinan el peso de cada fork. Se prioriza el fork con más participación ponderada.

- **Diferencia clave con mainnet:** No hay agregación BLS nativa. El aggregate proof es un pqSNARK generado por leanVm, no una firma BLS agregada. Slots de 4s en vez de 12s.

- **Dos claves por slot:** Para producir bloque se usa proposal_key, para attestation se usa attestation_key. Son dos árboles XMSS independientes.

---

## Slide 10: Tabla comparativa
Comparación del esquema del paper contra otros enfoques post-cuánticos:

| Esquema | Tipo | Agrega | Tamaño firma | Proof formal |
|---|---|---|---|---|
| **Este paper (XMSS+TSW+pqSNARK)** | Many-time hash | Sí, no-interactivo | ~2.2 KiB | Completo (SUF-CMA) |
| Khaburzaniya et al. | OTS + STARKs | Sí | ~8 KiB | Bosquejos |
| Squirrel / Chipmunk | Lattice XMSS | Sí | >32 KiB | Formal (EU-CMA) |
| SPHINCS+ (NIST) | Many-time hash | No | 8–50 KiB | Formal (EU-CMA) |
| XMSS clásico (NIST) | Many-time hash | No | ~2 KiB | Formal (EU-CMA) |

El esquema del paper es el único con agregación no-interactiva y prueba formal completa de Strong Unforgeability (SUF-CMA).

---

## Slide 11: Problemas abiertos
Lo que queda por resolver:

- **Adaptive knowledge soundness:** La propiedad que el pqSNARK necesita para que la prueba de multi-firmas sea completa. Ni Plonky3 ni stwo la tienen probada formalmente. Es el gap más crítico del diseño.

- **Multi-tree XMSS con LIFETIME = 2^32:** Son ~544 años de actividad con slots de 4 segundos. Requiere la sliding window (top_tree + bottom_trees). Benchmarks de eficiencia pendientes.

- **STIR/WHIR vs FRI:** Los proofs actuales con FRI pesan 2-3 MB por aggregate. Con STIR o WHIR se proyecta bajar a menos de 1 MB. Todavía no está implementado.

- **Benchmarks de pq-devnet-4:** leanMetrics recolectará resultados en hardware EIP-7870. Hasta que eso pase, las estimaciones de rendimiento (como 10K firmas/seg) son teóricas.
