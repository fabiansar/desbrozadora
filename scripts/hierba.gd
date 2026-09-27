class_name Hierba
extends Node3D

## El campo de hierba.
##
## Las hojas van repartidas en CUADRANTES, cada uno con su propio MultiMesh, en
## vez de todas juntas en uno solo. El motivo es el culling:
##
## Con un unico MultiMesh de 68 m de lado, su caja envolvente es tan grande que
## siempre se solapa con la pantalla, se mire donde se mire. El motor no puede
## descartar nada, asi que dibuja las 109.000 hojas enteras en cada fotograma
## aunque solo se vea un trozo de cesped. Con cuadrantes, cada uno lleva su caja
## ajustada a las hojas que tiene dentro, el motor descarta solo los que quedan
## fuera de la vista, y el dibujo se reduce a lo que se ve de verdad. Es lo que
## deja subir la densidad sin que el portatil se resienta.
##
## Por encima del culling de la vista hay un recorte por distancia, con
## `distancia_maxima`. Es la red de seguridad: si el campo crece, o si la niebla
## no llega, los cuadrantes lejanos se apagan directamente. El valor por defecto
## es mayor que el radio del campo, con lo cual hoy no apaga nada; esta ahi para
## que el dia que se suban las hojas o se agrande el campo no haya que tocar
## codigo.
##
## El estado de cada hoja (donde esta y cuanto le queda de altura) vive en
## arrays de GDScript, NO en el MultiMesh, por dos razones:
##
## - El MultiMesh solo existe en el servidor de graficos. En modo headless no
##   guarda nada, asi que una prueba en linea de comandos no veria ni una hoja y
##   el sistema de corte no se podria comprobar.
## - Leer 40.000 transformaciones del motor en cada fotograma seria una
##   chapuza. Con los arrays se va directo.
##
## El MultiMesh solo recibe la transformacion y el color de la hoja. El shader
## lee INSTANCE_CUSTOM, y de ahi sale cuanto se dobla con el viento y cuanto le
## queda de altura despues del corte. Asi cortar es escribir un numero: no se
## toca ninguna geometria, y se puede ir cortando en plan largo sin que baje el
## ritmo. El color se compone aqui, en GDScript, y no se vuelve a leer del
## MultiMesh: antes al cortar se hacia un get_instance_custom_data por hoja, que
## es una lectura de la tarjeta grafica, y no hacia falta para nada porque los
## cuatro numeros del color ya estaban en los arrays de aqui.
##
## Para el corte hay ademas una rejilla: un diccionario con las celdas de 2 m y
## la lista de indices de cada una. Sin ella habria que revisar las cuarenta
## mil hojas por fotograma; asi solo se mira lo que hay alrededor del cabezal.
## Ojo: la rejilla de 2 m es para el CORTE y no tiene nada que ver con los
## cuadrantes, que son de `lado_cuadrante` y solo existen para el dibujo.

## Numero de tipo de hierba. El 1 es el cesped: una alfombra pareja y verde.
## El 2 es la maleza alta, la zarza seca y en matas, que rompe el tapiz verde.
## Los dos son ESTE MISMO nodo con otros parametros: mismo reparto en cuadrantes,
## mismo sistema de corte, mismo mapa de viento. Lo unico que cambia de un tipo
## a otro son los numeros de aqui abajo y los dos colores del material.
##
## La hoja lleva el tipo en el mismo sitio de siempre, en INSTANCE_CUSTOM.w (el
## tono), porque es la unica ranura que queda libre y el contrato del shader no
## se toca. El tipo no hace falta por hoja: cada tipo es su propio nodo con su
## propio material, y por eso las hojas del mismo tipo comparten color de una.
@export var tipo := 1

## Como se reparte la maleza por el suelo. Con 0 sale una alfombra pareja, que es
## el cesped. Con 1 solo salen los manchones, que es la zarza: claros y matas,
## no un tapiz uniforme. Entre medias, un cesped con calvas.
##
## El reparto sale de una cuenta suave, sin textura ni tabla, y es determinista:
## la misma semilla da siempre el mismo campo. Y con 0 el reparto es
## EXACTAMENTE el de antes, que es lo que deja el cesped intacto.
@export_range(0.0, 1.0, 0.01) var formacion := 0.0
## Cuanto cuesta cortar este tipo de maleza. El cesped vale 1. La zarza vale mas
## porque es mas densa y mas tiesa, y con esto el motor y el barrido frenan un
## poco mas al pasar por ella. Se multiplica por la densidad, de modo que lo
## que frena de verdad es "cuanta maleza cara hay debajo", que es justo lo que
## se nota.
@export_range(0.5, 4.0, 0.05) var dureza := 1.0
## Color de la base de la hoja. El del cesped va en el shader por defecto; el de
## la zarza es mas pardo.
@export var tono_pie := Color(0.098, 0.216, 0.063)
## Color de la punta de la hoja. La zarza va mas seca y mas clara.
@export var tono_punta := Color(0.353, 0.545, 0.157)

