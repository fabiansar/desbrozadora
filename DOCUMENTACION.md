# Documentacion tecnica

Todo lo que hay hecho, archivo por archivo y con el porque. Esta es la
referencia para tocar el proyecto sin romper lo que ya funciona.

---

## 1. Como esta montado

La escena principal es `scenes/main.tscn`. Es lo unico que se ejecuta; todo lo
demás cuelga de ahi.

```
main.tscn (Mundo)
├── Entorno        WorldEnvironment: cielo, luz de ambiente, niebla
├── Suelo          StaticBody3D + malla 80x80 m, con el shader de tierra
├── Sol            DirectionalLight3D, la luz principal
├── Relleno        DirectionalLight3D, luz de relleno sin sombras
├── Bosque         arboles repartidos por el campo (colision capa 2)
├── Hierba         192.454 hojas en 71 MultiMesh, uno por cuadrante
│   └── Viento     el mapa del viento, hijo de la hierba
└── Player         el jugador (CharacterBody3D)
    ├── Cabeza     pivote de la cabeza, a 1,62 m
    │   └── Camara la camara en primera persona
    └── Caderas     donde va colgada la maquina
        └── PivoteDesbrozadora
            └── Desbrozadora   la herramienta colgando
```

Lo de `Caderas` es importante y no es un detalle de colocacion: la maquina
cuelga de las caderas y **no** de la camara, porque el arnes es lo que justifica
que los dos lados sean distintos. `desbrozadora.gd` coloca el pivote en cada
fotograma segun hacia donde se mira, asi que ni `main.tscn` ni `jugador.tscn` le
fijan ninguna transformacion.

Las capas de fisica (`scenes/jugador.tscn`, `main.tscn`):

| Capa | Nombre | Quien |
| --- | --- | --- |
| 1 | `mundo` | suelo |
| 2 | `bosque` | troncos y copas de los arboles |
| 3 | `jugador` | el jugador |
| 4 | `hierba` | la hierba (por si algun dia hay colision) |
| 5 | `herramienta` | la desbrozadora |

**Decisiones que ya estan tomadas y no hay que volver a mirar:**

- La desbrozadora cuelga de un pivote bajo `Caderas`, no de la camara ni de las
  manos. El nombre `PivoteDesbrozadora` se conserva, pero ya no cuelga de la
  camara: el nombre pica, la jerarquia manda.
- **El cabezal esta SIEMPRE dentro del encuadre.** Va 1,27 m por debajo de la
  camara y 1,18 m por delante, unos 47 grados por debajo del horizonte, y con el
  angular de 100 grados en 16:9 solo entran 34 grados por debajo del eje: de
  serie se salia de la foto. `CamaraGopro._pitch_limitado()` baja la vista lo
  justo para que no se salga nunca, y el jugador puede mirar hasta 55 grados
  hacia arriba. Antes de esto el cabezal se salia **a proposito**; ahora al
  reves, porque se van a cortar zarza alta y hay que ver donde corta la hoja.
- El corte se busca en un **disco horizontal en X/Z** bajo el cabezal, con radio
  `radio_corte`. La altura del cabezal no manda: asi el corte depende de la
  hoja, no de la maquina. Con `radio_corte = 0.40` el paso es de 80 cm.
- Se corta con el acelerador pulsado. Es lo que hace el `"cortando"` de
  `desbrozadora.gd`.

---

## 2. `scripts/jugador.gd` — el jugador

`CharacterBody3D` con movimiento propio, sin `CharacterBody3D.move_and_slide`
directo: se integra a mano para poder añadir la inercia.

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
| `pitch_inicial` | -25 | con la que arranca, mirando ya a donde se trabaja |
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
`get_velocidad_plano()`, `get_andando()`, `get_correr()`, `get_giro_total()`.

---

## 3. `scripts/camara_gopro.gd` — la camara

Camara en primera persona con el balanceo de una GoPro: se queda "colgada" al
girar y se suelta despues, y el paso te bota un poco.

### El encuadre automatico del cabezal

Es lo mas importante de este archivo, y lo que se cambio para poder cortar zarza
alta. La camara cuelga de `Cabeza` por un angulo fijo, de modo que el cabezal
queda 47 grados por debajo del horizonte y solo entran 34 grados por debajo del
eje. Mirando recto, y mas arriba todavia, la herramienta se salia de la foto.

`_pitch_limitado()` recorta la inclinacion por arriba para que el cabezal siga
dentro: mide el angulo real que baja desde **la posicion actual de la camara**
hasta `herramienta.punto_de_corte()`, le resta el margen que queda
(`margen_cabezal`, 4 grados) y acota el pitch a ese techo. El jugador puede
mirar lo que quiera; la vista se inclina sola, la herramienta no se mueve.

