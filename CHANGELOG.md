# Registro de cambios

Lo que se ha tocado y por que. Para el detalle de como esta cada cosa por dentro,
[DOCUMENTACION.md](DOCUMENTACION.md); para el estado y los problemas que quedan,
[REVISION.md](REVISION.md).

## Revision completa: dos bugs que ninguna prueba cazaba, y limpieza — 2026-09-29

- **La maquina no empujaba los restos.** En `_process` habia un
  `pass  # DIAG: _apartar_restos() desactivada` olvidado, mientras toda la
  documentacion decia que apartabas el escombro al pasar. **Ninguna prueba lo
  veia** porque las tres llamaban a `restos.empujar()` a mano, saltandose el
  bucle de fotogramas. Es la clase de fallo que no aparece nunca: la API
  funciona, la prueba pasa y el juego no lo hace.
  - Reactivado, y anadida una prueba que **pasa por el bucle de verdad** y
    comprueba el contador de empujones. Medido: **231 empujones** sin que nadie
    llame a `empujar()`.
  - Al reactivarlo apareció un segundo fallo que llevaba **escondido desde que
    estaba desactivado**: `empujar` suma velocidad a proposito (un cuerpo
    aparcado se come el impulso), pero la maquina llama unas ocho veces por
    segundo, y sin tope son 7,2 m/s: el escombro salia a **doce metros**.
    Ahora `Restos.VELOCIDAD_APARTAR_MAX` (2 m/s) lo limita.
- **Tres intentos fallidos al medir el escombro, y por que.** La media de
  posiciones del pool **no sirve para nada**: da 48 -> 1211 cm (la maquina se
  aleja catorce metros), luego 1274 -> 135 cm (el cabezal va hacia el escombro) y
  luego 45 -> 686 cm (al cortar, el pool se recicla y las piezas reaparecen a
  siete metros). Lo que no miente es el **contador de empujones**. Y una
  comprobacion sobre un conjunto de piezas vacio pasa sin comprobar nada: hacia
  falta decirlo porque es como se cuela un test que no prueba nada.
- **Sacan las reglas del cabezal a `scripts/estacion_cabezal.gd`.** Un
  `RefCounted` que **no toca un solo nodo**: que cabezal va, cuanto filo le
  queda y como responde a cada planta. La desbrozadora solo cuelga el modelo que
  esa clase elige. Mismo patron que `motor_desbrozadora.gd`, que ya existia y
  funciona.
  - **Premio: `tools/test_estacion_cabezal.gd`**, que prueba las reglas del
    cabezal **sin montar la maquina**. Antes habia que instanciar `main.tscn`,
    esperar a que el arbol creciera y tirar el cabezal real.
  - **El ciclo de cabezales se habia roto al sacarlo**: se llamaba a
    `montar(indice() + 1)` sin modulo, `montar` se negaba en el ultimo y el ciclo
    se detenia ahi. Solo lo cazaban las pruebas de la maquina entera.
  - **`configurar()` monta el primero, a proposito.** Cuando solo guardaba la
    lista, quien se olvidaba de llamar a `montar(0)` se quedaba con una estacion
    **sin cabezal y sin ningun error**. Lo cazó la prueba nueva.
  - **Y un parametro llamado `disponibles` hacia fallar el script entero**, con 33
    fallos en la suite principal que no tenian nada que ver con el cabezal. El
    error de GDScript senalaba el cuerpo de la funcion y el problema era la firma.
  - `medir_cabezales.gd` ya no escribe un campo privado de la desbrozadora desde
    una herramienta, que es lo que hacia antes.
- **`cortar()` de 141 a 48 lineas.** Hacia cinco cosas: el freno grueso, el
  reparto en sectores, el reparto de cuotas y el bucle. Ahora son
  `_repartir_en_sectores()` y `_repartir_cuotas()`. **Sin cambio de
  comportamiento**: sigue dando 144 hojas y `[18, 18, 18, 18, 18, 18, 18, 18]`.
- **Un banner duplicado en `desbrozadora.gd`:** las dos mitades del fichero
  se llamaban "La resistencia de la maleza", y la segunda no tiene nada que ver.
  La segunda ahora se llama "El cabezal, el desgaste y lo que la maquina le
  cuenta al mundo".
