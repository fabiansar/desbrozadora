# Documentacion tecnica

Todo lo que hay hecho, archivo por archivo y con el porque. Esta es la
referencia para tocar el proyecto sin romper lo que ya funciona.

---

## 1. Como esta montado

La escena principal es `scenes/main.tscn`. Es lo unico que se ejecuta; todo lo
demás cuelga de ahi.

```
main.tscn (Mundo)
├── Entorno        WorldEnvironment: cielo, luz de ambiente, tonemap, SSAO y glow
├── Suelo          StaticBody3D + plano de pruebas de 160x160 m y colisión
│   ├── Colision   cilindro de 160 m de radio y 0,4 m de alto
│   └── Malla      PlaneMesh con `shaders/suelo.gdshader`
├── Sol            DirectionalLight3D, la luz principal
├── Relleno        DirectionalLight3D, luz de relleno sin sombras
├── Bosque         arboles de prueba sobre el plano (colision capa 3)
├── Cesped         césped agrupado, 60 hojas/m², cuadrantes de 24 m
├── MalezaAlta     maleza en matas, 60 hojas/m², cuadrantes de 12 m
├── Zarza          zarza (mancha de 9 m), 1,5 m de alto, 7 m delante del jugador
├── Viento         el mapa del viento, UNO para los tres campos
├── Player         el jugador (CharacterBody3D)
│   ├── Cabeza     pivote a 1,62 m; la lente va 0,30 m hacia delante
│   │   └── Camara la camara en primera persona
│   ├── Colision   capsula de 0,35 m de radio y 1,7 m de alto, centrada a 0,85 m
│   ├── Cuerpo      modelo low-poly del operario
│   │   └── Modelo  personaje_trabajo.glb
│   ├── Brazos      brazos de primera persona, ligados a la herramienta
│   ├── Inventario  los nueve huecos y la rueda, con las guardadas dentro
│   ├── RuedaInventario  CanvasLayer: la rueda y los avisos
│   └── Caderas     donde va colgada la maquina
│       └── PivoteDesbrozadora
│           └── Desbrozadora   Node3D, lo que lleva en la mano en el hueco 1
└── Version        CanvasLayer: el cartel de la version al arrancar
```

Dos cosas de ese arbol que se ven de leerlo:

- **El nodo se llama `Cesped`, no `Hierba`.** `Hierba` es el `class_name` del
  script (`scripts/hierba.gd`) y tambien el nombre de la escena base
  (`scenes/vegetacion/hierba.tscn`) de la que salen las tres. En `main.tscn` lo
  que hay es una instancia de `cesped.tscn` llamada `Cesped`.
- **Hay tres campos de vegetacion, uno por planta:** `Cesped`, `MalezaAlta` y
  `Zarza`. Los tres tipos son el mismo script con otros numeros, y el tipo lo
  decide el atributo `tipo` de cada preset (1 cesped, 2 maleza, 3 zarza).
- **Un nodo por planta: `Cesped`, `MalezaAlta` y `Zarza`, hermanos al mismo nivel
  y sin ningun grupo alrededor.** Estructura identica para las tres, porque las
  tres son la misma clase; lo unico que cambia son los numeros del preset y el
  aspecto. Estuvo habiendo un contenedor `Zarzas` con cinco instancias de la
  zarza, cada una con su `altura`, su `radio` y su `semilla`: se aplanó y se
  redujo a una el 2026-09-30, porque la excepcion en la jerarquia no la pedia
  ningun script (todo se localiza por el grupo `vegetacion` / `hierba`, como
  hacen `viento.gd:132` y `desbrozadora.gd:772`) y hacia mas dificil de entender
  lo que es igual. Colocar zarzas en varios sitios es decision de mapa, no de
  esta escena.

Lo de `Caderas` es importante y no es un detalle de colocacion: la maquina
cuelga de las caderas y **no** de la camara, porque el arnes es lo que justifica
que los dos lados sean distintos. `desbrozadora.gd` coloca el pivote en cada
fotograma segun hacia donde se mira, asi que ni `main.tscn` ni `jugador.tscn` le
fijan ninguna transformacion.

Y ojo con una cosa de ese arbol que sale de nuevo: **`Caderas` esta en el origen
del jugador, y el origen del jugador esta a los pies**, no a la cadera. El
nombre engaña. Cualquier altura que se ponga ahi va desde el suelo: la cintura
de un operario de 1,7 m esta ahi en el 0,85, no en el 0.

La desbrozadora **ya no esta en la escena**: la crea `Inventario` al equipar el
hueco 1, y la lleva al pivote. La escena de la herramienta sigue siendo
`scenes/desbrozadora.tscn`, y la de la hoz `scenes/hoz.tscn`; lo unico que cambia
es quien las ponen y donde.

De `Entorno`: **no hay niebla.** El `Environment` solo lleva cielo, luz de
ambiente, tonemap ACES, SSAO y glow. Una version anterior si la tenia y se
quedo sin ella al retirarse el terreno procedural.

Las capas de fisica, y **los nombres ya estan escritos en `project.godot`**
(seccion `[layer_names]`), que es lo que hace que el Inspector los enseñe:

| Capa | Nombre | Quien | Puesto en |
| --- | --- | --- | --- |
| 1 | `mundo` | el suelo | `main.tscn:54-58` (por defecto, no se escribe) |
| 2 | `jugador` | el jugador | `jugador.tscn:24` |
| 3 | `bosque` | troncos y copas de los arboles | `arbol.tscn:37` |
| 4 | `herramienta suelta` | las herramientas en el suelo, para poder cogerlas | `inventario.gd:36` |
| 8 | `restos` | **sin uso desde 2026-09-30**: los restos son particulas y no tienen cuerpo | — |

**En el codigo el numero de capa se desplaza.** `inventario.gd`
guarda el **numero** de capa y lo pone con `1 << (capa - 1)`. No hay ningun
script que ponga una mascara suelta: por eso `collision_layer = 8` seria la capa
8, y el 4 de la herramienta suelta se escribe `1 << (4 - 1)`. La 4 se deja
sola, apartada de las de colision, para que el rayo de recogida no se confunda
con nada.

**Mascaras**, y por que son esas: el jugador lleva `5` (1 y 3), o sea que
**choca** con el suelo y con los arboles pero **no** con una herramienta suelta:
se puede andar por encima de una desbrozadora en el suelo sin que el suelo se
hunda. Los rayos que miden la altura del suelo
(`desbrozadora.gd:1070`, `restos.gd:284`) llevan `1 | 2 | 4`: ven el suelo, el
jugador y los arboles, y no la herramienta suelta.

**Decisiones que ya estan tomadas y no hay que volver a mirar:**

- La desbrozadora cuelga de un pivote bajo `Caderas`, no de la camara ni de las
  manos. El nombre `PivoteDesbrozadora` se conserva, pero ya no cuelga de la
  camara: el nombre pica, la jerarquia manda.
- **El cabezal esta SIEMPRE dentro del encuadre.** Su posicion cambia con el
  alcance y la inclinacion de la maquina, así que `CamaraGopro._pitch_limitado()`
  mide el punto de corte real y acomoda la vista; no depende de una distancia o
  un angulo fijo. El jugador puede mirar hasta 55 grados hacia arriba. Antes el
  cabezal se salia **a proposito**; ahora se mantiene en pantalla para poder ver
  donde corta la hoja.
- El corte se busca en un **disco horizontal en X/Z** bajo el cabezal. El radio
  único `Desbrozadora.radio_corte` pertenece a la herramienta: `Hierba` y
  `MalezaAlta` usan el mismo valor. El radio efectivo es 1,0 m para que la pasada
  alcance suficientes hojas y deje un rastro visible; no es la medida literal de
  la cuchilla.
- Se corta con el acelerador pulsado. Es lo que hace el `"cortando"` de
  `desbrozadora.gd`.

---

## 2. `scripts/jugador.gd` — el jugador

`CharacterBody3D` con movimiento propio: el `move_and_slide()` de Godot se llama
igual, pero **la velocidad se integra a mano** (`eje.move_toward(...)`) para poder
añadir la inercia y el giro. Ver `scripts/jugador.gd:106`.

| Export | Valor | Que hace |
| --- | --- | --- |
| `velocidad_andar` | 3.0 | m/s andando |
| `velocidad_correr` | 5.8 | m/s corriendo |
| `aceleracion` | 14.0 | cuanto se tarda en tomar velocidad |
| `control_aire` | 2.5 | control en el aire, respecto al suelo |
| `fuerza_salto` | 5.2 | salto |
| `gravedad` | 18.0 | mas fuerte que la real, se siente mas seco |
| `sensibilidad` | 0.16 | sensibilidad del raton |
| `limite_pitch` | 85 | grados de tope **hacia abajo** |
| `limite_pitch_arriba` | 55 | grados de tope hacia arriba. No es 85 porque arriba hay que dejarle sitio a la camara para que el cabezal quepa |
| `pitch_inicial` | -40 | inclinación inicial hacia la zona de trabajo |
| `altura_agachado` | -0.55 | cuanto baja la camara |
| `rapidez_agachado` | 9.0 | rapidez con la que se agacha |
| `rapidez_cuerpo` | 4.0 | rapidez a la que el cuerpo se vuelve hacia donde caminas |
| `cabeza` | — | el nodo que gira |
| `agachado_extra` | 0.0 | lo baja la desbrozadora al trabajar, no el jugador |

**Los topes de inclinacion son asimetricos a proposito** (`_limitar_pitch()`):
hacia abajo llegan a 85 grados, pero hacia arriba solo a 55. Con un tope
simetrico, mirar arriba empujaria el cabezal fuera del encuadre y habria que
apretar el raton hacia abajo para no perderlo de vista. Con el tope asimetrico la
camara se encarga sola.

Ojo con el signo: el pitch es **negativo mirando hacia abajo**. `_limitar_pitch()`
calcula `hacia_abajo = -deg_to_rad(limite_pitch)` y `hacia_arriba =
deg_to_rad(limite_pitch_arriba)`, y acota entre los dos. Una version anterior
restaba los dos topes a un solo lado y el clamp salia al reves; la suite lo
comprueba.

Metodos que usan las pruebas: `mirar_a(yaw, pitch)`, `get_yaw()`, `get_pitch()`,
`get_velocidad_plano()`, `get_andando()` y `get_correr()`. (No hay ningun
`get_giro_total()`: el giro total del jugador se compone dentro de `jugador.gd`, sin
exponerlo.)