## Altura de la hoja, en metros. Entre 0,30 y 0,55 se ve como cesped; de mas de
## 0,8 ya parece trigo.
@export_range(0.05, 1.5, 0.01) var altura := 0.38
## Cuanto varian las alturas entre si. Es lo que mas quita el aire de copia:
## un cesped con todas las hojas iguales parece una moqueta.
@export_range(0.0, 1.0, 0.01) var variacion_altura := 0.45
## Ancho de la hoja, en metros.
@export_range(0.005, 0.3, 0.005) var grosor := 0.045
## Cuanto varian los grosores.
@export_range(0.0, 1.0, 0.01) var variacion_grosor := 0.35
## Radio del campo, en metros. Fuera no hay hierba, y las hojas del final se
## achican para que el campo se acabe sin que se vea un circulo en el suelo.
@export_range(5.0, 90.0, 1.0) var radio := 34.0
## Hojas por metro cuadrado. Con 30 salen unas 109.000 hojas en 34 m de radio,
## que es lo que aguanta un portatil sin despeinarse. Por debajo de 8 se ve ralo.
@export_range(1.0, 60.0, 0.5) var densidad := 30.0
## Desde que fraccion del radio se empieza a achicar el campo. Si vale 1 el
## cesped se corta en seco y se ve un circulo perfecto.
@export_range(0.3, 1.0, 0.01) var borde := 0.72
## Semilla del reparto, para que el campo salga siempre igual y se puedan
## comparar dos pruebas.
@export var semilla := 90210

## Lado del cuadrado de cada trozo de campo, en metros. Decide cuantas llamadas
## de dibujo se hacen y cuanto se ahorra el culling. Con 8 m en un campo de 68 m
## salen 81 trozos, y mirando al frente solo se dibujan veinte o asi. Con 4 m
## habria 289: mejor culling, pero demasiadas llamadas de dibujo. 8 m es donde
## las dos cosas cuadran.
@export_range(2.0, 24.0, 0.5) var lado_cuadrante := 8.0
## A que distancia se apaga un cuadrante. Con 0 no hay recorte por distancia y
## se queda solo el culling de la vista, que tambien funciona. Por defecto va
## por encima del radio del campo, para que de momento no se apague nada y el
## recorte este preparado ya para cuando el campo crezca.
@export_range(0.0, 120.0, 1.0) var distancia_maxima := 42.0

## Radio del corte, en metros. Es la mitad del ancho de corte del cabezal: una
## desbrozadora normal corta de 40 a 50 cm, o sea de 0,20 a 0,25 de radio. Con
## 0,12, que es lo que se puso al principio, el rastro salia finisimo, como si
## fuera un punzon. Ahora esta en 0,40 (un 60 % mas que antes) para que el
## rastro se vea de sobra mientras se prueba.
@export_range(0.05, 1.0, 0.01) var radio_corte := 0.40
## Dejar un tocón corto en vez de pelar el suelo. Con false el rastro se ve
## limpio; con true se ve el pelo, como un cesped recien cortado.
## Si esta activo, cortar deja un tocón de altura_tocon en vez de tumbar la
## hoja del todo. Sin esto la hierba cortada queda a 0 cm, tumbada en el suelo
## y no se ve desde la camara, asi que no hay ni rastro de por donde has
## pasado la maquina.
@export var dejar_tocon := true
## Altura del tocón cuando dejar_tocon esta activo. Con 8 cm el corte se ve de
## sobra desde la camara: es una mancha mas corta y mas clara que la hierba de
## pie.
@export_range(0.0, 0.4, 0.01) var altura_tocon := 0.08

## Donde esta cada hoja, y cuanto le han cortado. 0 esta de pie, 1 cortada.
var _pos := PackedVector3Array()
var _corte := PackedFloat32Array()
var _alto := PackedFloat32Array()
var _gordo := PackedFloat32Array()
var _tonos := PackedFloat32Array()
var _fases := PackedFloat32Array()
var _rigideces := PackedFloat32Array()
var _angulos := PackedFloat32Array()

## En que casilla del mapa de cuadrantes esta cada hoja, y en que hueco dentro de
## ese cuadrante. El indice local hace falta porque dentro de un MultiMesh las
## instancias se numeran desde 0, y ese 0 es el del cuadrante, no el del campo.
var _cuadrante_de := PackedInt32Array()
var _dentro_de := PackedInt32Array()