- **Cuatro `.uid` huerfanos** de los scripts de zarza borrados.
- **Seis ficheros sin documentar**, ya documentados: `motor_desbrozadora.gd`,
  `cabezal_desbrozadora.gd`, `interfaz_herramienta.gd`, `bosque.tscn` frente a
  `arbol.tscn`, y `shaders/piedra.gdshader`.
- **`shaders/piedra.gdshader` no lo usa nadie, y se queda.** Son 117 lineas de
  granito gallego terminado, hechas para la aldea, que es una fase que todavia no
  existe. Borrar trabajo terminado no es limpieza, es tirar comida. Ahora se
  documenta como "hecho, sin usar" para que no se borre por error ni se
  redescubra dentro de seis meses.

## Se borra el sistema de montones; el suelo solo guarda restos — 2026-09-29

- **Las "pilas de rectangulos" del campo no eran los restos.** Habia **dos
  sistemas** dejando material en el suelo y se confundian porque se pisaban el
  sitio: `Restos`, los motitos, y `Montes`, que guardaba el material acumulado en
  una rejilla de celdas de 50 cm y lo dibujaba con un `MultiMesh` de cajas. Era el
  **unico `BoxMesh` del proyecto entero** y median 46 cm. De ahi las cajas.
- **`Montes` esta borrado entero** (decision del usuario): `scripts/montes.gd`,
  `_apisonar()` en la desbrozadora, el `aportar()` que llamaba `Restos.soltar()` y
  las consultas de dos pruebas. En el suelo solo quedan los trozos de `Restos`.
  - **Lo que se pierde**, y queda anotado a proposito: el amontonado ya no crece
    sin limite, asi que una pasada larga ya no levanta un monton de 55 cm que haya
    que rodear. Desaparece la regla de juego de "no basta con dar dos pasadas por
    el mismo sitio". Es una decision, no una mejora tecnica.
  - Antes de borrarlo se intento arreglar la malla y **estaba bien y no era la
    solucion**: la pregunta no era si las cajas parecieran montones, sino si el
    suelo tenia que tener dos sistemas.
- **En su lugar, lo que hacia falta:** `test_vegetacion_tier3.gd` comprueba que el
  escombro **caiga junto al corte**, que es lo que hacia util el monton: la pasada
  siguiente tiene que pisar donde acaba de cortar y no dejar un reguero a tres
  metros.
- **Diagnostico retirado por falso, y conviene no repetirlo.** La primera
  conclusion fue "48 cubos de un metro amontonados en el origen del mundo", y
  venia de leer el `MultiMesh` de vuelta. En headless **no se puede**: en cuatro
  maneras distintas de escribir, `get_instance_transform` devuelve la identidad
  siempre, porque sin servidor de render el `MultiMesh` no guarda los datos. Es el
  mismo caso que `get_instance_custom_data`, que ya estaba anotado.
- **Prueba nueva, `tools/test_origen_restos.gd`:** enumera que hay en el suelo tras
  cortar cada una de las tres plantas y **avisa si aparece algo que no sea un
  resto**, que es como se caza un sistema fantasma. Dio un dato que no se ve
  jugando: hay que **cortar avanzando**, porque quieto el material se queda donde
  cae y no se acumula. En 10 metros: 12 celdas con el cesped, 21 con la maleza, 42
  con la zarza.
- **Ocho funciones muertas fuera**, a las que no se llamaba desde ningun sitio
  y que arrastraban comentarios que ya no describian nada: `get_cabeza()`,
  `angulo_cabeza()`, `_cercania_al_tope()`, `ids_de_los_huecos()`,
  `get_giro_total()`, `cuantos_cerca()`, `velocidad_de()` y `fuerza_media()`.
  Una de ellas, `get_giro_total()`, decia "lo usa la camara para el retardo de la
  mirada" y la camara no lo llamaba: un comentario que miente es peor que uno que
  falta.