---

## 3. `scripts/camara_gopro.gd` — la camara

Camara en primera persona con el balanceo de una GoPro: se queda "colgada" al
girar y se suelta despues, y el paso te bota un poco.

### El encuadre automatico del cabezal

Es lo mas importante de este archivo, y lo que se cambio para poder cortar zarza
alta. La camara calcula el encuadre desde la posicion actual del punto de corte,
que cambia con el nuevo alcance y con la inclinacion de la maquina. Mirando recto
o hacia arriba, la herramienta debe permanecer en la foto.

`_pitch_limitado()` recorta la inclinacion por arriba para que el cabezal siga
dentro: mide el angulo real que baja desde **la posicion actual de la camara**
hasta `herramienta.punto_de_corte()`, le resta el margen que queda
(`margen_cabezal`, 8 grados) y acota el pitch a ese techo. El jugador puede
mirar lo que quiera; la vista se inclina sola, la herramienta no se mueve. Este
encuadre automatico actua mientras la desbrozadora esta en la escena y bajo el
arnés del jugador.

El margen de 8 grados no es decorativo: sin el, la herramienta entra y sale del
borde segun el bamboleo del paso, que mueve la camara 4,5 cm arriba y abajo.

Dos detalles que hay que respetar si se toca esto:

- **El recorte se aplica al pitch suavizado, no al del jugador.** Si se recorta el
  del jugador, la camara va con retardo y llega tarde.
- **El angulo se mide desde donde esta la camara, no desde la cabeza.** Con el
  bamboleo puesto cambia hasta un par de grados, y justo al borde es lo que
  hace que la herramienta parpadee.

`herramienta` se busca con `_buscar_herramienta()` y se reintenta en `_process`,
porque la camara entra en escena **antes** que la desbrozadora y al primer
fotograma no hay nada que encuadrar.

### El giro se mide en el mundo, no en local

La camara cuelga del **cuerpo**, y el cuerpo se vuelve hacia donde camina. Antes
la camara tomaba como su rotacion local el retardo de la mirada, asi que el giro
del cuerpo se le sumaba entero: con `S` el cuerpo se daba media vuelta y el mundo
daba un tiron de 180 grados. Ahora `_colocar()` resta el giro del cuerpo, de modo
que la guiñada de la camara en el mundo es siempre `_yaw_suave` y da igual hacia
donde se ande.

Por eso la prueba del retardo mide el **guiñada en el mundo**
(`_error_de_camara()`) y no `camara.rotation.y`: la rotacion local ya no es la
correccion, es la diferencia con el cuerpo.

### El bamboleo

El peso del paso entra rapido y se calma despues: `move_toward` con ritmo **6**
subiendo y **2.2** bajando. Con una sola tasa el bamboleo se colgaba y hacia
fallar la prueba del ladeo. La fase corre libre con `wrapf`; antes solo
alternaba entre 0 y `PI`, y como `sin(0)` y `sin(PI)` son los dos cero, el
bamboleo vertical salia siempre a cero y solo se notaba el balanceo lateral.

El ladeo de mira se suaviza aparte, con `exp`. La prueba del ladeo usa
`ladeo_de_mirada()`, que devuelve **solo** el ladeo, sin el bamboleo. Antes de
que existiera, la prueba fallaba porque el bamboleo contaminaba la medida.

| Export | Valor | Que hace |
| --- | --- | --- |
| `bamboleo_vertical` | 0.045 m | salto vertical del paso |
| `bamboleo_lateral` | 0.030 m | balanceo de lado |
| `bamboleo_rodada` | 1.7° | balanceo en diagonal |
| `ladeo_giro` | 2.4° | cuanta la camara se queda colgando al girar |
| `retardo_mirada` | 0.12 | suavizado del retardo de la mirada |
| `retardo_ladeo` | 0.30 | suavizado del ladeo |
| `angular` | 100° | FOV horizontal base |
| `angular_correr` | 12° | cuanto se abre al correr |
| `ajuste_fov` | script: 0°; `main.tscn`: +20° (rango ±20°) | ajuste adicional del FOV horizontal |
| `margen_cabezal` | 8° | margen que se deja al cabezal en el encuadre |
| `tope_ladeo_herramienta` | 8° | tope del ladeo que le pone la maquina |

El agachado lo aplica una sola vez `Jugador._agacharse()` moviendo `Cabeza`;
`CamaraGopro` solo suma el bamboleo. Así, correr agachado no acumula dos bajadas
de cámara.

El ladeo de la herramienta lo pone la maquina cada fotograma, y **antes era un
`@export` de la camara**. Eso hacia que en el Inspector apareciera como algo que
se puede tocar a mano, cuando no: lo que hay que tener a mano es
`tope_ladeo_herramienta`, que si es del jugador. Ahora `ladeo_herramienta` es
una variable normal.

La ganancia tambien estaba mal: el codigo multiplicaba por 6
(`rad_to_deg(_barrido * 6.0)`), y con el barrido completo de 96 grados eso son
576 grados de ladeo, que no son un ladeo sino un giro. Con la ganancia de 0,07
el tope sale justo: 96 grados de barrido dan 6,7 grados de ladeo, y de ahi el
tope de 8 grados. El tope hace falta ademas porque el barrido tiene mas recorrido
a la izquierda (96 grados) que a la derecha (38) y, sin tope, el lado izquierdo
se llevaria bastante mas.

---

## 4. `scripts/desbrozadora.gd` — la herramienta

`class_name Desbrozadora` sobre `Node3D`. Permanece anclada al pivote de las
caderas; se apunta sola al grupo `"herramienta"` en `_ready()` y busca dentro del
modelo los nodos `Giro` y `Corte` por nombre, asi que moverlo de sitio en la
escena no rompe nada.

**El nuevo `models/desbrozadora.glb` gira sobre Y.** Este asset tiene una
orientacion distinta del modelo anterior: la logica escribe `Giro.rotation.y`.
El nodo `Giro` va sin inclinacion inicial para que la cuchilla se mantenga plana.
La prueba mecanica mira los tres ejes, porque si se cambia el eje la comprobacion
del giro podria quedarse leyendo un valor fijo y pasar por accidente.

### Los ficheros del modelo y el cambio de cabezal

El modelo se reparte en **un `.glb` por cabeza**, y esto es lo que hace posible
cambiarla y ponerla en otra desbrozadora:

| Fichero | Contenido |
| --- | --- |
| `models/desbrozadora.glb` | la maquina con su cuchilla de serie: `Motor`, `Barra`, `Manillar` y `Cabezal_Corta` |
| `models/cabezal_hilo.glb` | carrete de hilo |
| `models/cabezal_disco_2p.glb` | cuchilla de dos puntas |
| `models/cabezal_disco_3p.glb` | cuchilla de tres puntas |

Los cuatro se generan con `tools/crear_desbrozadora_mesh.py`.

La escena activa `models/desbrozadora.glb`, no `desbrozadora_pro.glb`. El modelo
conserva la jerarquia `Desbrozadora/Giro/Corte`, mide aproximadamente **2,46 m
de largo por 0,48 m de ancho** y su punto `Corte` queda a `y = -1,56 m` en el
espacio del `.glb`. La prueba de Blender y la suite de Godot validan ese
contrato.

### Primera iteracion: cuerpo y anclaje

`models/personaje_trabajo.glb` es el primer operario completo, generado por
`tools/crear_personaje_mesh.py`: low-poly, 1,98 m de alto, 796 triangulos,
origen en el suelo y escala en metros. Incluye chaqueta de alta visibilidad,
pantalon, botas, casco y cara; el modelo completo se puede revisar en Blender.

En primera persona se ocultan la cabeza y los brazos estáticos. El torso y la
parte inferior son visibles por defecto para una perspectiva GoPro de trabajo.
`scripts/brazos_primera_persona.gd` genera mangas y antebrazos que llegan a los
dos `Marker3D` de agarre de `scenes/desbrozadora.tscn`; siguen los marcadores
durante el barrido y la inclinación. Los conmutadores `mostrar_torso` y
`mostrar_parte_inferior` permiten aislar piezas al revisar el encuadre.

La lente se monta 0,30 m por delante del pivote de cabeza para no quedar dentro
del pecho. La mirada inicial baja 40° hacia la zona de trabajo. **La lectura
visual del torso y las piernas sigue en calibración**: la captura es un punto de
partida para ajustar la pose y el encuadre en el juego.

Esta primera pasada fija escala y agarres, pero deja para la siguiente
iteracion la calibracion ergonomica: punto del arnes en la cadera, altura de
manos, offset lateral y recorrido de los puños al barrer. También falta validar
la silueta corporal en carrera, agachado y salto.

La pose de trabajo inicial usa `alcance = 1,56 m` e
`inclinacion_reposo = -22 grados`: la barra queda extendida, el motor detrás del
operario a la derecha y `Corte` hacia delante y abajo. El modelo transforma su
eje longitudinal a `-Z` mediante el giro interno de 180 grados en Y. **No se
aplica un yaw fijo a `Desbrozadora`**: su `rotation.y` controla el barrido lateral.
Los marcadores y la cadena de brazos se mantienen; la pose se ajusta con el
alcance y la inclinacion de reposo.

El objetivo visual es un estilo low-poly estilizado muy cercano a **How to Fish**:
cuerpos simples y alargados, cabezas/cuerpos facetados, extremidades cilindricas
o prismatica, paleta limpia, silueta exagerada y expresiva. Los personajes del
proyecto deben parecer de la misma familia visual, no un cuerpo realista junto a
una herramienta realista.

El contrato, que es lo que hay que respetar al cambiar un cabezal:

- Todos tienen el **origen en el centro de giro**, que es `(0, 0, 0)` en el
  `.glb` del cabezal. Por eso da igual en que maquina se monte: se cuelga del
  nodo `Giro` con `add_child()` y cae justo en el pivote, sin moverlo a mano.
- Los tres de repuesto vienen **sin gearbox y sin protector**: el protector es
  parte de la maquina y se queda puesto con cualquier cabezal.
- El plano de corte esta a `z = -0,222` en los cuatro, asi que un cabezal
  cambiado corta a la misma altura que la cuchilla de serie.
- La geometria es **tumbada** (plana en Z) y el nodo `Giro` va **sin rotacion**.

