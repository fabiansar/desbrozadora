# Desbrozadora

Simulador de desbrozadora en Godot 4.7. Andas por un huerto, llevas herramientas
colgadas del arnés y lo que toca, se cae.

Estado: **prototipo jugable del trabajo de desbroce**, version `v0.1.0`. Se anda,
se corre, se salta, se mira, se acelera la desbrozadora, suena el motor, se corta
hierba, maleza y zarza, que es la misma planta mas dura. Para
las pruebas el mundo vuelve temporalmente al suelo plano inicial; el terreno
procedural y el layout de la aldea están retirados mientras se prepara el mapa
artesanal definitivo. El mapa futuro será un valle; el plugin de terreno aún no
está decidido.

## Como se juega

| Tecla | Que hace |
| --- | --- |
| `W` `A` `S` `D` | Andar |
| `Shift` | Correr |
| `Espacio` | Saltar |
| `Ctrl` / `C` | Agacharse |
| Raton | Mirar |
| **Raton izq.** | **Acelerar la herramienta (y con ella se corta)** |
| **Rueda del raton** | **Pasar por las nueve herramientas del inventario** |
| `G` | Soltar lo que llevas en la mano: se cae al suelo |
| `E` | Recoger lo que estás mirando |
| `Q` | Cambiar de cabezal, con el motor parado |
| `Esc` | Liberar el raton |
| Clic en la ventana | Volver a capturar el raton |

**Para cortar, hay que acelerar.** Con el motor parado el cabezal no corta, y
la hierba solo se dobla si el motor esta a medias. El acelerador es el boton
izquiero, como en una desbrozadora de verdad.

## Las dos herramientas

Llevas nueve huecos y uno en la mano. La rueda del raton los va recorriendo, y la
rueda de arriba a la derecha dice cuál llevas y cuál tienes en la mano. Ahora
mismo hay dos:

- **Desbrozadora** (hueco 1). A motor, pesa y empuja. Corta por debajo de la
  cintura y es la única que entra en la zarza. Con `Q` le cambias el cabezal:
  cuchilla de serie, hilo de nylon o disco.
- **Hoz** (hueco 2). A mano, para el cesped de al lado y la maleza baja. Es más
  ágil, no gasta gasolina y no se ahoga en la maleza, pero no llega a la zarza.

Un hueco vacío son las manos vacías: los brazos se quedan al lado del cuerpo y ya
no hay herramienta. Se llega con la rueda, no por accidente.

**Con la `G` la herramienta se suelta y cae**, y se queda en el suelo con lo que
le quedaba dentro (gasolina, desgaste). **Con la `E` la coges**, pero solo
miras: el aviso sale cuando tienes algo delante, y si el inventario está lleno
te lo dice en vez de dejarte pulsando. Lo que coges va al primer hueco libre y a
la mano.

### Los cuatro cabezales: no hay uno que gane siempre

Con `Q` y el motor parado cambias de cabezal. Los cuatro cortan de todo, asi
que la pregunta nunca es "puedo con esto", sino "cuanto me va a costar". Cada uno
tiene dos numeros contra cada planta:

- **Eficacia** (1 a 5): lo rápido que lo corta.
- **Resistencia** (0 a 5): lo que la planta le hace al cabezal. Le come el filo
  **y** frena el motor. Por eso una resistencia de 5 contra la zarza significa
  que la estás cortando, pero el hilo se deshace y la máquina se ahoga.

| cabezal | nivel | contra la hierba | contra la maleza | contra la zarza |
| --- | :-: | --- | --- | --- |
| **Hilo de nylon** | 1 | eficaz 5, res. 1 | eficaz 2, res. 3 | eficaz 1, res. 5 |
| **Cuchilla de serie** | 2 | eficaz 3, res. 1 | eficaz 3, res. 2 | eficaz 3, res. 3 |
| **Disco de dos puntas** | 2 | eficaz 3, res. 1 | eficaz 4, res. 2 | eficaz 2, res. 3 |
| **Disco de tres puntas** | 3 | eficaz 1, res. 1 | eficaz 5, res. 1 | eficaz 4, res. 2 |

