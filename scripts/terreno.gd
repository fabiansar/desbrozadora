class_name Terreno
extends StaticBody3D

## El terreno del huerto, con desnivel.
##
## Aqui NO hay un plano: hay una malla de cuadros, cada uno con su caja
## ajustada, y una funcion que dice a que altura esta cada punto. El terreno
## crece por capas, y las tres cosas que se suman son las que hacen que esto
## parezca un sitio y no una colina:
##
## 1. Una pendiente general, de unos 6 grados, que va subiendo hacia el
##    norte. Es la que hace que el horizonte no sea una raya.
## 2. Ondulación suave, en dos escalas, como el lomo de un campo. Sin esto, la
##    pendiente general se ve como una rampa uniforme, y con solo la
##    pendiente el juego entero seria un tobogán.
## 3. Las TERRAZAS: en la parte alta, la ladera se corta en pisos planos, como
##    los bancales de Galicia. Cada terraza es plana de verdad, con su talud
##    entre una y otra, y son las que dan los sitios donde se puede dejar la
##    maquina a trabajar sin que la pendiente le juegue a la contra.
##
## Y ademas hay SURCOS: canales estrechos y hondos que bajan por la ladera,
## que es como se va el agua cuando llueve mucho y el terreno no es de los
## blandos. Van mas o menos perpendiculares a la pendiente, asi que el agua
## baja por ellos.
##
## La decision que manda en todo el archivo es esta: **la altura sale de una
## funcion pura, `_cota()`, y todo lo demas pregunta ahi.** La malla la dibuja,
## pero la hierba, las casas, los muros y las pruebas no la miran: la usan. Asi
## una hoja nunca queda flotando medio metro, una casa nunca se queda medio
## metro enterrada, y una prueba puede comprobar en headless una cosa que
## depende de la forma del terreno sin que se dibuje nada.
##
## Y por lo mismo `_cota()` NO depende de donde este el jugador ni de nada que
## pase: es determinista. Con la misma semilla, el mismo terreno. Sin eso no se
## puede comparar una medicion con otra, y el proyecto entero vive de eso.

## Semilla. Con la misma sale siempre el mismo terreno, que es lo que hace
## falta para poder comparar unas pruebas con otras.
@export var semilla := 41021
## Lado del terreno, en metros. Cuadrado, centrado en el origen.
@export var lado := 240.0
## Lado de cada trozo de malla, en metros. Es lo que permite que el motor
## descarte lo que no se ve: sin trocear, la caja de la malla entera siempre
## solaparia con la pantalla y se dibujaria el terreno entero cada fotograma.
##
## El numero va en el compromis entre dibujar y descartar. Con 240 de lado y
## trozos de 12 m son 20x20 = 400 trozos: 400 llamadas de dibujo y 400
## colisiones, que son pocas. A 4 m salen 3.600 trozos, y eso ya se nota en el
## frame: son 3.600 llamadas de dibujo y 3.600 formas de colision por el
## mismo numero de triangulos, porque partir mas pequeno no anade vertices,
## solo multiplica las llamadas. Con 6 m salen 800 y el culling sigue
## funcionando bien en una ladera tan poco accidentada.
@export var lado_cuadrante := 12.0
## Distancia entre puntos de la malla, en metros. Este numero es el que decide
## como de bien sale un talud de terraza: a 1 m, el escalon de 1,7 m de alto
## cae en tres o cuatro puntos y se ve de canto. A 4 m, el mismo escalon cae
## entre dos puntos y sale un triángulo gigante. Ojo al subir el terreno de
## lado: los puntos son (lado / lado_cuadrante)^2 y con 300 sale a hundreds de
## miles, que en GDScript se nota.
@export var paso_malla := 1.0
## Pendiente general, en grados. La ladera sube hacia el norte (-Z).
@export var pendiente := 6.0
## Cuanto sube la pendiente general en total, de sur a norte. Sale de la
## pendiente y del lado, y se calcula solo.
@export_range(0.0, 30.0, 0.1) var desnivel := 0.0
## A partir de que altura empezar a hacer terrazas. Las terrazas se hacen en
## la parte alta, que es donde en Galicia se hacen: las faldas de monte.
@export var desde_terraza := 3.0
## Alto del piso de cada terraza.
@export var alto_terraza := 1.7
## Proporcion del alto que ocupa el talud entre terraza y terraza. Con 0,2 el
## talud es una quinta parte del alto, o sea un talud de mas de 60 grados:
## se ve de canto y se puede apoyar la maquina en el.
@export_range(0.05, 0.6, 0.01) var talud_terraza := 0.2
## Cuanto de fondo tienen los surcos, en metros.
@export_range(0.0, 2.0, 0.05) var fondo_surco := 0.9
## Ancho del surco, en metros. Se mide de lado a lado del canal.
@export var ancho_surco := 2.6
## Distancia entre surcos, en metros. Menos que el ancho, y se solapan: asi los
## surcos no salen con separacion regular, que es lo que los delata.
@export var paso_surco := 5.5
## Techo de la malla. Las esquinas de la malla se sondan mas arriba que el
## resto, para saber cuanto alto hay.
@export var altura_nube := 60.0