Cambiar de cabezal en el juego es entonces:

```gdscript
var nuevo := CABEZALES[cabezal_elegido].instantiate()
giro.add_child(nuevo)          # cae en el pivote solo
anterior.queue_free()          # y se esconde el que estaba
```

### La forma de la maquina

El manillar es un **tubo unico curvo**, no una barra recta con dos palos clavados
en los extremos. Sale de la abrazadera (que esta en el origen, donde el juego
cuelga las manos), se abre en U y sube por los dos lados hasta los punos, que
quedan arriba y atras. El camino se recorre con `tubo_trayecto()`, que coloca un
anillo perpendicular a la tangente en cada punto y los empolva, para que la curva
sea continua. Los dos punos van con goma mate mas oscura que la barra, y solo en
el derecho se montan el gatillo del acelerador (naranja) y el paro (rojo).

Delante del manillar, en la barra, hay una **anilla del arnes**: un collar con
una argolla colgando por debajo, que es por donde se sujeta el operario. Hay
ademas una **abrazadera** corta que une el manillar con la barra, y la **barra**
que baja de ella.

El **cable del acelerador** sale de debajo del gatillo y va **pegado** a los
tubos, no suelto por el aire: primero sigue la curva del manillar por fuera,
gira en la esquina de la abrazadera y luego baja por delante de la barra hasta
la caja de engranajes. Cada punto del camino esta a `radio del tubo + radio del
cable` del eje, ni más ni menos, y el generador lo comprueba: mide la **holura**
(distancia al eje menos el radio del tubo) de cada tramo y avisa si supera los
5 mm. La esquina entre manillar y barra se salta, porque ahí el cable no puede
estar pegado a los dos tubos a la vez.

El punto de arranque del cable no está escrito a mano: se calcula a partir de la
posición del gatillo, así que si el mando se mueve, el cable le sigue.

Medidas del rediseño actual, con `Y_CABEZA` a `-1,56 m`:

| Pieza | Valor | Por que |
| --- | --- | --- |
| radio de la barra | 0.025 m (50 mm) | antes 44 mm: parecia un alambre junto al motor |
| largo de la barra | 2.06 m | aproximadamente el doble que la versión anterior |
| corte (`Corte`) | `y = -1.56`, `z = -0.222` | bajo la cabeza y al final de la barra |

La máquina completa mide **2,46 m de largo por 0,48 m de ancho**, con 776
triángulos. La regla 4 del generador comprueba que la altura media del manillar
**sube** al alejarse del centro; dos palos rectos clavados en una barra no la
suben y el generador avisa.

Para medir bien hay dos helpers que conviene conocer, porque las dos medidas
salen mal si se hacen a ojo:

- `_distancia_camino()` mide contra la **polilínea**, no contra los puntos sueltos.
  El tubo se crea entre punto y punto, y sus vértices caen en medio, lejos de
  cualquiera de los dos: midiendo solo los puntos, la holura sale el doble.
- `_muestra_camino()` mete puntos intermedios en el camino, para poder medir por
  franjas. Los tramos largos no tienen puntos en la banda que se mira, y la
  media sale 0 sin querer.

**Con el activo `models/desbrozadora.glb`, el disco gira sobre `rotation.y`.**
Eso es lo que escribe `scripts/desbrozadora.gd`; en este modelo el eje Y sigue
siendo vertical aunque `Modelo` lleve el giro de 180 grados en Y. El nodo
`Giro` no lleva inclinacion inicial: el pitch y el barrido horizontal pertenecen
al nodo de herramienta y se actualizan por separado.

| Export | Valor | Que hace |
| --- | --- | --- |
| `modelo`, `giro`, `corte`, `motor_sonido` | — | nodos que se buscan por nombre, se pueden mover de sitio |
| `radio_corte` | 1.0 m | radio efectivo del cabezal; común a todos los campos de hierba |
| `rpm_maximas` | 9000 | tope del motor |
| `subida_rpm` | 0.85 s | de parado a tope |
| `bajada_rpm` | 0.6 s | de tope a parado |
| `vueltas_maximas` | 130 | vueltas/s del carrete |
| `altura_cadera` | 0.88 m | altura del arnes |
| `lateral_cadera` | 0.26 m | el arnes va a la **derecha**, y de ahi sale la asimetria |
| `rapidez_caderas` | 2.6 | las caderas van detras de la maquina |
| `alcance` | 1.56 m | barra extendida; motor detrás del operario, junto a la cadera derecha |

El arnes y el barrido:

| Export | Valor | Que hace |
| --- | --- | --- |
| `max_left_angle` | 96° | barrido a la izquierda, el arco largo |
| `max_right_angle` | 38° | barrido a la derecha, donde topa el hombro |
| `sweep_speed` | 2.4 rad/s | rapidez maxima del barrido |
| `inertia_smoothness` | 0.24 s | el **peso**:cuanto tarda en llegar y en parar |
| `barrido_teclado` | 26° | barrido a proposito con A y D |
| `masa_izquierda` | 1.6 | cuanto pesa a la izquierda (multiplica el peso del muelle) |
| `rigidez_derecha` | 2.2 | cuanto se pone rigida al llegar al tope derecho |
| `ladeo` | 3.8° | ladeo fijo de la herramienta |
| `ganancia_ladeo` | 0.07 | cuanto ladeo la camara por cada radian de barrido |

La vertical:

| Export | Valor | Que hace |
| --- | --- | --- |
| `inclinacion_reposo` | -22° | morro abajo en reposo; negativo es hacia abajo |
| `inclinacion_acelerando` | 22° | cuanto baja el morro al acelerar |
| `mirar_suelo` | 44° | pitch al que el cabezal apoya en el suelo y deja de hundirse |
| `mirar_alto` | 45° | pitch al que la maquina llega arriba del todo |
| `inclinacion_alta` | 95° | cuanto sube el morro al mirar arriba |
| `rapidez_inclinacion` | 50°/s | con que rapidez llega a la inclinacion que toca |
| `caida_max` | 0.26 m | cuanto bajan las manos al trabajar |
| `vista_baja` | 0.30 m | cuanto baja la vista al trabajar: los ojos van detras de las manos |

La vertical va en los dos sentidos, y esa era la parte que faltaba. Bajar la
mirada apoya el cabezal en el suelo: se busca el angulo al que queda a la
altura del suelo y el morro no pasa de ahi, que si no la maquina se hunde en
tierra. **Subir la mirada sube el morro**, con el mismo reparto porVision: con
`mirar_alto` se llega a toda la altura con el mismo gesto con el que
`mirar_suelo` se llega al suelo. Sin esta parte el morro se quedaba clavado en
`inclinacion_reposo` para cualquier mirar, y el cabezal no pasaba de 0,35 m: no
habia forma de cortar nada por encima de la rodilla.

La geometria sale medida, no supuesta. Al arrancar, `_medir_maquina()` sube desde
el nodo `Corte` sumando transformaciones y saca dos numeros:

- `_radio` (0,79 m): lo lejos que esta el cabezal de las manos.
- `_angulo_cabeza` (116°): hacia que lado cae el cabezal respecto a la horizontal.

Con eso la altura del cabezal sale en linea, sin ir probando:

```
altura = altura_manos + radio * cos(morro - angulo)
```

Y de ahi salen `altura_del_cabezal()` y `morro_para_altura()`, que son las que
usan las pruebas. `morro_para_altura()` devuelve la solucion de **por delante**
del arco (el signo menos), que es la que usa el juego; la de atras daria un morro
apuntando al suelo y diria que la maleza es inalcanzable.

La resistencia: cuanto mas maleza de pie hay por delante, mas frena la maquina.

| Export | Valor | Que hace |
| --- | --- | --- |
| `densidad_corte` | 75 | hojas por m2 (contando dureza) a las que el frenado es maximo |
| `frenao_motor` | 0.22 | cuanto bajan las rpm en la maleza mas cerrada |
| `frenao_barrido` | 0.30 | cuanto frena el barrido, que es lo que mas se nota |
| `intervalo_resistencia` | 0.15 s | cada cuanto se pregunta cuanta maleza hay |
| `anticipacion_resistencia` | 0.40 m | a que distancia por delante se mira |
| `constante_resistencia` | 0.45 s | cuanto tarda el motor en entrar y salir del frenao |

`rpm` representa las revoluciones sin carga y `rpm_efectiva()` calcula las
revoluciones estimadas al aplicar la resistencia. **Esa RPM efectiva gobierna las
dos cosas**: el tono y el volumen del motor (`_sonido()`, `pitch_scale` y
`volume_db`) y la velocidad de giro del cabezal (`Giro`, con
`_motor.rpm_efectivas / rpm_maximas` sobre las vueltas maximas). Ver
`scripts/desbrozadora.gd:484` y `:969`.

Lo que **no** es cierto es que la subida de rpm tenga curva. Es lineal:
`rpm_sin_carga = move_toward(rpm_sin_carga, objetivo, paso * delta)`, con el paso
calculado como `rpm_maximas / duracion` en `scripts/motor_desbrozadora.gd:38`.

Tres detalles que aqui importan de verdad:

- Se mira **por delante**, no debajo. La hierba de justo debajo la acaba de
  cortar la propia maquina en ese mismo fotograma, asi que medir ahi daria cero
  siempre.
- La distancia de mira no es un numero fijo: tiene que pasar del ancho del
  cabezal (`max(anticipacion, Desbrozadora.radio_corte + 0.20)`), o el punto cae
  dentro de lo recién cortado.
- **El suavizado va aparte de la medida.** Preguntar cada 0,15 s esta bien, pero
  si el filtro se aplicase solo en esos fotogramas, el motor tardaria varios
  segundos en llegar al frenao y en un cesped normal se quedaria a media carga
  sin que se notara. La medida se queda quieta entre preguntas y el filtro va
  cada fotograma.

`densidad_corte` va **por encima** de la densidad con la que se siembra, a
proposito. Si se pusiera al nivel del cesped, el tope se alcanzaria en cualquier
sitio y el frenao no diria nada: lo que se busca es recorrido entre un claro
(≈ 0) y un zarzal (≈ 1).

> El angulo de barrido lleva el signo de Godot: **positivo es hacia la
> izquierda** del operario y negativo hacia la derecha. Por eso los topes se
> llaman `max_left_angle` y `max_right_angle` pero los dos son positivos, y el
> codigo los aplica con su signo.

