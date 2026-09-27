# Registro de cambios

Lo que se ha tocado y por que. Para el detalle de como esta cada cosa por dentro,
[DOCUMENTACION.md](DOCUMENTACION.md); para el estado y los problemas que quedan,
[REVISION.md](REVISION.md).

---

## Fase 3 — El terreno y la aldea

El prado llano deja de existir. Ahora el suelo se genera con pendiente, ondulacion,
terrazas y surcos de arado, y en esa ladera hay una aldea de minifundios con sus
huertos cerrados con muro de piedra seca.

### El terreno

- `scripts/terreno.gd` (`class_name Terreno`, `extends StaticBody3D`) genera el
  suelo por codigo: 6 grados de pendiente, ondulacion de 12,6 m, terrazas y
  surcos de arado. 400 trozos de 12 m, 67.600 puntos y 135.200 triangulos, unos
  500 ms de generacion, y las normales calculadas con `generate_normals()`.
- La malla va troceada con AABB propio por trozo, que es lo que permite el
  culling: con una sola malla de 135.000 triangulos no habria culling posible.
- La colision se construye con los triangulos **expandidos**, sin compartir
  vertices entre trozos. Con vertices compartidos, `set_faces()` se come los
  indices y la ladera se atraviesa andando.
- `altura_origen` deja el centro del mapa en `y = 0`, que es donde aparece el
  jugador.
- La API (`cota_en`, `cota_en_3d`, `cotas`, `pendiente_en`, ...) es la unica
  fuente de altura del juego. Hierba, arboles, aldea y maquina la preguntan.

### La aldea

- `scripts/aldea.gd` (`class_name Aldea`) reparte 18 parcelas y 9 casas, mas dos
  hórreos, caminos y lomos de labranza. Todo se apoya en `terreno.cota_en()`.
- Las parcelas van cerradas con su muro de piedra seca, con hueco para el paso, y
  el muro baja y sube escalon a escalon siguiendo el suelo, que es lo que hace
  un bancal de verdad.
- Los tejados van mitad de paja y mitad de pizarra, con `shaders/piedra.gdshader`
  para la piedra: sillares, juntas, grano y musgo por la altura sobre el suelo.
- Una malla por material (6 en total) en vez de una por casa: unas 11.600 caras
  en seis llamadas de dibujo.
- Las cajas de colision cuelgan de un `StaticBody3D` llamado `Solidos`. Sueltas
  bajo el `Node3D` de la aldea no colisionaban con nada y Godot no avisaba.
- El reparto va en tres pasadas de mas a menos exigencia. Con 6 grados de
  pendiente, 22 m de lado ya son 2,3 m de desnivel, asi que el filtro estricto
  solo encontraba 4 parcelas y la aldea salia a medias.
- Se deja un claro de 24 m en el centro: es donde aparece el jugador y tiene que
  quedar libre, que aparecer dentro de un huerto cerrado es empezar mal.

### Hierba y bosque sobre el terreno

- `scripts/hierba.gd` y `scripts/bosque.gd` admiten `terreno` y `aldea`. Con el
  terreno, cada hoja y cada arbol se siembran a la altura que tenga el suelo ahi.
  Con la aldea, no se siembra dentro de los recintos: 0 de 377.821 hojas caen en
  un huerto.
- Las dos referencias se pasan por el inspector, y en el `.tscn` los nodos que
  las tienen necesitan `node_paths=PackedStringArray(...)` en la cabecera. Sin esa
  linea Godot lee la propiedad, no la encuentra en la lista y la deja a null sin
  decir nada.

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
