# Revision del proyecto

Analisis del estado del proyecto tal y como esta ahora, con lo que esta bien,
lo que esta raro y lo que falta. Para decidir el siguiente paso.

Ultima revision: **version `v0.1.0`**, con el inventario de nueve herramientas y
la zarza con raiz. El terreno procedural y el layout de la aldea siguen
retirados mientras se prepara un mapa manual; el plugin para esculpirlo desde el
editor aún no está elegido.

Estado de las pruebas (las siete que se ejecutan sin abrir nada):

| Prueba | Resultado |
| --- | --- |
| `tools/test_juego.gd` (suite principal) | **207 correctas, 0 fallos, 1 aviso** |
| `tools/test_movimiento_integrado.gd` | 82/82 |
| `tools/test_cabezales.gd` | 28/28 |
| `tools/test_estacion_cabezal.gd` | OK |
| `tools/test_vegetacion_tier3.gd` | OK |
| `tools/test_corte_organico.gd` | OK |
| `tools/test_inventario.gd` | OK |
| `tools/test_origen_restos.gd` | OK (enumera, no comprueba) |

**Todo en verde.** Mas medidores y miradores, que no son tests y no se ejecutan en
la bateria: `medir_cabezales.gd`, `medir_densidad.gd`, `medir_foto.gd`,
`ver_encuadre.gd`, `ver_restos.gd`.

Lo que **ninguna** prueba mide, y es a proposito: el aspecto. Ni el del corte ni el
de los restos. Se juzga a ojo, y a cuatro metros un trozo de 10 cm son unos
pixeles. Para el de los restos esta `ver_restos.gd`, que los pone a 40 cm.

### Lo que dejo escrito para que no se repita

1. **Una prueba que mide un ratio contra una media que tu has cambiado no mide lo
   que dice medir.** El empujon del escombro se comprobaba con "la distancia media
   crecio un 20 %". Al abrir la salida de los restos, la media de partida subio y
   el ratio se encogio **sin que el empujon cambiase**.

   Aparece en **dos** pruebas, y en una se corrigio la primera vez y se
  olvido en la otra. La leccion: el ratio mola, pero miente en cuanto cambias la
   distribucion de partida. Ahora las
   dos piden **6 cm en absoluto**, que es lo que el ratio viejo codificaba.

   Y en `test_vegetacion_tier3.gd` el fallo era **intermitente**: una de cada dos.
   Medido seis veces seguidas, el escombro se aparta 0,35->0,46, 0,33->0,44,
   0,62->0,74, 0,62->0,73, 0,45->0,56 y 0,52->0,64. **Once centimetros en las
   seis**, exactamente igual; lo unico que variaba era la linea base, de 0,33 a
   0,62 segun que trozos se reciclan. Un test que falla una de cada dos sin motivo
   es peor que uno que falla siempre, porque entrena a ignorarlo.

   **La regla: antes de relajar una comprobacion que falla, mide que la cosa que
   mide no ha cambiado. Y si falla intermitente, ejecuta seis veces y mira los
   numeros, no una.**
2. **Un `MultiMesh` en headless no guarda los datos.** `get_instance_transform`
   devuelve la identidad siempre, en cualquier forma de escribirlo, porque no hay
   servidor de render. Diagnosticar con el da numeros inventados, y se dio por
   bueno un diagnostico entero de "48 cubos de un metro en el origen del mundo" que
   era mentira. Lo que si se puede leer en headless es el **numero de celdas del
   gestor**, no el `MultiMesh`.
3. **Un parametro llamado `disponibles` hacia fallar el script entero.** Al sacar
   la estacion del cabezal, `configurar(disposibles: Array[CabezalDesbrozadora])`
   daba `Identifier "disponibles" not declared in the current scope` en la linea
   de despues, y **todo lo que dependia de el dejaba de compilar**: 33 fallos en
   la suite principal que no tenian nada que ver con el cabezal. El fichero
   estaba limpio, los bytes eran ASCII y el `.uid` no estaba duplicado.
   **El error de GDScript no esta necesariamente donde dice que esta**: el mensaje
   senalaba el cuerpo de la funcion y el problema era la firma. Se arreglo cambiando
   el nombre a `lista`, que ademas se lee mejor.