Las rpm no suben en linea recta: la subida se hace mas rapida al principio y se
frena cerca del tope, con `rpm_maximas * (0.45 + 0.55*t) * delta / ritmo`.

El sonido (`audio/motor.wav`) sube de tono con las revoluciones y de volumen
con las rpm, que es lo que se oye de verdad cuando acelera.

> El pitido tiene que ir **en bucle**. El WAV dura 2,0 s y si no se repite se
> calla a los 2 segundos. El import va con `loop_mode=2`, y `_asegurar_bucle()`
> lo deja puesto en memoria aunque alguien reimporte el WAV sin bucle. Para saber
> si esta sonando se pregunta a `motor_sonido.playing`, y no con una bandera
> propia: asi, si se para por lo que sea, se rearranca solo.

**Lo que el sistema de corte necesita de aqui:**

- `punto_de_corte()` — el punto del cabezal, en mundo.
- `rpm` / `cortando` — propiedades de lectura; el estado de corte se deriva del umbral de RPM.
- `rpm_efectiva()` — RPM estimada bajo carga de maleza.
- `telemetria_actualizada(rpm_sin_carga, rpm_bajo_carga, rpm_maximas, resistencia,
  combustible_litros, combustible_maximo_litros, nombre_cabezal, desgaste_cabezal)`
  — ocho parametros, y no tres: el combustible y el cabezal viajan en la misma
  señal que las revoluciones. Es lo que conecta `scripts/interfaz_herramienta.gd` sin
  que la interfaz dependa de nodos internos. La declara y la emite
  `desbrozadora.gd`; la interfaz se **conecta**, no emite.
- `velocidad_corte()` — velocidad del hilo. **Pendiente:** ahora solo es la
  velocidad de giro; cuando haya que modelar el arrastre habra que sumarle la
  velocidad del jugador.

---

## 5. `scripts/hierba.gd` — la hierba (lo importante)

`class_name Hierba`, que **extiende `Vegetacion`**, que a su vez extiende `Node3D`.
No sobre un `MultiMeshInstance3D`: el nodo crea y guarda sus propios hijos, uno por
cuadrante.

### Por que cuadrantes

Con un unico MultiMesh que cubriera el campo entero, su caja envolvente seria tan
grande que siempre se solaparia con la pantalla. El motor no podria descartar
nada aunque solo se viera un trozo de cesped. Con cuadrantes, cada uno lleva su caja
ajustada a las hojas que tiene dentro, el motor descarta solo los que quedan
fuera de la vista, y el dibujo se reduce a lo que se ve de verdad.

Por encima del culling de la vista hay un **recorte por distancia**
(`distancia_maxima`) en `_recortar()`. En la configuración actual es 80 m para
`Cesped`, 16 m para `MalezaAlta` y 20 m para la zarza; los dos campos grandes
tienen `radio = 90 m` y la zarza 9. Ojo con la relacion: el recorte es mas
corto que el radio a proposito, y por eso el cesped se ve aclararse antes de
llegar al borde de su campo. El filtro se aplica a los centros de los
cuadrantes.

El estado de cada hoja (donde esta y cuanto le queda de altura) vive en arrays
de GDScript, **NO** en el MultiMesh:

- El MultiMesh solo existe en el servidor de graficos. En headless no guarda
  nada, asi que una prueba en linea de comandos no veria ni una hoja y el
  sistema de corte no se podria comprobar.
- Leer todas las transformaciones del motor en cada fotograma seria una chapuza.
  Con los arrays se va directo.

El MultiMesh solo recibe la transformacion y el color. El shader lee
`INSTANCE_CUSTOM`, y de ahi sale cuanto se dobla con el viento y cuanto le queda
de altura despues del corte. Asi cortar es escribir un numero: no se toca ninguna
geometria, y se puede ir cortando en plan largo sin que baje el ritmo.

Para el corte hay ademas una rejilla: un diccionario con celdas de 2 m y la
lista de indices de cada una, para no revisar el campo entero por fotograma.
**Esa rejilla no tiene nada que ver con los cuadrantes**: es para el corte, y los
cuadrantes son solo para el dibujo.

### Los 4 canales de `INSTANCE_CUSTOM`

Esto es lo que hay que tener mas claro del proyecto, porque es donde estuvo el
bug de que no se veia nada. El vertex shader de un MultiMesh **no ve la matriz
de cada instancia** (solo la del nodo, que ahora es la de un cuadrante entero),
asi que todo lo que el shader necesita viaja en estos 4 canales:

| Canal | Que lleva | Rango |
| --- | --- | --- |
| `x` | **cuanto le queda de altura** | 1 = de pie, 0 = cortada |
| `y` | donde cae la hoja en el mapa del viento, en X | 0..1 |
| `z` | lo mismo en Z | 0..1 |
| `w` | el tono de la hoja | 0..1 |

> **El canal `x` es lo que QUEDA, no lo que se ha cortado.** Leerlo al reves
> hacia que la hierba de pie salia tumbada y la cortada salia de pie. Ocurrio, y
> por eso la hierba solo se veia donde habias pasado la maquina.

La fase del aleteo y la rigidez **no** viajan: salen del tono con
`fract(tono * 7.31)` y `0.75 + 0.5 * tono`. Asi no hacen falta dos canales mas.

### Siembra

`_sembrar()` rellena **todos** los arrays, despues asigna `instance_count` **una
sola vez** por cuadrante y escribe transforms y datos. La version anterior
asignaba `instance_count` dos veces (una al principio, otra al final) y la
segunda asignacion **borraba el buffer entero**: `get_instance_count()` decia
43.592 y no habia ni una hoja en la GPU.

Luego `_repartir_en_cuadrantes()` decide a que cuadrante va cada hoja
(`_casilla_de()`) y `_montar_cuadrante()` crea un `MultiMeshInstance3D` por
cuadrante con su `custom_aabb` ajustada. El número de hojas y de cuadrantes no
es una constante: depende de los parámetros y la semilla. La configuración
efectiva está en `scenes/main.tscn` y se resume en la tabla siguiente.

La siembra es sobre una rejilla con jitter, y el borde se va aclarando con
`borde` para que el campo no tenga un corte recto. Con `formacion` por encima de
cero la siembra se hace en **matas** en vez de repartir por igual: se tira el
suelo, se sortea el ruido y, si sale por encima del umbral, se siembra ahi; si no,
se deja claro. Un claro no es un sitio con menos hojas, es un sitio **sin
hojas**, y por eso se puede pasar andando sin oir el motor.

Los tres presets son el **mismo** script (`scripts/hierba.gd`, sobre el contrato de
`scripts/vegetacion.gd`) con otros numeros. Y los numeros **no viven en
`main.tscn`**: viven en `scenes/vegetacion/cesped.tscn`, `maleza_alta.tscn` y
`zarza.tscn`, que son las escenas que `main.tscn` instancia. Lo unico que
`main.tscn` toca de ellas es una sola cosa: el `position` de la zarza, que es
el unico dato de **donde** esta cada planta y no tiene preset que lo diga.

| Export | Por defecto del script | **`cesped.tscn`** | **`maleza_alta.tscn`** | **`zarza.tscn`** | Que hace |
| --- | --- | --- | --- | --- | --- |
| `tipo` | 1 | 1 | **2** | **3** | 1 cesped, 2 maleza, 3 zarza |
| `altura` | 0.38 m | **0.49 m** | **0.76 m** | **1.50 m** | altura de referencia antes del borde |
| `variacion_altura` | 0.45 | **1.0** | **0.09** | **0.22** | variación aleatoria de altura |
| `grosor` | 0.045 m | **0.10 m** | **0.26 m** | **0.40 m** | ancho de la hoja |
| `variacion_grosor` | 0.35 | **1.0** | **0.38** | **0.30** | variación aleatoria del grosor |
| `radio` | 34 m | **90 m** | **90 m** | **9 m** | radio del campo sembrado |
| `densidad` | 30 | **60** | **60** | **60** | hojas por m2 sembradas |
| `borde` | 0.72 | **0.85** | **0.85** | **0.85** | fracción del radio donde se aclara el borde |
| `formacion` | 0 | **0.70** | **0.70** | **0.70** | agrupación en matas; 0 = uniforme |
| `dureza` | 1.0 | 1.0 | **3.3** | **3.6** | cuanto cuesta cortarla |
| `tono_pie` | verde | verde (heredado) | **(0.204, 0.157, 0.078)** | **(0.086, 0.118, 0.063)** | color de la base |
| `tono_punta` | verde claro | verde (heredado) | **(0.478, 0.396, 0.188)** | **(0.157, 0.235, 0.106)** | color de la punta |
| `semilla` | 90210 | 90210 | **24601** | **33031** | con la misma sale siempre igual |
| `lado_cuadrante` | 8 m | **24 m** | 12 m | 12 m | lado de cada trozo de campo |
| `distancia_maxima` | 42 m | **80 m** | 16 m | 20 m | distancia máxima al centro del cuadrante |
| `dejar_tocon` | true | true | true | true | cortar deja tocón |
| `altura_tocon` | 0.08 m | **0.15 m** | **0.06 m** | **0.12 m** | altura del tocón |
| `hoja_estrecha` | 0.88 | **0.88** | **0.60** | **0.30** | cuanto se estrecha la hoja hacia arriba |
| `hoja_curva` | 0.09 | **0.09** | **0.06** | **0.02** | curvatura: 0 tiesa, 0,09 casi recta |
| `hoja_tuerce` | 12 | **12** | **9** | **4** | grados de giro a lo largo de la hoja |

Ojo con `formacion`, que va **al reves** de lo que parece: es la parte de
terreno que se deja **bare**, no la que se planta. Con 0 se siembra todo y con
1 solo donde la mancha pasa del umbral de `borde`. Los tres presets van en 0,70 a
proposito, para que la zarza se vea tan cerrada como la maleza; si se notara mas
claro no se distinguiria de pasar por maleza, y el trabajo no pareceria el mismo.

La zarza es la unica de las tres con `radio` corto (9 m) porque es una mancha
local, no un campo. En la escena hay **una** (`Zarza`, a 7 m por delante del
jugador), con los numeros del preset: 1,5 m de alto y semilla 33031. Antes se
instanciaba cinco veces con alturas y semillas distintas; se redujo a una el
2026-09-30. Repartirla por el mapa sera cosa del valle, no de esta escena.

