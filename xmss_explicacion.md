# Esquema de Firmas XMSS

## ¿Qué es XMSS?

XMSS (eXtended Merkle Signature Scheme) es un esquema de firma digital **post-cuántico**. Esto significa que es resistente a ataques de computadoras cuánticas.

Se construye combinando tres conceptos:

```
Lamport → W-OTS+ → Merkle Tree → XMSS
```

---

## 1. Funciones de Hash: La Base

Una función de hash toma cualquier input y produce un output de **tamaño fijo**.

```
"hola"       → a4d1f8c9e2b3...  (32 bytes)
"hola mundo" → 7f3c9a1d4e8b...  (32 bytes)
"hola!"      → 2b8e4f7a1c9d...  (32 bytes)
```

### Propiedades clave

- **Determinista:** el mismo input siempre produce el mismo output.
- **Efecto avalancha:** un cambio mínimo en el input cambia completamente el output.
- **Irreversible (one-way):** dado un hash, es imposible encontrar el input original.
- **Resistencia a colisiones:** imposible encontrar dos inputs distintos que produzcan el mismo hash.

---

## 2. OTS: One Time Signatures

### El problema que resuelve

Firmar un mensaje usando solo funciones de hash, sin curvas elípticas.

### Lamport Signatures (la OTS más simple)

**Generar clave privada:**

Generás 256 pares de números aleatorios:
```
Par 1:   (a1, b1)
Par 2:   (a2, b2)
...
Par 256: (a256, b256)
```

**Generar clave pública:**

Hasheas cada número:
```
Par 1:   (H(a1), H(b1))
Par 2:   (H(a2), H(b2))
...
```

**Firmar un mensaje:**

Hasheas el mensaje → obtenés 256 bits. Por cada bit:
- Si el bit es **0** → revelás **a_i**
- Si el bit es **1** → revelás **b_i**

Esa colección de valores revelados es tu firma.

**Verificar la firma:**

El verificador hashea cada valor revelado y lo compara con la clave pública. Si coincide, la firma es válida.

**¿Por qué "one time"?**

Si firmás dos mensajes distintos, revelás diferentes combinaciones. Con suficientes firmas, alguien puede reconstruir tu clave privada completa. Una clave → una sola firma. Después se quema.

---

### W-OTS (Winternitz OTS)

Optimización de Lamport. En vez de hashear cada bit por separado, agrupa bits y aplica la función de hash **varias veces en cadena**.

```
Lamport: 1 hash por bit  → 256 valores en la firma
W-OTS:   1 cadena por grupo de bits → muchos menos valores
```

El parámetro **w** (Winternitz) controla cuántas veces se aplica el hash en cada cadena. Es un número interno del esquema de firma, no tiene relación con la cantidad de validadores ni de mensajes.

```
w = 4 → cada cadena tiene 4 pasos de hash
w = 16 → cada cadena tiene 16 pasos de hash
```

A mayor w:
- Cadena más larga → firma más pequeña (menos elementos a revelar)
- Más cómputo para firmar y verificar

A menor w:
- Cadena más corta → firma más grande
- Menos cómputo para firmar y verificar

### W-OTS+

Mejora de seguridad sobre W-OTS. Agrega valores aleatorios en cada paso de la cadena de hashes para dificultar ataques.

> XMSS usa **W-OTS+** como su OTS interna. Lamport es el abuelo de todo esto.

---

## 3. Merkle Tree

### El problema que resuelve

Con OTS necesitás una clave distinta por cada firma. Si un validador firma miles de veces, necesita miles de claves públicas. El Merkle tree resume todas en **un único valor**: la raíz.

### Construcción

Supongamos 4 claves OTS públicas: PK1, PK2, PK3, PK4.

**Paso 1:** Hashear cada clave pública:
```
H1 = H(PK1)
H2 = H(PK2)
H3 = H(PK3)
H4 = H(PK4)
```

**Paso 2:** Hashear los pares:
```
H12 = H(H1 + H2)
H34 = H(H3 + H4)
```

**Paso 3:** Hashear el resultado:
```
Raíz = H(H12 + H34)
```

**Visualmente:**
```
        Raíz  ← clave pública XMSS
       /    \
     H12    H34
    /   \  /   \
   H1  H2 H3  H4
```

### Clave pública = Raíz

La raíz es la **única clave pública** que necesita conocer la red. Un único hash que representa a todas las claves OTS del validador.