## La altura que tiene el terreno en el punto (0, 0), que es donde aparece el
## jugador y de donde sale el camino. El terreno entero se sube o se baja para
## que el centro quede aqui.
##
## Sin esto, cambiar la pendiente o la altura de las terrazas mueve el terreno
## entero de golpe y el jugador aparece en el aire o enterrado, y con el
## terreno a -5,76 en el centro la escena entera vive en numeros negativos
## que no dicen nada. Con esto, el 0 del terreno es el 0 de la escena, y el
## desnivel se ve en las cotas, que es donde se mira.
@export var altura_origen := 0.0

## Malla y colision se construyen una vez y se guardan aqui para poder
## consultarlas y medirlas sin tener que reconstruirlas.
var _cuadrantes: Array[MeshInstance3D] = []
var _cuadradas: Array[CollisionShape3D] = []
var _minima := 0.0
var _maxima := 0.0
## Las dos cosas que se usan para medir la forma del terreno, guardadas porque
## son el techo y el suelo de todo lo que se apoya encima.
var _cota_min := 0.0
var _cota_max := 0.0
# El desplazamiento que hace que el centro quede a `altura_origen`.
var _origen := 0.0


func _ready() -> void:
	_cotas()
	_construir()


# --- La forma del terreno ---------------------------------------------------

## La pendiente general de este punto, ya en metros. Se separa porque la usan
## las terrazas: el suelo de una terraza es esta recta mas el escalon que le
## toque, y el escalon hay que medirlo contra la pendiente, no contra la
## altura final (que ya lleva dentro las terrazas de abajo).
func _pendiente_en(p: Vector2) -> float:
	return -p.y * tan(deg_to_rad(pendiente))


## La ondulation de base, en metros. Dos escalas de ruido, con la grande
## mandando y la pequena rompiendo el lomo.
func _ondulacion_en(p: Vector2) -> float:
	return _ruido(p * 0.013) * 7.0 + _ruido(p * 0.045 + Vector2(31.7, 12.9)) * 2.2


## La cuenta de terrazas, de 0 (nivel de valle) hacia arriba.
##
## OJO con el signo: la pendiente SUBE hacia el norte, y -Z es el norte, asi que
## en el norte la cuenta es mas alta. Por eso entra el signo menos.
func _terraza_de(altura: float) -> float:
	return -altura / alto_terraza


## La parte de la ladera que son terrazas, en metros. Se separa de `_cota()`
## porque el talud (donde cae de un piso al siguiente) tiene una forma distinta
## a la del piso, y esa forma se nota.
##
## El truco esta en el `fract` de la cuenta. En el suelo del piso, el
## `fract` va JUSTO por 0, y `smoothstep` esta ahi en su valor de en medio: el
## piso queda medio Raising la terraza y medio bajando, o sea plano. Ya en el
## talud, el `fract` recorre 0 a 1 y la curva lo suaviza. Asi sale el escalon
## redondeado sin tener que cortar la malla a mano.
func _terraza_en(altura: float) -> float:
	if altura < desde_terraza:
		return 0.0
	var cuenta := _terraza_de(altura)
	# El suelo del piso es el mas bajo de su cuenta: se le quita la parte de
	# talud y se le deja el suelo, para que los pisos queden a la misma
	# separacion y no se vaya acumulando error hacia arriba.
	var suelo := floorf(cuenta)
	var de_pie := cuenta - suelo
	var alto_del_piso := alto_terraza * (1.0 - talud_terraza)
	# El talud se reparte entre el final de un piso y el principio del
	# siguiente. Antes de esto, la parte baja de la cuenta esta en el suelo
	# plano y el escalon salia justo en el borde, que es donde se nota que
	# es un truco.
	var f := (de_pie - (1.0 - talud_terraza)) / talud_terraza
	var rampa := smoothstep(0.0, 1.0, clampf(f, 0.0, 1.0))
	return (suelo + rampa) * alto_terraza - alto_del_piso