La fila del nylon es la que resume el juego: **es el más rápido con la hierba y el
peor con todo lo demás**. Contra la zarza la abre, porque si no no habría forma
de entrar, pero es la peor opción: la cortas a mordiscos, se te come el hilo y la
máchina se frena. Los discos hacen lo contrario, aguantan la maleza y la zarza,
y a cambio se arrastran por el césped.

Y fíjate en la esquina del disco de tres puntas: es el mejor con la maleza y con
la zarza, y el **peor con la hierba** (eficacia 1 contra 5 del nylon). Subir de
nivel no es mejor en todo, es **cambiar para qué trabajo**. Si el encargo es
matar el césped, el mejor cabezal es el más barato, y eso también es una
decisión.

Lo que cuesta cada uno, en tiempo, sobre la misma pasada por una mata de zarza:

| cabezal | fotogramas para abrir la misma pasada | hojas/s en césped |
| --- | :-: | :-: |
| Hilo de nylon | 106 (1,8 s) | 250 |
| Disco de dos puntas | 57 | 150 |
| Disco de tres puntas | 33 | 50 |

Fíjate en la última columna al revés: **el mejor cabezal para la maleza es el
peor para el césped**, y de eso va el juego. Andando a 2 m/s pisas unas 150 hojas
por segundo, así que el nylon (250) va por delante de tus propios pies limpiando
y el disco de tres puntas (50) **no llega**: dejas un reguero por delante y
tienes que volver. Por eso en un encargo de maleza te compensa el disco aunque
se arrastre, y en un encargo de césped te compensa el nylon aunque se gaste.

Y el motor se entera. Medido con el jugador trabajando en la maleza alta:

| cabezal | carga | vueltas |
| --- | :-: | :-: |
| Disco de tres puntas | 0,13 | 8.649 |
| Hilo de nylon | 0,61 | 7.698 |
| Cuchilla de serie | 0,75 | 7.433 |

Parado en lo más espeso, el nylon se va a 0,95 de carga y 6.963 vueltas: se
ahoga. El filo también se gasta y la barra del FILO se mueve mientras trabajas:
entre el 0,1 % y el 0,6 % por segundo según cabezal y planta, o sea que un
cabezal dura entre tres y diecisiete minutos de trabajo. Y la gasolina sube con
la carga, de 0,5 a 0,7 ml/s: un cabezal malo en zarza sale más caro no solo
porque tarda, sino porque el motor está más rato ahogado.

Y el radio también cuenta: el disco de tres puntas barre 1,15 m y el nylon
0,78, así que cada uno barre distinta anchura.

### Hasta donde llega el cabezal

Con el motor echado, la altura del morro depende solo de hacia donde miras:

| Mirada | Altura del morro |
| --- | ---: |
| 55 grados arriba | 1,34 m |
| 35 grados arriba | 1,97 m |
| 15 grados arriba | 0,94 m |
| De frente | 0,09 m |
| 10 grados abajo o mas | 0,00 m (en el suelo) |

O sea que **cualquier mirada hacia abajo apoya el cabezal en el suelo**, y para
"cortar por arriba" hay que mirar un poco **arriba**, no menos abajo. Sin el
motor echado el morro no se hunde: se queda a nueve centimetros aunque mires de
narices, porque es el peso del trabajo lo que lo baja.

### Como se abre el claro: ocho sectores

El disco no corta las hojas **en orden aleatorio**, que es lo obvio y lo que hacia
que un sector entero se limpiara mientras el de al lado conservaba todas sus hojas.
El resultado eran manchurrones.

Lo hace en **ocho sectores de 45 grados**. En cada fotograma:

1. Cada sector recoge **las mismas hojas**, las que caen dentro de su angulo.
2. Cada sector recibe **la octava parte** del presupuesto, con su resto decimal
   propio, que sobrevive de un fotograma a otro.
3. Dentro del sector, las hojas se ordenan **de dentro hacia fuera**.