- **Un test fallaba una de cada dos, y no habia nada roto.** `test_vegetacion_tier3`
  comprobaba que el escombro se apartara un 20 % en distancia **media**, y al
  dispersar la salida de los restos la media de partida paso de 0,33 a 0,62 m segun
  que trozos se reciclan. Medido seis veces: el escombro se aparta **once
  centimetros en las seis**, exactamente igual; solo bailaba la linea base. Ahora
  pide 6 cm en absoluto, que es lo que el ratio viejo codificaba. Es el mismo
  fallo que ya se habia corregido en `test_movimiento_integrado.gd` y aqui se
  habia olvidado. Un test intermitente es peor que uno que falla siempre, porque
  entrena a ignorarlo.
- **Documentacion al dia.** `DOCUMENTACION.md` era lo peor: la seccion 12 entera
  (mas de cien lineas) describia la maraña con raiz e inundacion, que se borro
  hace semanas, y la tabla de `tools/` listaba ocho ficheros inexistentes y no
  mencionaba ninguno de los nuevos. Tambien, la API de `hierba.gd` listaba
  funciones que no existen y no listaba las nuevas. En `LEEME.md` havia una
  instruccion para ejecutar `foto_pruebas_zarza.gd`, borrado hace semanas, y
  `DISENO.md` daba por hecha una regla de juego que ya no aplica.

## El corte se abre en sectores y los restos dejan de ser bloques — 2026-09-29

- **El claro salia hecho de manchurrones.** El cabezal morda una celda al azar y
  un sector entero se limpiaba mientras el de al lado conservaba todas sus hojas.
  Ahora el disco se reparte en **ocho sectores de 45 grados**, cada uno con la
  octava parte del presupuesto y su resto decimal propio, y dentro de cada sector
  se corta de dentro hacia fuera. Medido sobre 60 fotogramas, de una partida
  inicial de `[26, 24, 26, 21, 23, 25, 25, 23]`, se pierden
  `[18, 18, 18, 18, 18, 18, 18, 18]`: dieciocho en los ocho.
  - Se descarto el reparto barato de "la hoja mas cercana", que se ve mucho mejor
    pero en una mata pasa por encima, o faila a la base y se viene la corona entera
    de golpe: con el nylon la zarza se vaciaba en un fotograma, mas rapido que con
    un disco de tres puntas. **Ninguna prueba lo caza**, porque las pruebas miden
    el total y no el reparto.
  - Se descarto tambien la orla a media altura, que era mas organica todavia pero
    ponia el corte **14 veces mas lento**. Queda anotado el margen, 0,012 hojas.
- **El borde del disco tiene dientes.** Cada hoja tiene su propio umbral de
  distancia, fijo, que sale de **donde esta** y no del azar. Que sea fijo es lo
  importante: si saliera del azar en cada fotograma, una hoja entraba y salia y el
  claro parpadeaba al avanzar.
- **Los restos parecian bloques apilados, y lo eran.** Cinquenta trozos tumbados
  horizontales, en el mismo plano, con una sola silueta y de 36 cm con la zarza:
  una pila de losas. Ahora:
  - **Orientacion libre en los tres ejes**, que era el problema de verdad. Con los
    trozos horizontales, cincuenta planchas superpuestas son una pila de ladrillos.
  - **Malla curva** de cinco tramos, con arco y retorcido, para que el trozo se
    quede apoyado en dos puntos con el hueco por debajo.
  - **Cuatro siluetas distintas**, tamano de 0,55 a 1,35 por trozo, y uno de cada
    cinco desaturado hacia pajizo.
  - Trozos un 30 % mas pequenos y con el tope de escala de la planta bajado de
    2,6 a 1,5; el pool sube de 50 a 110 porque las piezas son mas pequeñas y el
    coste esta en las que estan despertando, no en las aparcadas.
- **El repartido por sectores expose un fallo propio:** el resto decimal se
  reiniciaba cada fotograma, y con 2,5 hojas por fotograma entre 8 sectores la
  parte entera se quedaba en cero y **no se cortaba nada**. Lo cazan dos pruebas
  nuevas, `test_corte_organico.gd` y `test_vegetacion_tier3.gd`.