El mapa de viento compartido toma el radio mayor, 90 m, y cubre 180 m de lado.

**El radio de corte no pertenece a estos campos.** `Desbrozadora.radio_corte`
vale 1,0 m y ambos campos consultan ese mismo radio para cortar y medir la
resistencia. El primer intento de usar el radio geométrico de la cuchilla (0,13 m)
producía una pasada demasiado estrecha para que el corte se viera; por eso este
es el radio efectivo de simulación. Si cambia el cabezal se ajusta una sola
propiedad en la herramienta.

`dureza` va aparte de la densidad a proposito. La densidad es "cuantas hojas hay
debajo"; la dureza es "cuanto cuesta cada una". Con las dos juntas se puede
tener un cesped ralo y barato, o una maleza corta y cara, y el motor nota las
dos cosas. Sumarlas en un solo numero haria que "mas densa" y "mas cara" fueran
lo mismo, y entonces la maleza seria solo una alfombra mas alta.

`dureza` **no va al shader**: el shader no sabe quanto cuesta nada, solo dibuja.
Quien la usa es `desbrozadora.gd`, que al medir la resistencia multiplica las
hojas de pie que hay por delante por `coste_maleza()` de cada campo. Por eso
`Hierba` expone `coste_maleza()`: el motor pregunta a cada campo cuanto cuesta
lo que tiene debajo.

> **Ojo con estas columnas: son valores distintos y estan en sitios distintos.**
> La primera columna es el `@export` de `scripts/hierba.gd`; las otras dos son
> los valores efectivos de `scenes/main.tscn`. En la última carga headless del
> plano se sembraron 268.115 hojas de `Hierba` y 31.162 de `MalezaAlta`; el
> recuento cambia al modificar los campos y se consulta con `total()`.
>
> Al cambiar estos numeros, dos cosas se quedan viejas solas: los comentarios que
> dan recuento de hojas, y las pruebas que comparen con un literal. Por eso la
> prueba del ancho de corte lee `Desbrozadora.radio_corte` en vez de duplicar el
> valor, y `medir_densidad.gd` lee la densidad de la escena al
> arrancar en vez de tenerla en su lista. Esta tabla refleja los exports de la
> escena actual, no una medición de hojas ni de rendimiento.


`dejar_tocon` esta en `true` a proposito: con `false` la hierba cortada queda a
0 cm, tumbada en el suelo, y **no se ve nada desde la camara**, asi que no hay
ni rastro de por donde has pasado. Con tocón el corte se ve como una mancha más
corta y clara. La configuración actual deja 15 cm en el césped, 6 en la maleza
y 12 en la zarza, y el de la
maleza.

### API para el corte y las pruebas

```gdscript
# --- el corte ---
cortar(centro_mundo, r, presupuesto := -1.0) -> int   # devuelve cuantas quita
cortar_por_banda(centro, radio, presupuesto := -1.0) -> int
cortar_y_soltar(centro, radio, presupuesto := -1.0) -> int
#   Los tres reciben el CENTRO EN MUNDO y lo convierten a local. `posicion_hoja()`
#   sigue devolviendo local, y quien la llame convierte con `to_global()`.
#   Mezclar los dos sistemas lo hacia fallar en silencio: las zarzas estan fuera
#   del origen del mundo, y el corte se les iba 7 metros.
#   `presupuesto` a -1 significa "quitate la banda entera" (lo que hacen la hoz y
#   las pruebas). Con presupuesto salen las hojas que caben en el tiempo pasado.

# --- las preguntas que hacen las pruebas ---
hojas_en_pie() -> int                      # cuantas quedan de pie
total_de_pie() -> int                      # alias, se conserva
de_pie(centro_mundo, r) -> int             # cuantas hay de pie en un circulo
densidad_bajo(centro_mundo, r) -> float    # hojas DE PIE por m2 alrededor
hoja_en_pie_mas_alta() -> float            # la mas alta que queda
total() -> int                             # hojas sembradas
altura_hoja(i) -> float                    # altura visual actual
altura_visual() -> float                   # altura de una hoja cortada
posicion_hoja(i) -> Vector3                # en LOCAL
uv_de_hoja(i) -> Vector2                   # su sitio en el mapa del viento
alto_de(i) / gordo_de(i) -> float
datos_de_hoja(i) -> Color                  # los 4 canales tal cual van a la GPU
tono_de(i) -> float                        # el tono, que nunca cambia
coste_maleza() -> float                    # dureza
tipo_vegetacion() -> int                   # 1 cesped, 2 maleza, 3 zarza
regenerar() -> void                        # resiembra y reconstruye la rejilla
refresca_uv_de_viento() -> void            # rehace las uv si cambio el radio
uv_rehechas() -> int                       # cuantas hojas rehizo el ultimo refresco
forzar_recorte(desde: Vector3)             # el recorte, pero a mano

# --- los cuadrantes ---
num_cuadrantes() -> int                    # depende de radio, tamaño y siembra
casillas_totales() -> int
lado_de_casillas() -> int
hojas_de_cuadrante(n) -> int               # hojas de ese cuadrante
caja_de_cuadrante(n) -> AABB               # su caja ajustada
cuadrantes_visibles() -> int               # cuantos quedan tras el recorte
caja_del_campo() -> AABB                   # union de todas las cajas
material_compartido() -> ShaderMaterial    # el material, para compartirlo
material_cortado() -> float
malla() -> ArrayMesh                       # la malla de una hoja
```

> `cuadrantes_visibles()` y `hojas_de_cuadrante()` devuelven lo que hay **despues**
> del recorte por distancia, no el total: por eso las pruebas las comparan antes
> y despues de `forzar_recorte()`. Para el total esta `num_cuadrantes()`.
>
> `caja_del_campo()` hay que volver a pedirla si el campo cambia, y devuelve la
> union de las cajas de todos los cuadrantes. `mirar_hierba.gd` y `foto.gd` la
> usan en vez de calcular el AABB a mano, que es lo que se hacia antes.
>
> `total_de_pie()` y `hojas_en_pie()` devuelven lo mismo. Se dejo el nombre viejo
> porque estaba en las pruebas de antes y cambiarlo no hacia falta.

---

## 5 bis. Los tres ficheros de la desbrozadora que no son la desbrozadora

`scripts/desbrozadora.gd` tiene 1.166 lineas y se ocupa de casi todo. Estos tres
estan dentro de su responsibility y estan separados, y conviene saber por que.

### `scripts/motor_desbrozadora.gd` — el motor

Un `RefCounted` sin nodo, que mantiene **dos** juegos de revoluciones:

- `rpm_sin_carga`: las que pide el acelerador.
- `rpm_efectivas`: las que quedan bajo carga. Bajan, y esa caida es lo que hace
  que la maquina "suene" cargada.

El combustible se consume segun la demanda y sube con la carga. Esta separado
porque **no es un motor de verdad**: es una curva, y su unico consumidor es la
telemetria de la interfaz y el sonido. Si algum dia se quiere un motor con
embrague, este es el sitio, y no hay que tocar `_physics_process` de la
desbrozadora.

### `scripts/estacion_cabezal.gd` — que cabezal va y cuanto le queda

Un `RefCounted` que **no toca un solo nodo**: decide que cabezal esta montado,
cuanto filo le queda, y como responde a cada planta. La desbrozadora solo cuelga
el modelo que esta clase elige.

Sale de `desbrozadora.gd`, que tiene 1.166 lineas, con las reglas de
datos mezcladas con el codigo que instancia el `.glb` y lo cuelga de `Giro`. El
mismo patron que `motor_desbrozadora.gd`, que tambien es un `RefCounted` con las
reglas del motor y del que la desbrozadora no tiene ni una linea de simulacion.

El premio es `tools/test_estacion_cabezal.gd`: **las reglas del cabezal se
comprueban sin montar la maquina**. Antes habia que instanciar `main.tscn`, esperar
a que el arbol creciera y tirar el cabezal de verdad.

Ojo con una cosa que se debe: `configurar()` **monta el primero**. Lo hace a
proposito, porque cuando solo guardaba la lista habia que acordarse despues de
llamar a `montar(0)`, y quien se olvidaba se quedaba con una estacion sin cabezal
**y sin ningun error**. La prueba nueva lo cazó en la segunda ejecucion.

### `scripts/cabezal_desbrozadora.gd` — los datos del cabezal

Un `Resource`, uno por cabezal, en `resources/cabezales/*.tres`. Lleva **dos
numeros que van en direcciones opuestas** y que es facil confundir:

- **eficacia** (1 a 5): lo rapido que corta.
- **resistencia** (0 a 5): lo que la vegetacion le hace a el.

Que se separen es deliberado: un cabezal de punta de diamante que corta poco y
dura mucho tiene que ser posible, y si fuera un solo numero seria imposible.

El desgaste **activo no esta aqui**, esta en la desbrozadora, para que dos
herramientas puedan compartir la misma definicion sin compartir su estado.

### `scripts/interfaz_herramienta.gd` — el panel

El `CanvasLayer` con las revoluciones, la carga, la gasolina y el filo. Emite
`telemetria_actualizada` y **no toca la desbrozadora**: es de solo lectura, y por
eso la logica de simulacion puede ir en un `RefCounted` sin la UI enterada.

### `scripts/version_pantalla.gd` — el cartel de arranque

Otro `CanvasLayer`, en la capa 100 para ir por encima del panel. Enseña el
nombre y la version los primeros 2,5 segundos y se quita.

Va **suelto del panel de la herramienta** a proposito. Ese cuelga de la
desbrozadora y viaja con ella; la version es del programa, no de la maquina que
llevas en la mano.

Dos cosas que se aprende aqui si se toca:

- **El numero sale de `ProjectSettings`, nunca de una constante.** Si el cartel
  tuviera el numero escrito dentro, subir la version obligaria a tocar dos sitios
  y se olvidaria el segundo. `tools/test_version_pantalla.gd` lo comprueba
  cambiando el ajuste en caliente y viendo que el cartel cambia con el.
- **El reloj es un contador en `_avanzar(delta)`, no un `Tween` ni un
  `await`.** El proyecto ya se comio ese problema: una cosa que espera se
  queda parada en el primer fotograma y en headless no se ve. Separar el reloj
  del `_process` es ademas lo que permite probarlo sin esperar 2,5 segundos.

