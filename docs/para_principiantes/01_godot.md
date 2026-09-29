# Godot desde cero

Esta guía explica cómo inspeccionar y modificar el juego desde el editor, sin
necesitar conocer de memoria Godot ni GDScript.

## 1. Abrir y ejecutar

Desde la raíz del repositorio:

```bash
flatpak run --filesystem=$HOME/Documentos org.godotengine.Godot --path .
```

Atajos importantes del editor:

| Acción | Atajo |
| --- | --- |
| Ejecutar el juego principal | `F6` ejecuta la escena actual; `F5` ejecuta el proyecto |
| Detener | `F8` o el botón Stop |
| Guardar la escena actual | `Ctrl+S` |

Para probar el juego completo usa `F5`. Si estás editando una escena aislada,
`F6` es útil, aunque algunas escenas necesitan objetos que solo existen en la
escena principal.

## 2. Cuatro palabras de Godot

- **Nodo:** una pieza de la escena. Puede ser un jugador, una cámara, una luz o
  un `Marker3D`.
- **Escena (`.tscn`):** un árbol de nodos guardado. Una escena puede instanciar
  otra; por ejemplo, `main.tscn` instancia `jugador.tscn`.
- **Script (`.gd`):** código que da comportamiento a un nodo.
- **Recurso:** un archivo reutilizable, como una textura, un sonido, un material
  o un modelo `.glb`.

En el panel **Scene**, selecciona un nodo. El panel **Inspector** enseña sus
propiedades. La pestaña **Script** abre el código asociado. El panel inferior
**Output** y la pestaña **Debugger** muestran errores y advertencias.

## 3. Dónde está cada sistema

| Quiero tocar… | Empiezo por… |
| --- | --- |
| Escena y configuración del campo | `scenes/main.tscn` |
| Movimiento, ratón y agachado | `scripts/jugador.gd` |
| Cámara GoPro y encuadre | `scripts/camara_gopro.gd` |
| Barrido, inclinación, motor y corte | `scripts/desbrozadora.gd` |
| La hoja, el motor y los depósitos | `scripts/motor_desbrozadora.gd` y `scripts/cabezal_desbrozadora.gd` |
| Los huecos, la rueda y soltar/coger | `scripts/inventario.gd` y `scripts/rueda_inventario.gd` |
| La segunda herramienta | `scripts/hoz.gd` y `scenes/hoz.tscn` |
| La zarza, que es el nivel 3 de la misma hoja | `scenes/vegetacion/zarza.tscn` |
| Los trozos de escombro que quedan en el suelo | `scripts/restos.gd` |
| Siembra y corte de hierba | `scripts/hierba.gd` |
| Viento que mueve las hojas | `scripts/viento.gd` y `shaders/hierba.gdshader` |
| Suelo plano temporal | `scenes/main.tscn`, nodo `Suelo` |
| Modelo de primera persona | `models/personaje_trabajo.glb` y `scripts/brazos_primera_persona.gd` |

El flujo habitual de una escena es:

```text
scenes/main.tscn
  ├── Suelo     → plano y colisión para pruebas
  ├── Bosque    → scripts/bosque.gd; árboles sobre Y=0
  ├── Hierba    → scripts/hierba.gd
  ├── MalezaAlta→ scripts/hierba.gd, el mismo script con otro tipo
  ├── Zarzas    → scenes/zarza.tscn, cinco matas
  ├── Viento    → scripts/viento.gd
  └── Player    → scenes/jugador.tscn
                   ├── Cámara     → scripts/camara_gopro.gd
                   ├── Brazos     → scripts/brazos_primera_persona.gd
                   ├── Inventario → scripts/inventario.gd
                   │                └── crea la herramienta del hueco 1
                   └── Caderas
                        └── PivoteDesbrozadora
                             └── Desbrozadora → scenes/desbrozadora.tscn
                                                └── scripts/desbrozadora.gd
```

Dos cosas que sorprenden de este árbol y conviene saber antes de tocar nada:

- **La desbrozadora no está en la escena.** La crea `Inventario` al equipar el
  hueco 1 y la cuelga del pivote. Si buscas la herramienta en `main.tscn` o en
  `jugador.tscn` y no la encuentras, está en el inventario.
- **El nodo `Caderas` está a los pies del jugador, no en la cadera.** El
  nombre engaña, y por eso cualquier altura que pongas ahí va desde el suelo.

## 4. El primer cambio: ajustar algo sin programar

Es la forma más segura de aprender el Inspector:

1. Ejecuta el proyecto y observa cómo se ve la hierba.
2. Detén el juego con `F8`.
3. Abre `scenes/main.tscn` y selecciona el nodo `Hierba`.
4. En el Inspector cambia una propiedad visual, por ejemplo `altura`, un poco.
5. Guarda con `Ctrl+S`, ejecuta con `F5` y compara.
6. Si el resultado empeora, vuelve a poner el valor anterior y guarda.

**Importante:** una escena puede guardar un valor propio que sustituye al valor
por defecto del script. Si cambias un `@export` en el código y en el juego no se
nota, busca esa propiedad en `main.tscn` o en la escena que instancia el nodo.
Para la hierba principal, los valores activos están en `scenes/main.tscn`.

## 5. Leer GDScript sin aprenderlo todo primero