- **Documentacion al dia:** `LEEME.md` (ocho sectores, restos, tabla de las tres
  plantas corregida, que ponia 20 por m2 en la zarza cuando va a 60) y
  `REVISION.md` (por que se descartaron los otros dos repartos, y por que hay dos
  acumuladores de resto decimal y no es una duplicacion).

## La zarza es el tier 3 y el escombro pesa — 2026-09-29

- **La zarza deja de ser un sistema propio.** Borrados `zarza.gd` (888 lineas con
  celdas, coronas, raices, enredo e inundacion), tres escenas y siete pruebas.
  Ahora es un preset de `scenes/vegetacion/zarza.tscn` que hereda de `hierba.tscn`
  con otros numeros: misma hoja, color y forma distintos, y **la misma densidad
  que la maleza**, 60 por metro cuadrado. Su dificultad tiene que venir de la
  dureza, no de estar mas rala. La tabla de las tres plantas esta en `LEEME.md`.
- **El escombro ahora tiene cuerpo y pesa.** Pool de `RigidBody3D` con forma de
  hoja (no cajas), 0,35 kg cada uno, que caen al
  suelo **al lado** del corte, se quedan y **se apartan con la maquina**. Alimentan
  los montones desde cualquier planta, no solo de la zarza. Cinco bugs que solo
  aparecieron al mirar: la mascara a cero los hacia caer al vacio; la friccion del
  suelo se comia el empuje; un cuerpo dormido no recibe impulsos; `Montes.obtener`
  creaba **dos gestores distintos** en dos llamadas seguidas (el nodo se anade en
  diferido) y el material se perdia en el primero; y el propio "aparcar lo que se
  ha parado" deshacia el empuje en el mismo fotograma.
- **Lo que no se nota en el codigo pero se notaba jugando:** el peso del cuerpo
  sobre la maquina se media con las **vueltas del motor**, asi que con la carga
  alta el motor bajaba y la maquina se erguida sola: cuanto mas trabajo habia, mas
  alto se quedaba el morro. Ahora lo pone el acelerador.
- **La mecanica de raiz desaparece**, y hay que decirlo: el corte es un disco en el
  suelo y una hoja cortada no se vuelve a cortar, asi que una pasada y punto. La
  dificultad del tier 3 esta en el coste (motor, hilo, gasolina), no en el numero
  de pasadas.
- **`tools/test_vegetacion_tier3.gd`** (nueva, 20 comprobaciones) mide el alcance
  del morro **con la maquina de verdad** y lo compara con la hoja mas alta real de
  cada mata. Nacio porque el usuario probo el juego y reporto que las zarzas
  eran gigantes y no se cortaban, y eso no lo cubria ninguna prueba. Los tres
  fallos que reporto (matorral desmesurado, morro que se levanta, escombro que no
  parece escombro) estan ahora medidos.

## Los cabezales pasan a tener estrategia de tier — 2026-09-29

- **Cada cabezal tiene eficacia y resistencia contra cada planta**, las dos en
  1 a 5. La eficacia es un presupuesto de corte por fotograma, y la resistencia
  se lleva el filo **y** frena el motor. La tabla completa esta en
  [LEEME.md](LEEME.md) y en [REVISION.md](REVISION.md).
- **Subir de nivel no es mejor en todo, y esa es la gracia.** El nylon es el mas
  rapido con la hierba y el peor con todo lo demas: contra la zarza la abre, pero
  a mordiscos, comiendose el hilo y ahogando el motor. El disco de tres puntas
  es el mejor con maleza y zarza y el **peor con la hierba**. Elegir cabezal es
  elegir trabajo, y el juego se pone interesante en el momento en que el
  cabezal "mejor" no es el que te sirve para lo que tienes delante.
- **Se acaba la lista de "esto no lo puedes cortar"** en los cabezales. El nylon
  no puede con la maleza era mentira: la abre de pena. Ahora todos cortan de
  todo y lo que decide son los numeros.
- **El corte es un presupuesto, no un rayo instantaneo.** Por eso el mismo
  Disco tarda 50 fotogramas en abrir la misma pasada de zarza que el de tres
  puntas abre en 14, y por eso un cabezal malo sale mas caro: el motor esta mas
  rato ahogado y la gasolina se nota.