## Los surcos: canales hondos y estrechos que bajan por la ladera. Se
## calculan sobre el Norte-Sur, o sea en el eje de la pendiente, y con una
## palmada de aire para que no salgan con la misma separacion: si salieran
## rectos y a la misma distancia, el ojo los cuenta y se ve que son un truco.
func _surco_en(p: Vector2) -> float:
	var avance := p.y / paso_surco
	var continuo := _ruido(Vector2(avance * 0.35, 0.0))
	# Ojo: GDScript no tiene `fract()`, que es una palabra reservada de los
	# shaders. La parte decimal es restarle el suelo.
	var entero := floorf(avance + continuo * 1.6)
	var fraccion := (avance + continuo * 1.6) - entero
	# 1 en el fondo del canal, 0 en el borde. Con el pow sale mas tiempo en el
	# borde que en el fondo, que es como es de verdad: un canal de agua es
	# una V con las paredes largas.
	var perfil := 1.0 - pow(absf(fraccion * 2.0 - 1.0), 1.4)
	var ancho := clampf(ancho_surco / paso_surco, 0.05, 1.0)
	return -perfil * ancho * fondo_surco


## La cota del terreno en un punto, en metros. ESTA FUNCION ES LA QUE MANDA:
## la malla la dibuja, y todo lo demas la usa.
##
## No guarda nada y no depende de nada, asi que se puede llamar mil veces por
## fotograma si hace falta. Las tres capas se suman, y el orden importa: las
## terrazas se miden contra la pendiente y la ondulation, y los surcos se
## restan al final, para que el canal se vea en el piso de la terraza y no
## underneath.
## La altura, sin el origen. La malla, la colision, la hierba y las casas
## preguntan a `_cota()`, que es esta mas el desplazamiento del origen; esta de
## aqui se usa solo para calcular el desplazamiento, y por eso no se llama
## recursivamente a si misma.
func _neta(p: Vector2) -> float:
	var base := _pendiente_en(p) + _ondulacion_en(p)
	var con_terraza := base + _terraza_en(base)
	return con_terraza + _surco_en(p)


func _cota(p: Vector2) -> float:
	return _neta(p) + _origen


## Ruido de valor, con la misma cuenta que el del shader del suelo pero aqui
## en GDScript, para que la forma del terreno no dependa de la tarjeta. Ojo:
## la malla y la funcion usan ESTA, y no al reves, que es al reves no se
## podria ni dibujar ni comprobar.
func _ruido(p: Vector2) -> float:
	var i := Vector2(floorf(p.x), floorf(p.y))
	var f := Vector2(fposmod(p.x, 1.0), fposmod(p.y, 1.0))
	# Suavizado cuadratico de la celda. Con la interpolacion recta se notan
	# las esquinas de la celda y el terreno sale a cuadros.
	# El 3.0 tiene que ser un Vector2: `3.0 - 2.0 * f` no vale, porque restar
	# un escalar a un Vector si vale, pero restar un Vector a un escalar no.
	var u := f * f * (Vector2(3.0, 3.0) - 2.0 * f)
	var a := _hash(i)
	var b := _hash(i + Vector2(1.0, 0.0))
	var c := _hash(i + Vector2(0.0, 1.0))
	var d := _hash(i + Vector2(1.0, 1.0))
	return lerpf(lerpf(a, b, u.x), lerpf(c, d, u.x), u.y) * 2.0 - 1.0


## El hash de una celda, en 0..1. Es la cuenta clasica de Dave Hoskins sin
## seno, que es la que usa el shader del suelo tambien. Que los dos usen la
## misma no es casualidad: asi el suelo y el terreno tienen la misma textura de
## ruido, que es lo que hace que no se note el cambio de plano a ladera.
func _hash(p: Vector2) -> float:
	# El mismo hash que el `hash21` del shader del suelo, translatedo a GDScript.
	# Que sean el mismo no es casualidad: el suelo del prado y este terreno
	# llevan la misma textura de ruido, y si las cuentas fueran distintas se
	# notaria el cambio de un escenario al otro.
	var q := Vector3(p.x, p.y, p.x) * 0.1031
	# fract, que en GDScript es restar el suelo.
	q -= Vector3(floorf(q.x), floorf(q.y), floorf(q.z))
	# El `dot(q, q.yzx + 33.33)` del shader, con las permutadas al reves: en
	# GDScript no hay swizzles, asi que se escribe a mano.
	var d := q.x * (q.y + 33.33) + q.y * (q.z + 33.33) + q.z * (q.x + 33.33)
	q += Vector3(d, d, d)
	var r := (q.x + q.y) * q.z
	return r - floorf(r)


