# Revision del proyecto

Analisis del estado del proyecto tal y como esta ahora, con lo que esta bien,
lo que esta raro y lo que falta. Para decidir el siguiente paso.

Ultima revision: con la hierba alta (88 cm), los cuadrantes puestos y la camara
encuadrando el cabezal. Suite en **131 correctas / 0 fallos** en headless y
**133 / 0** con GPU.

Lo que se puede jugar hoy esta en [LEEME.md](LEEME.md), el detalle por archivo en
[DOCUMENTACION.md](DOCUMENTACION.md) y la hoja de ruta en
[DISENO.md](DISENO.md).

---

## 1. Que funciona

- Se anda, se corre, se salta, se agacha y se mira.
- **El cabezal no se pierde de vista nunca.** Es lo que faltaba para poder
  cortar zarza alta, y va con topes de inclinacion asimetricos y encuadre
  automatico. La prueba lo recorre entero.
- **La tecla `S` anda hacia atras sin girar el mundo 180 grados.** La camara
  mide su giro en el mundo y le resta el del cuerpo.
- La desbrozadora cuelga de las caderas, acelera con curva, suena el motor con
  el tono y el volumen correctos, y el cabezal baja al acelerar.
- Hay bosque con colision, y suelo de tierra procedural que se ve bien.
- **La hierba se ve, el viento la dobla por zonas, y se corta donde pasas.**
  Verificado con render real, no solo con tests.
- El campo va **por cuadrantes**, con culling por caja y por distancia, asi que
  la densidad se puede subir sin que el motor dibuje las hojas enteras.

## 2. Los bugs que se han resuelto, y que conviene no repetir

Los importantes eran casi todos **el mismo tipo de bug**: una contradiccion
entre lo que dice el codigo y lo que hace el motor. Se listan porque son la
clase de error que mas tiempo ha costado en este proyecto.

### a) `instance_count` asignado dos veces

La siembra asignaba el recuento, lo llenaba, y volvia a asignar el mismo
recuento al final. La segunda asignacion **crea el buffer de cero**, asi que
`get_instance_count()` decia 43.592 y no habia ni una hoja en la GPU. Con el
renderer headless no se veia porque ese renderer no dibuja MultiMesh de todas
formas; con Vulkan salio a la primera.

### b) La hoja de 8 vertices sin indices

`SurfaceTool` en `PRIMITIVE_TRIANGLES` con 8 vertices lanzaba:

```
ERROR: Vertex amount (8) must be a multiple of the amount of vertices required
by the render primitive (3).
at: draw_list_draw (servers/rendering/rendering_device.cpp:6149)
```

Una malla en modo triangulos **no** acepta un numero de vertices que no sea
multiplo de 3. Ahora hay 8 vertices y un array de indices explicito de 18
elementos (6 triangulos). Hay una prueba que lo comprueba, porque el renderer
headless **tampoco dibuja** y no lo habia pillado.

### c) El signo invertido de `INSTANCE_CUSTOM.x` — el grave

El canal `x` guarda **cuanto le queda** de altura. El shader lo leia como
**cuanto se ha cortado**, y hacia `enpie = 1.0 - corte`. Resultado: **la hierba
de pie salia tumbada y la cortada salia de pie**. Por eso la hierba solo se
veia donde habias pasado la maquina, que era exactamente la pista que dio el
usuario.

La leccion: **el contrato de los canales de `INSTANCE_CUSTOM` esta documentado
en `DOCUMENTACION.md` y en el propio shader, y no se cambia de la cabeza.**

### d) La proyeccion del viento multiplicada por 22

El empuje del viento se pasaba a coordenadas de hoja dividiendo por la longitud
del eje de la instancia, que es el **grosor**. Eso multiplicaba el empuje por
1/0.045 ≈ 22 y las hojas salian despedidas varios metros. Se veia el caso raro:
la hierba cortada si se veia, porque tumbada `curva = 0` y no hay empuje. Se ha
reescrito para que el empuje vaya en proporcion de la altura de la hoja, que no
necesita la matriz de la instancia.