- **Las escalas se ajustaron después de que el usuario lo probara y dijera que
  no se notaba ni el frenado ni el desgaste y que todo cortaba mucho.** Tenia
  razon: los tres numeros estaban en una escala que no se ve. La base de corte
  del cesped baja de 200 a 50 hojas/s, y el motivo es el que hace que todo lo
  demas tenga sentido: **andando a 2 m/s se pisan unas 150 hojas por segundo**,
  asi que con 200 la base iba sobrada y los cuatro cabezales se sentian
  iguales. El desgaste por hoja sube 50 veces (era 0,0000 por segundo) y la
  carga del motor se sube con `densidad_corte` de 110 a 75.
- **El corte con presupuesto ahora va de arriba abajo.** Antes mordia una celda
  al azar y, si le tocaba la base de una mata, la corona entera caia de golpe:
  medido, el nylon vaciaba la zarza en un fotograma, mas rapido que un disco de
  tres puntas que muerde cuatro veces mas. Un cabezal lento tirando el zarzal
  antes que uno rapido era un agujero del modelo. Ahora se shavea la copa, luego
  el tallo y la raiz se llega al final, que es ademas la mecanica que el juego ya
  explicaba.
- **`tools/medir_cabezales.gd`** (nuevo, no es un test) mide carga, vueltas,
  desgaste por segundo y gasolina de cada cabezal en cesped, maleza y zarza. Es
  la herramienta que responde con numeros a "no se nota", en vez de suponer. Y
  tiene una trampa documentada: para medir el desgaste hay que **andar**, porque
  quieto el cabezal se come el disco en el primer segundo y no hay nada mas que
  cortar, y el desgaste sale a cero.
- **`tools/test_cabezales.gd`** (nueva, 28 comprobaciones) deja escrito por que
  la tabla es coherente como juego y no como lista de numeros: que cada peldaño
  aguanta mas que el anterior, que el mejor con la maleza es el peor con la
  hierba, y que la parte decimal del presupuesto se guarda (1,00 celdas por
  fotograma tardan 50 en vaciar la pasada, 1,67 tardan 31).

## La maleza vuelve a ser maleza, y la raiz de la zarza es alcanzable — 2026-09-29

- **La maleza esta en matas de verdad.** `formacion` subio de 0,24 a 0,70 en
  `main.tscn` y con ello paso de ocupar el 93 % del mapa (una alfombra de 0,76 m
  donde no se veia nada) al 37 %, con claros por los que se anda. Era lo que
  pedia la comprobacion de la suite desde hacia tiempo, y el usuario lo confirmo
  al preguntarle que queria: matas separadas, no alfombra.
- **Se midio el rango real del cabezal** y se documenta en `LEEME.md`. Con el
  motor echado el morro recorre de 0 a 2 m segun la mirada, y **cualquier mirada
  hacia abajo lo deja en el suelo**. Por eso "cortar por arriba" es mirar un poco
  **arriba**, no menos abajo. Antes no estaba escrito en ningun sitio y hacia
  falta saberlo para jugar.
- **`tools/test_zarza_raiz.gd`** (nueva) cierra la garantia que faltaba: que una
  pasada **de verdad**, con el jugador y la maquina reales, tumba una raiz. Las
  demas pruebas de zarza cortaban llamando a `cortar_en()` con un punto dado, lo
  que demuestra que la mecanica esta bien pero no que se pueda jugar. La pasada
  por arriba deja la raiz viva y la pasada a la base se la lleva.
- `Desbrozadora.distancia_anticipacion()`: la distancia a la que se mide la
  resistencia de verdad era `max(anticipacion, radio + 0,20)` dentro de una
  linea, y una comprobacion la calculaba por su cuenta con una cuenta vieja.

## Inventario de nueve herramientas y la hoz — 2026-09-28

- La desbrozadora deja de ser un nodo fijo de la escena y pasa a ser un objeto
  del inventario, equipado en el hueco 1 al abrir el juego. El hueco 2 lleva la
  **hoz**, que se ha generado en Blender con `tools/crear_hoz_mesh.py` (114
  triángulos, 45 cm, mango de madera, virola y hoja en media luna con el filo
  por dentro). Corta cesped y maleza, y no entra en la zarza.