# --- La malla ---------------------------------------------------------------

## La altura mas baja y la mas alta de todo el terreno, con la misma funcion
## que usa la malla. Se calcula antes de construir, que es lo que necesita el resto.
func _cotas() -> void:
	# El origen se calcula antes que nada, con la funcion sin origins, y a
	# partir de ahi ya manda `_cota()` en todo.
	_origen = altura_origen - _neta(Vector2.ZERO)
	desnivel = lado * tan(deg_to_rad(pendiente)) * 0.5
	_cota_min = altura_nube
	_cota_max = -altura_nube
	var pasos := 24
	for i in pasos + 1:
		for j in pasos + 1:
			var p := Vector2(-lado * 0.5 + lado * float(i) / pasos,
				-lado * 0.5 + lado * float(j) / pasos)
			var h := _cota(p)
			_cota_min = minf(_cota_min, h)
			_cota_max = maxf(_cota_max, h)
	print("Terreno: desnivel de %.1f m, cotas de %.1f a %.1f m, pendiente %.0f grados"
		% [desnivel, _cota_min, _cota_max, pendiente])


## Cuantos trozos de malla hay por lado. Minimo 1, que es lo que hace que
## `lado_cuadrante` pueda ser tan grande como quiera sin que se rompa nada.
func _cuadrantes_por_lado() -> int:
	return maxi(1, int(round(lado / lado_cuadrante)))


## Cuantos puntos tiene el lado de un trozo. Con `paso_malla` de 1 m y trozos
## de 12 m salen 13x13 puntos por trozo: 169 puntos y 288 triangulos. El paso
## de 1 m es el que decide que se vea bien el talud de una terraza, y con 1 m
## un escalon de 1,7 m de alto cae en tres o cuatro puntos, que se ve de canto
## y no redondeado.
func _resolucion(paso: float) -> int:
	return maxi(1, int(round(paso / paso_malla)))


## Construye la malla y su colision. Los dos salen de la MISMA rejilla de
## alturas, que es lo unico que garantiza que se pisen: si la colision se
## hiciera con otro redondeo, el jugador andaria por encima o por debajo del
## suelo sin que se viera por que.
func _construir() -> void:
	var material := _material()
	var n := _cuadrantes_por_lado()
	var paso := lado / float(n)
	var res := _resolucion(paso)
	var puntos_totales := 0
	for i in n:
		for j in n:
			var x0 := -lado * 0.5 + paso * float(i)
			var z0 := -lado * 0.5 + paso * float(j)
			# Las alturas de ESTE trozo, en una rejilla de (res+1)^2. Se
			# calculan en un array aparte y no directamente en la malla porque
			# hace falta volver a ellas para las normales y para la caja.
			var alturas := PackedFloat32Array()
			var minimo := altura_nube
			var maximo := -altura_nube
			for v in res + 1:
				for u in res + 1:
					var h := _cota(Vector2(x0 + paso * float(u) / res,
						z0 + paso * float(v) / res))
					alturas.push_back(h)
					minimo = minf(minimo, h)
					maximo = maxf(maximo, h)
			puntos_totales += alturas.size()
			var malla := _malla_de(alturas, res, paso, x0, z0)
			var mi := MeshInstance3D.new()
			mi.mesh = malla
			mi.material_override = material
			# La caja ajustada es lo que permite el culling, y TIENE que llevar
			# la altura de verdad: con una caja plana en y=0, que es lo facil,
			# el motor descarta el trozo entero siempre que la camara no este
			# a la misma altura, y el terreno aparece y desaparece a trozos.
			mi.custom_aabb = AABB(Vector3(x0, minimo, z0),
				Vector3(paso, maximo - minimo, paso))
			add_child(mi)
			_cuadrantes.append(mi)
			# La colision sale de los MISMOS puntos, y por eso no hace falta
			# volver a preguntar al terreno: es la misma rejilla, la misma
			# funcion. Un trimesh por trozo, que es lo unico que se puede
			# deformar sin tocar la forma.
			#
			# OJO: `set_faces()` NO quiere los vertices de la malla, quiere la
			# lista de triangulos, tres vertices por triangulo y punto por
			# punto. Si se le pasa el array de vertices de la malla (que son los
			# puntos COMPARTIDOS, 25 por trozo) el motor no avisa de nada
			# util: dice que el numero de caras no es multiplo de tres y se
			# queda sin colision, o sea, con el terreno invisible pero andable
			# a traves.
			var forma := ConcavePolygonShape3D.new()
			forma.set_faces(_triangulos_de(alturas, res, paso, x0, z0))
			var col := CollisionShape3D.new()
			col.shape = forma
			add_child(col)
			_cuadradas.append(col)
	print("Terreno: %d trozos de %.1f m, %d puntos y %d triangulos en total"
		% [_cuadrantes.size(), paso, puntos_totales, puntos_totales * 2])