> Las claves privadas **no están en el árbol**. Solo hay hashes de claves públicas.

### Camino de autenticación

Para demostrar que PK1 es parte del árbol, incluís en la firma el camino hasta la raíz:

```
PK1 → necesitás mostrar: H2 y H34
```

Con H2 el verificador calcula H12. Con H34 calcula la Raíz. Si coincide con la clave pública conocida, la firma es válida.

---

## 4. XMSS: Todo junto

### Estructura

1. Generás **N claves W-OTS+** (por ejemplo 1024)
2. Las organizás en un Merkle tree
3. La raíz del árbol es tu **clave pública XMSS**
4. Cada vez que firmás, usás la siguiente OTS disponible y adjuntás su camino de autenticación

```
Firma 1    → usa OTS_1    + camino de autenticación
Firma 2    → usa OTS_2    + camino de autenticación
...
Firma 1024 → usa OTS_1024 → árbol agotado, generás uno nuevo
```

### ¿Dónde está cada cosa?

```
Disco del validador:
├── SK_OTS_1       ← clave privada 1
├── SK_OTS_2       ← clave privada 2
├── ...
├── SK_OTS_1024
└── contador       ← en qué OTS voy (ej: 47)

Merkle tree:
└── hashes de claves públicas → Raíz = clave pública XMSS
```

### Flujo para firmar

```
1. Mira el contador → toca usar OTS_47
2. Agarra SK_OTS_47 del disco
3. Firma el mensaje con SK_OTS_47 → produce firma W-OTS+
4. Incluye en el paquete:
   - La firma W-OTS+
   - PK_OTS_47 (la clave pública de ese par)
   - El camino de autenticación de OTS_47 en el árbol
5. Incrementa el contador a 48
6. Nunca más usa SK_OTS_47
```

### ¿Qué significa "firmar con W-OTS+"?

SK_OTS_47 no es un único número. Es una **lista de N números aleatorios**:

```
SK_OTS_47 = [sk_1, sk_2, sk_3, ..., sk_N]
```

La clave pública se deriva aplicando el hash **w veces** (parámetro Winternitz) a cada elemento:

```
pk_1 = H aplicado w veces sobre sk_1
pk_2 = H aplicado w veces sobre sk_2
...
PK_OTS_47 = [pk_1, pk_2, ..., pk_N]
```

**Para firmar el mensaje:**

Primero se hashea el mensaje y se convierte en una lista de números entre 1 y w-1 (nunca 0 ni w, para evitar revelar la clave privada o no aplicar ningún hash). Por ejemplo con w=4:

```
H(mensaje) → [3, 1, 2, 2, ...]   ← un número v_i por cada elemento de SK
```

Luego para cada elemento sk_i se aplica el hash **(w - v_i) veces**:

```
v_1 = 3 → aplica 4-3 = 1 hash sobre sk_1 → resultado_1
v_2 = 1 → aplica 4-1 = 3 hashes sobre sk_2 → resultado_2
v_3 = 2 → aplica 4-2 = 2 hashes sobre sk_3 → resultado_3
v_4 = 2 → aplica 4-2 = 2 hashes sobre sk_4 → resultado_4
```

La firma es esa lista de resultados:

```
firma W-OTS+ = [resultado_1, resultado_2, resultado_3, resultado_4, ...]
```

**El verificador** hashea el mismo mensaje, obtiene los mismos [3, 1, 2, 2, ...] y aplica los **hashes restantes** sobre cada elemento de la firma para llegar a PK:

```
v_1 = 3 → aplica 3 hashes sobre resultado_1 → debería dar pk_1
v_2 = 1 → aplica 1 hash  sobre resultado_2 → debería dar pk_2
v_3 = 2 → aplica 2 hashes sobre resultado_3 → debería dar pk_3
v_4 = 2 → aplica 2 hashes sobre resultado_4 → debería dar pk_4
```

Firmante + verificador siempre suman **w hashes en total** por elemento. Si el resultado coincide con PK_OTS_47 → firma válida.

**¿Por qué no se puede falsificar?**

Para falsificar habría que aplicar más hashes de los que aplicó el firmante, lo que requiere conocer el valor intermedio correcto. Obtenerlo implicaría invertir un hash → imposible.

---

### Lo que el validador publica vs lo que manda en cada slot