El margen de 4 grados no es decorativo: sin el, la herramienta entra y sale del
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
| `angular_correr` | 12° | cuanto se abre al correr |
| `angular` | 100° | angular normal, horizontal |
| `margen_cabezal` | 4° | margen que se deja al cabezal en el encuadre |
| `ladeo_herramienta` | — | lo pone `desbrozadora.gd` cada fotograma, no se toca a mano |

---

## 4. `scripts/desbrozadora.gd` — la herramienta

`class_name Desbrozadora`. Se apunta sola al grupo `"herramienta"` en `_ready()`,
y busca dentro del modelo los nodos `Giro` y `Corte` por nombre, asi que
moverlo de sitio en la escena no rompe nada.

| Export | Valor | Que hace |
| --- | --- | --- |
| `modelo`, `giro`, `corte`, `motor_sonido` | — | nodos que se buscan por nombre, se pueden mover de sitio |
| `rpm_maximas` | 9000 | tope del motor |
| `subida_rpm` | 0.85 s | de parado a tope |
| `bajada_rpm` | 0.6 s | de tope a parado |
| `vueltas_maximas` | 130 | vueltas/s del carrete |
| `altura_cadera` | 0.88 m | altura del arnes |
| `lateral_cadera` | 0.26 m | el arnes va a la **derecha**, y de ahi sale la asimetria |
| `rapidez_caderas` | 2.6 | las caderas van detras de la maquina |
| `alcance` | 1.15 m | del arnes al cabezal, fijo: va atado, no sostenido |

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

La vertical:

| Export | Valor | Que hace |
| --- | --- | --- |
| `inclinacion_reposo` | -16° | morro arriba en reposo; negativo es hacia abajo |
| `inclinacion_acelerando` | 22° | cuanto baja el morro al acelerar |
| `mirar_suelo` | 44° | pitch al que el cabezal apoya en el suelo y deja de hundirse |
| `caida_max` | 0.26 m | cuanto bajan las manos al trabajar |
| `vista_baja` | 0.30 m | cuanto baja la vista al trabajar: los ojos van detras de las manos |

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
- `get_cortando()` — si el motor pasa del 15 % de las rpm maximas.
- `velocidad_corte()` — velocidad del hilo. **Pendiente:** ahora solo es la
  velocidad de giro; cuando haya que modelar el arrastre habra que sumarle la
  velocidad del jugador.

---

## 5. `scripts/hierba.gd` — la hierba (lo importante)

`class_name Hierba`, sobre un **`Node3D`**, no sobre un `MultiMeshInstance3D`.
El nodo crea y guarda sus propios hijos, uno por cuadrante.

### Por que cuadrantes

Con un unico MultiMesh de 68 m de lado, su caja envolvente es tan grande que
siempre se solapa con la pantalla, se mire donde se mire. El motor no puede
descartar nada, asi que dibuja las 192.000 hojas enteras en cada fotograma
aunque solo se vea un trozo de cesped. Con cuadrantes, cada uno lleva su caja
ajustada a las hojas que tiene dentro, el motor descarta solo los que quedan
fuera de la vista, y el dibujo se reduce a lo que se ve de verdad.

Por encima del culling de la vista hay un **recorte por distancia**
(`distancia_maxima`, 42 m) en `_recortar()`: es la red de seguridad para el dia
que el campo crezca. Hoy no apaga nada, porque 42 m es mas que el radio del
campo (34 m).

El estado de cada hoja (donde esta y cuanto le queda de altura) vive en arrays
de GDScript, **NO** en el MultiMesh:

- El MultiMesh solo existe en el servidor de graficos. En headless no guarda
  nada, asi que una prueba en linea de comandos no veria ni una hoja y el
  sistema de corte no se podria comprobar.
- Leer 190.000 transformaciones del motor en cada fotograma seria una chapuza.
  Con los arrays se va directo.

El MultiMesh solo recibe la transformacion y el color. El shader lee
`INSTANCE_CUSTOM`, y de ahi sale cuanto se dobla con el viento y cuanto le queda
de altura despues del corte. Asi cortar es escribir un numero: no se toca ninguna
geometria, y se puede ir cortando en plan largo sin que baje el ritmo.

Para el corte hay ademas una rejilla: un diccionario con celdas de 2 m y la
lista de indices de cada una, para no revisar las casi doscientas mil hojas por
fotograma.
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
cuadrante con su `custom_aabb` ya ajustada. Reparto verificado: **71 cuadrantes
de 8 m, 192.454 hojas, ninguna perdida, ninguno vacio**.