**`project.godot` lleva la version con `config/version`, bajo `[application]`,**
que en codigo es `application/config/version`. Ojo al escribirlo a mano: los
comentarios de ese fichero son con punto y coma, y con almohadillas el parser
se las come como parte del valor, la version se queda vacia **sin avisar** y el
cartel sale diciendo "(sin version)". Pasa, y por eso esta escrito aqui.

## 6. `shaders/hierba.gdshader` — como se dibuja

`render_mode cull_disabled, diffuse_lambert, specular_disabled,
shadows_disabled`.

**El viento.** La hoja busca su celda en la textura del viento con la UV de su
canal `y`/`z`. El filtro de la textura es lineal, asi que entre celda y celda no
se ven costuras. El empuje va **en proporcion de la altura de la hoja, no en
metros del mundo**:

```glsl
VERTEX.x += dir.x * (empuje + aleteo) * curva;
```

> **Ojo aqui, que ya se rompió una vez.** Se intento antes pasar el viento a
> coordenadas de hoja dividiendo por el eje de la instancia. El problema es que
> el eje de la instancia es el **grosor** de la hoja (0.045), y dividir por eso
> multiplicaba el empuje por 22: las hojas salian despedidas varios metros y no
> se veia ninguna. Las cortadas si se veian, porque al estar tumbadas `curva` es
> cero y no hay empuje. **La proporcion de altura es la forma correcta** y no
> necesita la matriz de la instancia.

El doblez es `curva = alto^2`, o sea que la punta se dobla mucho mas que la
raiz, que es como se dobla una hoja de verdad. El tocón ademas se estrecha
(`VERTEX.x *= mix(0.5, 1.0, enpie)`) porque si no un corte de 15 cm pareceria una
alfombra.

**El corte.** Cortada, todos los vertices caen al suelo y el triangulo se
degenera, asi que la hoja no pinta nada. Sin tocar un solo vertice desde el
juego, por eso cortar medio millon de hojas es barato.

**El color.** Degradado pie→punta, cada hoja con su tono, la punta mas clara
porque la luz la atraviesa, y lo cortado mas seco. Se compone en GDScript al
sembrar y al cortar, y **no** se vuelve a leer del MultiMesh: antes al cortar se
hacia un `get_instance_custom_data` por hoja, que es una lectura de la tarjeta
grafica, y no hacia falta para nada. La normal se mezcla con la de la camara
(`mix(NORMAL, VIEW, 0.55)`) porque con `cull_disabled` la cara de atras recibe la
normal del reves y la hoja se veria negra.

---

## 7. `scripts/viento.gd` — el viento por zonas

`class_name Viento`. **No dibuja nada**: solo mantiene una textura pequena con
la direccion y la fuerza de cada celda, y se la pasa a la hierba. Lo que se
mueve de verdad es cada hoja, en el shader.

El mapa es una imagen `32x32` RGBA8 (4 KB):

| Canal | Que lleva |
| --- | --- |
| R, G | la direccion, de 0 a 1 |
| B | la fuerza, de 0 a 1 |
| A | 255 |

| Export | Valor | Que hace |
| --- | --- | --- |
| `lado_celda` | 2.8 m | **se recalcula** en `_conectar()` |
| `celdas` | 32 | 32x32 = 1024 celdas |
| `fuerza` | 0.25 | fuerza global |
| `pasos_por_segundo` | 10 | cuantas veces se rehace el mapa |
| `giro_lento` | 0.035 | rapidez del giro de la direccion principal |
| `rapidez_ola` | 0.9 | rapidez de la ola que cruza el campo |
| `semilla` | 7381 | |

Encima del balanceo de cada celda hay dos cosas globales, y son las que hacen
que se vea **un campo** y no un ruido:

- La direccion principal gira muy despacio, asi que el campo va cambiando de
  rumbo con el rato.
- Una **ola plana que cruza el campo en linea recta**. Sin ella cada celda va por
  libre y se ve un ruido que hierve.

**El mapa tiene que medir lo mismo que el campo.** Por eso `_conectar()`
recalcula `lado_celda = radio * 2 / celdas` leyendo el `radio` de la hierba: la
hoja calcula su UV suponiendo eso, y si el mapa midiera otra cosa cada hoja
buscaria su celda en el sitio equivocado.

Con varios tipos de hierba se usa el **radio mayor de todos**, que es lo unico
que vale para todos los campos a la vez.

**Un solo nodo de viento para todo el prado.** Vive en `main.tscn`, no dentro de
`hierba.tscn`. Antes era hijo de la hierba, y al partir el campo en varios tipos
cada uno traia el suyo: habia dos mapas peleandose por los mismos materiales y
poniendole cada uno su reloj. El viento es una cosa del mundo, no de un campo.

Se apunta a la hierba por el grupo `"hierba"`. Como ahora es hermano de la
hierba y no hijo, el orden de arranque es el contrario: hay casos en que el
`_ready` del viento corre antes de que los campos esten sembrados, asi que
`_process` reintenta durante los primeros 90 fotogramas y ademas vigila que no
entre ningun campo nuevo despues.

> **La UV se calcula al sembrar, y se rehace si el radio cambia.** La hoja lleva
> su sitio en el mapa metido en `INSTANCE_CUSTOM`. Si se cambia `radio` en
> caliente sin mas, cada hoja sigue buscando su celda con el radio viejo y el
> viento sale descuadrado. `Hierba` lo vigila: guarda aparte `_radio_uv` (el
> radio con el que estan escritas las uv) y en `_process` compara. Si ha
> cambiado, `refresca_uv_de_viento()` reescribe **todas** las hojas.
>
> Al reescribir se tocan **solo los canales `g` y `b`**, que son la uv. El `r`
> (altura que le queda a la hoja) y el `a` (tono) van con la hoja, no con el
> sitio donde se busca su viento, y se recuperan de los arrays para no
> perderlos.

---

## 8. Suelo plano temporal y `shaders/suelo.gdshader`

`main.tscn` contiene un nodo `Suelo` (`StaticBody3D`) con una malla plana de
160 × 160 m y una colisión cilíndrica de radio 80 m. La cara superior del
collider está en `Y = 0`, que es también la altura a la que se siembran hierba y
árboles. El shader solo da aspecto de tierra; ya no genera geometría ni altura.

> Godot 4.7 **no tiene `noise()` ni `hash()`** en el lenguaje de sombreado. Se
> comprobo. El ruido de valor va montado a pelo con `hash21()` y `ruido()`.

El ruido usa la **posicion del mundo**, no la UV, para que las manchas no se
repitan con el borde de la malla y no se vea el empalme al alejarse.

| Export | Valor |
| --- | --- |
| `tierra_seca` | (0.345, 0.259, 0.169) |
| `tierra_humeda` | (0.145, 0.098, 0.062) |
| `verdin` | (0.208, 0.271, 0.129) |
| `cantidad_verdin` | 0.3 |
| `grano` | 0.45 |
| `escala_manchas` | 0.28 |

El plano tiene 160 × 160 m y el borde superior de su collider queda a `Y = 0`.
Esta configuración está en `scenes/main.tscn`; la forma es plana a propósito.

---

## 9. Terreno definitivo y aldea manuales (pendientes)

No hay nodos ni scripts de terreno procedural o de aldea en la escena actual. El
mapa futuro será un valle esculpido desde el editor; el plugin aún está por
elegir. Las casas, muros, carreteras y parcelas se colocarán manualmente desde el
editor en otra fase.

**Hubo un `shaders/piedra.gdshader`** de 117 lineas de granito: el tono de cada
sillar por separado, las juntas mas oscuras y el musgo por abajo, con el patron en
el espacio del mundo y eligiendo el plano con la normal en vez de mezclar los
tres (en un muro la mezcla se ve como una mancha en las esquinas). **Se borro el
2026-09-30.** No lo usaba ninguna escena ni ningun script, y estaba esperando a
una aldea que no existe: un shader sin nada que sombrear no es una anticipacion,
es 117 lineas que nadie va a leer ni a probar. Cuando haya un muro de verdad se
hace otra vez, aplicando el criterio de la seccion 6: que se note y que se pueda
medir. Los dos shaders que quedan son `hierba.gdshader` y `suelo.gdshader`, y los
dos estan en uso.


---

## 10. `scripts/bosque.gd` y las escenas del bosque

Reparte arboles por el campo con semilla fija, sobre una rejilla con jitter para
que no salgan en lineas. Cada arbol es un `StaticBody3D` con tronco y dos copas,
todo con colision solo en el tronco (la copa no, que es mas barato y se nota
igual). Va en la **capa 3**, `bosque`.

| Export | Valor | Que hace |
| --- | --- | --- |
| `arbol` | `arbol.tscn` | la escena que se instancia cada vez |
| `cuantos` | 55 | cuantos arboles sale |
| `radio_min` | 9 m | el mas cercano al centro |
| `radio_max` | 65 m | el mas lejos |
| `separacion` | 4 m | distancia minima entre troncos, sobre rejilla con jitter |
| `semilla` | 20260926 | con la misma sale siempre el mismo bosque |

Son dos ficheros y conviene no confundirlos: `scenes/bosque.tscn` es el **grupo**
que reparte, y `scenes/arbol.tscn` es **un arbol**, que se instancia las veces que
haga falta. `main.tscn` solo cuelga del grupo.

---

### Los grupos, y por que son el contrato

En vez de buscar nodos por nombre, los sistemas se localizan por grupo. Estos son
todos, y son la unica forma que usa el codigo para encontrar algo:

| Grupo | Quien se mete | Quien lo busca |
| --- | --- | --- |
| `hierba` | cada campo de vegetacion, en `_ready()` | los que miden densidad o buscan el punto de corte |
| `vegetacion` | idem, los tres niveles | `brazos_primera_persona.gd:205` |
| `herramienta` | la herramienta equipada | `test_juego.gd:1005` |
| `inventario` | el nodo del inventario | `desbrozadora.gd` |
| `suelto` | cada herramienta en el suelo | la recogida por rayo |
| `restos` | el singleton de restos | el propio `Restos.obtener()` |

### `Restos` no esta en `main.tscn`, y es a proposito

Los restos de planta cortada son un **singleton** que se cuelga de `root` la
primera vez que se corta algo, y se recuperan con `Restos.obtener(arbol)`
(`scripts/restos.gd:196`). No es un nodo de la escena porque no hace falta que
este montado desde el principio: se crea solo, y se queda. Por eso no aparece en
el arbol de la seccion 1, y por eso `recuento()` y `limpiar()` se llaman siempre a
traves de `obtener()` y no de un nodo.