Lo segundo es lo que hace que el frente sea un frente y no una corona de agujas.
Lo tercero, que cada sector pierda lo mismo en el mismo tiempo. Medido sobre 60
fotogramas con la partida de ejemplo:

```
hojas de partida por sector: [26, 24, 26, 21, 23, 25, 25, 23]
cortadas: 144
perdidas por sector:      [18, 18, 18, 18, 18, 18, 18, 18]
```

**Dieciocho en los ocho**, partiendo de cantidades distintas. El reparto no es
igual de hojas por sector, que no puede ser porque las plantas no estan plantadas
en circulos perfectos: es igual de **hojas perdidas** por sector, que es lo que se
ve.

El borde del disco tampoco es un circulo. Cada hoja tiene su propio umbral de
distancia, fijo, que sale de **donde esta** y no del azar: unas quedan dentro
antes que otras y el recorte sale con los dientes, como el cesped recien cortado.
Y como el umbral es fijo, una hoja no entra y sale entre fotogramas, asi que el
claro **no parpadea** mientras avanzas.

Un numero lo tunea todo: `Hierba.SECTORES`. Con menos sectores el frente es mas
suave y con mas se ve el rayado.

### Los restos: hojas, no ladrillos

Cuando se corta algo, el trozo sale despedido y cae al suelo. Tres cosas lo hacen
que parezca una hoja y no un bloque verde:

**Caen retorcidos, no tumbados.** La orientacion es libre en los tres ejes, asi que
en el monton hay trozos de cara y trozos de canto, unos encima de otros en todas
direcciones. Esto es lo mas importante: con los trozos horizontales, cincuenta
planchas superpuestas son, literalmente, una pila de losas.

**La malla esta curvada.** Cada trozo es una cinta de cinco tramos con un arco (el
centro se levanta y las puntas se apoyan) y un retorcido. Un trozo de verdad nunca
esta recto, y al quedar apoyado en dos puntos con el hueco por debajo se ve lo que
es desde cualquier angulo. Y hay **cuatro siluetas distintas**, para que el monton
no se vea repetido.

**De diferentes tamanos y tonos.** Cada trozo va de 0,55 a 1,35 veces la escala de
la planta, y uno de cada cinco se desatura hacia pajizo, como las hojas secas. Un
monton donde todo es el mismo verde parece un charco de pintura.

Lo que se ve al final es un **enredo de vegetacion troceada**. La prueba de
`tools/test_vegetacion_tier3.gd` comprueba que el escombro pesa, salta, cae al
suelo y que apartarlo lo mueve de sitio; el aspecto hay que mirarlo en el editor.

### La zarza es el tier 3: la misma hoja, mas dura

La zarza **no** es un cesped mas alto, pero tampoco es otra cosa. Es la **misma
hoja** que el cesped y que la maleza, con otros numeros, y todo lo que hay que
saber de ella se ve en una tabla:

| | cesped (tier 1) | maleza (tier 2) | zarza (tier 3) |
|---|---|---|---|
| altura | 49 cm | 76 cm | 150 cm |
| hojas por m2 | 60 | 60 | **20**, y gordas |
| grosor de la hoja | 1 cm | 2,6 cm | **4 cm** |
| se estrecha al subir | mucho (0,88) | algo (0,60) | **poco (0,30)**: arriba sigue siendo hoja |
| se dobla | sí (0,09) | algo (0,06) | **casi nada (0,02)**: tiesa |
| coste para el motor | 1,0 | 3,3 | **3,6** |
| cobertura | todo el mapa | 40 % en matas | mata local de 9 m |

Una zarza son **pocos caños gruesos**, no muchas briznas: por eso van a 20 por
metro cuadrado y no a 60, y por eso la hoja es cuatro veces mas ancha. Con 60
caños de metro y medio la carga se iba a tope con **cualquier** cabezal, y en la
zarza daba igual lo que pusieras, que es justo donde mas deberia importar.

