# Desbrozadora

Simulador de desbrozadora en Godot 4.7. Andas por un huerto, llevas herramientas
colgadas del arnés y lo que toca, se cae.

Estado: **prototipo jugable del trabajo de desbroce**, version `v0.1.0`. Se anda,
se corre, se salta, se mira, se acelera la desbrozadora, suena el motor, se corta
hierba y maleza, y hay zarzas que hay que llegar a la raíz para tumbarlas. Para
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

### La zarza hay que tumbarla por la raiz

La zarza no es un CESped mas alto. Cada mata tiene una **raíz** clavada en el
suelo, y de raíz vuelve a brotar cada año. Por eso:

- **Una pasada por arriba no arregla nada.** Abre paso y quita la copa, y la raíz
  sigue ahí. Es el trabajo que no vale.
- **Hay que bajar el morro a la base.** Cortando a ras de suelo (unos 2 cm) llega
  a la raíz y entonces sí, la mata cae entera.
- **Las cañas se sostienen unas a otras.** Si la parte de arriba está enganchada a
  otra mata con su propia raíz, al cortarle el apoyo a una **no se cae**: se queda
  de pie. Por eso hay que dar varias pasadas y no vale con un solo intento.
- **Lo que cae se queda en un montón**, y hay que apartarlo con la máquina para
  poder seguir trabajando debajo.

En el juego normal no se ve ni la raíz ni los enganches. En la escena de pruebas
`scenes/pruebas_zarza.tscn` sí, en colores (caja roja = raíz, raya amarilla =
enganche), y el panel de arriba a la derecha dice cuántas raíces quedan.

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

Ultima ejecucion registrada en `v0.1.0`: **195 correctas, 6 fallos, 1 aviso**.
Los seis fallos son las comprobaciones que siguen esperando la maleza de 1,33 m,
cuando ahora mide 0,76 m (ver la tabla de mas abajo); no son un fallo de codigo.
El aviso es que la comprobacion de imagen no se puede hacer en headless, y se
cierra aparte con una herramienta que va en 3 segundos:

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

# La mecanica de la zarza: raiz, enganches y que cae lo que pierde el apoyo
flatpak run --filesystem=$HOME/Documentos org.godotengine.Godot \
  --headless --path . --script tools/test_zarza_conexion.gd
```

Para ver en foto lo que se esta midiendo (sin `--headless`):

```bash
# La rueda del inventario, la hoz en la mano y el aviso de "E recoger"
flatpak run --filesystem=$HOME/Documentos org.godotengine.Godot \
  --path . --script tools/foto_inventario.gd

# La zarza antes, con una pasada alta y con una pasada a la raiz
flatpak run --filesystem=$HOME/Documentos org.godotengine.Godot \
  --path . --script tools/foto_pruebas_zarza.gd
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

| campo | tipo | altura base | densidad | radio de siembra | lado de cuadrante |
|---|---|---|---|---|---|
| `Hierba` | cesped | 49 cm | 60 por m2 | 90 m | 24 m |
| `MalezaAlta` | maleza seca | 76 cm | 60 por m2 | 90 m | 12 m |

Las dos alturas bajaron desde la version anterior (69 y 133 cm) porque con la
maleza a 1,33 m tapaba la mitad del encuadre y no se veia donde estabas
cortando. **La suite todavia espera las alturas viejas y por eso da seis
fallos**: son las comprobaciones de "la maleza es mas alta que el cesped y que
el operario" y las de "viene en matas". Es un trabajo de actualizar la suite, no
un fallo de codigo.

La escena actual también agrupa el césped (`formacion = 0,70`); la maleza usa
`formacion = 0,24` y `dureza = 3,3`. Ambos campos se siembran sobre el suelo plano
de pruebas, sin exclusiones por terreno o parcelas. El recuento depende de la
semilla y la formación. El radio de corte **no es propio de estos campos**:
`Desbrozadora.radio_corte` vale 1,0 m y lo comparten césped y maleza. Es el
radio efectivo de la pasada para que alcance suficientes hojas y deje un rastro
visible, no el tamaño geométrico de la cuchilla.

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