## Los nodos de dibujo, uno por cuadrado con hojas, y el punto por el que se
## mide la distancia al apagar. Al saltar los cuadrados vacios (las esquinas
## del cuadrado grande quedan fuera del circulo), hace falta _ids para pasar de
## la casilla del mapa al indice de esta lista.
var _cuadrantes: Array[MultiMeshInstance3D] = []
var _centros: Array[Vector3] = []
var _ids := PackedInt32Array()

## Un solo material para todos los cuadrados, y el mismo recurso y no una copia
## por cuadrado a proposito: el viento mete el tiempo en el shader una vez y, al
## ser el mismo objeto, se ve en todos.
var _material: ShaderMaterial
var _malla: ArrayMesh

var _rejilla := {}
var _paso := 2.0
var _lado := 0
var _sembradas := 0
var _desbrozadora: Desbrozadora = null
var _buscada := false
## Ultima posicion desde la que se refresco el recorte por distancia. Solo se
## recalcula si la camara se ha movido mas de un metro, porque si no se estaria
## escribiendo lo mismo en 81 nodos sesenta veces por segundo.
var _mirada := Vector3(1.0e9, 0.0, 0.0)


func _ready() -> void:
	add_to_group("hierba")
	_crear_material()
	_sembrar()
	_crear_rejilla()
	var nombre := "cesped" if tipo == 1 else "maleza tipo %d" % tipo
	print("%s: %d hojas de %.0f cm en %.0f m de radio (%.1f por m2)"
		% [nombre.capitalize(), _sembradas, altura * 100.0, radio, densidad])
	print("  en %d cuadrantes de %.0f m, culling por caja y por distancia"
		% [_cuadrantes.size(), lado_cuadrante])
	if formacion > 0.0:
		print("  en matas: se siembra el %.0f %% del terreno (formacion %.2f), dureza %.1f"
			% [(1.0 - formacion * 0.85) * 100.0, formacion, dureza])


## El material va en override de cada cuadrado porque es ahi donde Godot
## rellena INSTANCE_CUSTOM; con un material de superficie se queda vacio.
func _crear_material() -> void:
	_material = ShaderMaterial.new()
	_material.shader = load("res://shaders/hierba.gdshader")
	# Los colores de la hoja van en el MATERIAL y no en el dato de la instancia,
	# porque son de todo el tipo y no de una hoja: asi el cesped es verde y la
	# zarza parda sin gastar ni un canal mas de INSTANCE_CUSTOM, cuyo contrato
	# (x = altura restante, y y z = UV del viento, w = tono) no se toca.
	_material.set_shader_parameter("color_pie", tono_pie)
	_material.set_shader_parameter("color_punta", tono_punta)
	_malla = _hoja()


## Cuanto le cuesta cortar este tipo de maleza. El nombre es distinto del export
## porque en GDScript una variable y una funcion no pueden llamarse igual.
func coste_maleza() -> float:
	return dureza


## Una mancha de maleza de 0 a 1 en un punto del suelo.
##
## Es la parte que hace que la zarza salga en matas y no como un tapiz: dos
## ondas cruzadas a escalas distintas, con lo que sale un manchon grande con
## motas dentro, que es como se ve de verdad. Sin textura, sin tabla y sin
## ruido de Ruido: son dos `sin` y un `cos`, y sale determinista, con lo que la
## misma semilla da siempre el mismo campo.
func _mancha(x: float, z: float) -> float:
	var grande := sin(x * 0.21 + semilla * 0.013) * cos(z * 0.17 - semilla * 0.021)
	var fina := sin((x + z) * 0.63 - semilla * 0.037)
	return clampf(0.5 + 0.34 * grande + 0.16 * fina, 0.0, 1.0)


## Una hoja: tres tramos de dos puntos y la punta. Ocho vertices y seis
## triangulos, que es lo que se ve sin mirar de cerca y sale muy barato: con
## 109.000 hojas son unas 650.000, repartidas en 81 llamadas de dibujo.
func _hoja() -> ArrayMesh:
	var t := SurfaceTool.new()
	t.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tramos := 3
	for i in tramos + 1:
		var u := float(i) / float(tramos)
		# Se estrecha al subir, un poco de curva hacia delante y algo de
		# torsion, para que no sea un carton plano.
		var ancho := (1.0 - u * 0.88) * 0.5
		var curva := u * u * 0.09
		var giro := deg_to_rad(12.0) * u
		var dx := cos(giro) * ancho
		var dz := sin(giro) * ancho
		t.set_normal(Vector3(0.0, 0.0, 1.0))
		t.set_uv(Vector2(0.0, u))
		t.add_vertex(Vector3(-dx, u, curva - dz))
		t.set_normal(Vector3(0.0, 0.0, 1.0))
		t.set_uv(Vector2(1.0, u))
		t.add_vertex(Vector3(dx, u, curva + dz))
	# La lista de indices no es opcional. Sin ella los 8 vertices se pasan a
	# dibujar como triangulos sueltos, y como 8 no es multiplo de 3 el servidor
	# de dibujo rechaza la llamada entera: no sale ni una hoja y no salta ningun
	# error en el motor sin pantalla. Con los indices se dibujan 6 triangulos
	# sin tener que repetir los 8 vertices.
	for i in tramos:
		var a := i * 2
		t.add_index(a)
		t.add_index(a + 1)
		t.add_index(a + 2)
		t.add_index(a + 1)
		t.add_index(a + 3)
		t.add_index(a + 2)
	return t.commit()