## 11. El inventario, la rueda y la hoz

### `scripts/herramienta.gd` — que es una herramienta

Un `Resource`, no un script del nodo, y a proposito: lo que el inventario necesita
saber de una herramienta (que escena instantiate, como se llama, que caja tiene en
el suelo) se puede mirar **sin crearla**. El mismo recurso describe las dos.

| Campo | Que es |
| --- | --- |
| `id` | la clave con la que la busca el inventario |
| `nombre` | lo que sale escrito en la rueda |
| `escena` | la escena del nodo que va en la mano |
| `caja` | la caja de colision cuando esta en el suelo |
| `tipos_compatibles` | 1 cesped, 2 maleza, 3 zarza |
| `radio_corte` | para la resistencia y para lo que mide la vegetacion |
| `descripcion` | el texto largo que explica la herramienta en la rueda |

Ojo con `tipos_compatibles`: el campo **existe y esta en los dos `.tres`**, pero
`Desbrozadora.cabezal_puede_cortar()` no lo consulta — mira que haya un cabezal
montado y ya (`desbrozadora.gd:670`). Es decir: los limites por tipo de planta
**no se estan aplicando**.

Los dos recursos estan en `resources/herramientas/`, y los cabezales de la
desbrozadora en `resources/cabezales/`. Ojo con esto: **un `.tres` que apunta a
un modelo se trae el modelo aunque la pieza no este en escena**. Con la tecla `Q`
el jugador cambia de cabezal, y los **cuatro** `.tres` se cargan con `preload` en
`desbrozadora.gd:5-10` (`serie`, `hilo`, `disco_2p`, `disco_3p`); si los `.glb` a
los que apuntan estuvieran fuera del repositorio, en un clon nuevo esos `preload`
traerian un `.tres` sin modelo y el juego no arrancaria bien. Ya paso, y por eso
los modelos estan dentro.

### `scripts/inventario.gd` — los nueve huecos

Nueve ids (`StringName`) en un array, un numero de seleccion, y tres metodos que
hacen todo: `equipar`, `soltar_en_mano` y `recoger`. La rueda solo llama a
`mover_seleccion`, que es un `posmod` sobre el numero.

Cuatro decisiones que no son obvias y que costaron un bug cada una:

- **La herramienta guardada no se destruye.** `_instancia()` la crea la primera
  vez y la guarda en `_vivas`; al guardar solo se apaga (`visible = false`,
  `process_mode = DISABLED`) y se cuelga de un nodo `Guardadas`. Con eso conserva
  la gasolina y el desgaste. Si se destruyera, tirar la maquina al suelo seria la
  forma de resetear el deposito.
- **Que hay en la mano se guarda aparte de la seleccion** (`_en_mano`). Si
  `equipar()` mirara "el hueco seleccionado" para guardar lo anterior, dependeria
  de que la seleccion se cambiara *despues*; cambiandola antes se guardaba la
  nueva en vez de la vieja, y las dos quedaban montadas a la vez. Hay prueba de
  esto: `solo hay una herramienta montada, no dos`.
- **El grupo `herramienta` solo lo tiene la equipada.** `Montes` lo buscaba cada
  fotograma con `get_first_node_in_group` y no guardaba
  la referencia: con la referencia guardada seguian cortando con la que ya no
  llevabas.
- **Los `CanvasLayer` hay que apagarlos a mano.** No heredan la visibilidad del
  padre, que es otra capa de dibujo. Sin `_interfaces_de()`, al cambiar a la hoz
  se quedaba el panel de la desbrozadora con las revoluciones congeladas.

Al soltar se crea un `RigidBody3D` en la **capa 8** (`CAPA_SUELTO`), que el
jugador **no** lleva en su mascara: se anda por encima de una herramienta sin que
el suelo se hunda ni se le falsee el apoyo. Se suelta medio palmo hacia un lado,
porque dos herramientas soltadas en el mismo punto aparecen encajadas y la fisica
las manda cada una a un lado. Para recoger hay que **mirar**: un rayo desde la
camara de tres metros, no un area alrededor del cuerpo, porque con un area cogias
lo que tuvieras al lado sin mirar. Lo recogido va al primer hueco libre y se
equipa, y sin hueco no se puede y se dice, que si no el jugador ve el aviso, pulsa
y no pasa nada.

### `scripts/rueda_inventario.gd` — la rueda de la pantalla

Un `CanvasLayer` con un `Control` que se dibuja entero en `_draw`: nueve sectores
de anillo en la esquina de arriba a la derecha, el elegido resaltado y el numero
dentro. Los huecos vacios se dibujan tambien, porque un hueco vacio es un estado
de verdad y si no se dibujara el circulo pareceria roto en vez de vacio.

Abajo van tres lineas de texto **separadas**: el nombre de lo que llevas, el aviso
momentaneo (`suelta: ...`) y el `E recoger`. Compartiendo linea, el aviso tapaba
justo el `E recoger` en el momento en que mas hace falta, que es despues de
soltar algo.

### `scripts/hoz.gd` — la segunda herramienta

Sin motor, sin barrido, sin resistencia, sin combustible. Un palo con un filo.
Corta lo que hay en el arco de la hoja mientras el acelerador este pulsado, y la
hoja baja con la mirada (`-30 grados - 0,7 * pitch`).

**Aqui no corta nada desde la hoja.** Corta cada campo de vegetacion en su propio
`_physics_process`, al estilo de siempre: la hoja solo contesta a las cuatro
preguntas que le hacen (`cortando`, `cabezal_puede_cortar`, `punto_de_corte`,
`radio_corte_actual` y `registrar_corte`). Si la hoz cortara por su cuenta *y* el
campo cortara tambien, cada hoja se contaria dos veces.

La pose esta en coordenadas del pivote, que esta **a los pies** (ver la seccion
1). La mano va a `ALTURA_MANOS = 0,82` m del suelo, a la cintura, y el filo baja
de ahi unos cuarenta centimetros. Con la mano mas arriba se ve mejor, pero el filo
queda por encima de la maleza y no corta nada de lo que esta en pie.

---

## 12. Los tres niveles de vegetacion y los restos

### Ya no hay dos vegetaciones, hay una

Hubo dos modelos y los dos dejaban la mecanica coja: una hoja (`hierba.gd`) y una
maraña (`zarza.gd`, 888 lineas con celdas, coronas, raices, enredo e inundacion).
La maraña era otro juego dentro del juego, y sobre todo era **imposible de
comparar**: no se podia pedirle a un cabezal lo mismo a las dos y ver que
diferencia habia, porque cada una tenia su cuenta atras.

Ahora hay **un solo `hierba.gd`** y la zarza es un preset:
`scenes/vegetacion/zarza.tscn` hereda de `hierba.tscn` y solo cambia numeros y
apariencia. Se borro `scripts/zarza.gd`, tres escenas y siete pruebas.

Los tres presets:

| preset | tipo | altura | densidad | dureza |
|---|---|---:|---:|---:|
| `cesped.tscn` | 1 | 49 cm | 60/m2 | — |
| `maleza_alta.tscn` | 2 | 76 cm | 60/m2 | 3,3 |
| `zarza.tscn` | 3 | 150 cm | 60/m2 | 3,6 |

**La zarza comparte la densidad con la maleza a proposito.** Su dificultad tiene
que venir de la dureza y de la resistencia del cabezal, no de estar mas rala: si
fuese mas rala, el tier mas duro seria el mas rapido de barbechar, que es al
reves de lo que dice la tabla de cabezales.

### El corte se reparte en ocho sectores

Con presupuesto, el cabezal morda una celda al azar. Repartido al azar, un sector
entero se limpiaba mientras el de al lado conservaba todas sus hojas, y el claro
salia hecho de manchurrones. Repartido en **ocho sectores de 45 grados**, cada
uno con la octava parte del presupuesto y su resto decimal propio, y dentro de
cada sector de **dentro hacia fuera**, el frente avanza como un frente.

Medido sobre 60 fotogramas, partiendo de `[26, 24, 26, 21, 23, 25, 25, 23]`, se
pierden `[18, 18, 18, 18, 18, 18, 18, 18]`. El reparto no puede ser de hojas por
sector, porque las plantas no estan plantadas en circulos perfectos: es de hojas
**perdidas** por sector, que es lo que se ve. Lo tunea `Hierba.SECTORES`.

Hay **dos** acumuladores de resto decimal y no es una duplicacion:
`_presupuesto_fraccion` es el freno grueso (con el nylon contra la zarza el
presupuesto es de 0,08 hojas por fotograma, menos de una, y sin el pasarian doce
fotogramas sin cortar nada), y `_sector_por_cortar` es el reparto fino.

El borde del disco tampoco es un circulo: cada hoja tiene su umbral de distancia
propio, fijo, que sale de **donde esta** y no del azar. Que sea fijo es lo
importante; con azar, una hoja entraba y salia y el claro parpadeaba.

### `scripts/restos.gd` — la rafaga que no deja nada

**Particulas (`CPUParticles3D`), sin fisica.** Un pool de 10 emisores de rafaga
unica (`one_shot`) que `soltar()` relanza en rotatorio. Cada rafaga nace sobre el
suelo del corte (rayo `1 | 2 | 4`, `restos.gd:278`), con la malla de una hoja
**curva** de 10 x 0,4 x 3 cm, color de la planta cortada, tamano de 0,55 a 1,35
y vida de ~1,6 s. Se apaga sola y **no queda nada en el suelo**.

Tres cosas hacen que parezca una hoja y no arena verde: la curva cocida en la
malla (cuatro siluetas repartidas entre emisores), el giro y bamboleo aleatorios,
y el color con varianza, que aclara y oscurece cada trozo.

**Caliente y frio.** `vida`, `velocidad_saltar` y `alza` se leen en cada rafaga:
se ajustan desde el arbol Remote con el juego en marcha. `rafagas`, `tamano` y
`variantes` se leen una vez en `_ready()`: hay que reiniciar la escena.

**La capa 8 queda libre.** Los restos ya no son cuerpos de fisica: no tienen
capa, ni mascara, ni `freeze`, ni aparcado. El nombre `restos` en
`project.godot` se conserva por no renumerar capas, pero no lo usa nadie.

