---
# REGLAS DE EJECUCIÓN Y MODOS DE TRABAJO DEL PROYECTO

Proyecto desarrollado en Godot 4.7 (GDScript + Shaders) y pipeline con Blender.

## MODOS DE OPERACIÓN DE AGENTE

### 1. `[MODO: VIVO]` (Iteración Ultra Rápida / Feedback Directo)
- **Instrucción clave**: Cero tests, cambios pequeños y ejecución instantánea.
1. **NO ejecutes la suite de tests** (`test_juego.gd`) por consola.
2. **NO escribas ni modifiques tests unitarios**.
3. Realiza cambios de código breves, puntuales y concisos en GDScript o Shaders.
4. Al finalizar la tarea, indícame brevemente qué archivos modificaste y qué debo probar yo manualmente dentro del editor de Godot para darte feedback.

### 2. `[MODO: SEMI]` (Desarrollo Asistido / Validación Rápida)
- **Instrucción clave**: Verificación básica pero la prueba grande y el feedback visual lo mantengo yo.
1. **Ejecuta una verificación sintáctica o de parseo rápida** en terminal tras los cambios, pero **NO corras la suite completa** para no perder tiempo.
2. Si el cambio requiere un test unitario muy básico o modificar una prueba existente afectada por la firma de un método, hazlo rápidamente.
3. No intentes resolver bucles de fallos complejos en bucle: si algo falla en la verificación básica, avísame con el error exacto para que yo tome la decisión.
4. Explícame qué cambió y deja la prueba funcional grande dentro del editor de Godot de mi lado.

### 3. `[MODO: NOCHE]` (Autónomo Total / Suite Completa TDD)
- **Instrucción clave**: Bucle autónomo profundo, cobertura total y 0 fallos.
1. Ejecuta la suite completa de pruebas en consola en modo headless tras cada modificación:
   `flatpak run --filesystem=$HOME/Documentos org.godotengine.Godot --headless --path . --script tools/test_juego.gd`
2. Escribe pruebas unitarias automáticas para cada nueva función o mecánica implementada.
3. Si un test falla, analiza y corrige el código en un bucle autónomo hasta conseguir 0 fallos en la suite completa.
4. Al terminar toda la sesión, genera o actualiza el registro de cambios (`CHANGELOG.md`).

## REGLAS DE GIT Y COMMITS
- Antes de editar, revisa `git status --short` y los últimos commits. Los cambios ya presentes se consideran trabajo del usuario.
- Mantén cada tarea o función en un commit lógico para que pueda revertirse por separado. Antes de empezar una función grande, propón un checkpoint si el árbol está limpio.
- No hagas `reset --hard`, `checkout --`, `restore` ni borrados amplios para revertir trabajo sin confirmar. Si los cambios están mezclados, revierte solo los hunks identificados; si no se pueden separar con seguridad, pregunta.
- No crees commits, los enmiendes ni hagas push sin autorización explícita. Con autorización, revisa `git diff` y `git status`, prepara solo rutas intencionadas (nunca `git add .`) y usa un mensaje breve en español con verbo de acción.

## REGLAS GENERALES DE ARQUITECTURA
- No rompas el contrato de `INSTANCE_CUSTOM` en Shaders.
- Mantén la simulación de corte en arrays de GDScript para permitir ejecución headless.
- Respeta la hoja de ruta del proyecto.

## REGLAS DE LOS MODELOS (BLENDER)
- **Todo modelo se abre en Blender con ventana, con el modelo importado, para
  que el usuario lo vea.** Exportarlo en background no cuenta: background es
  para generar y medir, y el último paso es siempre abrirlo a ojo.
- Se abre con `tools/abrir_modelo.py`, que importa el `.glb`, vacía la escena
  de arranque para que no queden el `Cube` y la luz de fábrica encima, y
  encuadra la máquina en la vista. **No vale con pasarle el fichero a
  Blender**: da `File format is not supported`.
  ```
  flatpak run --filesystem=$HOME/Documentos org.blender.Blender \
      --python "$PWD/tools/abrir_modelo.py" -- "$PWD/models/desbrozadora_100x.glb"
  ```
  Las rutas van con `$PWD` porque el flatpak arranca Blender en su propio
  directorio y no encuentra el proyecto con rutas relativas.
- Se carga el modelo tal cual, sin recolocar ni recolorear la máquina: el
  origen y la jerarquía (`Corte`, `Giro`) se respetan, porque de eso depende
  el juego.
- Se lanza en segundo plano (`nohup ... &`) y no se espera a que se cierre: la
  ventana se la queda el usuario.
- Si Blender no se puede abrir (no hay pantalla, o el flatpak falla), se avisa
  y se sigue con el trabajo. No se bloquea la tarea por no poder mostrarlo.
---