## Reparto en rejilla con algo de azar dentro de cada casilla, no azar a pelo:
## con la rejilla el campo queda compacto y llano, y con azar a pelo se hacen
## claros que se ven desde lejos.
func _sembrar() -> void:
	var paso := 1.0 / sqrt(densidad)
	var casillas := int(ceil(radio * 2.0 / paso))
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla
	_pos.resize(0)
	_corte.resize(0)
	_alto.resize(0)
	_gordo.resize(0)
	_tonos.resize(0)
	_fases.resize(0)
	_rigideces.resize(0)
	_angulos.resize(0)
	for j in casillas:
		for i in casillas:
			var x := -radio + (float(i) + rng.randf()) * paso
			var z := -radio + (float(j) + rng.randf()) * paso
			var d := sqrt(x * x + z * z)
			if d > radio:
				continue
			# La formacion, antes de gastarse una hoja. Con 0 no se mira nada y el
			# reparto es exactamente el de siempre, con lo que el cesped no se
			# entera. Con 1 solo se siembra donde la mancha pasa del 0,85, o sea
			# poco mas del 15 % del terreno, y eso es una zarza en claros y matas
			# y no un fieltro.
			if formacion > 0.0 and _mancha(x, z) < formacion * 0.85:
				continue
			var alto := altura * (1.0 - variacion_altura * 0.5
				+ rng.randf() * variacion_altura)
			# Achicado hacia fuera, para que el campo se disuelva en el suelo en
			# vez de acabarse en un circulo.
			var fuera := smoothstep(radio * borde, radio, d)
			alto *= 1.0 - fuera * 0.92
			if alto < 0.02:
				continue
			var gordo := grosor * (1.0 - variacion_grosor * 0.5
				+ rng.randf() * variacion_grosor)
			# Un centimetro por encima del suelo, para que las raices no pelen
			# con el terreno.
			_pos.append(Vector3(x, 0.01, z))
			_corte.append(0.0)
			_alto.append(alto)
			_gordo.append(gordo)
			_angulos.append(rng.randf() * TAU)
			# r = altura que le queda (1 de pie), g = tono, b = fase, a = rigidez.
			# El tono y la rigidez salen de una edad inventada por hoja, para que
			# unas sean mas oscuras y tiesas que otras sin necesitar un sistema
			# de crecimiento entero.
			_tonos.append(0.35 + rng.randf() * 0.65)
			_fases.append(rng.randf() * TAU)
			_rigideces.append(0.7 + rng.randf() * 0.5)
	_sembradas = _pos.size()
	_radio_uv = radio
	_repartir_en_cuadrantes()


## En que casilla del mapa de cuadrantes cae un punto. El campo va de -radio a
## +radio y se parte en _lado trozos iguales.
func _casilla_de(p: Vector3) -> int:
	var i := clampi(floori((p.x + radio) / lado_cuadrante), 0, _lado - 1)
	var j := clampi(floori((p.z + radio) / lado_cuadrante), 0, _lado - 1)
	return j * _lado + i