### e) El motor se callaba a los 2 segundos

El WAV del motor dura 2,0 s y venia importado **sin bucle**
(`edit/loop_mode=0`). El codigo hacia `play()` una vez y se ponia una bandera
propia (`_sonando = true`) para no volver a llamar. Al acabarse los 2 segundos
de sample, el motor se quedaba **muto para siempre**, y como la bandera decia
que seguia sonando, nadie lo rearrancaba.

Arreglado por dos lados: el import ahora es `loop_mode=2` (hacia adelante), y
ademas `_asegurar_bucle()` lo deja puesto en memoria aunque alguien vuelva a
importar el WAV sin bucle. Lo segundo que se cambio es usar
`motor_sonido.playing` en vez de la bandera propia, para que si el sonido se
para por lo que sea se rearranque solo.

Detalle que costó: el numero de frames del bucle **no** sale de `data.size()`,
porque el WAV se importa comprimido y los bytes no son frames. Sale de
`get_length() * mix_rate`. Con `data.size()` el bucle se comia 0,81 s de los 2 s.

### f) `dejar_tocon = false` hacia el corte invisible

Con el tocón apagado, la hierba cortada queda a 0 cm, tumbada en el suelo, y
**desde la camara no se ve nada**: no habia ni rastro de por donde habias
pasado. Ahora `dejar_tocon` esta en `true` con 8 cm de tocón.

### g) Una llamada a una funcion que no existe

Una prueba llamaba a `_cuadranes_de_la_hierba()` (con **t** en *hierba*) cuando
la funcion se llamaba `_cuadranes_de_la_herba()` (con **r**). Daba
`Function "..." not found in base self` y hacia fallar la suite entera.

No era un fallo grave, pero es el mismo tipo de despiste que el resto: el
nombre estaba escrito a mano en dos sitios y se separaron. La ortografia
correcta es `_cuadrantes`, y ahora es igual en el codigo, en la suite y en los
documentos. **Aviso: `hierba` y `herba` se parecen mucho y `cuadrante` tambien.**

### h) El cabezal fuera de la foto, "a proposito"

La documentacion decia, tranquilamente, que el cabezal estaba fuera del frustum
"a proposito: es lo que se ve en una desbrozadora real". Cuando se subio la
hierba a 88 cm para cortar zarza resulto que **no se veia donde cortabas**, y
habia que apuntar con el raton hacia abajo solo para no perderlo de vista.

El angular es de 100 grados, el cabezal va 47 grados por debajo del horizonte,
y en 16:9 solo entran 34 grados por debajo del eje. Los numeros no cuadran, y
no era cuestion de opinion.

Arreglado por dos partes, y las dos hacen falta:

1. `_pitch_limitado()` recorta la inclinacion para que el cabezal no se salga.
   El jugador puede mirar hasta 55 grados hacia arriba y la camara se baja sola.
2. Los topes de inclinacion del jugador son **asimetricos**: 85 grados hacia
   abajo y 55 hacia arriba.

Ojo con el signo al retocar `_limitar_pitch()`: el pitch es **negativo mirando
abajo**. Una version restaba los dos topes y el clamp salia al reves; la suite
lo coge.

### i) La camara arrastrada por el cuerpo, y el tiron de 180 grados con `S`

La camara cuelga de `Cabeza`, que cuelga del **cuerpo**, y el cuerpo se vuelve
hacia donde caminas. La camara tomaba como rotacion local el retardo de la
mirada, asi que el giro del cuerpo se le sumaba entero: con `S` el cuerpo se
daba media vuelta y la camara con el, y el mundo daba un tiron de 180 grados.

Ahora `_colocar()` le resta el giro del cuerpo y la guiñada de la camara en el
mundo es siempre la mirada. Con `S` se mide 0,4 grados de giro.

