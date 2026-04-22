# EIP-7732 — Enshrined Proposer-Builder Separation (ePBS)

**Estado:** Scheduled for Inclusion en Glamsterdam (EIP-7773)
**Tipo:** Consensus Layer (Standards Track)
**Autores:** potuz, terencechain

---

## El problema: cómo se construyen bloques hoy

En Ethereum, cada 12 segundos un validador es elegido para proponer un bloque. Ese bloque tiene dos partes: la parte de **consenso** (attestations, slashings, etc.) y la parte de **ejecución** (las transacciones). Construir un bloque de ejecución rentable es un trabajo especializado — hay que ordenar las transacciones para capturar MEV (Maximal Extractable Value: arbitraje, liquidaciones, sandwiching, etc.).

### El sistema actual: MEV-Boost

Como la mayoría de los validadores no tienen la sofisticación para construir bloques óptimos, se usa un sistema fuera del protocolo llamado **MEV-Boost** (creado por Flashbots):

```
Builder → construye bloque rentable
   ↓ envía bid (oferta) al relay
Relay → recibe bids de múltiples builders, elige el mejor
   ↓ envía header al proposer (sin revelar las transacciones)
Proposer → firma el header "a ciegas" (no ve las tx)
   ↓ devuelve firma al relay
Relay → revela el bloque completo a la red
```

**~90% de los bloques de Ethereum se construyen así.** El problema es que todo depende de **relays** — entidades centralizadas que no forman parte del protocolo:

1. **Confianza:** El relay promete al builder que no le roba las estrategias de MEV. Promete al proposer que el bid es válido y que va a cobrar. Promete a la red que el bloque es legítimo. Si el relay miente o falla, nadie tiene recurso on-chain.

2. **Centralización:** Hay muy pocos relays operativos (Flashbots domina). Si se caen o censuran transacciones, no hay alternativa en-protocolo.

3. **Resistencia a censura:** Un relay puede negarse a pasar bloques que contengan ciertas transacciones (OFAC compliance, etc.), y el proposer no tiene forma de saberlo porque firma a ciegas.

4. **No hay penalización:** Si un relay o builder se porta mal, no pierde stake — el protocolo no sabe que existen.

---

## La solución: meter PBS dentro del protocolo

EIP-7732 **enshrine** (consagra, mete en el protocolo) la separación proposer-builder. En lugar de depender de relays externos, el mecanismo es parte de las reglas de consenso de Ethereum.

### Los cambios fundamentales

1. **Los builders se vuelven entidades del protocolo.** Tienen una cuenta con balance en la Beacon Chain. Pueden depositar stake (mínimo 1 ETH, mucho menos que los 32 ETH de un validador). Si no cumplen, se les debita el pago al proposer de su balance on-chain.

2. **El `ExecutionPayload` sale del `BeaconBlock`.** Hoy un bloque de beacon contiene directamente las transacciones. Con ePBS, el `BeaconBlockBody` ya no incluye `ExecutionPayload` — en su lugar incluye un **compromiso firmado del builder** (`SignedExecutionPayloadHeader`).

3. **Mecanismo commit-reveal.** El builder se compromete a pagar X al proposer y a revelar un bloque con hash Y. El proposer incluye ese compromiso en su bloque de consenso. Después, el builder revela el payload en un mensaje separado (`SignedExecutionPayloadEnvelope`).

4. **Payload Timeliness Committee (PTC).** Un subcomité de 512 validadores verifica que el builder reveló el payload a tiempo. No necesitan validar la ejecución — solo verifican la firma del builder y que el blockhash coincida con el compromiso.

---

## Cómo funciona un slot con ePBS

El slot de 12 segundos se divide en **4 intervalos de 3 segundos**:

```
0s          3s          6s          9s          12s
├───────────┼───────────┼───────────┼───────────┤
│ Intervalo │ Intervalo │ Intervalo │ Intervalo │
│     0     │     1     │     2     │     3     │
│           │           │           │           │
│ Proposer  │ Attesta-  │ Builder   │   PTC     │
│ publica   │ tions     │ revela    │  vota     │
│ beacon    │ normales  │ payload   │ timeliness│
│ block     │           │           │           │
└───────────┴───────────┴───────────┴───────────┘
```