4. **Acumula los restos, no los mires de lejos.** Con la maquina quieta encima,
   `pisar()` se come el material que ella misma crea y no se ve nada. Hay que
   **cortar avanzando**, y las pruebas de integración lo hacen.

## 0. Lo nuevo desde la revision anterior

### La zarza deja de ser un sistema propio: es el tier 3 de la misma hoja

**Se han borrado 888 lineas y 10 ficheros**: `scripts/zarza.gd` (celdas, coronas,
raices, enredo e inundacion), `scenes/zarza.tscn`, `scenes/capas_zarza.tscn`,
`scenes/pruebas_zarza.tscn`, `scripts/overlay_prueba_zarza.gd` y siete pruebas y
utilidades. Ahora la zarza es un preset mas de la misma hoja:

    scenes/vegetacion/hierba.tscn      la base, con TODOS los exports
    scenes/vegetacion/cesped.tscn      tier 1
    scenes/vegetacion/maleza_alta.tscn tier 2
    scenes/vegetacion/zarza.tscn       tier 3

Un script, tres presets con nombre, y `main.tscn` instancia tres nodos sin
bloques de quince lineas de numeros. La "otra skin" son color, grosor y tres
numeros de forma de hoja que se han expuesto para esto: `hoja_estrecha`,
`hoja_curva` y `hoja_tuerce`. El cesped se estrecha un 0,88 (brizna), la maleza
un 0,60 y la zarza un 0,30, que es lo que hace que arriba siga siendo hoja en vez
de un pelo. **Cero codigo para una planta que no sea para las tres.**

**Lo que se pierde, y hay que decirlo claro:** la mecanica de raiz. Antes habia
que cortar la copa, bajar a la base y arrancar la raiz, y las cañas se sostenian
unas a otras. Ahora el corte es un **disco en el suelo** (`_dist2` mira solo x y z)
y una hoja cortada ya no se vuelve a cortar, asi que **una pasada y punto**. La
dificultad del tier 3 esta en el coste, no en el numero de pasadas: el motor se
ahoga, el hilo se gasta mas rapido y la gasolina sube. Si la mecanica de capas
importaba, hay que decidir si se recupera o se acepta que no.

#### Las cuatro cosas que habian quedado fuera de escala

Las reporto como salio, porque las cuatro son el mismo error de fondo y las
cuatro se habrian haber visto antes:

1. **La zarza media 2,4 m y el morro llega a 2,31 m.** No se podia cortar. Medido
   en `test_vegetacion_tier3.gd`, que **mide el alcance con la maquina de verdad**
   en vez de escribir un numero, y compara la hoja mas alta real de cada mata (la
   del preset por `1 + variacion/2`, que es mas alta que la del preset).
2. **El peso del cuerpo se media con las vueltas del motor.** Con la carga alta
   el motor bajaba de vueltas, `_trabajando` caia, y la maquina **se erguida
   sola**: cuanto mas trabajo habia, mas alto se quedaba el morro. Al reves. Lo
   que echa el peso del cuerpo eres tu pulsando el acelerador, asi que ahora hay
   `_apoyado`, que va con el acelerador. `_trabajando` se queda para el sonido.
3. **La zarza iba a 60 caños por metro cuadrado.** Con 2,4 m de alto eso pesa
   once veces mas que la maleza, y con el divisor de carga la carga se iba a
   1,00 **topsada con cualquier cabezal**: en la zarza daba igual el cabezal. Con
   20 caños gruesos la cosa es un matorral de verdad y el juego entre
   cabezales se vuelve a ver (0,92 con la cuchilla, 0,17 con el disco de tres
   puntas).
