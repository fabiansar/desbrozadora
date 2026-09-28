# Revision del proyecto

Analisis del estado del proyecto tal y como esta ahora, con lo que esta bien,
lo que esta raro y lo que falta. Para decidir el siguiente paso.

Ultima revision: base jugable de desbroce y entorno procedural integrada; la
integración visual de la aldea sigue pendiente. La última suite ejecutada antes
de los cambios de FOV e interacción dio **202 correctas / 0 fallos**, con un aviso esperado por la
imagen. Con la configuración y el encuadre actuales, la medición Vulkan registra **52,4 %** de
píxeles cambiados al ocultar el césped y **54,7 %** verdes.

La interacción experimental para coger/soltar la desbrozadora con `E` y `Q` se
retiró; la herramienta vuelve a permanecer anclada al arnés.

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
- **La hierba, el viento y el corte están implementados.** La escena actual se
  comprobó con Vulkan; la vegetación cambia el 52,4 % de los píxeles de la captura
  al ocultar `Hierba`.
- El campo va **por cuadrantes**, con culling por caja y por distancia, asi que
  la densidad se puede subir sin que el motor dibuje las hojas enteras.
- **Hay dos tipos de hierba.** `MalezaAlta`, alta y seca, sale en matas con
  claros de verdad entre medias, cuesta mas que el cesped y se corta con la misma
  maquina. Un claro va mas rapido que un zarzal, y se nota.
- **Mirar arriba sube la maquina**, y el cabezal llega a la parte alta de la
  maleza sin salirse del encuadre. Antes no pasaba de 0,35 m.
- **La aldea usa un catalogo modular.** `scripts/aldea.gd` solo calcula parcelas
  y coloca instancias; `assets/models/aldea/` aún no contiene modelos, por lo que
  las ubicaciones actuales son placeholders.
- **El terreno tiene desnivel real.** `Terreno` construye una superficie de
  240 × 240 m con pendiente, ondulación, terrazas y surcos; hierba, bosque y aldea
  consultan la misma función de altura.
- **Mirar arriba funciona con el motor parado.** El acelerador controla la
  bajada de trabajo y el corte, pero no bloquea la elevacion vertical por la
  mirada.
- **El modelo activo de la herramienta es `desbrozadora.glb`.** Su cabezal gira
  sobre Y y la jerarquia `Giro/Corte` esta verificada. La prioridad visual es
  afinar el anclaje ergonomico sobre el primer cuerpo low-poly integrado.
- **Primera iteración del operario integrada.** `personaje_trabajo.glb` mide
  1,98 m y tiene 796 triángulos; torso y parte inferior ya están visibles por
  defecto y los brazos dinámicos siguen los agarres. La pose GoPro requiere
  todavía feedback visual y ajuste de proporciones.
- **Barra extendida para la ergonomía:** 2,06 m de tubo y 2,46 m de largo total;
  `alcance = 1,56 m` e `inclinacion_reposo = -22°`. El motor queda detrás del
  operario, junto a la cadera derecha; `rotation.y` sigue reservado al barrido.
- **FOV horizontal ajustable:** base de 100°, con `ajuste_fov` entre −20° y +20°;
  `main.tscn` lo ajusta actualmente a +20°. Esta última corrección queda para
  probar manualmente.
- **Recorrido integrado de movimiento añadido:** 48 comprobaciones combinan
  paneos, barridos, WASD, correr, agacharse, saltar y acelerar, incluida la
  mirada alta con el motor encendido; última pasada limpia, 0 fallos.

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
pasado. Ahora `dejar_tocon` esta en `true`: 15 cm en el cesped y 30 cm en la
maleza, que es lo que se ve de verdad en cada una.

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

### k) La herramienta de medir la foto que no medi nada

`medir_foto.gd` buscaba el campo de hierba con `get_node("Hierba")` y luego
esperaba un `MultiMeshInstance3D`, pero desde el troceado por cuadrantes el
campo es un `Node3D` que crea sus hijos. La comprobacion de tipo fallaba en
cada fotograma, la foto salia siempre identica, y la herramienta **daba un
numero sin haber comparado nada**.

