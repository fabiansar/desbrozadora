# Registro de cambios

Lo que se ha tocado y por que. Para el detalle de como esta cada cosa por dentro,
[DOCUMENTACION.md](DOCUMENTACION.md); para el estado y los problemas que quedan,
[REVISION.md](REVISION.md).

Última suite completa automatizada registrada: **202 correctas, 0 fallos y 1
aviso esperado** en headless; la prueba integrada de movimiento registró
**48/48**. El 28-09-2026 el usuario probó manualmente la versión actual en Godot
y confirmó que funciona correctamente. No se repitió la suite completa después
de esa prueba.

## Base estable confirmada — 2026-09-28

Este punto es la base funcional desde la que continuar el desarrollo. La prueba
manual del usuario cubrió la versión actual del proyecto después de retirar la
interacción experimental `E`/`Q`; la desbrozadora vuelve a permanecer anclada al
arnés. El commit que introduce este registro fija exactamente el código de esta
base: **`8da06a626c01250e0dda99fa3df17095e6e7dac0`**.

## Guía para aportaciones manuales

Se añadió [docs/para_principiantes/](docs/para_principiantes/README.md), con
pasos iniciales para Godot/GDScript, Blender, Git y pruebas. La guía identifica
el commit estable anterior como punto de partida para experimentar y aprender
sin asistente.

## Regreso temporal al suelo plano — 2026-09-28

- `main.tscn` vuelve al suelo plano inicial: malla de 160 × 160 m y colisión
  hasta radio 80 m. La hierba, la maleza y el bosque continúan activos sobre
  `Y = 0`.
- Se retiraron `scripts/terreno.gd`, `scripts/aldea.gd` y las dependencias que
  sembraban o excluían objetos mediante sus APIs.
- `tools/test_juego.gd` deja de comprobar relieve y parcelas y verifica el plano,
  su collider y el apoyo del cabezal. El valle y la aldea manuales quedan para
  una fase futura, con el plugin de terreno aún por elegir.
- Parseo del editor y arranque de la escena durante 60 fotogramas en Godot 4.7.2
  headless, sin errores. `test_movimiento_integrado.gd`: **48/48** correctas. La
  suite completa queda pendiente.

La prueba focalizada `tools/test_movimiento_integrado.gd` cubre 48 comprobaciones
combinadas de paneo, giro, WASD, carrera, agachado, salto y acelerador, incluida
la mirada alta con el motor en marcha; ultima ejecucion: **48 correctas, 0
fallos**. Detecto tambien que el crouch bajaba la vista dos veces; ahora
`Jugador` es el unico que mueve la cabeza y la camara solo suma el bamboleo. No
sustituye a la suite larga.

El modelo activo de la herramienta es `models/desbrozadora.glb`. Su giro se
corrige sobre el eje Y y conserva `Giro`/`Corte`. La pose de trabajo se ha
ajustado a `alcance = 1,56 m` e `inclinacion_reposo = -22°`; se mantiene el yaw
Y para el barrido y no se tocan los pivotes ni los objetivos de las manos.

## Barra extendida y FOV calibrable

- La barra tubular de la desbrozadora pasa de 0,95 m a **2,06 m**; el conjunto
  mide **2,46 m** y el cabezal queda en `y = -1,56 m`. El motor se coloca detrás
  del operario, a la derecha, y el cable llega a su caja. El GLB se regeneró y
  pasó las comprobaciones de geometría y dimensiones.
- `scripts/desbrozadora.gd` usa `alcance = 1,56 m`; `_altura_del_suelo()` consulta
  el terreno bajo el cabezal actual. La suite verifica el apoyo físico durante
  el trabajo, también al bajar más la mirada.
- `scripts/camara_gopro.gd` expone `ajuste_fov` (−20° a +20°), con valor neutro
  `0`; el FOV horizontal base sigue en 100° y se abre 12° al correr. La posición
  de la cámara no cambia.
- Se retiró el offset vertical de cámara y la comprobación que dependía de él;
  el FOV queda para probar manualmente en el editor (Modo Vivo).
- Últimas validaciones anteriores al ajuste FOV: suite **202/202** y recorrido
  integrado **48/48**.

## Interacción inicial con objetos (retirada)