4. **`formacion` esta al reves de lo que parece.** Es la parte de terreno que se
   deja BARE, no la que se planta: con 0,90 se siembra el 7 % y sale un ralo. La
   zarza va en 0,12, que es lo contrario de lo que habia puesto al principio.

### La logica de los cabezales cambia de fondo

Los cabezales ya no son "una lista de lo que pueden cortar" con un
multiplicador de desgaste. Ahora cada cabezal tiene, **contra cada tipo de
vegetacion**, dos numeros de 1 a 5:

- **eficacia**: lo rapido que lo corta. Es un presupuesto por fotograma, no un
  rayon instantaneo.
- **resistencia**: lo que la planta le hace a el. Come filo **y** frena el
  motor, con la misma cifra.

| cabezal | nivel | ef. hier/male/zar | res. hier/male/zar |
| --- | :-: | --- | --- |
| Hilo de nylon | 1 | 5 / 2 / 1 | 1 / 3 / 5 |
| Cuchilla de serie | 2 | 3 / 3 / 3 | 1 / 2 / 3 |
| Disco de dos puntas | 2 | 3 / 4 / 2 | 1 / 2 / 3 |
| Disco de tres puntas | 3 | 1 / 5 / 4 | 1 / 1 / 2 |

Solo los numeros del nylon los dio el usuario; los demas se deducen por
escalones de tier, con la regla de que **subir de nivel no es mejor en todo**:
cada peldaño aguanta mas y abre mas la maleza y la zarza, y paga con velocidad
en la hierba. El disco de tres puntas es el mejor cabezal del juego contra la
maleza y el peor contra el cesped, y es a proposito: elegir cabezal es elegir
trabajo.

Lo que se borro, y por que:

- **`tipos_compatibles` de los cabezales.** Decir que el nylon "no puede" con la
  maleza era mentira: el nylon la abre de pena. Ahora todo cortador corta de
  todo y `puede_cortar(tipo)` devuelve true siempre, y la pregunta util es cuanta
  eficacia y cuanta resistencia hay. Un campo menos que se puede contradecir
  con los numeros. El de la **hoz** se queda, que esa si tiene limites de verdad.
- **`multiplicador_desgaste`**, que era un numero suelto por cabezal. Lo
  sustituye la resistencia contra esa planta, que tiene sentido como 0 a 5
  porque se puede sumar con la de los demas y se ve quien aguanta mas.
- **El parametro `dureza_vegetacion` de `registrar_corte`.** El desgaste sale
  ahora del choque entre planta y cabezal, no de la planta sola.

Cuatro cosas que hay que tener en cuenta al tocar esto:

1. **La parte decimal del presupuesto.** Un cabezal de 100 celdas por segundo
   son 1,67 por fotograma. Sin guardar la parte decimal entre fotogramas se
   corta una celda cada dos y el cabezal va a la mitad de velocidad de lo que
   dice su numero, sin que se note por donde. `_presupuesto_fraccion` en
   `hierba.gd` lo evita, y `test_cabezales.gd` lo comprueba: con 1,00 celdas por
   fotograma la pasada tarda 50 fotogramas, con 1,67 tarda 31.
2. **Por donde empieza a morder rota en cada fotograma.** Con presupuesto, si el
   barrido empezara siempre por la misma esquina, el claro se abriria como una
   esquina cuadrada y se veria que el cabezal va por orden.
3. **En la zarza el presupuesto no es el total.** Al cortar una rama cae todo lo
   que se colgaba de ella, y eso no es el cabezal cortando mas rapido: es la
   zarza perdiendo el apoyo. Por eso un corte puede quitar mas celdas de las
   pedidas, y por eso el nylon tarda mas en tirar la mata abajo aunque arranque
   el doble de ramas. Si alguna vez se queja de que el presupuesto no se
   respeta, hay que mirar `_recalcular_apoyo` antes que el limite.