## Los triangulos de un trozo, en la lista plana que quiere la colision: tres
## puntos por triangulo, sin compartir. Sale de las mismas alturas que la
## malla, y con el mismo orden de caras, asi que la superficie por la que se
## anda es EXACTAMENTE la que se ve.
func _triangulos_de(alturas: PackedFloat32Array, res: int, paso: float,
		x0: float, z0: float) -> PackedVector3Array:
	var caras := PackedVector3Array()
	caras.resize(res * res * 6)
	var w := res + 1
	var n := 0
	for v in res:
		for u in res:
			var a := Vector3(x0 + paso * float(u) / res, alturas[v * w + u],
				z0 + paso * float(v) / res)
			var b := Vector3(x0 + paso * float(u + 1) / res, alturas[v * w + u + 1],
				z0 + paso * float(v) / res)
			var c := Vector3(x0 + paso * float(u) / res, alturas[v * w + u + w],
				z0 + paso * float(v + 1) / res)
			var d := Vector3(x0 + paso * float(u + 1) / res, alturas[v * w + u + 1 + w],
				z0 + paso * float(v + 1) / res)
			# El mismo orden que en la malla, y por el mismo motivo (ver ahi).
			caras[n] = a; caras[n + 1] = b; caras[n + 2] = c
			caras[n + 3] = b; caras[n + 4] = d; caras[n + 5] = c
			n += 6
	return caras


## La malla de un trozo, a partir de las alturas de su rejilla.
##
## Las normales se calculan con las diferencias de los vecinos, que es lo
## mismo que hace el terreno por debajo pero gratis, porque las alturas ya
## estan. Con la normal plana (Vector3.UP en todos los puntos) el terreno sale
## facetado, y en una ladera con terrazas se nota muchisimo: los taludes se
## ven como una escalera de rombos.
func _malla_de(alturas: PackedFloat32Array, res: int, paso: float,
		x0: float, z0: float) -> ArrayMesh:
	var t := SurfaceTool.new()
	t.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := res + 1
	for v in res + 1:
		for u in res + 1:
			var x := x0 + paso * float(u) / res
			var z := z0 + paso * float(v) / res
			# Diferencias centrales sobre la rejilla. En los bordes se usa el
			# vecino de dentro, con lo que la normal se inclina un poco hacia
			# fuera: se nota en el borde del mundo, que es donde no se mira.
			var um := maxi(u - 1, 0)
			var up := mini(u + 1, res)
			var vm := maxi(v - 1, 0)
			var vp := mini(v + 1, res)
			var dx := (alturas[v * w + up] - alturas[v * w + um]) / (paso * float(up - um) * 0.5)
			var dz := (alturas[vp * w + u] - alturas[vm * w + u]) / (paso * float(vp - vm) * 0.5)
			t.set_normal(Vector3(-dx, 1.0, -dz).normalized())
			t.set_uv(Vector2(x, z) / 4.0)
			t.add_vertex(Vector3(x, alturas[v * w + u], z))
	# Las caras en HORARIO vistas desde arriba. O sea, al revés de lo que dice
	# la regla de la mano derecha, y no es un error: es la convencion de Godot.
	# Las caras delanteros son las que se ven en horario, mirandolas desde el
	# lado de la normal, y el PlaneMesh viene asi:
	#     (0, 1, 2) = (1,0,1) (-1,0,1) (1,0,-1)  ->  normal geometrica -Y
	# O sea, la normal geometrica de un triángulo del frente apunta AL
	# CONTRARIO de por donde se mira. Con el otro orden, el de la regla de la
	# mano derecha, el terreno se dibuja de cara al suelo: desde arriba no se
	# ve NADA, y con el culling puesto ni se nota, porque lo que se ve desde
	# abajo es justo el interior del terreno.
	#
	# Y con los indices, que sin ellos los puntos se dibujan como triangulos
	# sueltos y el servidor de dibujo rechaza la llamada entera.
	for v in res:
		for u in res:
			var a := v * w + u
			var b := a + 1
			var c := a + w
			var d := c + 1
			t.add_index(a); t.add_index(b); t.add_index(c)
			t.add_index(b); t.add_index(d); t.add_index(c)
	return t.commit()