La primera implementación experimental permitía desanclar/recoger con `E`,
soltar con `Q` y lanzar con `G`. Se retiró porque causaba errores: la
desbrozadora vuelve a ser un `Node3D` permanentemente anclado al arnés. También
se quitaron el punto de agarre virtual, las colisiones de recogida y el soporte
genérico para sostener objetos. Los brazos visibles continúan siguiendo los
marcadores del manillar.

Primera iteracion de cuerpo y agarres: `models/personaje_trabajo.glb` es un
personaje low-poly completo (1,98 m, 796 triangulos) integrado en la escena del
jugador. El torso y la parte inferior quedan visibles por defecto; se ocultan la
cabeza y los brazos estáticos, y los brazos dinámicos siguen los marcadores de
agarre. Se ensanchó y escalonó la postura de los pies para separarlos en la vista
desde arriba. La lente se adelanta 0,30 m y la mirada inicial baja 40 grados. La captura
de inspección de `tools/foto_personaje.gd` mira 80 grados hacia abajo. **La pose
GoPro sigue en calibración visual**: hay que revisar la lectura de torso y piernas
en juego, no solo en la captura.

## Limpieza y preparación para ampliar el juego

- La suite se puso al día con la escena actual: ahora busca parches sembrados
  determinísticamente, acepta radios de corte distintos por campo y verifica que
  torso y cuerpo inferior estén visibles. La rotación del carrete se valida con
  su ángulo acumulado, no con la fase envuelta.
- `Hierba.regenerar()` reemplaza sus cuadrantes y reconstruye la rejilla de corte;
  `medir_densidad.gd` ya no llama a `_sembrar()` a medias ni deja buffers viejos.
- `Aldea` sustituye los diccionarios de parcelas y ocupaciones por tipos con
  campos explícitos y ofrece consulta por ID para futuros encargos. La suite
  verifica los IDs, límites del layout y exclusiones de siembra.
- `rpm` y `cortando` son propiedades de lectura sin getters duplicados; la RPM de
  corte, la resistencia y la telemetría quedan con una API explícita.
- `Desbrozadora.telemetria_actualizada` expone RPM libre, RPM bajo carga y
  resistencia para que una futura UI consuma datos sin acoplarse al nodo visual.
- `crear_desbrozadora.py` queda como alias del generador vigente, las rutas de
  salida de las herramientas Blender se derivan del proyecto y se retiraron dos
  acciones de entrada sin uso.
- Validación de esa iteración: **200 correctas, 0 fallos y 1 aviso headless**; recorrido integrado
  **48/48**. Vulkan en la RX 6600 midió, para la escena actual, **52,4 %** de
  píxeles cambiados al ocultar el césped y **54,7 %** de píxeles verdes.
- `medir_densidad.gd` ya reporta la regeneración segura del césped; con 60 hojas/m²
  y radio 66 m sembró 255.360 hojas. El peor fotograma medido fue 8,3 ms, limitado
  por VSync a 120 fps.

---

## Terreno procedural y aldea (histórico; retirados temporalmente)

Las secciones siguientes registran la implementación procedural anterior. Ya no
forma parte de la escena ni del código activos; el prototipo volvió al plano de
pruebas descrito arriba.

El prado llano deja de existir. Ahora el suelo se genera con pendiente, ondulacion,
terrazas y surcos de arado, y en esa ladera hay una aldea de minifundios con sus
huertos cerrados con muro de piedra seca.

### El terreno

- `scripts/terreno.gd` (`class_name Terreno`, `extends StaticBody3D`) genera el
  suelo por código en un área de 240 × 240 m: 6 grados de pendiente, ondulación,
  terrazas y surcos de arado. La escena usa 400 fragmentos de 12 m, 67.600
  vértices y 135.200 triángulos. Las normales se calculan con diferencias entre
  alturas vecinas.
- La malla va troceada con AABB propio por trozo, que es lo que permite el
  culling: con una sola malla de 135.000 triangulos no habria culling posible.
- La colision se construye con los triangulos **expandidos**, sin compartir
  vertices entre trozos. Con vertices compartidos, `set_faces()` se come los
  indices y la ladera se atraviesa andando.
- `altura_origen` deja el centro del mapa en `y = 0`, que es donde aparece el
  jugador.
- La API (`cota_en`, `cota_en_3d`, `cotas`, `pendiente_en`, ...) es la unica
  fuente de altura del juego. Hierba, arboles, aldea y maquina la preguntan.

