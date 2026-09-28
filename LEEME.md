# Desbrozadora

Simulador de desbrozadora en Godot 4.7. Andas por un huerto, llevas una
desbrozadora y lo que toca, se cae.

Estado: **prototipo jugable del trabajo de desbroce**. Se anda, se corre, se
salta, se mira, se acelera la desbrozadora, suena el motor y se corta hierba. Para
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
| **Raton izq.** | **Acelerar la desbrozadora (y con ella se corta)** |
| `Esc` | Liberar el raton |
| Clic en la ventana | Volver a capturar el raton |

**Para cortar, hay que acelerar.** Con el motor parado el cabezal no corta, y
la hierba solo se dobla si el motor esta a medias. El acelerador es el boton
izquiero, como en una desbrozadora de verdad.

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

Última ejecución registrada antes del ajuste de FOV: **202 correctas, 0 fallos,
1 aviso**. El aviso es que la
comprobacion de imagen no se puede hacer en headless, y se cierra aparte con una
herramienta que va en 3 segundos:

```bash
timeout 300 flatpak run --filesystem=$HOME/Documentos org.godotengine.Godot \
  --path . --script tools/medir_foto.gd --rendering-driver vulkan
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

| campo | tipo | altura base | densidad | radio de corte | lado de cuadrante |
|---|---|---|---|---|---|
| `Hierba` | cesped | 69 cm | 60 por m2 | 1,00 m | 24 m |
| `MalezaAlta` | maleza | 145 cm (hasta ~169 cm) | 18 por m2 | 0,73 m | 12 m |

La escena actual también agrupa el césped (`formacion = 0,70`); la maleza usa
`formacion = 0,78` y `dureza = 1,8`. Ambos campos se siembran sobre el suelo plano
de pruebas, sin exclusiones por terreno o parcelas. El recuento depende de la
semilla y la formación; los radios de corte son distintos.

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
scenes/     las escenas: main, jugador, desbrozadora, hierba, bosque, arbol
scripts/    la logica de cada cosa
shaders/    el de la hierba y el del suelo
tools/      las pruebas y las herramientas de medicion
audio/      el motor
    models/     la desbrozadora, el personaje y modelos auxiliares
    assets/     recursos auxiliares
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