Es de la misma familia que (a) y (b): el codigoapia lo que era, y al cambiar la
estructura dejo de preguntarselo al motor. **La leccion aqui es que una
herramienta de medicion tambien es codigo que hay que actualizar**, y que si da
un numero sin que se note que ha hecho nada, hay que sospechar de ella.

### l) La cuchilla girando sobre el eje equivocado

El carrete giraba con `giro.rotation.y`, y ese es el eje **a lo largo del tubo**.
La cuchilla va tumbada, con su eje en la vertical, que en el modelo es el Z: la
escena le da al modelo un giro de 180 grados en Y, que no toca el Z. Con el giro
en Y la cuchilla daba vueltas de lado a lado y cortaba de canto.

Lo mas incomodo es que **no se notaba jugando**, y que la suite tampoco lo
cazaba del todo. La prueba de "el carrete gira" comparaba `giro.rotation.y`
antes y despues: como el giro ya no pasaba por ahi, la diferencia era de cero y
la prueba deberia haber fallado siempre. Fallaba, pero a veces el barrido movia
un poco el nodo entre las dos lecturas y la diferencia pasaba de 0,5 rad. O
sea, **una prueba que dependia de si el barrido se habia movido en esa
ventana**.

**La leccion: una prueba que lee un valor tiene que leer el valor que el codigo
escribe.** Aqui las dos leian `.y` y por eso las dos podian volver a ser
verdes sin comprobar nada. Cuando se toca un eje o un canal, hay que mirar los
tres.

### m) Las pruebas que fallaban por el reloj del sistema

`_esperar()` contaba milisegundos con `Time.get_ticks_msec()`. Godot solo
recupera 8 pasos de fisica por fotograma, asi que en un equipo sin GPU, que va a
unos 1 fps, la simulacion se quedaba atrasada, la espera se agotaba antes de
tiempo y las pruebas de movimiento veian al jugador **a medio camino**. En
headless no se notaba, porque ahi no hay tirones, y por eso la suite pasaba
limpia mientras la misma suite con ventana daba 2 o 10 fallos, sin patron.

Ahora `_esperar()` cuenta fotogramas de fisica y de proceso, no de reloj. Es
decir: el fallo era **del banco de pruebas, no del juego**, y se reconocia
porque salian fallos de raton y de velocidad todos a la vez. Cuando varias
pruebas de lo mismo fallan a la vez, casi nunca es que las tres cosas esten
mal.

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

### 4.1 El viento dependia del radio, y la UV se calcula al sembrar  _(resuelto)_

`viento.gd` recalcula `lado_celda = radio * 2 / celdas` leyendo el `radio` de la
hierba, y la hoja calcula su UV **en el momento de sembrarse**. Si se cambia
`radio` en caliente, la UV queda desfasada respecto al mapa. No se nota jugando
porque `radio` no cambia en ejecucion, pero era una trampa: las pruebas de
densidad si cambian la hierba en caliente.

**Resuelto en la fase 2.** `Hierba` guarda aparte el radio con el que estan
escritas las uv (`_radio_uv`), y en `_process()` compara. Si ha cambiado,
reescribe las uv de todas las hojas y vuelve a apuntar `_radio_uv`. Para no
tocar los otros dos canales de `INSTANCE_CUSTOM`, la altura que le queda a la
hoja y su tono se recuperan de los arrays, no del `MultiMesh`.

Lo que se reescribe al cambiar el radio son solo los canales `g` y `b` (la uv); el `r` (altura
restante) y el `a` (tono) van con la hoja, no con el sitio donde se busca su
viento, y no se tocan. Hay pruebas que lo comprueban, contando las hojas
reescritas con `uv_rehechas()`.

> Al escribir las pruebas de esto aparecio un detalle que no estaba previsto:
> `get_instance_custom_data()` **no lee nada util sin GPU delante**. En headless
> devuelve ceros, asi que comprobar el contrato del shader leyendo el `MultiMesh`
> no vale. Lo que se usa es `datos_de_hoja()`, que compone el color en CPU con la
> misma funcion que se manda a la tarjeta. Si alguna vez hay que comprobar algo
> que solo existe en la GPU, esa comprobacion tiene que ir en `medir_foto.gd`,
> no en la suite.

