class_name Hierba
extends Vegetacion

## El campo de hierba.
##
## Las hojas van repartidas en CUADRANTES, cada uno con su propio MultiMesh, en
## vez de todas juntas en uno solo. El motivo es el culling:
##
## Con un unico MultiMesh para todo el campo, su caja envolvente seria tan grande
## que siempre se solaparia con la pantalla. El motor no podria descartar hojas
## aunque solo se viera un trozo de cesped. Con cuadrantes, cada uno lleva su caja
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
## - Leer las transformaciones del motor en cada fotograma seria una chapuza.
##   Con los arrays se va directo.
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
@export_group("Forma de la hoja")
## Cuanto se estrecha la hoja al subir. Con 0,88 es una brizna: arriba es un pelo.
## Con 0,30 se queda ancha casi hasta la punta, que es lo que hace que una planta
## se lea como hoja y no como hierba.
##
## Este numero, con los colores y el grosor, es **toda** la diferencia entre un
## cesped y una zarza. No hay ni un branching en el codigo: las tres plantas son
## la misma hoja con estos numeros distintos, y por eso se pueden comparar entre
## si sin ningun caso especial.
@export_range(0.0, 0.95, 0.01) var hoja_estrecha := 0.88
## Cuanto se curva la hoja hacia delante. El cesped se dobla un poco; una hoja
## dura se dobra casi nada y se queda tiesa.
@export_range(0.0, 0.4, 0.005) var hoja_curva := 0.09
## Giro de la hoja al subir, en grados. Da el twist que evita que el campo se vea
## como un huerto de cartones iguales.
@export_range(0.0, 45.0, 0.5) var hoja_tuerce := 12.0
## Radio del campo, en metros. Fuera no hay hierba, y las hojas del final se
## achican para que el campo se acabe sin que se vea un círculo en el suelo.
@export_range(5.0, 90.0, 1.0) var radio := 34.0
## Hojas por metro cuadrado. El total también depende del radio, formación,
## borde y semilla. Por debajo de 8 se ve ralo.
@export_range(1.0, 60.0, 0.5) var densidad := 30.0
## Desde que fraccion del radio se empieza a achicar el campo. Si vale 1 el
## cesped se corta en seco y se ve un circulo perfecto.
@export_range(0.3, 1.0, 0.01) var borde := 0.72
## Semilla del reparto, para que el campo salga siempre igual y se puedan
## comparar dos pruebas.
@export var semilla := 90210

## Lado del cuadrado de cada trozo de campo, en metros. Se ajusta por instancia
## para equilibrar la granularidad del culling con el número de llamadas de dibujo.
@export_range(2.0, 24.0, 0.5) var lado_cuadrante := 8.0
## A que distancia se apaga un cuadrante. Con 0 no hay recorte por distancia y
## se queda solo el culling de la vista, que tambien funciona. Por defecto va
## por encima del radio del campo, para que de momento no se apague nada y el
## recorte este preparado ya para cuando el campo crezca.
@export_range(0.0, 120.0, 1.0) var distancia_maxima := 42.0

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

## Trabajo por sector: las hojas de pie de cada sector, ordenadas de dentro hacia
## fuera, y lo que a cada uno le sobra de la cuota (para que a la larga sectors
## con pocas hojas no se queden cortos). Se reutilizan: son listas que se vacian
## y se rellenan en cada corte, y no hay que crear nada por fotograma.
var _sector_hojas: Array = []
var _sector_por_cortar: PackedFloat32Array = PackedFloat32Array()
## Cuantas hojas lleva cortadas cada sector en este fotograma, para poder seguir
## por donde iba y saber cuantas le quedan.
var _cortadas_en: PackedInt32Array = PackedInt32Array()
var _rejilla := {}
var _paso := 2.0
## Parte decimal del presupuesto de corte que no ha cabido en el fotograma
## anterior. Sin esto, un ritmo de 1,5 hojas por fotograma cortaria una hoja
## cada dos fotogramas y la mitad del tiempo no pasaria nada.
var _presupuesto_fraccion := 0.0
var _lado := 0
var _sembradas := 0
## Ultima posicion desde la que se refresco el recorte por distancia. Solo se
## recalcula si la camara se ha movido mas de un metro, porque si no se estaria
## escribiendo lo mismo en 81 nodos sesenta veces por segundo.
var _mirada := Vector3(1.0e9, 0.0, 0.0)