## Monta los cuadrantes y reparte las hojas entre ellos.
##
## Va en dos pasadas porque hay que saber cuantas hojas lleva cada cuadrado
## antes de poder reservarle sitio en su MultiMesh: instance_count hay que
## fijarlo ANTES de rellenar, porque de 0 no escribe nada, y cada vez que se
## vuelve a tocar Godot borra lo que hubiera dentro. Antes se reservaba el
## campo entero y al final se ajustaba el recuento al numero de hojas bueno: ese
## ajuste era el que borraba el campo, y se quedaba un monton de hojas apiladas
## bajo la camara, fuera de la vista.
func _repartir_en_cuadrantes() -> void:
	_lado = maxi(1, int(ceil(radio * 2.0 / lado_cuadrante)))
	var cuantos := _lado * _lado
	var listas: Array = []
	listas.resize(cuantos)
	_ids.resize(cuantos)
	_cuadrante_de.resize(_sembradas)
	_dentro_de.resize(_sembradas)
	for i in _sembradas:
		var c := _casilla_de(_pos[i])
		_cuadrante_de[i] = c
		# Un Array con resize() se llena de null, asi que la primera hoja de cada
		# casilla es la que crea su lista. Los elementos de un Array de GDScript
		# son referencias, con lo que anadir a la lista no hace falta sacarla y
		# volver a guardarla como habia que hacer con los del diccionario de la
		# rejilla.
		if listas[c] == null:
			listas[c] = PackedInt32Array()
		var lista: PackedInt32Array = listas[c]
		lista.append(i)
		listas[c] = lista
	for c in cuantos:
		# Un Array con resize() se llena de null, no de listas vacias, asi que
		# los cuadrados por los que no paso ninguna hoja llegan aqui como null.
		if listas[c] == null:
			continue
		var lista: PackedInt32Array = listas[c]
		# Los cuadrados sin hojas se descartan: un MultiMesh con cero
		# instancias es una llamada de dibujo para nada. Pasa en las esquinas,
		# que quedan fuera del circulo del campo.
		if lista.is_empty():
			continue
		_ids[c] = _cuadrantes.size()
		_centros.append(_montar_cuadrante(lista).get_center())


## Crea el nodo de un cuadrado con su MultiMesh ya lleno, le pone la caja
## ajustada a lo que tiene dentro, y devuelve esa caja.
func _montar_cuadrante(lista: PackedInt32Array) -> AABB:
	var nodo := MultiMeshInstance3D.new()
	nodo.name = "Cuadrante_%d" % _cuadrantes.size()
	nodo.material_override = _material
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = _malla
	mm.instance_count = lista.size()
	nodo.multimesh = mm
	var minimo := Vector3(1.0e9, 1.0e9, 1.0e9)
	var maximo := Vector3(-1.0e9, -1.0e9, -1.0e9)
	for k in lista.size():
		var i: int = lista[k]
		_dentro_de[i] = k
		var base := Basis(Vector3.UP, _angulos[i])
		base = base.scaled(Vector3(_gordo[i], _alto[i], _gordo[i]))
		mm.set_instance_transform(k, Transform3D(base, _pos[i]))
		# El mapa del viento mide lo mismo que el campo, asi que la UV sale de
		# aqui. Va en los datos de la instancia porque el vertex shader de un
		# MultiMesh no ve la posicion de cada hoja: solo ve la del nodo, que es
		# la misma para todas. Sin esto el campo entero se doblaba al unisono
		# con la misma celda de viento.
		mm.set_instance_custom_data(k, _color_de(i, 1.0))
		# La caja se calcula a mano y se le pone al nodo. Sin esto Godot
		# deduciria la del MultiMesh, que es correcta pero mas conservadora, y
		# cuanto mas sobrante tenga la caja peor funciona el culling: cuanto
		# mas grande es, mas veces se solapa con la pantalla y menos cuadrados
		# se pueden descartar.
		var p := _pos[i]
		var gordo := _gordo[i] + 0.05
		minimo.x = minf(minimo.x, p.x - gordo)
		minimo.z = minf(minimo.z, p.z - gordo)
		minimo.y = minf(minimo.y, p.y)
		maximo.x = maxf(maximo.x, p.x + gordo)
		maximo.z = maxf(maximo.z, p.z + gordo)
		maximo.y = maxf(maximo.y, p.y + _alto[i])
	var caja := AABB(minimo, maximo - minimo)
	nodo.custom_aabb = caja
	add_child(nodo)
	_cuadrantes.append(nodo)
	return caja


## Los cuatro numeros de color de una hoja. r es lo que le queda de altura (1 de
## pie, y el tocon o 0 cuando esta cortada), y los otros tres los lee el shader
## para el viento. Se compone aqui y no se lee del MultiMesh porque al cortarla
## no hay ni que volver a traer los datos de la tarjeta: estan todos arriba.
func _color_de(i: int, r: float) -> Color:
	var uv := uv_de_hoja(i)
	return Color(r, uv.x, uv.y, _tonos[i])


## Rejilla de celdas de 2 m con los indices de las hojas de cada una. Solo se
## usa para el corte: al pasar el cabezal se mira la celda de al lado y ya esta.
func _crear_rejilla() -> void:
	_paso = 2.0
	for i in _sembradas:
		var c := _clave(_pos[i])
		if not _rejilla.has(c):
			_rejilla[c] = PackedInt32Array()
		# Hay que leer, anadir y volver a guardar: los PackedInt32Array dentro de
		# un diccionario se copian al sacarlos, y con un append directo
		# _rejilla[c] se perdia la lista entera.
		var lista: PackedInt32Array = _rejilla[c]
		lista.append(i)
		_rejilla[c] = lista


