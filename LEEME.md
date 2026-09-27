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
timeout 300 flatpak run --filesystem=$HOME/Documentos org.godotengine.Godot \
  --headless --path . --script tools/test_juego.gd
```

Acabo de salir: **131 correctas, 0 fallos, 1 aviso**. El aviso es que la
comprobacion de imagen no se puede hacer en headless, y se hace aparte con
render de verdad. Con la GPU si se hace, y entonces salen **133 correctas, 0
fallos, 0 avisos**:

```bash
timeout 300 flatpak run --filesystem=$HOME/Documentos org.godotengine.Godot \
  --path . --script tools/test_juego.gd --rendering-driver vulkan
```

> **Cierra el juego antes de lanzar la prueba con ventana.** Godot se queda con
> el teclado y el raton, y si hay otro Godot abierto la suite no los recibe:
> salen fallos de pruebas de raton y de movimiento que no son del codigo, y se
> ven todos a la vez. Se comprueba con `pgrep -af godot`: si sale `project.godot`
> en vez de `tools/test_juego.gd`, hay un juego abierto. La de headless no tiene
> ese problema y se puede repetir cuando quieras.

### Como esta repartida la hierba

El campo no es un solo MultiMesh, sino **71 cuadrados de 8 m**, cada uno con el
suyo. Un unico MultiMesh de 68 m tiene una caja tan grande que siempre se solapa
con la pantalla, se mire donde se mire, asi que el motor no descartaba nada y
dibujaba las hojas enteras en cada fotograma. Con los cuadrados, cada uno lleva
su caja ajustada y ademas se apagan los que estan lejos de la camara.

Son **192.454 hojas** de 88 cm en 34 m de radio, y van a 120 fps. Esto lo
comprueban las pruebas: que al repartir no se pierda ninguna hoja, que ningun
cuadrante salga vacio, que las cajas sean manejables y que el recorte por
distancia encienda y se apague.

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

Cambios pequenos, uno cada vez. Cada implementacion la prueba la persona que
lleva el proyecto ejecutando el juego y contando que ve, y el siguiente cambio
sale de ese feedback. No se meteran varias cosas en el mismo paso.