### 4.2 `velocidad_corte()` no sirve todavia para lo que hara falta

Ahora es solo la velocidad de giro del carrete. Cuando el jugador vaya rapido,
el corte tendra que sumar la velocidad del jugador para que el cabezal barra mas
ancho, y ahi habra que rehacerla. Esta anotado en el propio script.

Además, `rpm_efectiva()` calcula la caída de RPM bajo carga, pero el sonido y el
giro visual del carrete todavía siguen las RPM sin carga. La telemetría ya publica
ambas medidas para la futura interfaz; queda decidir cómo la maleza debe afectar
audible y mecánicamente al motor, con feedback de juego.

### 4.3 El estado de la desbrozadora tenía API duplicada  _(resuelto)_

Se eliminaron `get_rpm()` y `get_cortando()`. `rpm` y `cortando` son ahora
propiedades de lectura, con `cortando` derivado del umbral de RPM; el estado
interno se mantiene privado. La señal `telemetria_actualizada` publica RPM libre,
RPM efectiva y resistencia para desacoplar una futura UI.

### 4.4 `ladeo_herramienta` estaba cableado en los dos sentidos  _(resuelto)_

`camara_gopro.gd` lo exponia como `@export` y `desbrozadora.gd` se lo ponia cada
fotograma. Funcionaba, pero era un `@export` que no se debe tocar a mano, y en el
Inspector aparecia como si se pudiera.

**Resuelto en la fase 2.** Ahora es una variable normal, y la maqueta se la
pone. Lo que si se exporta es `tope_ladeo_herramienta`, que si es del jugador.

De paso se arreglo el propio ladeo, que estaba multiplicado por 6
(`rad_to_deg(_barrido * 6.0)`): un barrido de 96 grados se traducía en un ladeo
absurdo. Ahora la ganancia es de 0,07 y hay un tope de 8 grados.

### 4.5 Los valores de la hierba estan en dos sitios, y ademas son dos campos

Los `@export` de `scripts/hierba.gd` son valores por defecto; los que se juegan
son los de las dos instancias de `scenes/main.tscn`. Ahora `Hierba` está a
0,69 m de altura de referencia, 60 hojas/m² y radio 66 m; `MalezaAlta`, a 1,45 m,
18 hojas/m² y radio 50 m. Ambas usan formación en matas, radios de corte
diferentes y tamaños de cuadrante diferentes. La tabla exacta está en
`DOCUMENTACION.md`; hay que mantenerla al cambiar `main.tscn`.

El número total de hojas no se documenta como constante porque también depende
de la semilla y de las exclusiones por aldea. `medir_densidad.gd` lee parámetros
de la escena al arrancar y las pruebas evitan comparar con cantidades fijas.

### 4.6 `capturas/` se genera y no se versiona

Las herramientas de medicion crean la carpeta. Las imagenes generadas
(`paso1_de_pie.png` etc) son de diagnostico, no del juego.

**Nota:** las tres capturas que hay ahora si estan versionadas, porque se
guardaron a mano para comparar. Las que generan las herramientas
(`comparada_con_hierba.png` etc) no deberian subirse. Si la carpeta llega a
ensuciarse, la solucion es un `capturas/*.png` en el `.gitignore` con las
importantes sacadas antes a mano.

### 4.7 Límites de módulos antes de añadir sistemas grandes

- `desbrozadora.gd` conserva juntas la simulación del motor, sonido, carga de
  maleza, barrido, inclinación y colocación. La señal de telemetría ya separa la
  futura UI; antes de sumar combustible/desgaste conviene extraer un componente
  de motor con contrato propio.
- `hierba.gd` mantiene una sola fuente CPU para sembrado, corte y cuadrantes. La
  rejilla de corte y el renderer son buenos límites para separar antes de añadir
  crecimiento, recortes recogibles o nuevos tipos de vegetación.
- `aldea.gd` ya usa registros tipados de parcela y consultas por ID; el catálogo
  visual sigue vacío. Los encargos deberían depender de IDs/estado de parcela,
  no de nodos o nombres de modelos.

## 5. Lo que no esta hecho

- ~~**Tipo 2 de hierba.**~~ **Hecho:** `MalezaAlta` está en `main.tscn`, con
  formación, dureza, colores y configuración propios.