**Y una cosa que cambia respecto a antes: una pasada y ya está.** El corte es un
disco en el suelo, asi que el morro corta todo lo que pilla en el suelo, a la
altura que esté. Y una hoja cortada ya no se vuelve a cortar. No hay raices, ni
copas que haya que rematar, ni varias pasadas: **la dificultad del tier 3 no está
en el número de pasadas, está en lo que cuesta**. Con la cuchilla de serie el
motor se va a 7.147 vueltas y se ahoga; con el disco de tres puntas van 8.583 y
ni se enteran. El hilo se gasta el doble de rápido, y la gasolina sube. Eso es
lo que decides con el cabezal, no cuántas veces pasas.

**Lo que suelta es escombro de verdad**: hojas planas que caen, se quedan en el
suelo y **las apartas con la máquina** pasando por encima. Donde vas trabajando se
queda una pila, y esa pila es lo que tapa el suelo.

### Lo que queda en el suelo

Cuando cortas, el escombro **se queda**: trozos sueltos de unos 10 cm, con peso,
que caen de lado y de canto y se quedan tumbados donde caen. La maquina los **aparta
al pasar** por encima, asi que trabajar un sitio lo deja limpio.

Lo unico que hay en el suelo son esos trozos. Antes habia ademas un sistema de
**montones** que guardaba el material acumulado y lo dibujaba con cajas de casi
medio metro; salia como "pilas de rectangulos" y **esta borrado**. Se pierde una
cosa: una pasada larga ya no levanta un monton que haya que rodear. A cambio, el
suelo es siempre el mismo sitio y no hay dos sistemas diciendo cosas distintas.

Para mirar los restos de cerca, que desde la camara no se pueden juzgar:

```bash
flatpak run --filesystem=$HOME/Documentos org.godotengine.Godot \
    --path . --script tools/ver_restos.gd
```

Y para enumerar que hay en el suelo tras cortar cada planta:

```bash
flatpak run --filesystem=$HOME/Documentos org.godotengine.Godot \
    --headless --path . --script tools/test_origen_restos.gd
```

### La camara nunca pierde el cabezal

La camara se descuelga de la cabeza del jugador y comprueba el punto de corte
real de la herramienta en cada fotograma. Como la distancia y la inclinacion del
cabezal cambian con la pose, no dependen de un angulo fijo: mirando arriba la
vista se acomoda para mantener la zona de trabajo en la foto. El FOV horizontal
base es 100° y se abre 12° al correr; hay un ajuste adicional de ±20° en el
Inspector. Cero deja intacto el FOV base; la escena principal lo tiene ahora
20° por encima del base. El ajuste no cambia la posición de la cámara.

La barra de la desbrozadora mide ahora **2,06 m** y la máquina completa unos
**2,46 m**; el alcance de trabajo está ajustado a 1,56 m para llevar el motor
detrás del operario. El detalle de medidas está en
[DOCUMENTACION.md](DOCUMENTACION.md).

Asi que la camara se baja sola lo justo para que el cabezal siga dentro del
encuadre (`CamaraGopro._pitch_limitado`): uno mira con el raton todo lo que
quiera, hasta 55 grados hacia arriba, y la camara acomoda. No es que la
herramienta se mueva, es que la vista se inclina.

Lo mismo al reves: `S` anda hacia atras, el cuerpo se vuelve de espaldas, y como
la camara colgaba del cuerpo, el mundo daba un tiron de 180 grados al pulsar `S`.
Ahora la camara mide su giro **en el mundo** y le resta el del cuerpo, asi que se
mira siempre hacia donde mira el jugador, vaya hacia donde vaya. Lo comprueban
las pruebas: el cabezal se ve en las 10 inclinaciones de la gama, y con `S` la
camara se mueve 0,4 grados en vez de 180.

## Primer cuerpo en primera persona

El personaje low-poly conserva el torso y la parte inferior visibles en primera
persona; se ocultan la cabeza y los brazos estáticos, y las mangas dinámicas
siguen los puños de la herramienta. La cámara se adelanta a la cara para evitar
quedar dentro del pecho y arranca inclinada hacia la zona de trabajo. La pose
sigue en calibración visual. Para guardar una captura Vulkan:

```bash
flatpak run --filesystem=$HOME/Documentos org.godotengine.Godot \
  --path . --script res://tools/foto_personaje.gd --rendering-driver vulkan
```

La imagen queda en `capturas/personaje_primera_persona.png` y mira 80 grados
hacia abajo para inspeccionar cuerpo y herramienta. El asset completo
se genera con `tools/crear_personaje_mesh.py` y se abre para revisar en Blender
con `tools/abrir_modelo.py`.

## Como se ejecuta

El motor va instalado por Flatpak, asi que se abre siempre con `flatpak run`:

```bash
cd ~/Documentos/desarrollos/desbrozadora
flatpak run --filesystem=$HOME/Documentos org.godotengine.Godot --path .
```

## Como se ejecuta SIN el editor

Hay un ejecutable, y ya no hace falta abrir Godot para jugar. Se genera desde
`export_presets.cfg`, que **esta en el repositorio** a proposito:

```bash
cd ~/Documentos/desarrollos/desbrozadora
flatpak run --filesystem=$HOME/Documentos org.godotengine.Godot \
  --headless --path . --export-release "Linux"   build/desbrozadora.x86_64
flatpak run --filesystem=$HOME/Documentos org.godotengine.Godot \
  --headless --path . --export-release "Windows" build/desbrozadora.exe
```

Despues se juega `./build/desbrozadora.x86_64`, y en Windows
`build\desbrozadora.exe`. Los dos son **un solo fichero**: el paquete va dentro
del ejecutable, para que no sea el clasico "lo he descargado y no me arranca"
porque faltaba el `.pck` de al lado.

**El tamano no dice lo que parece.** El binario de Linux ocupa unos 70 MB, y de
eso **290 KB son el juego**: lo demas es la plantilla del motor con Vulkan, que
ya pesa 71 MB antes de abrir el proyecto. Windows son 105 MB por lo mismo.

**Que se meta el ejecutable es un filtro, no un milagro.** Sin los filtros de
`export_presets.cfg` el paquete lleva dentro 23 MB de `capturas/` (Godot importa
los PNG como texturas) y los 269 KB de una furgoneta que no usa ninguna escena.
La Exclusion esta escrita ahi con el porque de cada cosa.

## Como se prueban las cosas

Hay una suite de pruebas automaticas que va en headless y no necesita tarjeta
grafica. Es lo que hay que ejecutar antes de dar algo por bueno:

```bash
cd ~/Documentos/desarrollos/desbrozadora
timeout 400 flatpak run --filesystem=$HOME/Documentos org.godotengine.Godot \
  --headless --path . --script tools/test_juego.gd
```

Para validar solo el recorrido combinado de movimiento (paneo, barrido, WASD,
correr, agacharse, saltar y acelerar) sin esperar a toda la suite:

```bash
flatpak run --filesystem=$HOME/Documentos org.godotengine.Godot \
  --headless --path . --script res://tools/test_movimiento_integrado.gd
```

Ultima ejecucion registrada: **207 correctas, 0 fallos, 1 aviso**. El aviso es
que la comprobacion de imagen no se puede hacer en headless, y se cierra aparte
con una herramienta que va en 3 segundos:

```bash
timeout 300 flatpak run --filesystem=$HOME/Documentos org.godotengine.Godot \
  --path . --script tools/medir_foto.gd --rendering-driver vulkan
```

Hay pruebas focalizadas que van mucho mas rapido que la suite entera y cubren
una sola cosa. Se ejecutan igual, con `--headless`:

```bash
# El inventario entero: soltar, rueda, recoger y el orden invertido
flatpak run --filesystem=$HOME/Documentos org.godotengine.Godot \
  --headless --path . --script tools/test_inventario.gd

# El corte organico: los ocho sectores pierden lo mismo y el borde sale con dientes
flatpak run --filesystem=$HOME/Documentos org.godotengine.Godot \
  --headless --path . --script tools/test_corte_organico.gd

# Que se nota el reparto entre los cuatro cabezales sobre el tier 3
flatpak run --filesystem=$HOME/Documentos org.godotengine.Godot \
  --headless --path . --script tools/test_cabezales.gd

# El tier 3 entero: altura, corte, escombro que pesa, que cae y que se aparta
flatpak run --filesystem=$HOME/Documentos org.godotengine.Godot \
  --headless --path . --script tools/test_vegetacion_tier3.gd
```

Las tres comprueban numeros, no pictures. **El aspecto del corte y de los restos
no lo mide ninguna prueba**: eso hay que mirarlo en el editor, y con la ventana
abierta, que es como se juega.

Para ver en foto lo que se esta midiendo (sin `--headless`):

```bash
# La rueda del inventario, la hoz en la mano y el aviso de "E recoger"
flatpak run --filesystem=$HOME/Documentos org.godotengine.Godot \
  --path . --script tools/foto_inventario.gd

# Los restos de cerca, que es la unica vista donde se pueden juzgar
flatpak run --filesystem=$HOME/Documentos org.godotengine.Godot \
  --path . --script tools/ver_restos.gd
```

Esa mide si la hierba se dibuja de verdad. La última medición registrada fue en
la escena anterior con terreno procedural: **52,4 % de píxeles cambiados** al
ocultar `Hierba` y **54,7 % de píxeles verdes**. El plano actual aún no se ha
medido visualmente. Las capturas se guardan en `capturas/`.

> **No repitas la suite entera con ventana.** Se puede, pero con la GPU por
> software de esta maquina va a un fps y la suite tarda doce minutos. Para
> comprobar la imagen basta con `medir_foto.gd`, que hace justo eso y nada mas.
> Si aun asi la repites, **cierra antes el juego**: Godot se queda con el
> teclado y el raton, y si hay otro Godot abierto la suite no los recibe y salen
> fallos de pruebas de raton que no son del codigo. Se comprueba con
> `pgrep -af godot`: si sale `project.godot` en vez de `tools/test_juego.gd`, hay
> un juego abierto. La de headless no tiene ese problema.

### Como esta repartida la hierba

El campo no es un solo MultiMesh: se reparte en cuadrados, cada uno con el suyo.
El tamaño se configura por campo para equilibrar culling y llamadas de dibujo.
Cada cuadrado lleva una caja ajustada y se puede apagar por distancia.

Hay **dos campos**, cada uno con su semilla y su material:

| preset | tipo | altura | densidad | radio |
|---|---|---|---|---|
| `scenes/vegetacion/cesped.tscn` | cesped (tier 1) | 49 cm | 60 por m2 | 90 m |
| `scenes/vegetacion/maleza_alta.tscn` | maleza seca (tier 2) | 76 cm | 60 por m2 | 90 m |
| `scenes/vegetacion/zarza.tscn` | zarza (tier 3) | 150 cm | 60 por m2 | 9 m |

Las tres son **el mismo script** con numeros distintos. `main.tscn` solo las
instancia; los numeros viven en el preset, y se cambian ahi.

Las dos alturas bajaron desde la version anterior (69 y 133 cm) porque con la
maleza a 1,33 m tapaba la mitad del encuadre. Y la maleza se puso en matas de
verdad (`formacion` 0,70, antes 0,24): ocupa el 37 % del mapa en vez del 93 %, y
se ven los claros por los que se anda. Un claro se trabaja mas rapido que un
zarzal, y con la maleza en alfombra no habia forma de notarlo.

Las tres van con `formacion = 0,70`, o sea en matas y no en alfombra, y se siembran
sobre el suelo plano de pruebas, sin exclusiones por terreno o parcelas. La
maleza tiene `dureza = 3,3` y la zarza `dureza = 3,6`; el césped no lleva dureza
propia porque es el tier 1. La zarza comparte la densidad de la maleza, 60 por m2,
a proposito: su dificultad tiene que venir de la dureza y de la resistencia del
cabezal, no de estar mas rala, que haria que el tier mas duro fuese el mas lento
de barbechar. Lo que si es suyo es la altura (150 cm) y la distancia maxima
(20 m, frente a los 16 m de la maleza y 80 del cesped), para que se vea desde
lejos.