4. **La carga del motor** se multiplica por `frenado_para(tipo)`, la misma
   resistencia. Con la cuchilla de serie en la maleza el coste de motor cae al
   40 % de lo que era, porque el motor ya no pelea contra cada hoja. Es lo
   pedido, pero **el frenao se nota menos que antes** y hay que verlo jugando.

### Las tres escalas estaban mal, y no se notaba nada

Con la tabla puesta, el usuario lo probó y dijo lo mas honesto que se puede
decir: **"no veo frenado ni desgaste ni nada, todo corta mucho"**. Tenia razon,
y la causa no era la logica sino que **los tres numeros estaban en una escala
que no se nota**. Medido con `tools/medir_cabezales.gd` (nuevo, no es un test):

| | antes | despues | por que |
| --- | --- | --- | --- |
| base de corte del cesped | 200 hojas/s | 50 | 200 era mas rapido que andar |
| base de corte de la zarza | 60 celdas/s | 30 | base de corte de la zarza | 60 celdas/s | 30 | las celdas de tallo pesan mas | |
| desgaste por hoja | 0,000001 | 0,00005 | era 0,0000 por segundo |
| `densidad_corte` (carga) | 110 | 75 | la carga no pasaba de 0,65 |

La del corte es la que mas cuesta entender y la mas importante. La base de 200
hojas/s se eligio sin mirar contra que se compara, y **andar a 2 m/s con un
cabezal de 0,78 m pisa unas 150 hojas por segundo**. O sea que con la base en 200,
incluso la eficacia 1 iba sobrada: los cuatro cabezales vaciaban el disco en
siete fotogramas y se sentian exactamente igual. **La base tiene que estar por
debajo de lo que pisas andando**, y ahi es donde la eficacia empieza a decidir
algo. Con 50:

- eficacia 1 (tres puntas) = 50/s: no llegas, dejas reguero
- eficacia 3 (serie, dos puntas) = 150/s: justito
- eficacia 5 (nylon) = 250/s: vas por delante de tus pies

**El desgaste** era literalmente invisible: 0,000001 por hoja daba 0,0000 por
segundo, que es 0 en la barra del FILO. Con 0,00005 se gasta entre el 0,1 % y el
0,6 % por segundo segun cabezal y planta, o sea un cabezal dura entre 3 y 17
minutos. Ojo a un efecto raro que sale del modelo y que **es correcto**: el
desgaste por segundo sale parecido para todos los cabezales (0,002-0,006), porque
el mas rapido corta mas y por eso se desgasta mas por segundo. Lo que cambia de
verdad es el desgaste **por trabajo**: cortar una mata de maleza con el nylon
cuesta unas quince veces mas filo que con un disco de tres puntas, porque tarda
cinco veces mas y ademas aguanta la mitad.

**La carga** se quedaba en 0,65 en el mejor caso y el motor bajaba un 13 %.
Con `densidad_corte` en 75 la maleza da de 0,13 (tres puntas, 8.649 vueltas) a
0,95 parada (nylon, 6.963). Y aqui hay una dinamica que conviene entender: **andando,
el cabezal rapido acaba con menos carga**, no mas, porque limpia antes y luego
corre por terreno ya limpio. La resistencia se nota parada en lo espeso, y el
tiempo se nota gaste de mas. Los dos efectos van en la direccion correcta y el
test lo mira en las dos formas.

### El corte se reparte en ocho sectores, no al azar

**Este es el fallo que mas se vio, y no era un numero.** El cabezal morda una celda
al azar del mapa, y el claro salia hecho de manchurrones: un sector se limpiaba
entero mientras el de al lado conservaba todas sus hojas.

Hay dos formas de reparte y una esta descartada a proposito. La primera fue
**barato y de dentro hacia fuera**: se coge la hoja mas cercana y se corta. Se ve
mucho mejor, pero es untrue: en una mata pasa por encima, o faila a la base y se
viene la corona entera de golpe. Con presupuesto del nylon, la zarza se vaciaba en
**un fotograma**, mas rapido que con un disco de tres puntas que muerde cuatro
veces mas. Un cabezal lento derribando el zarzal mas rapido que uno rapido es
justo lo contrario de lo que dice la tabla, y **no lo caza ninguna prueba** porque
las pruebas miden el total, no el reparto. Eso no vuelve.