### j) La prueba que se rompia sola al cambiar un valor del Inspector

La prueba del ancho de corte comparaba `hierba.radio_corte` con un `0.40`
escrito a mano. Al subir la hierba en el Inspector el cabezal paso a 0,54 y la
prueba fallo **sin que el corte hubiera cambiado nada**. Una prueba que compara
un valor con un literal no comprueba comportamiento: comprueba que nadie haya
tocado el Inspector.

Ahora mide contra el valor de la propia escena, y comprueba que dentro del
ancho del cabezal no queda ni una hoja de pie. Igual con `medir_densidad.gd`,
que antes tenia la configuracion en su lista y se quedo vieja; ahora la lee al
arrancar.

## 3. La limitacion de las pruebas, que hay que tener presente

**El renderer headless de Godot descarta los transforms y los datos de instancia
del MultiMesh.** En headless, `diag_hierba.gd` da AABB de cero y transform
identidad para todas las hojas, aunque la escena este perfecta.

Consecuencias:

- La suite **no puede** comprobar nada visual. Comprueba los arrays de la
  logica, que es lo que se puede comprobar.
- El aviso de "falta la comprobacion de imagen" es esperado y no es un fallo.
- Cualquier cambio en el shader o en la siembra **hay que mirarlo con
  `--rendering-driver vulkan`**, no con la suite.

> Esto cambio un poco con los cuadrantes: cada cuadrante lleva su `custom_aabb`,
> y eso **si** se comprueba en headless, porque lo calcula GDScript. Lo que sigue
> sin poder comprobarse en headless es si la hoja sale dibujada.

**Y al reves de lo que se espera:** la suite **con ventana** (Vulkan) no se
puede lanzar con el juego abierto. Godot se queda con el foco y la entrada, y
salen fallos de pruebas de raton y de movimiento que no son del codigo. Se
reconoce porque salen todos a la vez. Se comprueba con `pgrep -af godot`: si sale
`project.godot` en vez de `tools/test_juego.gd`, hay un juego abierto.

## 4. Debilidades del codigo, por orden de importancia

### 4.1 El viento depende del radio, y la UV se calcula al sembrar

`viento.gd` recalcula `lado_celda = radio * 2 / celdas` leyendo el `radio` de
la hierba, y la hoja calcula su UV **en el momento de sembrarse**. Si se cambia
`radio` en caliente, la UV queda desfasada respecto al mapa. No se nota jugando
porque `radio` no cambia en ejecucion, pero es una trampa: las pruebas de
densidad si cambian la hierba en caliente.

**Sigue pendiente.** Es un cambio pequeño, pero importante antes de tocar el
viento otra vez.

### 4.2 `velocidad_corte()` no sirve todavia para lo que hara falta

Ahora es solo la velocidad de giro del carrete. Cuando el jugador vaya rapido,
el corte tendra que sumar la velocidad del jugador para que el cabezal barra mas
ancho, y ahi habra que rehacerla. Esta anotado en el propio script.

### 4.3 El estado de la desbrozadora se lee con `get_` y con `var` a la vez

Hay `get_rpm()` / `get_cortando()` y ademas `var rpm` / `var cortando`
publicos. Son la misma cosa por dos caminos. No es un bug, pero invita a
cambiar uno y no el otro.

### 4.4 `ladeo_herramienta` esta cableado en los dos sentidos

`camara_gopro.gd` lo expone como `@export` y `desbrozadora.gd` se lo pone cada
fotograma. Funciona, pero es un `@export` que no se debe tocar a mano, y en el
Inspector aparece como si se pudiera.

### 4.5 Los valores de la hierba estan en dos sitios

Los `@export` de `scripts/hierba.gd` (0,38 m de alto, 30/m2) **no** son los que
se juegan: `scenes/main.tscn` los sobrescribe (0,88 m, 53/m2). Es lo correcto
para explorar, pero hace que los valores por defecto y los reales divergan, y
que cualquier cifra escrita en un documento se pueda quedar vieja. Esta
documentado en `DOCUMENTACION.md`, se ha atualizado `medir_densidad.gd` para que
lea los de la escena, y las pruebas evitan literales. Sigue siendo la fuente de
errores mas probable del proyecto.