GDScript se parece a Python, pero Godot usa tipos y nodos. La indentación define
qué instrucciones pertenecen a una función.

```gdscript
extends Node3D

@export var fuerza := 0.25
var tiempo := 0.0

func _process(delta: float) -> void:
    tiempo += delta
```

- `var fuerza`: variable editable por el script.
- `@export`: también aparece en el Inspector.
- `:=`: Godot deduce el tipo a partir del valor inicial.
- `func`: empieza una función.
- `_ready()`: se ejecuta cuando el nodo entra en el árbol de la escena.
- `_process(delta)`: se ejecuta una vez por fotograma; `delta` es el tiempo
  desde el fotograma anterior.
- `_physics_process(delta)`: se ejecuta con el reloj fijo de física; úsalo para
  movimiento y colisiones.

En este proyecto, `class_name Desbrozadora` permite usar ese tipo desde otros
scripts, y `extends Node3D` indica qué clase de nodo base necesita el script.
Los nombres de métodos que empiezan por `_` suelen ser detalles internos; antes
de cambiar uno, busca quién lo llama con la búsqueda global del editor.

### Un cambio de código controlado

1. Abre el script asociado al nodo desde el Inspector.
2. Busca la variable o función que quieres entender.
3. Lee también unas líneas antes y después; no cambies solo una palabra sin ver
   quién usa ese valor.
4. Cambia una cosa y guarda.
5. Mira el panel Output. Si Godot marca una línea, corrige primero ese error.
6. Ejecuta el juego y prueba el caso concreto.

No cambies una variable llamada `delta` por segundos fijos: el juego puede ir a
distintas velocidades de fotogramas. Para movimiento gradual, multiplica la
velocidad por `delta`.

## 6. Nodos y rutas

Las rutas dependen exactamente del árbol de la escena. Por ejemplo,
`Cabeza/Camara` significa “hijo `Camara` dentro de `Cabeza`”. Si renombras un
nodo, revisa sus referencias en el Inspector y las búsquedas por nombre en los
scripts.

Las propiedades `NodePath` de una escena deben apuntar a un nodo existente. En
los `.tscn`, Godot registra esas propiedades en `node_paths=PackedStringArray(...)`;
si añades una ruta a mano y el nodo queda `null`, deja que el editor la configure
desde el Inspector o revisa también esa lista.

Para añadir un nodo de prueba:

1. Selecciona el padre correcto en el panel Scene.
2. Pulsa `+`, busca el tipo de nodo (por ejemplo `Marker3D`) y créalo.
3. Ponle un nombre que describa su función.
4. Guarda y ejecuta. No añadas nodos al azar a `main.tscn`: algunos sistemas
   esperan grupos, rutas y orden concretos.

## 7. Entradas y señales

Las acciones de teclado viven en **Project → Project Settings → Input Map** y
también están serializadas en `project.godot`. El código pregunta por nombres de
acción (`"acelerador"`), no por la tecla física directamente. Si renombras una
acción, actualiza todos sus usos.

Una señal comunica que algo ocurrió sin obligar al receptor a inspeccionar todo
el objeto. Por ejemplo, `Desbrozadora.telemetria_actualizada` publica datos del
motor para que una futura interfaz pueda escucharlos.

## 8. Shader y hierba: un contrato que hay que conservar

La hierba usa `MultiMesh`: miles de hojas se dibujan en grupos, no como miles de
nodos individuales. La simulación de corte se mantiene en arrays de GDScript para
que las pruebas puedan ejecutarse sin tarjeta gráfica.

El shader recibe datos por `INSTANCE_CUSTOM`; sus cuatro componentes tienen un
uso acordado entre GDScript y shader. **No cambies el significado ni el orden de
esos componentes en un solo lado.** Revisa `scripts/hierba.gd`,
`shaders/hierba.gdshader` y las pruebas relacionadas.

## 9. Comprobar cambios

Godot puede abrir el proyecto en modo editor sin mostrar una ventana y detectar
errores de carga o de scripts:

```bash
flatpak run --filesystem=$HOME/Documentos org.godotengine.Godot \
  --headless --editor --path . --quit
```

Para ejecutar todas las pruebas automatizadas:

```bash
flatpak run --filesystem=$HOME/Documentos org.godotengine.Godot \
  --headless --path . --script tools/test_juego.gd
```

Para probar solo el recorrido combinado de movimiento:

```bash
flatpak run --filesystem=$HOME/Documentos org.godotengine.Godot \
  --headless --path . --script res://tools/test_movimiento_integrado.gd
```

Ejecuta estos comandos desde la raíz del proyecto. Después de cambios visuales,
la última palabra la tiene una prueba con ventana: headless no dibuja la hierba
como la GPU.

## 10. Si algo falla

1. Lee la primera línea roja de Output; las siguientes a menudo son consecuencia
   del primer error.
2. Anota el archivo, la línea y los pasos exactos que lo producen.
3. Deshaz el último cambio pequeño y comprueba si desaparece.
4. Si el error menciona `null`, revisa que el nodo exista y que su ruta sea
   correcta.
5. Si el juego se queda quieto, comprueba que la acción exista en Input Map.
6. Si una escena deja de cargar, revisa rutas a escenas, modelos y scripts.

No borres `.godot/` para arreglar errores de script: esa carpeta contiene caché
regenerable y borrarla no corrige una ruta o una variable mal escrita.