- **Recoger la hierba cortada.** Ahora se aplana y se queda. Acumular los
  recortes seria el siguiente paso natural, y el shader ya calcula `v_corte`,
  asi que el color de lo cortado se podria reaprovechar.
- **Que el jugador enseñe la hierba en las manos.** El modelo no lleva hierba
  encima todavia.
- **Sonido de corte.** Ahora solo suena el motor.
- **Colision con la hierba.** La capa 4 esta reservada pero vacia.
- **Ciclo de dia.** La luz es fija.
- **Modelos de la aldea.** El layout de parcelas está implementado, pero los
  modelos de casas, muros, caminos, árboles y arbustos aún no están en el catálogo;
  por ahora se instancian placeholders.
- **Conducción y furgoneta jugable.** Hay un punto de inicio en la aldea y un
  modelo local excluido del repositorio, pero todavía no hay vehículo en la escena.
- **Telemetría del motor en pantalla.** Hay una medida de RPM efectiva y de
  resistencia, pero aún no existe una interfaz que las presente.

## 6. Estado de los shaders

| Shader | Estado |
| --- | --- |
| `shaders/hierba.gdshader` | correcto. Compila y se ve. Contrato de los 4 canales documentado |
| `shaders/suelo.gdshader` | correcto. Ruido propio porque Godot 4.7 no trae `noise()` |

Los dos compilan limpio. Se verifico a proposito rompiéndolos y mirando que
saliera el error, porque el renderer headless **si** compila los shaders aunque
no dibuje nada.

## 7. Medidas utiles para decidir

Configuración efectiva, leída de `main.tscn` (los defaults de
`scripts/hierba.gd` son distintos):

| Campo | Altura | Densidad | Formación | Radio | Cuadrante | Recorte | Corte |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `Hierba` | 0,69 m | 60/m² | 0,70 | 66 m | 24 m | 80 m | 1,00 m |
| `MalezaAlta` | 1,45 m | 18/m² | 0,78 | 50 m | 12 m | 16 m | 0,73 m |

La maleza tiene dureza 1,8; ambas instancias usan el terreno y la aldea. En la
última siembra se contaron **255.360** hojas de césped y **28.606** de maleza.
La configuración del terreno es 240 × 240 m, pendiente general de 6°, 400
fragmentos de 12 m y malla de 1 m. La aldea es una cuadrícula de 4 × 3 parcelas
de 15 × 12 m.

La medición Vulkan actual registró **8,3 ms de mediana** para el campo base, en
el límite de VSync a 120 fps; por eso no aísla el coste de la hierba. La peor
muestra fue de 8,3 ms para ese campo y hasta 8,6 ms en las configuraciones de
comparación. La medición visual registró 52,4 % de píxeles cambiados al ocultar
el césped y 54,7 % verdes con el encuadre inicial de −40°.

## 8. Propuesta de siguiente paso

Estado del camino inmediato:

1. **Ajustar la vista GoPro con feedback visual.** El cuerpo está visible, pero
   falta calibrar la escala aparente del torso y la lectura separada de las piernas.
2. **Completar la aldea visual.** Crear los modelos que faltan en
   `assets/models/aldea/` y revisarlos en el juego.
3. **Revisar maleza y carga del motor.** La interfaz futura debe mostrar telemetría
   desacoplada (`telemetria_actualizada`), incluida la RPM bajo carga.
4. **Integrar la furgoneta y conducción básica.** Hay punto de inicio y modelo,
   pero vehículo, controles y navegación siguen pendientes.
5. **Continuar el bucle de trabajo:** recoger hierba cortada, añadir sonido de
   corte y conectar la pendiente del terreno con la resistencia de la máquina.
6. **Después:** discos intercambiables, combustible, desgaste/afilado y encargos.

Ojo con una cosa al tocar la hierba: la suite **con ventana** necesita el juego
cerrado, y sin ventana (headless) no se ve nada de lo visual. Con la GPU por
software de esta maquina, ademas, la suite con ventana tarda doce minutos, asi
que para lo visual lo indicado es `tools/medir_foto.gd`, que va en 3 segundos.