### 4.6 `capturas/` se genera y no se versiona

Las herramientas de medicion crean la carpeta. Las imagenes generadas
(`paso1_de_pie.png` etc) son de diagnostico, no del juego.

## 5. Lo que no esta hecho

- **Tipo 2 de hierba.** El campo `tipo` ya existe en `scripts/hierba.gd` y vale
  1, pero no hay segundo tipo. Cuando se haga, la estructura ya esta: mismo
  nodo, mismos cuadrantes, otro `material_override` y otra semilla.
- **Recoger la hierba cortada.** Ahora se aplana y se queda. Acumular los
  recortes seria el siguiente paso natural, y el shader ya calcula `v_corte`,
  asi que el color de lo cortado se podria reaprovechar.
- **Que el jugador enseñe la hierba en las manos.** El modelo no lleva hierba
  encima todavia.
- **Sonido de corte.** Ahora solo suena el motor.
- **Colision con la hierba.** La capa 4 esta reservada pero vacia.
- **Ciclo de dia.** La luz es fija.

## 6. Estado de los shaders

| Shader | Estado |
| --- | --- |
| `shaders/hierba.gdshader` | correcto. Compila y se ve. Contrato de los 4 canales documentado |
| `shaders/suelo.gdshader` | correcto. Ruido propio porque Godot 4.7 no trae `noise()` |

Los dos compilan limpio. Se verifico a proposito rompiéndolos y mirando que
saliera el error, porque el renderer headless **si** compila los shaders aunque
no dibuje nada.

## 7. Medidas utiles para decidir

Configuracion real del juego, sacada de `main.tscn` (**no** de los valores por
defecto del script, que son otros):

- **192.454 hojas** = 1.154.724 triangulos, en **71 cuadrantes** de 8 m.
- 53 hojas/m2, 88 cm de alto, 0,145 m de grosor, en 34 m de radio.
- Recorte por distancia a 22 m, y con culling por caja de cada cuadrante.
- Mediana de **8,3 ms** (tope de vsync a 120 fps) y **8,3 ms** en el peor
  fotograma. El campo va sobrado.
- Campo de pie: **35,3 %** del frame. Cortado: **3,8 %**. Sin hierba: 0 %.

> **Ojo con el metrico "ocupa el X %":** sale a veces 18,9 % y a veces 75,2 %
> con la misma semilla, porque la captura coge el fotograma a medio renderizar.
> El metrico fiable es el de **verde**, que se repite igual en todas las
> pasadas.

Subiendo densidad y bajando radio, para tener hojas parecidas y ver donde se
rompe: 100/m2 en 20 m son 125.664 hojas y sigue a 8,3 ms; 160/m2 en 20 m son
201.067 y tambien. **Aun hay margen para subir la densidad.**

## 8. Propuesta de siguiente paso

**El tipo 2 de hierba.** Es lo que mas trabajo da ahora mismo y lo que mas
engana al jugador, porque con un solo tipo el campo es una alfombra uniforme. El
sitio esta preparado: mismo nodo, mismos cuadrantes, `material_override` distinto
y otra semilla.

Y antes, dos cosas que no son juego pero evitan perder tiempo luego:

1. Que el cambio de `radio` recalcule las UV de la hierba (punto 4.1).
2. Dejar de exponer `ladeo_herramienta` como `@export` si nadie lo va a tocar a
   mano (punto 4.4).

Ojo con una cosa al tocar la hierba: la suite **con ventana** necesita el juego
cerrado, y sin ventana (headless) no se ve nada de lo visual. Las dos cosas juntas
hacen que "lo he tocado y se ve bien" exija un poco de cuidado.