- La rueda del raton mueve la mano por **nueve huecos**, y la eleccion se dibuja
  como una rueda de nueve sectores en la esquina superior derecha. Un hueco
  vacio son las manos vacias: los brazos se quedan al lado del cuerpo, en una
  pose, y no desaparecen.
- `G` suelta lo de la mano: se desprende y cae. `E` recoge lo que se esta
  mirando, va al primer hueco libre y ademas se equipa. Con el inventario lleno
  el aviso es otro, porque si no el jugador ve "recoger", pulsa y no pasa nada.
- `Herramienta` (Resource) describe lo que el inventario necesita saber sin
  instanciarla. Los nodos que van en la mano siguen siendo los de antes: la
  desbrozadora no se ha tocado. Lo unico que se ha unificado es el contrato con
  la vegetacion (`tipo_vegetacion`, `cortar_por_banda`, y las cuatro preguntas
  que hacen las dos herramientas), que antes estaba filtrado por
  `is Desbrozadora` y hacia que la hoz no cortase nada.
- Pruebas: `tools/test_inventario.gd` recorre la secuencia entera pedida (soltar
  y recoger la desbrozadora, cambiar a la hoz con la rueda, soltarla y recogerla,
  y soltar las dos y recogerlas **al reves**) y comprueba que la herramienta
  vuelve al hueco que le toca y no al primero. También que solo hay una
  herramienta montada. Suite focalizada en OK; el recorrido integrado sigue en
  **71/71** y los tres tests de zarza en OK.
- Cuatro bugs que salieron por el camino, todos del mismo tipo: lo que se
  rompia de verdad se escondia en un sitio improbable.
  - `seleccionar` cambiaba el numero de hueco **antes** de equipar, con lo que
    la herramienta anterior nunca se guardaba: se quedaba montada y en el grupo
    a la vez que la nueva, y las dos cortaban.
  - Un `CanvasLayer` no hereda la visibilidad de su padre, así que el panel de
    la desbrozadora se quedaba encima con la hoz en la mano.
  - El pivote de las manos cuelga de "Caderas", y ese nodo esta en el origen del
    jugador, **a los pies**, no a la cintura. Con offsets de decimetros la hoz y
    las manos sueltas quedaban enterradas en la maleza.
  - Dos herramientas soltadas en el mismo punto aparecen encajadas y la fisica
    las manda cada una a un lado. Ahora se sueltan medio palmo hacia un lado.

## Zarza con raíz, enganches e inundación — 2026-09-28

- La zarza deja de ser un mapa de alturas ("cuanto queda en pie aqui") y pasa a
  ser una maraña: cada celda guarda su altura, si hay **corona** (raíz, el
  anclaje al suelo) y a qué vecinos se agarra. Tras cada corte, una **inundación
  desde las coronas vivas** marca qué se sostiene qué, y todo lo que no quede
  marcado cae a montones. La regla sale sola: cortar la base de una mata tumba lo
  que solo se sostenía con ella, y lo de arriba sigue en pie si tiene otro
  enganche con raíz. Mientras quede una raíz, la zarza vuelve.
- El cabezal secciona todo lo que asoma por encima de su altura. Antes una
  pasada a ras de suelo **no cortaba nada** en celdas altas, porque la banda de
  corte impedía que llegara abajo.
- `densidad` aclara la hoja, no el tallo. Antes abría huecos estructurales y cada
  hueco partía la maraña: se perdía un tercio de la zarza sin haberla tocado.
- Se corrigió el mismo bug de `instance_count` que había en la zarza, también en
  `Montes`: subir el contador de uno en uno dentro del bucle rehace el buffer del
  MultiMesh y borra lo anterior, con lo que de toda la pila de escombro se
  quedaba en pie una sola caja.
- `scenes/pruebas_zarza.tscn` estaba **rota**: pedía un `overlay_prueba_zarza.gd`
  que no existía. Se ha escrito y se han montado seis matas que aíslan cada
  regla, con las raíces marcadas en pantalla (caja roja) y los enganches
  (raya amarilla).