#### El vaiven: particulas -> cuerpos -> particulas

El orden historico es ese, y las tres veces fueron a proposito:

1. **Particulas de GPU** al principio: chispa que salta y desaparece. Bien como
   efecto, mal como escombro.
2. **Pool de 60 `RigidBody3D`** (2026-09-29): se hizo para DOS cosas — que el
   trozo **se quedara en el suelo** y que la maquina **lo pudiera apartar** — y
   para eso cada trozo pago cuerpo, contacto, reposo y congelado manual.
3. **Vuelta a particulas** (2026-09-30): esas dos cosas **ya no se quieren**. Y
   lo que quedaba (saltar, caer y verse como monton desde la camara) era
   exactamente el trabajo de una particula, pagado en cuerpos rigidos, rayos y
   mecanica de empuje (`empujar` en `restos.gd`, `_apartar_restos` en
   `desbrozadora.gd`), los dos borrados.

Lo que se pierde esta dicho en `LEEME.md`: **el suelo ya no recuerda el
trabajo**. Lo que se paga a cambio era fisica de verdad para un resultado que a
cuatro metros era cosmetico.

#### Lo que se borro: `Montes`

Hubo un segundo sistema, `Montes`, que guardaba el material acumulado en una
rejilla de celdas de 50 cm y lo dibujaba con un `MultiMesh` de cajas. Al usuario le
aparecieron como "pilas de rectangulos" de casi medio metro, y no hacia falta mas
que mirar el codigo para ver el motivo: era el **unico `BoxMesh` del proyecto**.

**Esta borrado.** Con los restos hechos particulas ya no queda material en el
suelo en absoluto: ni montones de rejilla, ni trozos posados. El suelo es siempre
el mismo sitio, sin dos sistemas diciendo cosas distintas, que era el problema de
verdad.

### `scripts/vegetacion.gd` — el contrato comun

Cinco metodos, y existen para que las herramientas no tengan que saber de que clase
es cada campo: `tipo_vegetacion()` (1 cesped, 2 maleza, 3 zarza),
`cortar_por_banda(centro, radio, presupuesto)` —que son tres parametros, no dos—,
`densidad_bajo()`, `coste_maleza()` y `tasa_corte_base()`. Esta ultima fija el ritmo
de corte y **no la sobreescribe nadie**: los tres niveles cortan a 50 celdas/s.
Lo que los diferencia es la dureza, que entra por otro lado. La base devuelve
cero en `cortar_por_banda` a proposito: una
vegetacion que no se sabe cortar no tiene que inventar un sistema, tiene que
decir que no.

### Donde se ve la mecanica

No hay escena de pruebas de la zarza. **No hace falta**: la zarza es la misma
hoja que el cesped, y las pruebas van contra la escena real (`main.tscn`) con la
maquina de verdad, que es donde se puede medir si el morro llega o no.

La que habia, `scenes/pruebas_zarza.tscn`, aislaba seis reglas de la maraña
(matas sueltas, enredadas, altas y pegadas) con `marcar_anclajes` y unos contadores
en pantalla. Todo eso se borro junto con el sistema, porque describia reglas que ya
no existen. Ademas **estaba rota**: pedia un `overlay_prueba_zarza.gd` que no
existia, y nadie se dio cuenta porque no se abria. Esa es la clase deScene que
sobrevive a su motivo y un dia，销售 cara.

---

## 13. `tools/` — pruebas y medicion

### Las que se ejecutan sin abrir nada

Todas con `--headless` y `--script`. Las **ocho** de `test_` son las que tienen
que estar en verde; las de `medir_`, `ver_` y `foto_` **no comprueban nada**,
informan, y por eso no se ejecutan en la bateria.

| Archivo | Que hace |
| --- | --- |
| `test_juego.gd` | la suite principal: movimiento, desbrozadora, vegetacion y suelo plano |
| `test_movimiento_integrado.gd` | paneo, WASD, carrera, agachado, salto, acelerador y el tier 3 |
| `test_vegetacion_tier3.gd` | el tier 3 con la maquina de verdad: alcance del morro, corte y escombro |
| `test_cabezales.gd` | que se note el reparto entre los cuatro cabezales sobre el tier 3 |
| `test_corte_organico.gd` | los ocho sectores pierden lo mismo, el presupuesto se respeta y el borde tiene dientes |
| `test_inventario.gd` | soltar, rueda, recoger y el orden invertido |

### Las que hay que mirar con ventana

| Archivo | Que hace |
| --- | --- |
| `foto.gd` | una foto suelta |
| `foto_inventario.gd` | la rueda, la hoz, las manos vacias y el "E recoger" |
| `foto_personaje.gd` | el personaje |
| `ver_encuadre.gd` | que mallas entran en la foto y a que grados del centro |
| `mirar_hierba.gd` | tres fotos con render real y cuanto ocupa cada una |
| `medir_foto.gd` | mide pixeles de la foto a render real |
| `medir_densidad.gd` | frame time con distintas densidades y radios |
| `medir_cabezales.gd` | medida de los cabezales sobre el tier 3 |
| `diag_hierba.gd` | AABB, reparto por cuadrante y datos de instancia |

**Ninguna prueba mide el aspecto**, ni el del corte ni el de los restos. Es
deliberado: el aspecto se juzga a ojo, y los restos se miran ahora **en el
propio juego** — duran lo que dura la rafaga, no hay estado que fotografiar
por separado (`ver_restos.gd` y `test_origen_restos.gd` se borraron con los
cuerpos fisicos).

### Los scripts de Python

Son once, y se separan en dos grupos que no se mezclan:

**Los que generan modelos** (Blender en background, miden y exportan):
`crear_desbrozadora.py`, `crear_desbrozadora_mesh.py`, `crear_desbrozadora_100x.py`,
`crear_motor.py`, `crear_hoz_mesh.py`, `crear_personaje_mesh.py`,
`crear_furgoneta_mesh.py`.

**Los que abren Blender con ventana para que el modelo se vea**, que es como
manda `AGENTS.md`: `abrir_modelo.py` (el que se usa, y **no** vale con pasarle el
fichero a Blender: da `File format is not supported`), `exportar_blender.py`,
`ver_modelo.py` y `probar_cambio.py`.

### Como se cierra el aviso de imagen

La suite comprueba que la foto sale **con algo de contenido** (que no sea todo
negro), y eso en headless no se puede: no se dibuja nada, asi que la prueba avisa
en vez de fallar. Para cerrarlo sin tener que abrir el juego:

```bash
flatpak run --filesystem=$HOME/Documentos org.godotengine.Godot \
  --path . --script tools/medir_foto.gd --rendering-driver vulkan
```

`medir_foto.gd` hace la foto, espera 40 fotogramas reales, tira otra con
`Hierba` oculta y compara las dos. La última medición fue sobre la escena
anterior, con terreno procedural y encuadre inicial de −40°: cambió el **52,4 %**
de los píxeles al ocultar ese campo y el **54,7 %** de la captura tenía píxeles
verdes. El plano actual aún no se ha medido visualmente.

> **No se lanza la suite completa con Vulkan para cerrar el aviso.** En una
> maquina sin GPU (render por software) va a unos 1 fps y las pruebas tardan
> **doce minutos**, y ademas salen a veces falladas por motivo del reloj y no
> del codigo. `medir_foto.gd` tarda 3 segundos y comprueba justo lo que
> comprueba el aviso. Ademas la suite ahora espera **tiempo simulado** y no de
> reloj (`_esperar()`), asi que las pruebas de movimiento ya no dependen de que
> la maquina renderice rapido.

`mirar_hierba.gd` espera 70 fotogramas antes de medir, porque si no el jugador
todavia se esta asiendo y las tres fotos no salen con la misma camara y no se
pueden comparar.

> **Por que a veces salen fallos que no son del codigo:** la suite con ventana
> abierta (Vulkan) necesita el raton y el teclado, asi que **no puede correr
> mientras el juego este abierto en otra ventana**. Godot se queda con el foco y
> la entrada, y entonces salen fallos que no tienen nada que ver: el bamboleo a
> 0,0000 m, la camara sin retardo, la velocidad de carrera a 4,63 m/s, y el giro
> de la camara al pulsar `S` medido a 69 grados en vez de 0,4. Se reconoce
> porque salen todos a la vez y son pruebas de raton y de movimiento.
>
> Se comprueba con `pgrep -af godot`: si sale `project.godot` en vez de
> `tools/test_juego.gd`, hay un juego abierto. En headless no pasa nada de esto:
> el renderer de mentira no pide foco, y se puede repetir sin problema.

---

## 14. Rendimiento medido (referencia de la escena anterior)

Medición registrada con una AMD Radeon RX 6600, Forward+, Vulkan 1.4 y
`tools/medir_densidad.gd`. El jugador se oculta durante la captura, pero el resto
de la escena anterior permanece activo: terreno procedural, bosque y
`MalezaAlta`. Los recuentos y triángulos de la tabla son solo los del cesped
(entonces el nodo se llamaba `Hierba`); **estas cifras no son una medición del
plano actual**, y la primera fila lleva un radio de 66 m que ya no existe en
ningun preset: el cesped va ahora a 90 m.

| Densidad | Radio | Hojas | Triángulos | Mediana | Peor |
| ---: | ---: | ---: | ---: | ---: | ---: |
| **60/m² (baseline anterior)** | **66 m** | **255.360** | **1.532.160** | 8,3 ms | 8,3 ms |
| 30/m² | 20 m | 8.136 | 48.816 | 8,3 ms | 8,4 ms |
| 60/m² | 20 m | 16.301 | 97.806 | 8,3 ms | 8,4 ms |
| 100/m² | 20 m | 27.118 | 162.708 | 8,3 ms | 8,6 ms |
| 160/m² | 20 m | 43.305 | 259.830 | 8,3 ms | 8,3 ms |
| 100/m² | 14 m | 14.190 | 85.140 | 8,3 ms | 8,6 ms |
| 160/m² | 14 m | 22.673 | 136.038 | 8,3 ms | 8,4 ms |

La mediana de 8,3 ms está limitada por VSync a 120 fps, así que no aísla el coste
de la hierba. La columna de peor fotograma tampoco incluye un pase sin VSync ni
separa el coste del terreno y la maleza. Sirve como referencia de la escena
completa; para perfilar un cuello de botella hace falta medir esas partes por
separado.
