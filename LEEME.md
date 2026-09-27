# Desbrozadora

Simulador de desbrozadora en Godot 4.7. Andas por un huerto, llevas una
desbrozadora y lo que toca, se cae.

Estado: **jugable de punta a punta**. Se anda, se corre, se salta, se mira, se
acelera la desbrozadora, suena el motor, hay bosque, hay suelo de tierra y hay
hierba que se dobla con el viento y que se corta donde pasas.

## Como se juega

| Tecla | Que hace |
| --- | --- |
| `W` `A` `S` `D` | Andar |
| `Shift` | Correr |
| `Espacio` | Saltar |
| `Ctrl` / `C` | Agacharse |
| Raton | Mirar |
| **Raton izq.** | **Acelerar la desbrozadora (y con ella se corta)** |
| Raton der. | Capturar / soltar el raton |
| `R` | Reiniciar la prueba |

**Para cortar, hay que acelerar.** Con el motor parado el cabezal no corta, y
la hierba solo se dobla si el motor esta a medias. El acelerador es el boton
izquiero, como en una desbrozadora de verdad.

### La camara nunca pierde el cabezal

La camara se descuelga de la cabeza del jugador por un angulo fijo, asi que el
cabezal, que va 1,27 m por debajo y 1,18 m por delante, queda unos 47 grados por
debajo del horizonte. Con el angular de 100 grados solo entran 34 grados por
debajo del eje, de modo que mirando recto, y mas todavia mirando arriba, la
herramienta se salia de la foto. Y no puede pasar: se van a cortar zarza alta y
hay que ver donde corta la hoja **siempre**.

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

Acabo de salir: **183 correctas, 0 fallos, 1 aviso**. El aviso es que la
comprobacion de imagen no se puede hacer en headless, y se cierra aparte con una
herramienta que va en 3 segundos:

```bash
timeout 300 flatpak run --filesystem=$HOME/Documentos org.godotengine.Godot \
  --path . --script tools/medir_foto.gd --rendering-driver vulkan
```

Esa mide si la hierba se dibuja de verdad, y ahora mismo da **93,9 % de pixeles
cambiados al ocultarla** y un 76,3 % de pixeles verdes. Sale en `capturas/`.

> **No repitas la suite entera con ventana.** Se puede, pero con la GPU por
> software de esta maquina va a un fps y la suite tarda doce minutos. Para
> comprobar la imagen basta con `medir_foto.gd`, que hace justo eso y nada mas.
> Si aun asi la repites, **cierra antes el juego**: Godot se queda con el
> teclado y el raton, y si hay otro Godot abierto la suite no los recibe y salen
> fallos de pruebas de raton que no son del codigo. Se comprueba con
> `pgrep -af godot`: si sale `project.godot` en vez de `tools/test_juego.gd`, hay
> un juego abierto. La de headless no tiene ese problema.

### Como esta repartida la hierba

El campo no es un solo MultiMesh, sino **cuadrados de 8 m**, cada uno con el
suyo. Un unico MultiMesh de 100 m tiene una caja tan grande que siempre se solapa
con la pantalla, se mire donde se mire, asi que el motor no descartaba nada y
dibujaba las hojas enteras en cada fotograma. Con los cuadrados, cada uno lleva
su caja ajustada y ademas se apagan los que estan lejos de la camara.

Hay **dos campos**, cada uno con su semilla y su material:

| campo | tipo | alto | densidad | corte | en |
|---|---|---|---|---|---|
| `Hierba` | cesped | 71 cm | 60 por m2 | 0,73 m | 146 cuadrados de 8 m |
| `MalezaAlta` | maleza | 145 cm | 18 por m2 | 0,73 m | 62 cuadrados de 12 m |

El cesped da **471.239 hojas** y la maleza **31.162**. La maleza sale en **matas**
y no como una alfombra: con `formacion = 0,78` solo se siembra el 34 % del
terreno, asi que se ven claros de verdad por los que se pasa sin cortarse nada.
Se corta con la misma maquina y el mismo radio que el cesped, que es la condicion
para que no se note como otra herramienta.

Esto lo comprueban las pruebas: que al repartir no se pierda ninguna hoja, que
ningun cuadrante salga vacio, que las cajas sean manejables, que el recorte por
distancia encienda y se apague, que los dos campos esten sembrados y que
caminando por encima se corten los dos.

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
models/     la desbrozadora
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