### La aldea: última implementación modular (retirada)

En aquella implementación `scripts/aldea.gd` no generaba geometría. Calculaba una cuadrícula de 4 × 3 (12)
parcelas de 15 × 12 m y colocaba casas, muros, carretera, árboles y arbustos desde
el catálogo `assets/models/aldea/*.glb`. El catálogo estaba vacío, así que las
ubicaciones eran placeholders `Node3D` con metadata `asset_path`.

Cada instancia consultaba `terreno.cota_en()`. `Aldea/PuntoInicioFurgoneta` era el
`Marker3D` del tramo principal, y `Aldea.dentro()` / `Aldea.ocupada()` excluían
parcelas y edificios de la siembra. Esas APIs ya se eliminaron.

### La aldea: histórico procedural sustituido

Lo siguiente describe la versión anterior, ya reemplazada por el catálogo
modular; no es el contenido ni la configuración activos de `main.tscn`.

- La versión anterior de `scripts/aldea.gd` montaba una **cuadricula de 12
  parcelas** de 15 x 12 m, con 5 casas y dos hórreos, mediante geometría
  procedural. Ese generador se sustituyó por el layout modular descrito arriba.

  Las parcelas van en cuadricula y no sueltas porque van a ser el marco del
  juego: un vecino te puede pedir que le desbrozes una, y para eso tiene que
  haber manera de decir "la parcela 7" y de llegar hasta ella. Cada parcela
  guarda su `id`, su fila y su columna.

- **Los muros van por lineas de cuadricula, no alrededor de cada parcela.** Con un
  muro por parcela, el de una caia encima del de la vecina y en las juntas se
  veian dos paredes peleandose por el mismo metro de suelo. Ahora entre dos
  parcelas hay un solo muro. El paso va solo en las lineas de fila, para que
  cada parcela tenga un hueco y solo uno.

- **La calle va sobre una linea de muros**, con el muro abierto a lo ancho de la
  calzada, y dos ramales fuera del bloque. Antes el camino se trazaba de casa en
  casa con el vecino mas cercano, y con las parcelas sueltas pasaba por encima
  de los huertos y de los muros.

- Los tejados a dos aguas caian **al reves**: los dos faldones bajaban hacia el
  centro y dejaban una V en medio, con la caballera flotando por encima sin
  tocar nada. De lejos no se leia como tejado.

- Los muros de las casas ya no son cajas planas a la altura del solar, que en
  una ladera hundian la esquina de abajo y dejaban la de arriba en el aire. Ahora
  se trazan con el mismo camino que los muros de las parcelas, siguiendo el
  suelo a escalones.

- La aldea se coloca en el sitio llano **y visible** desde el punto de
  aparicion, a menos de 62 m. Antes salia en el llano mas bueno del mapa, que
  estaba a cien metros y detras de un lomo: desde donde aparece el jugador se
  veia un tejado de nueve y el resto no se veia. Ahora la aldea ocupa el 28,6 %
  del cuadro.

- En la implementación modular actual hay una ubicación de casa por parcela;
  sin modelos, todas son placeholders. La selección de parcelas de encargo aún
  no está implementada.

- Las cajas de colision cuelgan de un `StaticBody3D` llamado `Solidos`. Sueltas
  bajo el `Node3D` de la aldea no colisionaban con nada y Godot no avisaba.

- 7.908 caras en 6 mallas, unas 100 ms de generacion. Los muros van sin
  colision a proposito: uno de piedra seca de un metro se salta, y un trimesh de
  4.000 triangulos hace que la maquina se enganche en los bordes.

### Hierba y bosque sobre el terreno

- `scripts/hierba.gd` y `scripts/bosque.gd` admiten `terreno` y `aldea`. Con el
  terreno, cada hoja y cada árbol se siembran a la altura del suelo. La hierba
  excluye las zonas ocupadas por casas y carretera; el bosque excluye el área de
  las parcelas. Los recuentos dependen de la configuración y no se fijan aquí.
- Las dos referencias se pasan por el inspector, y en el `.tscn` los nodos que
  las tienen necesitan `node_paths=PackedStringArray(...)` en la cabecera. Sin esa
  linea Godot lee la propiedad, no la encuentra en la lista y la deja a null sin
  decir nada.

