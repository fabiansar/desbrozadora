class_name Montes
extends Node3D

## El material que cae al cortar y se queda en el suelo. Al contrary que antes,
## aqui los restos no desaparecen: se acumulan y forman un monton que tapa la
## vegetacion que quedara debajo.
##
## Es la razon por la que no basta con dar dos pasadas por el mismo sitio. Si
## cortas la base de una columna, el monton tapa justo lo que ibas a rematar, y
## toca rodearlo o apartarlo con la maquina.
##
## Como los montones son terreno que se puede mover, se guardan en una rejilla de
## celdas con la altura del material. Se dibujan con un MultiMesh de cajas, sin
## colision: el jugador no deberia tropezar con ellos, y hacerlos solidos
## complicaria el movimiento por un monton de escombro.

## Lado de la celda del monton, en metros.
const PASO := 0.5
## Altura a la que se aplana un monton, en metros. Por encima se ignora: evita que
## un desbroce masivo cree un muro.
const TOPE := 0.55
## Cuanto se aplana un monton al pasarle la maquina por encima.
const APISONADO := 0.35
## Cuanto tiempo esta un monton protegido del apisonado, en segundos. Es el
## margen para que el material que acaba de caer no se borre en el mismo
## fotograma en que se crea, que era lo que pasaba y hacia que no se viera nada.
const PROTEGIDO := 1.2
## Lo que gana una celda de monton por metro cuadrado de vegetacion cortada.
const RENDIMIENTO := 0.9

var _alturas := {}
## Momento en que se creo cada celda, para protegerla un rato del apisonado.
var _nacido := {}
var _malla: MultiMeshInstance3D
var _total := 0


## Devuelve el unico gestor de montones de la partida, creandolo si hace falta.
static func obtener(arbol: SceneTree) -> Montes:
	for nodo in arbol.get_nodes_in_group("montones"):
		if nodo is Montes:
			return nodo as Montes
	# Se anade en diferido porque en este momento el arbol puede estar montandose
	# (la primera zarza pide montones desde su propio _ready) y anadir un hijo
	# mientras se eso da error en el motor.
	var nuevo := Montes.new()
	nuevo.name = "Montes"
	arbol.root.add_child.call_deferred(nuevo)
	return nuevo


func _init() -> void:
	# El grupo se registra aqui y no en _ready: cualquier vegetation puede pedir
	# los montones en su propio _ready, que corre antes que este, y entonces el
	# nodo no estaria aun en el grupo y se crearia un segundo gestor.
	add_to_group("montones")


func _ready() -> void:
	_crear_malla()


func _crear_malla() -> void:
	var caja := BoxMesh.new()
	caja.size = Vector3(1.0, 1.0, 1.0)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = caja
	# El color por instancia solo se puede activar con el MultiMesh vacio.
	mm.use_colors = true
	mm.instance_count = 0
	_malla = MultiMeshInstance3D.new()
	_malla.name = "Montones"
	_malla.multimesh = mm
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.98
	_malla.material_override = material
	add_child(_malla)


## Anade material en un punto del mundo. La cantidad es en metros de vegetacion
## que ha caido ahi.
func aportar(punto: Vector3, cantidad: float) -> void:
	if cantidad <= 0.0:
		return
	var celda := _clave(punto)
	var actual: float = _alturas.get(celda, 0.0)
	var nuevo := minf(actual + cantidad * RENDIMIENTO, TOPE)
	if nuevo <= actual:
		return
	_alturas[celda] = nuevo
	_nacido[celda] = Time.get_ticks_msec()
	_total += 1
	_dibujar()


## Anade material de golpe desde una poda, para no redibujar la pila entera por
## cada celda que cae. Una caida de verdad son cientos de celdas a la vez, y con
## un `aportar` por celda habia cientos de redibujados de la pila en el mismo
## fotograma. Aqui se suman todas y se dibuja una vez.
func aportar_varios(puntos: PackedVector3Array, cantidades: PackedFloat32Array) -> void:
	var cambios := 0
	for n in mini(puntos.size(), cantidades.size()):
		var cantidad := cantidades[n]
		if cantidad <= 0.0:
			continue
		var celda := _clave(puntos[n])
		var actual: float = _alturas.get(celda, 0.0)
		var nuevo := minf(actual + cantidad * RENDIMIENTO, TOPE)
		if nuevo <= actual:
			continue
		_alturas[celda] = nuevo
		_nacido[celda] = Time.get_ticks_msec()
		_total += 1
		cambios += 1
	if cambios > 0:
		_dibujar()


## Cuanto monton hay en un punto del mundo, en metros.
func altura_en(punto: Vector3) -> float:
	return float(_alturas.get(_clave(punto), 0.0))