func _ready() -> void:
	add_to_group("hierba")
	add_to_group("vegetacion")
	_crear_material()
	_sembrar()
	_crear_rejilla()
	# El nombre de la planta en los avisos. Separan los tres: decir "maleza tipo 3"
	# de la zarza es exactamente lo que hace que el tier 3 parezca que va aparte.
	var nombre: String = ["cesped", "maleza alta", "zarza"][clampi(tipo - 1, 0, 2)]
	print("%s: %d hojas de %.0f cm en %.0f m de radio (%.1f por m2)"
		% [nombre.capitalize(), _sembradas, altura * 100.0, radio, densidad])
	print("  en %d cuadrantes de %.0f m, culling por caja y por distancia"
		% [_cuadrantes.size(), lado_cuadrante])
	if formacion > 0.0:
		print("  en matas: se siembra el %.0f %% del terreno (formacion %.2f), dureza %.1f"
			% [(1.0 - formacion * 0.85) * 100.0, formacion, dureza])


## Vuelve a generar el campo con los exports actuales.
##
## Se usa en las herramientas de medición al cambiar densidad o radio. Mantiene
## el material compartido, pero sustituye todos los cuadrantes y reconstruye la
## rejilla de corte para que los datos visuales y lógicos sigan sincronizados.
func regenerar() -> void:
	for cuadrante in _cuadrantes:
		if is_instance_valid(cuadrante):
			cuadrante.queue_free()
	_cuadrantes.clear()
	_centros.clear()
	_ids.clear()
	_cuadrante_de.clear()
	_dentro_de.clear()
	_rejilla.clear()
	_sembradas = 0
	_uv_rehechas = 0
	_radio_uv = 0.0
	_mirada = Vector3(1.0e9, 0.0, 0.0)
	_sembrar()
	_crear_rejilla()
	print("Hierba tipo %d regenerada: %d hojas en %d cuadrantes"
		% [tipo, _sembradas, _cuadrantes.size()])


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
## triangulos, que es lo que se ve sin mirar de cerca y sale muy barato. El
## total de triangulos depende de las hojas que se siembren y sus cuadrantes.
##
## La forma sale de tres numeros del preset (`hoja_estrecha`, `hoja_curva`,
## `hoja_tuerce`) y no de codigo, que es lo que permite que las tres plantas
## compartan la misma hoja y se diferencien solo en como se estrecha, como se
## dobla y como se retuerce.
func _hoja() -> ArrayMesh:
	var t := SurfaceTool.new()
	t.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tramos := 3
	for i in tramos + 1:
		var u := float(i) / float(tramos)
		# Se estrecha al subir, un poco de curva hacia delante y algo de
		# torsion, para que no sea un carton plano.
		var ancho := (1.0 - u * hoja_estrecha) * 0.5
		var curva := u * u * hoja_curva
		var giro := deg_to_rad(hoja_tuerce) * u
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
			# El suelo de pruebas es plano y está en Y=0. Las raíces quedan un
			# centímetro por encima para evitar z-fighting.
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


## Cuantas hojas siguen de pie. Para las pruebas y para el interfaz: cuanto queda
## en un campo es lo unico que se puede medir de un vistazo, porque
## `altura_visual()` devuelve SIEMPRE la altura del tocon, que es la misma tanto
## si el campo esta entero como si esta recien cortado.
## La hoja mas alta que hay de pie ahora mismo, en metros.
##
## Para las pruebas: la zarza tiene que caber en el alcance del morro, y eso se
## comprueba contra la hoja de verdad, con su variacion, y no contra el numero
## del preset. Con `variacion_altura` al alza, la hoja mas alta es mas alta que
## la que dice el preset, y es la que hay que poder cortar.
func hoja_en_pie_mas_alta() -> float:
	var alta := 0.0
	for i in _corte.size():
		if _corte[i] > 0.0:
			continue
		alta = maxf(alta, _alto[i])
	return alta


func hojas_en_pie() -> int:
	var total := 0
	for i in _corte.size():
		if _corte[i] <= 0.0:
			total += 1
	return total