- **Al registrarse:** publica solo la **Raíz** del árbol. Es su identidad permanente.
- **En cada slot:** la firma incluye adicionalmente PK_OTS_i y el camino de autenticación. Estos no eran conocidos antes y se revelan en el momento de firmar.

La raíz nunca cambia durante los 1024 slots. Lo que cambia slot a slot es qué OTS se usa.

### Flujo para verificar

El verificador recibe: firma W-OTS+, PK_OTS_47, y el camino de autenticación.
Realiza **dos verificaciones independientes**:

**Verificación 1: ¿La firma corresponde a PK_OTS_47?**

W-OTS+ funciona como una cadena de hashes. Firmar consume parte de la cadena, verificar completa el resto:

```
SK  → H → H → H → H → H → H → PK
           ↑                ↑
        firma           verificación
        (llega hasta acá)  (completa hasta PK)
```

Ejemplo concreto con cadena de 4 pasos:
```
SK = 1234

H(1234) = AAAA
H(AAAA) = BBBB  ← firma (aplicó 2 hashes, determinado por el mensaje)

Verificador recibe BBBB y aplica los 2 hashes restantes:
H(BBBB) = CCCC
H(CCCC) = DDDD  ← compara con PK_OTS_47

Si DDDD == PK_OTS_47 → firma válida
```

> **Nota:** la cantidad de hashes que aplica el firmante (y por lo tanto los que le quedan al verificador) está determinada por el contenido del mensaje firmado. Firmante y verificador siempre suman la misma cantidad total de hashes para llegar a PK.

El verificador **nunca ve ni reconstruye SK**. Solo completa la cadena hacia adelante y compara con PK. El hash es irreversible, no hay camino de vuelta.

**Verificación 2: ¿PK_OTS_47 pertenece al árbol de este validador?**

```
H(PK_OTS_47) + H_hermano → H_padre
H_padre + H_tio          → H_abuelo
...
→ Raíz reconstruida

¿Raíz reconstruida == Raíz conocida del validador? → Si coincide, PK_OTS_47 es legítima
```

**¿Dónde están las trampas posibles y cómo se evitan?**
- **Inventar una firma falsa:** imposible sin SK_OTS_47, por irreversibilidad del hash.
- **Inventar una PK_OTS_47 falsa:** el camino de autenticación no llegaría a la Raíz correcta.
- **Reusar una OTS:** la red lleva registro de qué OTS ya fueron usadas y las rechaza.

---

## 5. ¿Por qué es post-quantum?

Todo se basa en **funciones de hash**. No hay curvas elípticas ni logaritmos discretos.

El algoritmo de Shor (el ataque cuántico más conocido) sirve para romper logaritmos discretos, pero **no tiene efecto conocido sobre funciones de hash**.

### Comparación con BLS (Ethereum clásico)

| | BLS | XMSS |
|---|---|---|
| Base matemática | Curvas elípticas | Funciones de hash |
| Tamaño de firma | ~96 bytes | Varios kilobytes |
| Resistente a cuántica | No | Sí |
| Reusar clave | Sí, infinitas veces | No, una OTS por firma |
| Agregación | Simple y nativa | Compleja (requiere leanVm) |

---

## 6. XMSS en la práctica: validadores en Lean Ethereum

Un validador usa su árbol XMSS durante **miles de slots**. No crea un árbol nuevo por slot.

```
Slot 1    → usa OTS_1   ✓ (quemada)
Slot 2    → usa OTS_2   ✓ (quemada)
Slot 3    → usa OTS_3   ✓ (quemada)
...
Slot 1024 → usa OTS_1024 → genera nuevo árbol
```

Es como una libreta de cheques: no abrís una cuenta nueva por cada pago, usás la misma cuenta y gastás cheques de a uno.

### Regla crítica

**Nunca reusar una OTS.** Si el validador pierde el contador o lo reinicia, podría reusar una clave y comprometer su seguridad. Es la principal complejidad operativa de XMSS comparado con BLS.

---

## Resumen visual

```
Clave privada → N claves W-OTS+ (en disco, nunca salen)
                        ↓
                   Merkle Tree
                        ↓
Clave pública →    Raíz del árbol (conocida por toda la red)

Para firmar  → firma W-OTS+ + PK_OTS_i + camino de autenticación
Para verificar:
  1. Completar la cadena de hashes desde la firma hasta PK_OTS_i
  2. Reconstruir la raíz usando PK_OTS_i + camino de autenticación
  3. Comparar raíz reconstruida con la raíz conocida del validador
```