Las secciones de fases anteriores son históricas: sus recuentos y parámetros
describen el estado de entonces. Para la configuración activa, consultar
`scenes/main.tscn` y [DOCUMENTACION.md](DOCUMENTACION.md).

## Fase 2 — La maleza (tipo 2), la resistencia y el morro que sube

El cesped de siempre se queda, y encima aparece un segundo tipo de hierba: alta,
seca y en matas. El motor nota lo que tiene debajo y va mas despacio, y la
maquina sube de verdad cuando el operario mira para arriba.

### Segundo tipo de hierba

- `scenes/main.tscn` lleva ahora un segundo campo, `MalezaAlta`, con su semilla,
  su material y su troceado. 31.162 hojas de 145 cm, en 62 cuadrados de 12 m.
- La maleza sale en **matas**: con `formacion = 0,78` solo se siembra el 34 % del
  terreno, y se ven claros de verdad. Con `formacion` a 0 sembraba como una
  alfombra y no hacia falta un segundo tipo de nada.
- `dureza` es el coste por hoja, y lo usa la desbrozadora al medir la
  resistencia (no va al shader: el shader no sabe quanto cuesta nada). Con esto
  la maleza no es solo "mas densa", es "cuesta mas". Sin `dureza` el motor solo
  notaria el numero de hojas, y una zarza y un cesped espeso se cortarian igual.
- Colores secos y distintos: `(0,20; 0,16; 0,08)` en la base y `(0,48; 0,40;
  0,19)` en la punta, frente al verde del cesped.
- Se corta con la misma maquina y el mismo radio. Es la condicion para que la
  segunda herramienta no se note como una herramienta distinta.

### El viento: uno para todo el prado

- **El nodo `Viento` se ha movido de `scenes/hierba.tscn` a `main.tscn`.** Al
  partir la hierba en varios tipos, cada campo traia su propio nodo `Viento`, y
  habia dos mapas peleandose por los mismos materiales y poniendole cada uno su
  reloj. El viento pertenece al mundo, no a un campo.
- Se conecta a los campos por el grupo `hierba`, y se da cuenta de los que
  aparezcan despues durante los primeros fotogramas, que es cuando el motor
  carga la escena.
- El tamano de celda se calcula con el radio **mayor** de todos los campos, para
  que la uv de cualquier hoja caiga en el mapa.
- Si el radio se cambia en caliente, se reescriben las uv de todas las hojas sin
  tocar los otros dos canales de `INSTANCE_CUSTOM`. Es la trampa que estaba
  anotada en `REVISION.md` 4.1, y ahora hay pruebas que la vigilan.

### La resistencia

- El motor y el barrido se frenan con lo que hay **de pie** por delante del
  cabezal, no debajo. Mirar justo debajo daba cero siempre, porque la hierba de
  ahi la acaba de cortar la propia maquina en ese mismo fotograma.
- La distancia de mira no es fija: tiene que pasar del ancho del cabezal, o el
  punto cae dentro de lo recien cortado.
- El suavizado va **aparte** de la medida. Medir cada 0,15 s y suavizar solo en
  esos fotogramas tardaba varios segundos en llegar al tope, y con el cesped
  normal se quedaba a media carga sin que se notara.
- `densidad_corte` va por encima de la densidad con la que se siembra, para que
  el tope no se alcance en un cesped normal y haya recorrido real entre un claro
  y un zarzal.

### El morro que sube

- **Mirar arriba sube la maquina.** Antes el morro se quedaba clavado en su
  angulo de reposo para cualquier mirar y el cabezal no pasaba de 0,35 m: no
  habia forma de cortar nada por encima de la rodilla. Ahora llega a 0,99 m
  mirando 45 grados arriba, y se ve en la foto.
- `morro_para_altura()` devuelve la solucion de por delante del arco, que es la
  que usa el juego. Con la de atras daba un morro hacia el suelo y decia que la
  maleza era inalcanzable.

### La cuchilla: gira sobre Z

- El carrete giraba con `giro.rotation.y`, que es el eje a lo largo del tubo. La
  cuchilla va tumbada, con su eje en la vertical, que en el modelo es el Z. Con
  el giro en Y la cuchilla daba vueltas **de lado a lado** y cortaba de canto.
- El nodo `Giro` va sin inclinacion a proposito: en `YXZ` cualquier inclinacion
  previa se sumaria a la de cada fotograma y la dejaria de girar plana.