La siembra es sobre una rejilla con jitter, y el borde se va aclarando con
`borde` (0.72) para que el campo no tenga un corte recto.

| Export | En el codigo | **En el juego** | Que hace |
| --- | --- | --- | --- |
| `tipo` | 1 | 1 | 1 = hierba, 2 = el otro tipo (aun no hecho) |
| `altura` | 0.38 m | **0.88 m** | |
| `variacion_altura` | 0.45 | **0.96** | quanto hay de alto y de bajo |
| `grosor` | 0.045 m | **0.145 m** | |
| `variacion_grosor` | 0.35 | **0.64** | |
| `radio` | 34 m | 34 m | radio del campo |
| `densidad` | 30 | **53** | hojas por m2 |
| `borde` | 0.72 | **0.76** | como se va aclarando el borde |
| `semilla` | 90210 | 90210 | con la misma sale siempre igual |
| `lado_cuadrante` | 8 m | 8 m | lado de cada trozo de campo |
| `distancia_maxima` | 42 m | **22 m** | recorte por distancia |
| `radio_corte` | 0.40 m | **0.54 m** | paso del cabezal, 108 cm de ancho |
| `dejar_tocon` | true | true | cortar deja tocón |
| `altura_tocon` | 0.08 m | 0.08 m | altura del tocón |

> **Ojo con estas dos columnas: son valores distintos y estan en sitios
> distintos.** La columna "en el codigo" es el `@export` por defecto de
> `scripts/hierba.gd`, y la de "en el juego" es lo que sobrescribe la instancia
> `Hierba` de `scenes/main.tscn`. Lo que se ve al jugar es la segunda. Se
> cambiaron a proposito para tener hierba alta y densa (88 cm, 53/m2) que se
> parezca a un zarzal, y por eso el campo real son **192.454 hojas**, no las
> 108.960 que salen con los valores por defecto.
>
> Al cambiar estos numeros, dos cosas se quedan viejas solas: los comentarios que
> dan recuento de hojas, y las pruebas que comparen con un literal. Por eso la
> prueba del ancho de corte mide contra `hierba.radio_corte` en vez de contra
> un 0,40 escrito a mano, y `medir_densidad.gd` lee la densidad de la escena al
> arrancar en vez de tenerla en su lista. Las cifras de este documento se sacan
> con el juego, no de los valores por defecto.


`dejar_tocon` esta en `true` a proposito: con `false` la hierba cortada queda a
0 cm, tumbada en el suelo, y **no se ve nada desde la camara**, asi que no hay
ni rastro de por donde has pasado. Con 8 cm de tocón el corte se ve de sobra,
como una mancha mas corta y mas clara.

### API para el corte y las pruebas

```gdscript
cortar(centro: Vector3, r: float) -> int   # corta y devuelve cuantas
total() -> int                             # hojas sembradas
total_de_pie() -> int                      # cuantas quedan de pie
de_pie(centro, r) -> int                   # cuantas hay de pie en un circulo
altura_hoja(i) -> float                    # altura visual actual
posicion_hoja(i) -> Vector3
uv_de_hoja(i) -> Vector2                   # su sitio en el mapa del viento
alto_de(i) / gordo_de(i) -> float
altura_visual() -> float                   # altura de una hoja cortada

# lo de los cuadrantes
num_cuadrantes() -> int                    # cuantos hay (71)
hojas_de_cuadrante(n) -> int               # hojas de ese cuadrante
caja_de_cuadrante(n) -> AABB               # su caja ajustada
cuadrantes_visibles() -> int               # cuantos quedan tras el recorte
material_compartido() -> ShaderMaterial     # el material, para compartirlo
malla() -> ArrayMesh                       # la malla de una hoja
caja_del_campo() -> AABB                   # union de todas las cajas
forzar_recorte(desde: Vector3)             # el recorte, pero a mano
```

> `cuadrantes_visibles()` y `hojas_de_cuadrante()` devuelven lo que hay **despues**
> del recorte por distancia, no el total: por eso las pruebas las comparan antes
> y despues de `forzar_recorte()`. Para el total esta `num_cuadrantes()`.
>
> `caja_del_campo()` hay que volver a pedirla si el campo cambia, y devuelve la
> union de las cajas de todos los cuadrantes. `mirar_hierba.gd` y `foto.gd` la
> usan en vez de calcular el AABB a mano, que es lo que se hacia antes.

---

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
(`VERTEX.x *= mix(0.5, 1.0, enpie)`) porque si no un corte de 8 cm pareceria una
alfombra.

**El corte.** Cortada, todos los vertices caen al suelo y el triangulo se
degenera, asi que la hoja no pinta nada. Sin tocar un solo vertice desde el
juego, por eso cortar 192.000 hojas es barato.

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