## Que tipo de vegetacion es: 1 el cesped, 2 la maleza alta. Lo decide el
## atributo `tipo` de la escena, y de ahi lo saca la herramienta para saber si su
## cabezal puede con esto.
func tipo_vegetacion() -> int:
	return tipo


## El corte del contrato comun. La desbrozadora tiene su propia logica de
## barrido y pregunta por dentro, asi que esta funcion es la puerta de entrada
## para las herramientas que solo saben cortar "lo que haya aqui": la hoz.
func cortar_por_banda(centro: Vector3, radio: float, presupuesto: float = -1.0) -> int:
	return cortar(centro, radio, presupuesto)


## Corta la hierba alrededor de un punto y devuelve cuantas hojas ha tumbado.
##
## El cabezal barre un disco en el suelo, digase la altura que tenga. Podria
## exigirse que la cabeza estuviera cerca del cesped para cortar, pero con el
## angulo que tiene el cabezal en la vista eso haria que cortar dependiera de
## cuanto mirases hacia abajo, y con la mirada normal no cortaria nada.
## Reparte en `_sector_hojas` las hojas de pie que caen dentro del disco, y las
## ordena de dentro hacia fuera. Devuelve si hay alguna.
##
## Esto es lo que hace que el corte se vea organico, y salio de aqui porque
## `cortar()` era ya ilegible. Repartido en orden aleatorio, un sector entero se
## limpiaba mientras el de al lado conservaba todas sus hojas, y el claro salia
## hecho de manchurrones. Repartido por sectores, cada uno pierde lo mismo en el
## mismo tiempo, el frente avanza como un frente, y el claro se abre limpio.
## Reparte en `_sector_hojas` las hojas de pie que caen dentro del disco, y dentro
## de cada sector las ordena de dentro hacia fuera. Devuelve si hay alguna.
##
## Esto es lo que hace que el corte se vea organico, y salio de aqui porque
## `cortar()` se habia vuelto ilegible. Repartido en orden aleatorio, un sector
## entero se limpiaba mientras el de al lado conservaba todas sus hojas, y el
## claro salia hecho de manchurrones. Repartido por sectores, cada uno pierde lo
## mismo en el mismo tiempo, el frente avanza como un frente, y el claro se abre
## limpio.
func _repartir_en_sectores(centro: Vector3, c: Vector2i, r: float,
		alcance: int) -> bool:
	if _sector_hojas.size() != SECTORES:
		_sector_hojas.resize(SECTORES)
		_sector_por_cortar.resize(SECTORES)
		_cortadas_en.resize(SECTORES)
		for k in SECTORES:
			_sector_hojas[k] = []
	var hay_algo := false
	for k in SECTORES:
		_sector_hojas[k].clear()
		_cortadas_en[k] = 0
		# OJO: `_sector_por_cortar` NO se limpia aqui a proposito. Es la parte
		# decimal que le ha sobrado a este sector, y tiene que sobrevivir de un
		# fotograma a otro, que es justo para lo que existe: con 2,5 hojas por
		# fotograma y 8 sectores salen a 0,31 por sector, y si se limpia cada
		# fotograma la parte entera se queda siempre en cero y **no se corta
		# absolutamente nada**.
	var lado := alcance * 2 + 1
	for n in range(lado):
		var dz := n - alcance
		for m in range(lado):
			var dx := m - alcance
			var lista: PackedInt32Array = _rejilla.get(
					Vector2i(c.x + dx, c.y + dz), PackedInt32Array())
			for i in lista:
				if _corte[i] > 0.0:
					continue
				# El borde del disco no es un borde. Cada hoja tiene su propio
				# umbral, fijo, que sale de DONDE ESTA y no del azar: unas quedan
				# dentro antes que otras y el recorte sale con los dientes, como
				# el cesped recien cortado. Y como el umbral es fijo, una hoja no
				# entra y sale entre fotogramas: el claro no parpadea.
				var alcance_hoja := r * (BORDE_MINIMO + BORDE_RANGO * _desvio_de(i))
				var d2 := _dist2(_pos[i], centro)
				if d2 > alcance_hoja * alcance_hoja:
					continue
				# A que sector va, por el angulo alrededor del centro: 45 grados.
				var angulo := atan2(_pos[i].z - centro.z, _pos[i].x - centro.x)
				var sector := int((angulo + PI) / TAU * float(SECTORES))
				_sector_hojas[clampi(sector, 0, SECTORES - 1)].append(
						Vector2(sqrt(d2), float(i)))
				hay_algo = true
	if not hay_algo:
		return false
	for k in SECTORES:
		# De dentro hacia fuera, que es lo que hace que el frente sea un frente
		# y no una corona de agujas: lo primero que se cae es lo de en medio.
		_sector_hojas[k].sort_custom(func(a: Vector2, b: Vector2) -> bool:
			return a.x < b.x)
	return true