func _clave(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / _paso), floori(p.z / _paso))


## Distancia en el suelo entre dos puntos: solo en X y Z, sin la altura.
##
## Importa mucho. El cabezal esta colgado del arnes, asi que cuando se mira al
## horizonte queda a mas de 0,8 m del suelo, y la hierba a 0,38. Si la cuenta
## fuese en 3D, ninguna hoja estara nunca mas cerca que la diferencia de alturas
## y no se cortaria nada: fue justo lo que pasaba.
func _dist2(a: Vector3, b: Vector3) -> float:
	var dx := a.x - b.x
	var dz := a.z - b.z
	return dx * dx + dz * dz


## Corta la hierba alrededor de un punto y devuelve cuantas hojas ha tumbado.
##
## El cabezal barre un disco en el suelo, digase la altura que tenga. Podria
## exigirse que la cabeza estuviera cerca del cesped para cortar, pero con el
## angulo que tiene el cabezal en la vista eso haria que cortar dependiera de
## cuanto mirases hacia abajo, y con la mirada normal no cortaria nada.
func cortar(centro: Vector3, r: float) -> int:
	var c := _clave(centro)
	var alcance := int(ceil(r / _paso)) + 1
	var r2 := r * r
	var destino := altura_visual()
	var tumbadas := 0
	for dz in range(-alcance, alcance + 1):
		for dx in range(-alcance, alcance + 1):
			var lista: PackedInt32Array = _rejilla.get(Vector2i(c.x + dx, c.y + dz),
				PackedInt32Array())
			for i in lista:
				if _corte[i] > 0.0:
					continue
				if _dist2(_pos[i], centro) > r2:
					continue
				_corte[i] = 1.0
				var nodo := _cuadrantes[_ids[_cuadrante_de[i]]]
				nodo.multimesh.set_instance_custom_data(_dentro_de[i],
					_color_de(i, destino))
				tumbadas += 1
	return tumbadas


## Cuanto le queda a una hoja cortada: nada, o un tocon si se ha pedido.
func altura_visual() -> float:
	return altura_tocon if dejar_tocon else 0.0


## Cuanto le queda de altura a la hoja i: 1 de pie, 0 o el tocon si esta cortada.
func altura_hoja(i: int) -> float:
	if _corte[i] <= 0.0:
		return 1.0
	return altura_visual()


## Donde esta la hoja i. Con el ritmo de la partida esto no se llama; solo en
## las pruebas y para dibujar el rastro.
func posicion_hoja(i: int) -> Vector3:
	return _pos[i]


## Donde cae la hoja i en el mapa del viento, de 0 a 1. El mapa tiene el mismo
## tamano que el campo, asi que se calcula al sembrar y ya no hay que tocarlo.
## El shader la lee de los datos de la instancia.
func uv_de_hoja(i: int) -> Vector2:
	return Vector2((_pos[i].x + radio) / (2.0 * radio),
		(_pos[i].z + radio) / (2.0 * radio))


## El radio con el que estan escritas las UV de ahora mismo. Se guarda aparte
## del `radio` del Inspector para poder detectar cuando se toquen entre si: si
## no, cambiar el radio en caliente dejaba todas las UV con el valor viejo y cada
## hoja empezaba a buscar su celda de viento en el sitio equivocado, que es la
## trampa que se dejo anotada en REVISION.md. Ver refresca_uv_de_viento().
var _radio_uv := 0.0
## Cuantas hojas se han reescrito la ultima vez que hubo que rehacer las UV.
## Lo miran las pruebas, y no el multimesh: leer los datos de la vuelta con
## get_instance_custom_data() solo funciona cuando hay una GPU delante, y las
## pruebas se suelen rodar sin ella, donde devuelve ceros siempre. Aqui la
## verdad esta en el contador, que es de CPU y no se miente.
var _uv_rehechas := 0


## Cuantas hojas reescribio el ultimo refresco de UV. Las pruebas.
func uv_rehechas() -> int:
	return _uv_rehechas


## El tono que se le dio a la hoja i al sembrarla, y que no cambia nunca. Lo
## escriben las pruebas para comprobar que el refresco de UV no lo mueve: el
## tono va con la hoja, no con el sitio donde se busca su viento.
func tono_de(i: int) -> float:
	return _tonos[i] if i >= 0 and i < _tonos.size() else 0.0