- Pruebas: `tools/test_zarza_conexion.gd` (nueva) demuestra la regla de la
  conexión con dos raíces; `test_zarza_capas` y `test_zarza_capas_recorrido`
  actualizados al modelo nuevo. Las tres en OK.

## La zarza no se veía en pantalla — 2026-09-28

- La zarza se sembraba bien y **no pintaba nada**: `_dibujar` subía
  `instance_count` de uno en uno antes de escribir cada hoja, y cada cambio
  rehace el buffer del MultiMesh. Sobrevivía una sola instancia, la última.
  Medido con `tools/medir_zarza.gd`: de 2 píxeles a 52.320 en el prado vacío.
- La zarza además salía **plana**: `INSTANCE_CUSTOM.x` (cuánto le queda de
  altura) se mandaba como `alto / altura_maxima` en vez de `alto / su altura de
  origen`, con lo que el shader encogía cada hoja por dos.
- Aun dibujando, desde el punto de aparición solo se veía el 4 % de la foto: la
  maleza alta de 0,76 m tapa el 83 % del encuadre. La mata cercana se subió a
  2,4 m y se apartó a 7 m para que se lea por encima.

## Estado de las pruebas en `v0.1.0`

| Prueba | Resultado |
| --- | --- |
| `tools/test_juego.gd` (suite completa) | **207 correctas, 0 fallos, 1 aviso** |
| `tools/test_movimiento_integrado.gd` | 71/71 |
| `tools/test_inventario.gd` | OK |
| `tools/test_zarza_conexion.gd` | OK |
| `tools/test_zarza_raiz.gd` | OK |
| `tools/test_cabezales.gd` | OK (28/28) |
| `tools/test_vegetacion_tier3.gd` | OK (20/20) |
| `tools/medir_cabezales.gd` | medidor, no es test |
| `tools/test_zarza_capas.gd` | OK |
| `tools/test_zarza_capas_recorrido.gd` | OK |

**La suite queda en verde: 207 correctas, 0 fallos.** Salio seis veces en rojo, y
las seis tenian dos causas distintas:

- **Cuatro por numeros viejos.** El cesped bajo a 0,49 m y la maleza a 0,76 m, y
  las comprobaciones seguian esperando las alturas de antes. Ahora se compara la
  altura **tipica** de cada campo y no la hoja mas alta suelta, y el check de
  "la maleza le pasa al operario" se ha invertido: se pide que pase la rodilla y
  **no** llegue a la cara.
- **Dos por bugs de verdad.** El apoyo del cabezal se media mirando a 50 grados
  y sin acelerar, y el morro solo baja **con el motor echado**. Y la anticipacion
  de la resistencia se comprobaba contra una cuenta que el codigo ya no usaba:
  ahora `Desbrozadora.distancia_anticipacion()` es la fuente y se mira esa.

La ultima ejecucion completa antes de estos cambios dio **202 correctas / 0
fallos**; el 28-09-2026 se probo a mano en Godot y el usuario confirmo que
funcionaba.

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

## Radio de corte común — 2026-09-28

- `radio_corte` deja de ser una propiedad de `Hierba`: pasa a
  `Desbrozadora.radio_corte`, que representa el cabezal montado.
- El primer valor, 0,13 m (radio geométrico de la cuchilla), no dejaba una pasada
  visible. Se amplió a un radio efectivo de 1,0 m para alcanzar suficientes
  hojas, manteniendo un único valor para corte y resistencia.
- Se quitaron los dos overrides diferentes de `main.tscn` y se actualizaron las
  pruebas para asegurar que ningún campo de vegetación tenga su propio radio.
- Parseo de Godot correcto y prueba integrada con corte en ambos campos:
  **55/55**. La suite completa queda pendiente.

La prueba focalizada `tools/test_movimiento_integrado.gd` cubre 55 comprobaciones
combinadas de paneo, giro, WASD, carrera, agachado, salto y acelerador, incluida
la mirada alta con el motor en marcha y el corte compartido de ambos campos;
última ejecución: **55 correctas, 0 fallos**. Detectó también que el crouch bajaba la vista dos veces; ahora
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