func cortar(centro_mundo: Vector3, r: float, presupuesto: float = -1.0) -> int:
	# **OJO: `centro` entra en coordenadas del MUNDO.** Las hojas, la rejilla y las
	# casillas viven en el sistema LOCAL de la planta, y antes se comparaban sin
	# convertir. Solo se notaba con las zarzas, que son las unicas que NO estan en el
	# origen del mundo: la primera esta a (0, 0, -7), con lo que el corte caia
	# siete metros mas alla de donde estaba el cabezal, y los restos salian ahi.
	# Con el cesped y la maleza, que estan en (0, 0, 0), local y mundo coinciden y
	# el fallo llevaba meses escondido.
	var centro := to_local(centro_mundo)
	var c := _clave(centro)
	var alcance := int(ceil(r / _paso)) + 1
	var r2 := r * r
	var destino := altura_visual()
	var tumbadas := 0
	# Sin presupuesto se come la banda entera, que es lo que hacen la hoz y las
	# pruebas. Con presupuesto, que es lo que hacen los cabezales, solo se quitan
	# las hojas que caben en el tiempo que ha pasado.
	#
	# OJO, hay DOS acumuladores de parte decimal y no es una duplicacion:
	#
	#   - Este, `_presupuesto_fraccion`, es el **freno grueso**. Con el nylon
	#     contra la zarza el presupuesto baja a 0,08 hojas por fotograma, o sea
	#     menos de una: sin este freno pasarian doce fotogramas enteros sin cortar
	#     nada y luego un tiron. Aqui solo decide si este fotograma se corta algo.
	#
	#   - Los de `_sector_por_cortar`, mas abajo, son el **reparto fino**: el uno
	#     octavo para cada sector, y cual de los ocho entra primero.
	#
	# Quitar este es facil y es un fallo: nadie ve un salto de doce fotogramas en
	# una prueba corta y aparece en el juego, con la hoz lenta, parandose a esperar.
	var limite := -1
	if presupuesto >= 0.0:
		var disponible := presupuesto + _presupuesto_fraccion
		limite = int(disponible)
		_presupuesto_fraccion = disponible - float(limite)
		if limite <= 0:
			return 0
	if not _repartir_en_sectores(centro, c, r, alcance):
		return 0

	# La cuota de cada uno. Sin presupuesto se come el disco entero, que es lo que
	# hacen la hoz y las pruebas; con presupuesto, el uno octavo para cada uno.
	#
	# La parte decimal se guarda por sector y no global: si se guardara global, un
	# fotograma de 1,2 hojas daria un sector entero y los otros siete nada, que es
	# justo lo que se quiere evitar. Guardandola por sector, la media sale a uno
	# exacto por unidad de tiempo.
	return _repartir_cuotas(limite, presupuesto, destino)


## Corta las primeras `cuantas` hojas de un sector, de dentro hacia fuera, y
## devuelve cuantas ha cortado de verdad. Lleva la cuenta por sector en
## `_cortadas_en`, que es lo que permite que un sector le ceda su cuota sobrante
## a otro sin tener que volver a mirar las hojas.
func _cortar_del_sector(k: int, cuantas: int, destino: float) -> int:
	var hechas := 0
	var lista: Array = _sector_hojas[k]
	while _cortadas_en[k] < lista.size() and hechas < cuantas:
		var i := int(lista[_cortadas_en[k]].y)
		_cortadas_en[k] += 1
		_corte[i] = 1.0
		var nodo := _cuadrantes[_ids[_cuadrante_de[i]]]
		nodo.multimesh.set_instance_custom_data(_dentro_de[i],
			_color_de(i, destino))
		hechas += 1
	return hechas