Lo que se hizo, que es **muestreo estratificado**:

1. Las hojas de pie del disco se agrupan en **ocho sectores de 45 grados**.
2. Cada sector recibe **la octava parte** del presupuesto, con su resto decimal
   propio, guardado por sector y no global.
3. Dentro de cada sector se ordena de **dentro hacia fuera**, que es lo que hace
   que el frente sea un frente y no una corona de agujas.

Medido sobre 60 fotogramas:

```
hojas de partida por sector: [26, 24, 26, 21, 23, 25, 25, 23]
perdidas por sector:        [18, 18, 18, 18, 18, 18, 18, 18]
```

**Hay dos acumuladores de resto decimal y no es una duplicacion.** El global
(`_presupuesto_fraccion`) es el freno grueso: con el nylon contra la zarza el
presupuesto es de 0,08 hojas por fotograma, menos de una, y sin ese freno pasarian
doce fotogramas enteros sin cortar nada. Los de `_sector_por_cortar` son el reparto
fino. Quitar el global es facil y es un fallo que no aparece en una prueba corta.

Un numero lo tunea todo: `Hierba.SECTORES`. Con menos, el frente es mas suave; con
mas, se ve el rayado.

### El borde del disco tiene dientes

El borde era un circulo perfecto y se notaba desde la ventana. Ahora **cada hoja
tiene su propio umbral de distancia**, fijo, que sale de **donde esta** y no del
azar: `BORDE_MINIMO` 0,78 y `BORDE_RANGO` 0,44 sobre el radio.

Que sea **fijo** y no aleatorio es lo importante. Si el umbral saliera del azar en
cada fotograma, una hoja entraba y salia y el claro **parpadeaba** mientras
avanzabas. Fijado por posicion, cada hoja cae una vez y se queda.

Se probó antes la orla a media altura, que se remata al volver a pasar, y era mas
organica todavia. Medida: **el corte se puso 14 veces mas lento**, 72 hojas por
pasada a 5, y rompio tres pruebas. Se descarto. El margen que queda, 0,012 hojas
por debajo del limite del cambio, esta anotado por si algun dia se quiere.

### Las "pilas de rectangulos" eran los montones, y el diagnostico mentia

El usuario reporto cajas grandes de color crema en el suelo, sin saber de donde
salian. **Habia dos sistemas dejando material y se confundian porque se pisaban el
sitio**: `Restos`, que son los motitos, y `Montes`, que era el material acumulado.
Las cajas eran de `Montes`: era el **unico `BoxMesh` de todo el proyecto**
(`scripts/montes.gd`), con celdas de 46 cm en una rejilla de 50 cm.

**Lo que no era: cubos de un metro en el origen del mundo.** Esa fue la primera
conclusion y era falsa. Venia de leer el `MultiMesh` de vuelta, y en headless no
se puede: se probaron cuatro maneras de escribir y en las cuatro
`get_instance_transform` devuelve la identidad siempre, porque sin servidor de
render el `MultiMesh` no guarda nada. Es el mismo caso que
`get_instance_custom_data`, que ya estaba anotado, y aun asi se dio por bueno.
La prueba aislada se borro con el resto, pero el dato queda aqui.

Lo que si se puede leer en headless es el numero de celdas del gestor. Salia **cero
con la maquina quieta**, y el motivo es un detalle que no se ve jugando:
`Montes.pisar()` aplana 35 cm por pasada y el material nace justo donde esta el
cabezal, asi que la maquina se come lo que ella misma crea. El monton se forma
**detras**. Con una pasada de 10 metros: 12 celdas con el cesped, 21 con la
maleza, 42 con la zarza.

### `Montes` esta borrado entero