## Los cuatro numeros que se le han dado a la hoja i, tal cual los lleva el
## multimesh: (altura que le queda, uv del viento, tono).
##
## Se compone aqui y no se lee del multimesh con get_instance_custom_data()
## porque eso SOLO funciona con una GPU delante: en las pruebas automaticas, que
## van sin ventana, devuelve ceros siempre y la comprobacion no diria nada. Esta
## es la verdad de CPU, y es justo la que se manda a la tarjeta.
##
## Lo piden las pruebas para verificar el reparto de canales del shader: r es lo
## que le queda de altura, g y b son la uv del viento, a es el tono. Si al
## refrescar las uv se tocara el tono o la altura, el cesped cambiaria de color
## o las hojas cortadas se levantarian solas.
func datos_de_hoja(i: int) -> Color:
	return _color_de(i, altura_hoja(i))


## Vuelve a escribir la UV de todas las hojas con el radio de ahora.
##
## El viento se lee del dato de la instancia, y ese dato se escribe una sola vez,
## al sembrar. Si despues se cambia el `radio` desde el Inspector con el juego
## en marcha (que es lo que hacen las pruebas de densidad, y lo que haria
## cualquiera tocando elInspector para ver), la UV se queda con el radio viejo y
## el campo entero se dobla con el viento corrido un metro. Aqui se reescriben los
## dos canales de la UV sin tocar los otros dos: la altura que le queda a la
## hoja (x) y el tono (w) se recuperan de los arrays, no del MultiMesh, porque
## leerlos de la tarjeta grafica seria justo lo que este sistema evita hacer.
##
## Cuesta una pasada por todas las hojas, asi que no se hace cada fotograma: se
## llama desde _process() solo cuando el radio ha cambiado de verdad.
func refresca_uv_de_viento() -> void:
	_radio_uv = radio
	_uv_rehechas = 0
	if radio <= 0.0:
		return
	for i in _sembradas:
		var nodo := _cuadrantes[_ids[_cuadrante_de[i]]]
		nodo.multimesh.set_instance_custom_data(_dentro_de[i],
			_color_de(i, altura_hoja(i)))
		_uv_rehechas += 1
	print("Hierba tipo %d: UV del viento rehecha para un radio de %.1f m (%d hojas)"
		% [tipo, radio, _uv_rehechas])


## Si el radio del Inspector se ha movido respecto al con el que se escribieron
## las UV, las reescribe. Va en _process() y no en un setter porque el setter de
## un export salta al cargar la escena, antes de que esten los arrays.
func _vigilar_radio() -> void:
	if _sembradas == 0 or is_equal_approx(radio, _radio_uv):
		return
	refresca_uv_de_viento()


## Lo que mide de alto y de gorda una hoja concreta. Son los numeros que se
## mandan a la matriz de la instancia, asi que las pruebas los miran: si la
## siembra saliera mal, el recuento de instancias casaria igual y el campo
## entero se quedaria en el origen, fuera de la vista.
func alto_de(i: int) -> float:
	return _alto[i]


func gordo_de(i: int) -> float:
	return _gordo[i]





## Cuantas hojas siguen de pie dentro de un radio.
func de_pie(centro: Vector3, r: float) -> int:
	var c := _clave(centro)
	var alcance := int(ceil(r / _paso)) + 1
	var r2 := r * r
	var n := 0
	for dz in range(-alcance, alcance + 1):
		for dx in range(-alcance, alcance + 1):
			var lista: PackedInt32Array = _rejilla.get(Vector2i(c.x + dx, c.y + dz),
				PackedInt32Array())
			for i in lista:
				if _corte[i] <= 0.0 and _dist2(_pos[i], centro) <= r2:
					n += 1
	return n


## Cuantas hojas de PIE hay por metro cuadrado alrededor de un punto.
##
## La desbrozadora se lo pregunta a esto para notar la maleza: un claro y un
## zarzal se cortan distinto, y lo que cambia no es la hoja sino cuantas hay.
## Se cuentan solo las de pie, porque lo que se nota es lo que queda delante del
## cabezal, no lo que se plantó; y se divide por el area, de modo que el numero
## sale en hojas por m2 y se puede comparar entre campos de tamano distinto.
func densidad_bajo(centro: Vector3, r: float) -> float:
	if r <= 0.0 or _sembradas == 0:
		return 0.0
	return float(de_pie(centro, r)) / maxf(PI * r * r, 0.0001)


## Cuantas hojas hay de pie en el campo entero. Solo para las pruebas.
func total_de_pie() -> int:
	var n := 0
	for i in _sembradas:
		if _corte[i] <= 0.0:
			n += 1
	return n


func total() -> int:
	return _sembradas


## Cuantos cuadrados tiene el campo. Solo para las pruebas.
func num_cuadrantes() -> int:
	return _cuadrantes.size()