- La prueba de "el carrete gira" leia `rotation.y`, o sea, el mismo eje que ya no
  se usaba. Fallaba a veces y pasaba otras, segun si el barrido movia el nodo
  entre las dos lecturas. Ahora lee el eje bueno, y hay una prueba aparte que
  mira los tres ejes.

### La camara y el ladeo

- El ladeo de la herramienta estaba multiplicado por 6 (`rad_to_deg(_barrido *
  6.0)`), lo que convertia un barrido de 96 grados en un ladeo absurdo. Bajado a
  una ganancia de 0,07, y con un tope de 8 grados.
- `ladeo_herramienta` ya no se exporta desde la camara: la camara lo recibe de la
  maqueta. Antes estaba cableado en los dos sentidos.

### Las pruebas

- La suite pasa de 131 a **183 comprobaciones, 0 fallos**. Las nuevas son: siembra
  y corte del tipo 2; que la maleza es mas alta que el operario y esta dentro del
  alcance del cabezal; que hay huecos entre matas; que los dos campos se mueven
  con el mismo mapa de viento y tienen colores distintos; que el refresco de uv
  reescribe **todas** las hojas y **solo** la uv; y que ese refresco se hace solo
  al cambiar el radio.
- Nuevas tambien para la resistencia (que frena, que el motor parado no frena, y
  que dentro de la maleza hay mas hojas que en un claro) y para el morro (que
  sube mirando arriba, que llega a la parte alta de la maleza, que se ve el
  cabezal y que al volver la vista baja).
- `tools/medir_foto.gd` estaba **roto** desde que la hierba se parto en
  cuadrados: buscaba el campo como `MultiMeshInstance3D` cuando es un `Node3D`
  con un `MultiMesh` por cuadrante. Reventaba en cada fotograma y la foto salia
  siempre igual, o sea, no comprobaba nada. Ahora mide bien: **93,9 %** de
  pixeles cambian al ocultar la hierba.

### El fallo de las pruebas que no era del codigo

La misma suite daba 0 fallos en headless y 2 o 10 con ventana, y no siempre
igual. La causa era `_esperar()`, que contaba milisegundos del reloj del
sistema: Godot solo recupera 8 pasos de fisica por fotograma, asi que un
fotograma lento dejaba la simulacion atrasada, la espera se agotaba antes de
tiempo y las pruebas que miden movimiento veian al jugador a medio camino. En
headless no se notaba porque ahi no hay tirones.

Ahora `_esperar()` cuenta fotogramas de verdad, de fisica y de proceso, y sale
cuando han pasado los dos.

Con eso la suite ya no depende de la velocidad de la maquina, pero **no se lanza
entera con ventana** en un equipo sin GPU: a render por software va a unos
1 fps y tardaria doce minutos. La comprobacion de imagen se hace aparte con
`tools/medir_foto.gd`, que tarda 3 segundos. En el mensaje de la suite, el aviso
de imagen dice ahora el comando exacto para cerrarlo.

### Control de versiones

- Repositorio git en `main`, con remoto en GitHub.
- `AGENTS.md` con los tres modos de trabajo: `[MODO: VIVO]`, `[MODO: SEMI]` y
  `[MODO: NOCHE]`.
- `.gitignore` para lo que Godot se regenera solo (`.godot/`, 5 MB de cachés).

---

## Antes de esto

### Fase 1 — Fundamentos

- Cuadrantes de 8 m en el campo de hierba, con caja ajustada y culling por
  distancia, en vez de un unico MultiMesh que no descartaba nada.
- Simulacion de corte en arrays de GDScript, para que todo esto se pueda probar
  en headless sin GPU.
- La desbrozadora cuelga de las caderas, con el barrido asimetrico (+96 a la
  izquierda, -38 a la derecha), inercia y peso al acelerar.
- La camara va en la cabeza, con limite automatico de inclinacion para que el
  cabezal nunca se salga del encuadre.
- El viento por zonas, con un mapa de fuerza por celdas.
- Suite de pruebas automaticas en `tools/test_juego.gd`.

Los bugs de fondo que se corrigieron entonces estan todos explicados uno a uno en
[REVISION.md](REVISION.md) (secciones 2a a 2j), con el motivo de cada uno, porque
son el tipo de fallo que vuelve si no se deja escrito por que paso.