> Consecuencia a tener en cuenta: la UV se calcula **al sembrar**. Si se cambia
> `radio` en caliente hay que volver a sembrar, o el viento sale descuadrado.

Se apunta a la hierba por el grupo `"hierba"`. Como el viento es hijo de la
hierba, el `_ready` del hijo va antes que el del padre y a la primera vez no
encuentra nada; `_process` reintenta hasta que la haya.

---

## 8. `shaders/suelo.gdshader` y el suelo

El suelo es una `StaticBody3D` con una malla de 80x80 m y este shader. Con un
color plano parecia un plastico verde, asi que se mezclan tres tonos con ruido
a tres escalas: manchas grandes (idea de terreno), media (tierra clara contra
humeda) y fina (grano).

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

---

## 9. `scripts/bosque.gd` — el bosque

Reparte arboles por el campo con semilla fija, sobre una rejilla con jitter para
que no salgan en lineas. Cada arbol es un `StaticBody3D` con tronco y dos copas,
todo con colision solo en el tronco (la copa no, que es mas barato y se nota
igual). Va en la capa 2.

---

## 10. `tools/` — pruebas y medicion

| Archivo | Que hace |
| --- | --- |
| `test_juego.gd` | la suite. **131 comprobaciones** en headless, **133** con GPU |
| `mirar_hierba.gd` | tres fotos con render real y cuanto ocupa cada una |
| `medir_densidad.gd` | frame time con distintas densidades y radios |
| `medir_foto.gd` | compara dos capturas pixel a pixel |
| `diag_hierba.gd` | AABB, reparto por cuadrante y datos de instancia |
| `foto.gd` | una foto suelta |
| `ver_encuadre.gd` | que mallas entran en la foto y a que grados del centro |
| `crear_desbrozadora.py` | genera el modelo de la desbrozadora |
| `crear_motor.py` | genera el modelo del motor |
| `ver_modelo.py` | mira un `.glb` por dentro |

Los tres `.py` son generadores: se ejecutan una vez para producir el `.glb` y
luego no hacen falta en el juego. Los `.uid` los genera Godot solo, no se tocan.

**La limitacion importante de las pruebas:** el renderer headless de Godot usa un
dispositivo de mentira que **descarta los transforms y los datos de instancia
del MultiMesh**. Por eso `diag_hierba.gd` en headless da AABB de cero y
transforms identidad, y por eso hay que usar `--rendering-driver vulkan` para
cualquier cosa visual. La suite comprueba la logica (los arrays), no el render.

> Con chunking esto ya no es un problema de diagnostico: cada cuadrante lleva su
> `custom_aabb`, y eso **si** se puede comprobar en headless, porque lo calcula
> GDScript. Lo que sigue sin poder comprobarse en headless es si la hoja sale
> dibujada, que es otra cosa.

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

## 11. Rendimiento medido

En una AMD Radeon RX 6600 con Forward+, Vulkan 1.4. Medido con
`tools/medir_densidad.gd`, que ademas **cambia el jugador a invisible** para que
el numero sea el de la hierba y no el de verse a uno mismo andando.

| Densidad | Radio | Hojas | Triangulos | Mediana | Peor |
| --- | --- | --- | --- | --- | --- |
| **53/m2 (el de ahora)** | 34 m | **192.454** | 1.154.724 | 8.3 ms | 8.3 ms |
| 30/m2 | 20 m | 37.696 | 226.176 | 8.3 ms | 8.4 ms |
| 60/m2 | 20 m | 75.380 | 452.280 | 8.3 ms | 8.4 ms |
| 100/m2 | 20 m | 125.664 | 753.984 | 8.3 ms | 8.6 ms |
| 160/m2 | 20 m | 201.067 | 1.206.402 | 8.3 ms | 8.5 ms |
| 160/m2 | 14 m | 98.535 | 591.210 | 8.3 ms | 8.4 ms |

La mediana esta clavada en 8,3 ms en todas las filas porque es el tope de vsync a
120 fps: **no se esta midiendo el coste de la hierba, sino que se aguanta**. El
dato util es la columna "Peor", que es donde se nota cuando algo se pasa de la
raya, y como ninguna se pasa, el campo va sobrado.

La conclusion: el campo real, con 192.454 hojas y 1,15 millones de triangulos, va
a 120 fps sin despeinarse. **Los cuadrantes lo que hacen es permitir subir la
densidad**, que antes de trocear no se podia: con un solo MultiMesh de 68 m el
motor dibujaba las hojas enteras siempre, y a esa densidad el portatil se
arrastraba.
