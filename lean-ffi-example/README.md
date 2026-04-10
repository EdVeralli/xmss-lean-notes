# lean-ffi-example

Ejemplo mínimo de Rust llamando una función verificada en Lean 4 vía FFI.

La función es `slot_is_justifiable_after` del protocolo 3SF-mini de ethlambda.

## Estructura

```
lean-ffi-example/
  lean/
    SlotJustifiable.lean      ← implementación verificada en Lean 4 (@[export])
    slot_justifiable.c        ← generado por `lean --c` (no commitear, es artefacto)
  src/
    ffi.rs                    ← único lugar con `unsafe`, binding al símbolo C
    main.rs                   ← wrapper público + tests
  build.rs                    ← compila el .c y linkea el runtime de Lean
  Cargo.toml
```

## Cómo correrlo

### 1. Instalar Lean 4

```bash
curl https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh -sSf | sh
```

### 2. Compilar el .lean a C

```bash
lean --c lean/slot_justifiable.c lean/SlotJustifiable.lean
```

### 3. Compilar y correr con Cargo

```bash
cargo run
```

### 4. Correr los tests

```bash
cargo test
```

## El pipeline completo

```
SlotJustifiable.lean          ← spec matemática con @[export]
      ↓  lean --c
lean/slot_justifiable.c       ← C generado por Lean (no tocar manualmente)
      ↓  build.rs (cc crate)
libslot_justifiable.a         ← librería estática
      ↓  cargo build
binario Rust final            ← llama la función verificada sin saber que hay Lean
```

## Por qué esto importa

La firma pública de `slot_is_justifiable_after` en Rust es idéntica a la versión
manual de ethlambda. El caller no sabe ni le importa que adentro hay Lean.

Cuando el `.lean` compila con todos los teoremas sin `sorry`, tenés garantía
matemática de que la función es correcta para **todos los valores posibles de u64**,
no solo para los casos que cubrís con tests.

## Variables de entorno

| Variable | Default | Descripción |
|---|---|---|
| `LEAN_SYSROOT` | `lean --print-prefix` | Path al sysroot de Lean |