El radio de corte **no es propio de estos campos**: `Desbrozadora.radio_corte` vale
1,0 m y lo comparten las tres. Es el radio efectivo de la pasada para que alcance
suficientes hojas y deje un rastro visible, no el tamaño geométrico de la cuchilla.

La suite comprueba el reparto, las cajas, el recorte por distancia y el corte de
ambos campos. Los valores efectivos están en `scenes/main.tscn`; el detalle está
en [DOCUMENTACION.md](DOCUMENTACION.md).

### Suelo plano de pruebas

La escena usa una superficie plana de 160 × 160 m con colisión que cubre un radio
de 80 m. Su altura es `Y = 0`, igual que el suelo inicial del prototipo. No hay
nodos ni scripts activos para `Terreno` o `Aldea`; el bosque y los dos campos de
hierba se generan sobre el plano sin exclusiones por parcelas.

El valle, las carreteras y la aldea manual se diseñarán más adelante. La hoja de
ruta está en [DISENO.md](DISENO.md).

### Mirar como queda de verdad

La prueba de headless usa un renderer de mentira que **se come los datos de las
instancias del MultiMesh**, asi que no sirve para ver nada. Para mirar la
hierba de verdad hay que usar la GPU:

```bash
# tres fotos: de pie, cortada y sin hierba, y cuanto ocupa cada una
timeout 280 flatpak run --filesystem=$HOME/Documentos org.godotengine.Godot \
  --path . --script tools/mirar_hierba.gd --rendering-driver vulkan

# rendimiento con distintas densidades
timeout 280 flatpak run --filesystem=$HOME/Documentos org.godotengine.Godot \
  --path . --script tools/medir_densidad.gd --rendering-driver vulkan
```

Las fotos se guardan en `capturas/`.

## Donde esta cada cosa

```
scenes/        main, jugador, desbrozadora, hoz, zarza, hierba, bosque, arbol
               y las de pruebas: pruebas_zarza, capas_zarza
scripts/       la logica de cada cosa, una por archivo
shaders/       el de la hierba y el del suelo
tools/         las pruebas, las herramientas de medicion y los generadores
               de modelo de Blender
resources/     los cabezales y las herramientas, como recursos de Godot
models/        la desbrozadora, la hoz, el personaje y los modelos auxiliares
assets/        recursos auxiliares
audio/         el motor y el sonido de corte
capturas/      las fotos que dejan las herramientas de medicion
docs/          la guia para quien empieza de cero
```

Los detalle de cada archivo estan en [DOCUMENTACION.md](DOCUMENTACION.md), el
analisis del estado del proyecto en [REVISION.md](REVISION.md), y **la vision
global y la hoja de ruta** en [DISENO.md](DISENO.md).

## Como trabajamos

Los cambios van en git, y hay un `AGENTS.md` con **tres modos de trabajo**. Segun
lo que necesites, el mensaje empieza por una etiqueta:

| etiqueta | que hace | pruebas |
|---|---|---|
| `[MODO: VIVO]` | cambio pequeno y directo | ninguna, pruebas tu en el editor |
| `[MODO: SEMI]` | cambio con una comprobacion de parseo | la minima imprescindible |
| `[MODO: NOCHE]` | bucle autonomo hasta dejarlo bien | suite completa, 0 fallos |

Ademas del modo, los cambios pequenos van uno cada vez y el feedback sale de
jugar, no de inventarlo. Lo que se va tocando se apunta en el
[CHANGELOG.md](CHANGELOG.md).

Si quieres aprender a hacer cambios directamente, consulta la
[guía para principiantes](docs/para_principiantes/README.md): explica Godot,
GDScript, Blender, Git y las pruebas del proyecto paso a paso.