## El material del suelo: el mismo shader que el del prado, con su ruido. El
## color sale de la posicion en el mundo, no de la UV, asi que las manchas
## no se empalman con el borde de la malla y no se ve el cosido al alejarse.
func _material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/suelo.gdshader")
	m.set_shader_parameter("tierra_seca", Color(0.345, 0.259, 0.169))
	m.set_shader_parameter("tierra_humeda", Color(0.145, 0.098, 0.062))
	m.set_shader_parameter("verdin", Color(0.208, 0.271, 0.129))
	m.set_shader_parameter("escala_manchas", 0.28)
	m.set_shader_parameter("cantidad_verdin", 0.34)
	return m


# --- Lo que pregunta el resto del juego -------------------------------------

## La altura del terreno en un punto del mundo, en metros. ESTA ES LA QUE
## TIENEN QUE USAR LA HIERBA, LAS CASAS, LOS MUROS Y EL JUGADOR.
##
## Se llama `cota` y no `_cota` porque es de las que se piden desde fuera. Y
## no devuelve la altura de la malla, sino la de la funcion: la malla es una
## aproximacion con puntos cada `paso_malla` metros, y si alguien se apoya en
## la altura de un vertice, una casa se queda flotando medio metro en medio de
## un lado y medio metro enterrada en el siguiente.
func cota_en(p: Vector2) -> float:
	return _cota(p)


## Lo mismo, pero con la altura de un punto en 3D. Para lo que ya tiene un
## Vector3 a mano y solo quiere la Y.
func cota_en_3d(p: Vector3) -> float:
	return _cota(Vector2(p.x, p.z))


## Las dos esquinas de la caja del terreno, en altura. Lo usan las pruebas y
## sirve para saber cuanto alto hay que poner el sol y la niebla.
func cotas() -> Vector2:
	return Vector2(_cota_min, _cota_max)


## Cuantos trozos de malla hay. No es solo para medir: el culling por caja
## es lo que hace que se pueda agrandar el terreno, y sin esto no se
## comprobaria que la caja de cada trozo esta bien puesta.
func num_cuadrantes() -> int:
	return _cuadrantes.size()


## La caja de un trozo de malla. Si esta mal, el trozo se ve o no se ve
## cuando no toca, que es el sintoma mas dificil de ver de todo el terreno.
func caja_de_cuadrante(n: int) -> AABB:
	return _cuadrantes[n].custom_aabb


## La pendiente en el suelo, en grados y con el signo: positivo es cuesta
## arriba. La usan las pruebas para comprobar que el terreno tiene de verdad
## desnivel y no es un plano con bultos.
func pendiente_en(p: Vector2) -> float:
	var e := 1.0
	var dx := (_cota(p + Vector2(e, 0.0)) - _cota(p - Vector2(e, 0.0))) / (2.0 * e)
	var dz := (_cota(p + Vector2(0.0, e)) - _cota(p - Vector2(0.0, e))) / (2.0 * e)
	return rad_to_deg(atan(sqrt(dx * dx + dz * dz)))


## La parte de la ladera que son terrazas, en metros, o 0 si este punto esta
## por debajo de donde empiezan. Lo usan las pruebas para buscar un piso
## plano: donde esta funcion da lo mismo en varios puntos seguidos, hay
## terraza, y donde cambia de golpe, hay talud.
func cota_terraza(p: Vector2) -> float:
	return _terraza_en(_pendiente_en(p) + _ondulacion_en(p))


## El fondo del surco, en metros. Siempre 0 o menos, porque un surco excava.
## Lo usan las pruebas para comprobar que los canales estan donde deben y
## que no se cruzan con los muros de las parcelas.
func profundidad_surco(p: Vector2) -> float:
	return _surco_en(p)