La primera vez que se vio el problema se arreglo la malla (un monton con el borde
irregular en vez de una caja, una instancia por celda en vez de apilar capas de 12
cm, giro y color por hash de celda). **Estaba bien y no era la solucion.** La
pregunta era si el suelo tenia que tener dos sistemas, y la respuesta es que no.

Se borro `scripts/montes.gd`, `_apisonar()` en la desbrozadora, el `aportar()` que
llamaba `Restos.soltar()` y los dos metodos de consulta que usaban las pruebas. En
el suelo solo quedan los trozos de `Restos`.

**Lo que se pierde**, y hay que decirlo: el amontonado ya no crece sin limite, asi
que una pasada larga ya no levanta un monton de 55 cm que haya que rodear. Con el
sistema viejo habia una regla de juego ("no basta con dar dos pasadas por el mismo
sitio") que desaparece. Es una decision del usuario, no una mejora tecnica, y el
precio se ha anotado aqui para que no se pierda.

En su lugar, `test_vegetacion_tier3.gd` comprueba lo que hacia falta para que el
sistema unico sirva: que el escombro **caiga junto al corte**, que es lo que hacia
util el monton, porque la pasada siguiente tiene que pisar donde acaba de cortar y
no dejar un reguero a tres metros.

### Los restos eran bloques, y era la orientacion

El usuario reporto, con razon, "bloques apilados". No era una impresion, eran cuatro
numeros:

| | antes | efecto |
|---|---|---|
| orientacion | inclinacion de ±0,12 rad | las 50 **horizontales en el mismo plano** |
| tamano | 14 cm × escala hasta 2,6 | **36 cm**: un tablon |
| silueta | una sola malla | 50 copias identicas |
| malla | 4 triangulos planos | plana por definicion |

La que mandaba era la **orientacion**: tumbarlas a proposito, pensando "caen al
suelo", convertia cincuenta planchas superpuestas en una pila de losas.

Ahora: orientacion libre en los tres ejes (mitad de cara, mitad de canto), malla
**curva** de cinco tramos con arco y retorcido, **cuatro siluetas** distintas,
tamano de 0,55 a 1,35 por trozo, uno de cada cinco desaturado hacia pajizo, y
trozos un 30 % mas pequenos con el tope de escala de la planta bajado a 1,5. El
pool subio de 50 a 110 porque las piezas son mas pequenas; el coste esta en las
que estan **despertando**, y aparcadas son un cuerpo congelado.

### Los dos numeros que se tunean desde un solo sitio

Si hay que ajustar la sensacion, se tocan estos dos y nada mas:

- `tasa_corte_base` en `vegetacion.gd`. **Las tres plantas son el mismo script**;
  ya no hay numeros de corte en ningun sitio mas.
- `desgaste_por_hoja` y `densidad_corte` en `desbrozadora.gd`.
- `Hierba.SECTORES` para el frente de corte, y `Restos.MAXIMO` para cuanto escombro
  se ve en el suelo.

`test_cabezales.gd` comprueba que la base siga por debajo de las 150 hojas/s, que
es el numero de referencia. Si alguna vez se sube por encima, la eficacia deja de
decidir nada y el juego vuelve a ser "todo corta igual", que es exactamente el
fallo que reporto el usuario.

### El inventario y la segunda herramienta

Nueve huecos, la rueda del raton para elegir y una rueda en pantalla que dice
cual llevas. La desbrozadora paso de ser un nodo fijo de la escena a ser el objeto
del hueco 1, y la **hoz** (generada en Blender con `tools/crear_hoz_mesh.py`) es
el hueco 2. `G` suelta y `E` recoge.

Lo que hay que tener presente al tocarlo:

- **La herramienta guardada no se destruye.** Se queda viva en un escondite con
  el proceso apagado, y por eso conserva la gasolina y el desgaste. Si al soltar
  se destruyera y al recoger se creara de cero, tirar la maquina al suelo seria
  la manera de resetearle el deposito.
- **El grupo `herramienta` solo lo tiene la que esta en la mano.** `Montes` lo
  consultaba en cada fotograma. Con la referencia guardada, al cambiar de
  herramienta en el inventario seguia aplastando con la anterior.
- **Un `CanvasLayer` no hereda la visibilidad de su padre.** Los paneles de cada
  herramienta (el de la desbrozadora con sus revoluciones) hay que apagarlos a
  mano al guardar la herramienta.
- **El pivote de las manos cuelga de `Caderas`, y ese nodo esta en el origen del
  jugador, a los pies, no a la cadera.** Cualquier altura de una herramienta
  equipped ahi va desde el suelo. Con offsets de decimetros, la hoz y las manos
  sueltas quedaban enterradas en la maleza.

### Lo que se decidio aplazar

La mecanica esta explicada en [LEEME.md](LEEME.md) y en
[DOCUMENTACION.md](DOCUMENTACION.md). Dos cosas pendientes:

1. **La zarza no vuelve a brotar.** Se decidio que la regresion se deja para mas
   adelante, asi que ahora mismo tumbar la base es el final del asunto.
2. **El escombro no se puede quitar de raiz.** Se aparta pasando la maquina, pero
   no hay ninguna razon de juego que obligue a hacerlo. La razon de verdad (una
   cana cortada en el suelo echa raquis) es la que le haria falta, y **no es solo
   un boton que falte**: hay que decidir que hace la raquis antes.

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
- Hay bosque de prueba con colisión y un suelo plano de 160 × 160 m con collider.
- **La hierba, el viento y el corte están implementados.** La escena conserva los
  dos campos de vegetación sobre el plano; falta repetir la comprobación visual
  Vulkan después de este cambio.
- El campo va **por cuadrantes**, con culling por caja y por distancia, asi que
  la densidad se puede subir sin que el motor dibuje las hojas enteras.
- **Hay dos tipos de hierba.** `MalezaAlta`, alta y seca, sale en matas con
  claros de verdad entre medias, cuesta mas que el cesped y se corta con la misma
  maquina. Un claro va mas rapido que un zarzal, y se nota.
- **Mirar arriba sube la maquina**, y el cabezal llega a la parte alta de la
  maleza sin salirse del encuadre. Antes no pasaba de 0,35 m.
- **El mundo de prueba está plano.** Hierba y árboles se siembran a `Y = 0`; no
  hay referencias activas a `Terreno` o `Aldea`.
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
- **Recorrido integrado de movimiento:** 55 comprobaciones combinan
  paneos, barridos, WASD, correr, agacharse, saltar y acelerar, incluida la
  mirada alta con el motor encendido y el corte compartido de ambos campos;
  última pasada limpia, 0 fallos.

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

### j) El radio de corte pertenece a la herramienta, no a la hierba

Antes cada campo tenía su propio `radio_corte` y las pruebas leían ese valor,
aunque el cabezal era el mismo. Ahora la fuente única es
`Desbrozadora.radio_corte`; ambos campos y la medida de resistencia consultan ese
radio. La prueba también verifica que `Hierba` y `MalezaAlta` ya no exporten esa
propiedad.

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
son los de las dos instancias de `scenes/main.tscn`. Ahora `Hierba` esta a
0,49 m de altura de referencia y `MalezaAlta` a 0,76 m, las dos con 60 hojas/m2 y
radio de siembra 90 m. Las dos bajaron respecto a la version anterior (0,69 y
1,33 m) porque la maleza tapaba la mitad del encuadre. Ambas usan formación en matas, radios de corte
diferentes y tamaños de cuadrante diferentes. La tabla exacta está en
`DOCUMENTACION.md`; hay que mantenerla al cambiar `main.tscn`.

El número total de hojas no se documenta como constante porque depende de los
parámetros y la semilla. `medir_densidad.gd` lee la configuración de la escena al
arrancar y las pruebas evitan comparar con cantidades fijas.

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
- El generador de terreno y el layout procedural de aldea ya no están activos.
  El futuro mapa y sus parcelas se diseñarán manualmente desde el editor.

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
- **Mapa de valle y aldea manuales.** No hay terreno definitivo, layout de parcelas,
  edificios ni carreteras en la escena de pruebas.
- **Conducción y furgoneta jugable.** Hay un modelo de furgoneta, pero no está
  integrada ni tiene punto de inicio en el mundo.
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

| Campo | Altura | Densidad | Formación | Radio de siembra | Cuadrante | Recorte | Tocon |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `Hierba` | 0,49 m | 60/m² | 0,70 | 90 m | 24 m | 80 m | 0,15 m |
| `MalezaAlta` | 0,76 m | 60/m² | 0,70 | 90 m | 12 m | 16 m | 0,06 m |

Los dos campos llevan `densidad` 60/m² y formacion de matas. La maleza subio
su formacion de 0,24 a 0,70 al arreglar la suite: con 0,24 ocupaba el 93 % del
mapa y no habia por donde andar, y con 0,70 ocupa el 37 % y se ven los claros. La maleza tiene
dureza 3,3 (el cesped 1,0) y es la que frena de verdad a la maquina.

La maleza tiene dureza 3,3. Ambos campos se siembran sobre el plano sin
exclusiones por terreno o aldea. El radio efectivo de corte común es 1,0 m y lo
define la herramienta, no los campos. El suelo temporal mide 160 × 160 m y su
collider alcanza un radio de 80 m.

La medición Vulkan del mapa anterior registró **8,3 ms de mediana**, limitada por
VSync a 120 fps, así que no aislaba el coste de la hierba. La medición visual de
esa versión registró 52,4 % de píxeles cambiados al ocultar el césped y 54,7 %
verdes con el encuadre inicial de −40°. El suelo plano actual no se ha perfilado.

## 8. Propuesta de siguiente paso

Estado del camino inmediato:

1. **Elegir y probar el editor de terreno.** Comprobar la compatibilidad de
   Terrain3D con Godot 4.7.2 antes de incorporarlo al proyecto.
2. **Diseñar el valle a mano.** Esculpir relieve, zonas de parcelas y carreteras,
   midiendo la duración real de los desplazamientos.
3. **Colocar manualmente la aldea y sus assets.** El layout procedural se retiró;
   el flujo futuro será construir escenas y ubicarlas desde el editor.
4. ~~**Darle una version que se pueda instalar.**~~ **Hecho.** Ya estan
   `export_presets.cfg` (Linux y Windows x86_64), la linea `config/version` y
   `scripts/version_pantalla.gd`, que la enseña al arrancar. El ejecutable de
   Linux ocupa 70 MB, de los cuales **290 KB son el juego**: el resto es la
   plantilla del motor con Vulkan. Aun **no se ha probado jugando**; falta esa
   comprobacion.
5. **Integrar la furgoneta y conducción básica.** Vehículo, controles y navegación
   siguen pendientes.
6. **Continuar el bucle de trabajo:** que la zarza vuelva a brotar (la regresion
   que se decidio aplazar), decidir que hace la raquis de las canas cortadas,
   conectar la pendiente del terreno con la resistencia y afilar el filo.
7. **Después:** encargos, NPCs y la aldea.

Lo que ya no esta pendiente, para que no se repita: la telemetria
desacoplada esta en `interfaz_herramienta.gd` con la senal
`telemetria_actualizada`, el sonido de corte esta, y los cabezales ya se
cambian con `Q` en caliente con el motor parado.

Ojo con una cosa al tocar la hierba: la suite **con ventana** necesita el juego
cerrado, y sin ventana (headless) no se ve nada de lo visual. Con la GPU por
software de esta maquina, ademas, la suite con ventana tarda doce minutos, asi
que para lo visual lo indicado es `tools/medir_foto.gd`, que va en 3 segundos.