### Paso a paso:

**Intervalo 0 (0-3s):** El proposer recopila bids de builders (cada bid es un `SignedExecutionPayloadHeader` que contiene el blockhash comprometido y el valor a pagar). Elige el mejor bid y lo incluye en su `BeaconBlock`. Publica el bloque.

**Intervalo 1 (3-6s):** Los validadores regulares envían attestations sobre el bloque de consenso, igual que hoy. Pero ahora **no necesitan validar el execution payload** — solo la parte de consenso. Esto es mucho más rápido.

**Intervalo 2 (6-9s):** El builder revela el `ExecutionPayloadEnvelope` — el bloque completo con todas las transacciones. Lo publica en la red P2P.

**Intervalo 3 (9-12s):** Los 512 miembros del PTC votan: ¿el builder reveló a tiempo? ¿El blockhash coincide con el compromiso? Publican `PayloadAttestation` con su voto (PRESENT, MISSING, o WITHHELD).

### Tres resultados posibles de un slot:

| Resultado | Qué pasó | Consecuencia |
|---|---|---|
| **Full block** | Proposer publicó, builder reveló a tiempo | Bloque completo, estado avanza, builder paga al proposer |
| **Empty block** | Proposer publicó, builder NO reveló | Se debita al builder el pago al proposer igual. El bloque de consenso cuenta pero sin ejecución. |
| **Missed block** | Proposer no publicó | Slot vacío, como hoy |

El punto clave del "empty block": **el builder paga aunque no revele**. Esto es lo que hace al sistema trust-free — el proposer cobra sí o sí, y el builder no tiene incentivo a withhold porque pierde plata.

---

## Cambios técnicos en el protocolo

### Nuevas estructuras de datos

**`ExecutionPayloadHeader` (bid del builder):**
- `parent_block_hash` — hash del bloque padre
- `parent_block_root` — root del estado padre
- `block_hash` — hash del bloque que el builder se compromete a revelar
- `gas_limit` — límite de gas del bloque
- `builder_index` — índice del builder en la Beacon Chain
- `slot` — slot del bloque
- `value` — pago al proposer (en Gwei)
- `blob_kzg_commitments_root` — root de los blob commitments (EIP-4844)

**`ExecutionPayloadEnvelope` (revelación del builder):**
- `execution_payload` — el payload completo con las transacciones
- `builder_index` — quién lo construyó
- `beacon_block_root` — referencia al bloque de consenso
- `blob_kzg_commitments` — compromisos de blobs
- `state_root` — raíz del estado resultante tras aplicar el payload

**`PayloadAttestation` (voto del PTC):**
- `validator_index` — quién vota
- `data` — slot + beacon_block_root
- `payload_status` — PRESENT (0), MISSING (1), o WITHHELD (2)

### Cambios en `BeaconBlockBody`

```
Antes (hoy):                    Después (ePBS):
─────────────                   ───────────────
attestations                    attestations
slashings                       slashings
deposits                        deposits
voluntary_exits                 voluntary_exits
execution_payload  ← REMOVIDO   signed_execution_payload_header  ← NUEVO
                                payload_attestations             ← NUEVO
```

### Cambios en `BeaconState`

Campos nuevos:
- `latest_block_hash` — hash del último bloque de ejecución revelado
- `latest_full_slot` — último slot donde se reveló un payload completo
- `latest_withdrawals_root` — root de los últimos withdrawals (ahora se procesan asincrónicamente)

### Cambios en fork choice

El fork choice ahora tiene que considerar tres estados por slot en vez de dos (bloque/no-bloque):
- **Full:** bloque de consenso + payload revelado
- **Empty:** bloque de consenso + payload NO revelado (builder falló)
- **Missing:** sin bloque de consenso

El PTC vota sobre si el payload está PRESENT o no. El fork choice usa estos votos para decidir si el slot tiene un bloque full o empty.

---

## Tiempos de validación: la ganancia clave

Con ePBS, la validación del execution payload se **desacopla temporalmente** de la validación del consenso:

