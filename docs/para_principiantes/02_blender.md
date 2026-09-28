# Blender desde cero

Aquí Blender sirve para crear y revisar modelos que luego usa Godot. La regla
principal es que los `.glb` del juego dependen de su escala, origen, ejes y
jerarquía, no solo de su aspecto.

## 1. Abrir un modelo del proyecto

Abre una terminal en la raíz del repositorio y ejecuta:

```bash
nohup flatpak run --filesystem=$HOME/Documentos org.blender.Blender \
  --python "$PWD/tools/abrir_modelo.py" -- "$PWD/models/desbrozadora.glb" \
  >/tmp/desbrozadora_blender.log 2>&1 &
```

Para abrir el personaje, sustituye el último argumento por:
`"$PWD/models/personaje_trabajo.glb"`.

Se usa `tools/abrir_modelo.py` porque pasar el `.glb` directamente a Blender
como argumento no lo importa correctamente. El script limpia la escena inicial,
importa el modelo y encuadra la vista. Blender se abre con ventana para que puedas
inspeccionarlo; el proceso puede seguir abierto aunque cierres la terminal.

## 2. Qué mirar al inspeccionar

- ¿Se ve completo y desde un tamaño razonable?
- ¿Las piezas están donde deben y no hay geometría perdida lejos del modelo?
- ¿El origen está donde el juego necesita sujetar o apoyar el objeto?
- ¿La jerarquía conserva los nombres que consulta Godot?
- ¿La escala tiene sentido en metros?

No recoloces ni recolorees la desbrozadora solamente para que quede bonita en la
vista de Blender: el juego depende de su origen y de sus nodos.

## 3. Generadores y ficheros fuente

Los modelos principales se generan con scripts de Python que usan la API de
Blender. El `.py` es la receta reproducible; el `.glb` es el resultado que carga
Godot.

| Modelo | Fuente | Resultado |
| --- | --- | --- |
| Desbrozadora | `tools/crear_desbrozadora_mesh.py` | `models/desbrozadora.glb` |
| Personaje | `tools/crear_personaje_mesh.py` | `models/personaje_trabajo.glb` |
| Furgoneta | `tools/crear_furgoneta_mesh.py` | `models/furgoneta.glb` |

Para regenerar la desbrozadora:

```bash
flatpak run --filesystem=$HOME/Documentos org.blender.Blender --background \
  --python "$PWD/tools/crear_desbrozadora_mesh.py"
```

Para regenerar el personaje:

```bash
flatpak run --filesystem=$HOME/Documentos org.blender.Blender --background \
  --python "$PWD/tools/crear_personaje_mesh.py"
```

`--background` sirve para generar y medir, no para la revisión visual final. Tras
generar un modelo, ábrelo con ventana usando `tools/abrir_modelo.py`.

## 4. Editar a mano o cambiar el generador

Si el modelo lo genera un script, una edición manual del `.glb` se perderá la
próxima vez que se regenere. Para conservar un cambio, ajusta primero el script
generador y vuelve a exportar. Si decides retocar un `.glb` directamente,
documenta ese flujo para no sobrescribirlo por accidente.

Un flujo de aprendizaje seguro es:

1. Abre y mira el modelo actual.
2. Abre el generador `.py` y busca la función que crea la pieza o el material.
3. Cambia una medida o un color pequeño.
4. Ejecuta el generador.
5. Abre el `.glb` nuevo en una ventana de Blender.
6. Si la forma es correcta, ejecuta Godot y comprueba la escena.

## 5. Ejes, origen y transformaciones

Blender usa Z como eje vertical; Godot usa Y. Los generadores del proyecto
exportan glTF con la conversión de ejes configurada en
`tools/exportar_blender.py`. No añadas una rotación arbitraria al nodo raíz para
corregir una pieza que exportó mal: averigua primero en qué espacio está el
error.

Reglas concretas de la desbrozadora:

- El origen principal es el punto de referencia donde el juego cuelga la
  herramienta.
- Se conservan los nombres y la jerarquía `Giro` y `Corte`.
- `Giro` debe poder rotar en el eje que usa `scripts/desbrozadora.gd`; hoy es
  `rotation.y` en Godot.
- La barra y el cabezal deben mantener sus medidas y alineación. El generador
  contiene comprobaciones y comentarios sobre ese contrato.
- Aplica escala y rotaciones a la geometría antes de exportar cuando el
  generador así lo requiera.

El personaje tiene una jerarquía propia (`Personaje`, `Cabeza`, `Torso`, brazos)
porque Godot oculta algunas piezas y sustituye los brazos estáticos por otros
que siguen los puños.

## 6. Llevar el modelo a Godot

1. Guarda o genera el `.glb` dentro de `models/`.
2. Espera a que Godot importe el recurso; puede tardar unos segundos.
3. Abre la escena que lo instancia y comprueba el árbol de nodos.
4. Ejecuta con `F5` y observa posición, escala y orientación en el juego.
5. Si se ve mal, compara el resultado con el modelo abierto en Blender y cambia
   una sola cosa cada vez.

Godot crea archivos `.import` para guardar opciones de importación. No borres ni
edites esos archivos para corregir la forma del modelo: corrige la geometría o
la escena que la instancia.

## 7. Añadir un modelo a la aldea

El catálogo modular de la aldea busca rutas como
`assets/models/aldea/casa_1.glb`. Ahora el catálogo puede no contener modelos y
la aldea usa placeholders. Para añadir uno:

1. Guarda el `.glb` en la carpeta correspondiente dentro de `assets/models/aldea/`.
2. Abre el modelo con el helper de Blender y revisa escala, origen y orientación.
3. Añade o cambia la ruta en el catálogo exportado de `scripts/aldea.gd`.
4. Ejecuta el juego y comprueba que apoya en el terreno y no tapa zonas de forma
   inesperada.

Los modelos de casa, muro, carretera, árbol y arbusto no comparten necesariamente
el mismo origen; mira el contexto de `_instanciar()` antes de cambiar una ruta.

## 8. Solución rápida de problemas

- **Blender dice “File format is not supported”:** abre el archivo con
  `tools/abrir_modelo.py`, no pasando el `.glb` directamente al programa.
- **No encuentra el script o el modelo:** ejecuta desde la raíz y usa rutas con
  `"$PWD"` como en los comandos anteriores.
- **La pieza aparece desplazada:** revisa origen, padre y `matrix_parent_inverse`
  en el generador.
- **La herramienta gira torcida:** comprueba `Giro`, `Corte`, los ejes y las
  transformaciones aplicadas antes de cambiar código de cámara.
- **Godot no muestra el modelo nuevo:** espera la importación y revisa la ruta del
  recurso en la escena y el panel FileSystem.
