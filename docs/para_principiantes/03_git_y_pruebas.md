# Git, cambios pequeños y pruebas

Esta guía es para poder experimentar con seguridad y volver a un punto conocido
sin borrar accidentalmente trabajo útil.

## 1. La idea de Git

- **Working tree:** archivos que has cambiado desde el último commit.
- **Commit:** fotografía identificada de archivos; queda en el historial.
- **Diff:** lista exacta de líneas cambiadas.
- **Revert:** crea un commit nuevo que deshace un commit anterior, conservando
  la historia.

El repositorio incluye esta base estable confirmada manualmente:

```text
8da06a626c01250e0dda99fa3df17095e6e7dac0  Establece base funcional para continuar
```

Es mejor crear commits pequeños con nombres claros que guardar meses de trabajo
en una sola fotografía. No mezcles una función nueva con limpieza general si
quieres poder deshacer solo esa función.

## 2. Antes de editar

Desde la carpeta del proyecto:

```bash
git status --short
git log --oneline -5
```

Si `git status` muestra archivos modificados, averigua de qué trabajo son antes
de sustituirlos. Si quieres empezar una función grande, crea primero un
checkpoint limpio. Para saber qué cambiaría un archivo:

```bash
git diff -- scripts/desbrozadora.gd
git diff --check
```

`git diff --check` detecta problemas de espacios; no ejecuta el juego.

## 3. Confirmar tu propio trabajo

Cuando la tarea esté probada y quieras guardarla:

1. Mira `git status --short` y `git diff`.
2. Añade solo los archivos de esa tarea, indicando sus rutas:

   ```bash
   git add scripts/mi_cambio.gd scenes/mi_escena.tscn
   ```

3. Revisa lo que va a entrar:

   ```bash
   git diff --cached
   git status --short
   ```

4. Confirma con un mensaje corto que empiece con un verbo:

   ```bash
   git commit -m "Ajusta el encuadre de la cámara"
   ```

5. Comprueba el resultado:

   ```bash
   git log --oneline -3
   git status --short
   ```

No uses `git add .` sin revisar: podría añadir capturas, archivos temporales o
cambios de otra tarea. Si el mismo archivo contiene trabajo mezclado, no lo
confirmes entero sin mirar el diff.

## 4. Volver atrás con seguridad

Si el cambio está en un commit propio y quieres deshacerlo:

```bash
git revert HASH_DEL_COMMIT
```

Git crea otro commit que revierte ese cambio. Sustituye `HASH_DEL_COMMIT` por el
código que muestra `git log --oneline`. Revisa el resultado y prueba el juego.

Si todavía no hiciste commit, `git diff -- ruta/al/archivo` te enseña el cambio.
No restaures el archivo completo si mezcla líneas útiles y líneas del experimento.
En ese caso, deshaz solo el bloque que identificaste; si no estás segura, guarda
una copia y pide una revisión antes de limpiar.

Evita `git reset --hard`, `git checkout -- archivo` y `git restore archivo` como
soluciones rápidas: pueden borrar cambios que no pertenecen al experimento.

## 5. Qué prueba ejecutar

Primero arranca Godot y prueba el caso que has cambiado. Para mirar el proyecto:

```bash
flatpak run --filesystem=$HOME/Documentos org.godotengine.Godot --path .
```

Después elige una comprobación apropiada:

| Cambio | Comprobación recomendada |
| --- | --- |
| Sintaxis o escena | Abrir el proyecto en el editor y mirar Output; parseo headless |
| Movimiento/cámara/herramienta | Recorrido manual y `test_movimiento_integrado.gd` |
| Corte, hierba, viento o suelo plano | Prueba manual; suite `test_juego.gd` si quieres comprobar todo |
| Inventario, rueda, soltar o recoger | `test_inventario.gd` |
| Raíz de zarza, enganches o caída | `test_zarza_conexion.gd` |
| Modelo Blender | Abrir el GLB con ventana y luego ejecutar el juego |

**Las pruebas focalizadas van mucho más rápido que la suite** y cubren una sola
cosa, así que para un cambio concreto usa esa antes que `test_juego.gd`. Se
ejecutan igual, con `--headless`:

```bash
flatpak run --filesystem=$HOME/Documentos org.godotengine.Godot \
  --headless --path . --script tools/test_inventario.gd

flatpak run --filesystem=$HOME/Documentos org.godotengine.Godot \
  --headless --path . --script tools/test_zarza_conexion.gd
```

Un aviso sobre la suite completa: **ahora mismo da seis fallos** y no son tu
culpa. La maleza se bajó de 1,33 a 0,76 m para que no tapara el encuadre, y las
comprobaciones de la suite siguen esperando la altura vieja. Si los ves, son esos.

Parseo rápido, que carga el proyecto en modo editor sin interfaz:

```bash
flatpak run --filesystem=$HOME/Documentos org.godotengine.Godot \
  --headless --editor --path . --quit
```

Prueba integrada de movimiento:

```bash
flatpak run --filesystem=$HOME/Documentos org.godotengine.Godot \
  --headless --path . --script res://tools/test_movimiento_integrado.gd
```

Como esto ya tiene nombre de version, cada vez que se termina algo que se pueda
jugar se marca el commit con una etiqueta, y esa etiqueta es la version:

```bash
git tag -a v0.1.0 -m "Primera version jugable"
git push origin v0.1.0
```

La regla que se sigue: **minor** (`v0.2.0`) para una cosa grande jugable, y
**patch** (`v0.1.1`) para arreglar cosas.

Suite completa:

```bash
flatpak run --filesystem=$HOME/Documentos org.godotengine.Godot \
  --headless --path . --script tools/test_juego.gd
```

La suite puede tardar. No la ejecutes por costumbre para cada ajuste visual; elige
la prueba que cubra lo que tocaste. Para la hierba, el resultado visual real
necesita renderizado Vulkan: headless no sustituye esa revisión.

## 6. Una ficha de prueba manual

Antes de probar, escribe tres líneas en una nota:

```text
Quería: que la cámara mantenga visible el cabezal al mirar arriba.
Hice: cambié solo el ajuste de encuadre.
Comprobé: mirar arriba, barrer a ambos lados y andar hacia atrás.
```

Si algo sale mal, esas líneas indican qué repetir y qué cambio deshacer. Apunta
el primer mensaje rojo de Godot y los pasos exactos; “no funciona” suele requerir
volver a preguntar qué botón o movimiento lo provoca.

## 7. Cuándo usar cada modo del proyecto

`AGENTS.md` define los modos oficiales:

- **VIVO:** cambio pequeño; sin suite; tú haces la prueba en el editor.
- **SEMI:** parseo/verificación rápida; la prueba visual grande la haces tú.
- **NOCHE:** ejecución autónoma de toda la suite y corrección hasta dejarla limpia.

Para aprender haciendo, VIVO o SEMI suelen ser suficientes. Pide NOCHE solo para
una tarea en la que realmente quieras la validación completa.