## Cuanto monton hay repartido en un disco. Para las pruebas.
## Devuelve la media ponderada por area, en metros.
func densidad(centro: Vector3, radio: float) -> float:
	if radio <= 0.0:
		return 0.0
	var total := 0.0
	var celdas := 0
	for clave in _alturas:
		var centro_celda := _centro_de(clave)
		if centro_celda.distance_to(centro) > radio:
			continue
		total += float(_alturas[clave])
		celdas += 1
	return total / float(maxi(celdas, 1))


## Aplana los montones que pilla la maquina al pasar. Esto es lo que permite
## apartarlos y seguir trabajando donde estaban.
func pisar(centro: Vector3, radio: float) -> int:
	if radio <= 0.0:
		return 0
	var pisados := 0
	var ahora := Time.get_ticks_msec()
	for clave in _alturas.keys():
		var centro_celda := _centro_de(clave)
		if centro_celda.distance_to(centro) > radio:
			continue
		# Un monton recien creado todavia no se aplana: lo que acaba de caer del
		# cabezal todavia no se ha asentado.
		if ahora - int(_nacido.get(clave, 0)) < int(PROTEGIDO * 1000.0):
			continue
		var actual: float = _alturas[clave]
		var nuevo := maxf(actual - APISONADO, 0.0)
		if nuevo == actual:
			continue
		_alturas[clave] = nuevo
		pisados += 1
		if nuevo <= 0.0:
			_alturas.erase(clave)
			_nacido.erase(clave)
	if pisados > 0:
		_dibujar()
	return pisados


## Espera a que pase la herramienta y apisone lo que haya.
##
## Se pregunta a la de la mano en cada fotograma y no se guarda, por el mismo
## motivo que en la hierba y en la zarza: con la referencia guardada, al cambiar
## de herramienta en el inventario se seguirian aplastando montones con la que
## ya no llevas.
func _physics_process(_delta: float) -> void:
	if _alturas.is_empty():
		return
	var herramienta := get_tree().get_first_node_in_group("herramienta")
	if herramienta == null or not herramienta.has_method("punto_de_corte"):
		return
	var cabeza: Vector3 = herramienta.punto_de_corte()
	var radio: float = herramienta.radio_corte_actual()
	pisar(cabeza, radio)


func _clave(punto: Vector3) -> Vector2i:
	return Vector2i(floori(punto.x / PASO), floori(punto.z / PASO))


func _centro_de(clave: Vector2i) -> Vector3:
	return Vector3((float(clave.x) + 0.5) * PASO, 0.0,
		(float(clave.y) + 0.5) * PASO)


## Dibuja el monton como una pila de cajas por celda. Se redibuja entero porque
## son pocas celdas: la alternativa de ir moviendo instancias seria mas lenta de
## escribir y mas facil que se desincronice.
func _dibujar() -> void:
	if _malla == null:
		return
	var mm := _malla.multimesh
	# El numero de instancias se pone UNA vez, antes del bucle, y no se toca
	# dentro. Cada vez que cambia, Godot rehace el buffer del MultiMesh y borra
	# lo que hubiera escrito antes, con lo que de toda la pila se queda en pie
	# solo la ultima caja. La trampa es la misma que habia en la zarza; el
	# comentario de ahi explica el por que con mas detalle.
	var total := 0
	for clave in _alturas:
		var alto: float = _alturas[clave]
		if alto > 0.0:
			total += maxi(1, int(ceil(alto / 0.12)))
	mm.instance_count = maxi(total, 1)
	var instancias := 0
	for clave in _alturas:
		var alto: float = _alturas[clave]
		if alto <= 0.0:
			continue
		var capas := maxi(1, int(ceil(alto / 0.12)))
		var por_capa := alto / float(capas)
		for c in capas:
			var centro := _centro_de(clave)
			centro.y = por_capa * (float(c) + 0.5)
			var escala := Vector3(PASO * 0.92, por_capa * 0.95, PASO * 0.92)
			mm.set_instance_transform(instancias,
				Transform3D(Basis().scaled(escala), centro))
			# Un tono pardo, mas oscuro cuanto mas alto, para que se vea el
			# monton de lado en la foto.
			var t := por_capa * (float(c) + 0.5) / maxf(alto, 0.001)
			mm.set_instance_color(instancias,
				Color(0.20, 0.15, 0.08).lerp(Color(0.32, 0.26, 0.14), t))
			instancias += 1
	for k in range(instancias, mm.instance_count):
		mm.set_instance_transform(k, Transform3D(Basis().scaled(
			Vector3(0.001, 0.001, 0.001)), Vector3.ZERO))


## Numero de celdas con monton. Para las pruebas.
func celdas() -> int:
	return _alturas.size()