## Reparte el presupuesto entre los sectores y corta. Sin presupuesto se come
## el disco entero, que es lo que hacen la hoz y las pruebas.
##
## La parte decimal se guarda **por sector** y no global: si se guardara global, un
## fotograma de 1,2 hojas daria un sector entero y los otros siete nada, que es justo
## lo que se quiere evitar. Guardandola por sector, la media sale a uno exacto por
## unidad de tiempo.
func _repartir_cuotas(limite: int, presupuesto: float, destino: float) -> int:
	if limite < 0:
		# Sin presupuesto: se come el disco entero, que es lo que hacen la hoz y
		# las pruebas.
		var todas := 0
		for k in SECTORES:
			todas += _cortar_del_sector(k, _sector_hojas[k].size(), destino)
		return todas
	# Con presupuesto: el uno octavo para cada uno, empezando por un sector distinto
	# cada fotograma, para que ninguno se lleve siempre la parte entera.
	var primero: int = randi() % SECTORES
	var cortadas := 0
	for paso in SECTORES:
		var k: int = (primero + paso) % SECTORES
		var disponibles: int = _sector_hojas[k].size()
		if disponibles <= 0:
			continue
		var disponible := presupuesto / float(SECTORES) + _sector_por_cortar[k]
		var cuota: int = mini(int(disponible), disponibles)
		_sector_por_cortar[k] = disponible - float(cuota)
		cortadas += _cortar_del_sector(k, cuota, destino)
		# Si a este sector no le quedaban hojas, su parte sobrante la cogen los
		# sectores que aun tienen, o la maquina iria mas lenta en los claros y en
		# los bordes del campo, que es donde mas se nota.
		if cuota < disponibles:
			var sobra := disponible - float(cuota)
			for otro in SECTORES:
				var libre: int = _sector_hojas[otro].size() - _cortadas_en[otro]
				if libre <= 0:
					continue
				var cogidas: int = mini(int(sobra), libre)
				cortadas += _cortar_del_sector(otro, cogidas, destino)
				sobra -= float(cogidas)
				if sobra < 1.0:
					break
	return cortadas


## El desvio de cada hoja, de 0 a 1, fijo para siempre.
##
## Sale de un seno de su posicion, que es la manera corta de tener ruido que no
## necesita tabla ni semilla: la misma hoja sale siempre con el mismo numero, y
## dos hojas que estan al lado salen distintas. Con `randf()` el borde del claro
## cambiaba en cada fotograma y la hierba parpadeaba.
## El borde del disco va entre el 78 % y el 122 % del radio, segun la hoja. Por
## eso una comprobacion de "no queda nada de pie" solo puede mirar el centro, y
## solo hasta el minimo.
const BORDE_MINIMO := 0.78
const BORDE_RANGO := 0.44
## En cuantos sectores se parte el disco al repartir el corte.
##
## OCHO. Pocos, y anchos: el objetivo es que el frente de corte se vea continuo,
## y con treinta y dos sectores el reparto sale fino y se nota el rayado. Con ocho
## sectores de 45 grados, un cuarto de disco por sector, el frente es limpio.
const SECTORES := 8


func _desvio_de(i: int) -> float:
	var v := sin(_pos[i].x * 91.733 + _pos[i].z * 47.219) * 43758.5453
	return v - floorf(v)


## Cuanto le queda a una hoja cortada: nada, o un tocon si se ha pedido.
func altura_visual() -> float:
	return altura_tocon if dejar_tocon else 0.0


## Cuanto le queda de altura a la hoja i: 1 de pie, 0 o el tocon si esta cortada.
## Cuanto material se ha cortado en total, sumando la fraccion de cada hoja.
##
## Antes el corte era una bandera (0 o 1) y esto no tenia sentido: o estaba
## cortada o no. Ahora una hoja se queda a medias y el total es la magnitud que de
## verdad se esta midiendo. La usan las pruebas para saber cuando una pasada ha
## terminado, que contando hojas enteras se para antes de tiempo.
func material_cortado() -> float:
	var total := 0.0
	for v in _corte:
		total += v
	return total