| Quién | Tiempo para validar ejecución |
|---|---|
| Siguiente proposer | 6 segundos (2 intervalos) |
| Todos los demás validadores | 9 segundos (3 intervalos) |
| Hoy (sin ePBS) | ~2-3 segundos (antes de attestar) |

Esto es el argumento principal de **escalabilidad**: con más tiempo para validar, se pueden procesar bloques más grandes (más gas, más blobs) sin exigir hardware más potente a los validadores. El siguiente proposer tiene 6 segundos enteros para ejecutar las transacciones y preparar su bloque — hoy tiene que hacerlo en ~2 segundos.

---

## Builders como entidades staked

Los builders son una nueva clase de participante en la Beacon Chain:

- **Depósito mínimo:** 1 ETH (vs 32 ETH para validadores)
- **Balance on-chain:** su cuenta en la Beacon Chain tiene un balance que se debita cuando se comprometen a pagar a un proposer
- **Sin slashing tradicional:** no se les hace slashing como a los validadores, pero pierden el pago comprometido si no revelan
- **Pago incondicional:** cuando el proposer incluye el bid del builder en su bloque, el pago se transfiere al proposer **inmediatamente**, antes de que el builder revele. Si el builder no revela, pierde la plata y el slot queda empty.

---

## Eliminación de los relays

Con ePBS, los relays ya no son necesarios porque:

1. **El builder paga on-chain** — no hay promesa off-chain de pago que un relay tenga que garantizar
2. **El compromiso es firmado y verificable** — cualquier validador puede verificar que el bid es válido
3. **El PTC verifica la revelación** — 512 validadores independientes verifican que el builder cumplió, no un relay centralizado
4. **El builder tiene skin in the game** — si no cumple, pierde stake. Los relays no tenían esta penalización

---

## Consideraciones de seguridad

**Builder griefing:** Un builder podría comprometerse y luego no revelar, causando un slot empty. Pero pierde el pago, así que el griefing tiene costo.

**Timing games:** El builder podría intentar revelar muy tarde para maximizar MEV (viendo transacciones extra del mempool). El PTC y los tiempos estrictos de los intervalos mitigan esto.

**PTC corruption:** Si >50% del PTC es malicioso, podrían votar PRESENT cuando el builder no reveló, o MISSING cuando sí lo hizo. Con 512 miembros elegidos aleatoriamente, atacar al PTC requiere controlar una fracción grande del total de validadores.

**Proposer equivocation:** El proposer podría publicar dos bloques distintos con bids de builders distintos. Las reglas de slashing existentes aplican.

---

## Relación con ethlambda

ethlambda implementa 3SF-mini, que es un protocolo de consenso simplificado. 3SF-mini no tiene PBS actualmente — los validadores proponen y construyen sus propios bloques. Si leanEthereum incorporara algo análogo a ePBS, los cambios serían:

- Nueva estructura de datos para bids de builders
- Modificación del `BeaconBlockBody` para incluir el header del builder en vez del payload
- Nuevo mensaje P2P para el `ExecutionPayloadEnvelope`
- Nuevo comité (PTC) con su duty adicional en el tick schedule
- Cambios en fork choice para manejar bloques full/empty/missed

Esto todavía no está en la hoja de ruta de leanEthereum/ethlambda.

---

## Fuentes

- [EIP-7732: Enshrined Proposer-Builder Separation](https://eips.ethereum.org/EIPS/eip-7732)
- [ePBS Implementation in Prysm — EPF Cohort 5](https://github.com/eth-protocol-fellows/cohort-five/blob/main/projects/epbs-implementation-in-prysm.md)
- [EIP-7732 (ePBS) Selected as Glamsterdam Headliner — EtherWorld](https://etherworld.co/2025/08/11/eip-7732-epbs-selected-as-glamsterdam-headliner/)
- [Builders and Relays in ePBS — Titan Builder](https://titanbuilder.substack.com/p/builders-and-relays-in-epbs)
- [The case for EIP-7732 in Fusaka — potuz](https://hackmd.io/@potuz/Bkcwd5hG1x)
- [SoK: Current State of Ethereum's Enshrined PBS](https://arxiv.org/html/2506.18189)