## Cuantas casillas tiene la rejilla de cuadrantes, contando las que se han
## quedado vacias. Es el techo de num_cuadrantes(), porque un cuadrado sin
## hojas no se monta. Se calcula del radio y del lado, y no de un numero
## escrito a mano: el campo se puede agrandar desde el Inspector y una prueba
## con el 81 clavado se rompe sola cada vez que se toca el radio.
func casillas_totales() -> int:
	return _lado * _lado


## Lado de la rejilla de cuadrantes. Solo para las pruebas, que lo necesitan
## para saber el techo de num_cuadrantes() sin tener que recalcularlo.
func lado_de_casillas() -> int:
	return _lado


## Cuantas hojas lleva un cuadrado concreto. Solo para las pruebas.
func hojas_de_cuadrante(n: int) -> int:
	if n < 0 or n >= _cuadrantes.size():
		return 0
	return _cuadrantes[n].multimesh.instance_count


## La caja que se le ha puesto al cuadrado n. Solo para las pruebas: sirve para
## comprobar que las cajas son manejables y que entre todas cubren el campo.
func caja_de_cuadrante(n: int) -> AABB:
	if n < 0 or n >= _cuadrantes.size():
		return AABB()
	return _cuadrantes[n].custom_aabb


## Cuantos cuadrados se estan dibujando ahora mismo. Solo para las pruebas.
func cuadrantes_visibles() -> int:
	var n := 0
	for c in _cuadrantes:
		if c.visible:
			n += 1
	return n


## El material que comparten todos los cuadrados. El viento lo busca para meter
## el tiempo en el shader; como es el mismo para todos, tocarlo una vez vale
## para el campo entero.
func material_compartido() -> ShaderMaterial:
	return _material


## La malla de una hoja, que es la misma en todos los cuadrados. La usan las
## pruebas para mirar como esta construida.
func malla() -> ArrayMesh:
	return _malla


## La caja que ocupa el campo entero: la union de las de todos los cuadrados.
## Antes salia del unico MultiMesh y media 68 m de lado, con lo cual no servia
## para nada; ahora sale de las cajas de los cuadrados, que si estan ajustadas.
func caja_del_campo() -> AABB:
	var unida := AABB()
	for i in _cuadrantes.size():
		unida = unida.merge(_cuadrantes[i].custom_aabb)
	return unida


## Apaga los cuadrados que se han quedado lejos. Lo llaman el proceso y las
## pruebas, para poder forzarlo sin esperar a que se mueva la camara.
func _recortar(desde: Vector3) -> void:
	if distancia_maxima <= 0.0:
		return
	var limite2 := distancia_maxima * distancia_maxima
	for c in _cuadrantes.size():
		var lejos := _centros[c].distance_squared_to(desde) > limite2
		_cuadrantes[c].visible = not lejos


## Lo mismo, pero a pelo, para las pruebas.
func forzar_recorte(desde: Vector3) -> void:
	_recortar(desde)
	_mirada = desde


## Solo se recalcula el recorte si la camara se ha movido mas de un metro desde
## la ultima vez. Con 81 cuadrados son 81 comparaciones, que no es nada, pero
## escribirlas sesenta veces por segundo sin necesidad tampoco tiene sentido.
func _process(_delta: float) -> void:
	# Lo primero: si alguien ha movido el radio en caliente, la UV del viento de
	# todas las hojas se ha quedado atrasada. Se mira antes que nada porque el
	# resto de este proceso depende de las UV para que el viento caiga donde
	# toca. Es una comparacion por fotograma, que no es nada.
	_vigilar_radio()
	if _cuadrantes.is_empty() or distancia_maxima <= 0.0:
		return
	var camara := get_viewport().get_camera_3d()
	if camara == null:
		return
	var p := camara.global_position
	if p.distance_squared_to(_mirada) < 1.0:
		return
	_mirada = p
	_recortar(p)


## Corta por donde pase el cabezal mientras el motor este en marcha.
##
## La desbrozadora se busca por el grupo "herramienta" y se guarda en cuanto
## aparece, porque recorrer el arbol en cada fotograma seria tirar CPU. Si no
## esta todavia (depende del orden de arranque) se reintenta, y por eso
## _buscada solo se activa cuando de verdad se ha encontrado.
func _physics_process(_delta: float) -> void:
	if not _buscada:
		var encontradas := get_tree().get_nodes_in_group("herramienta")
		for n in encontradas:
			if n is Desbrozadora:
				_desbrozadora = n as Desbrozadora
				_buscada = true
				break
		if not _buscada:
			return
	if _desbrozadora.get_cortando():
		cortar(_desbrozadora.punto_de_corte(), radio_corte)