## Cuanto le queda de alto a la hoja i, como fraccion de su altura entera: o la
## entera (1,0) o el tocon. De escalon, a proposito; se probo continuo y
## hacia el corte mucho mas lento.
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
## Cuantas hojas hay de pie en un disco del mundo, en coordenadas del mundo. Ver
## la nota de `cortar`: por eso el motor, que mide en el mundo, media a la zarza
## siete metros mas alla de donde estaba.
func de_pie(centro_mundo: Vector3, r: float) -> int:
	var centro := to_local(centro_mundo)
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
## Hojas por metro cuadrado en un punto del mundo. Lo mismo que `de_pie`, con el
## punto en coordenadas del mundo: ver la nota de `cortar`.
func densidad_bajo(centro_mundo: Vector3, r: float) -> float:
	if r <= 0.0 or _sembradas == 0:
		return 0.0
	return float(de_pie(centro_mundo, r)) / maxf(PI * r * r, 0.0001)


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
## Se construye como unión de las cajas de los cuadrantes actuales.
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
	# El recorte compara los centros de los cuadrados, que son locales, con la
	# camara, que es del mundo. Con la planta en el origen no se nota; con las
	# zarvas displaced se descartan los cuadrados equivocados y media mata deja de
	# dibujarse mientras trabajas en ella.
	_recortar(to_local(p))


## Corta por donde pase la herramienta mientras este cortando.
##
## La herramienta se busca en el grupo "herramienta" en cada fotograma y no se
## guarda. Antes se guardaba la primera desbrozadora que aparecia, con lo que
## al cambiar de herramienta en el inventario el campo se quedaba cortando con
## la que estaba en la mano antes, que ya no corta. Es una busqueda en un grupo
## con un elemento, no un recorrido del arbol: sale gratis.
func _physics_process(delta: float) -> void:
	var herramienta := get_tree().get_first_node_in_group("herramienta")
	if herramienta == null or not herramienta.has_method("cabezal_puede_cortar"):
		return
	if herramienta.cortando and herramienta.cabezal_puede_cortar(tipo):
		var punto: Vector3 = herramienta.punto_de_corte()
		var radio: float = herramienta.radio_corte_actual()
		# Cuanto cabe en este fotograma. Sin metodo de tasa (una herramienta de
		# prueba, o la hoz) es sin limite, como antes.
		var presupuesto := -1.0
		if herramienta.has_method("tasa_corte_para"):
			presupuesto = herramienta.tasa_corte_para(tipo, tasa_corte_base()) \
				* delta
		herramienta.registrar_corte(tipo, cortar_y_soltar(punto, radio, presupuesto))


## Corta y suelta restos, que es lo que hace una herramienta de verdad.
##
## Existe como una sola funcion y no como dos porque **cortar sin soltar no se ve
## nada**: una prueba que llama a `cortar()` y luego comprueba que hay restos en
## el suelo falla, y no porque los restos no salgan, sino porque se le ha
## olvidado la segunda mitad. Y ese fallo es facil de "arreglar" en la prueba
## llamando a la funcion privada, con lo que la prueba deja de probar el juego y
## pasa a probar su propia copia.
func cortar_y_soltar(centro: Vector3, radio: float, presupuesto: float = -1.0) -> int:
	var cortadas := cortar(centro, radio, presupuesto)
	_soltar_restos(centro, cortadas)
	return cortadas


## Al cortar no queda la planta en su sitio: aparecen restos sueltos que salen
## despedidos y se apagan solos. Aqui solo se avisa a `Restos` de cuantas hojas
## han caido, de donde y de que planta: la cuenta entera (trozos por hoja,
## cuando se junta una rafaga, cuanto vive el trozo) vive en `scripts/restos.gd`,
## que es el unico sitio donde se ajusta el escombro.
func _soltar_restos(origen: Vector3, hojas: int) -> void:
	if hojas <= 0:
		return
	var direccion := Vector3(randf_range(-0.3, 0.3), 0.0,
		randf_range(-0.3, 0.3))
	# El tamano del trozo va con el de la planta: una brizna de 4,5 mm deja un
	# trozo pequeño y un cano de 26 cm deja un trozo grande. El tope va en 1,5,
	# con lo que el trozo mayor mide 15 cm, que es una hoja de mata troceada y
	# no un tablón.
	var escala := clampf(grosor / 0.12, 0.7, 1.5)
	Restos.obtener(get_tree()).soltar(origen, hojas, direccion,
		tono_punta.lerp(tono_pie, randf() * 0.5), escala, tipo)
