extends Node3D

## Sustituye los brazos de pose del modelo por extremidades que siguen los
## marcadores reales de la herramienta que llevas en la mano, sin mover el cuerpo
## con ella.
##
## Hay tres estados, y son los tres de verdad, no un caso raro:
##   - Dos agarres (la desbrozadora): las dos manos en los puños, como hasta
##     ahora.
##   - Un agarre (la hoz): la derecha en el mango y la izquierda colgando, que
##     es como se lleva una herramienta de una mano.
##   - Ningun agarre: las manos sueltas al lado del cuerpo. Es lo que se ve al
##     elegir un hueco vacio con la rueda, y tiene que ser una pose y no un
##     fallo: si las desaparececieran, el jugador creeria que se ha roto el personaje.
##
## La herramienta se pregunta al inventario y no se busca en el grupo, porque
## el grupo "herramienta" solo lo tiene la que esta en la mano. Asi al cambiar de
## hueco las manos saltan al sitio correcto en el mismo fotograma.

## Los nombres de agarre de la desbrozadora: uno por puño.
const NOMBRES_AGARRE := ["AgarreIzquierdo", "AgarreDerecho"]
## El nombre del agarre de una herramienta de una mano.
const NOMBRE_AGARRE_SOLO := "Agarre"
## Donde se quedan las manos cuando no hay nada que agarrar, en el sistema del
## jugador: al lado del cuerpo, a la altura de la cintura.
##
## OJO con la altura: estas coordenadas van desde el origen del jugador, que esta
## a los PIES. Por eso el 0,80 y no un 0,2: con la mano casi a nivel del suelo se
## metia entre la maleza y no se veia, y con las manos vacias no verse es justo lo
## que hace pensar que el juego esta roto.
const MANOS_SUELTAS := Vector3(0.26, 0.80, -0.12)

## Activalos desde el inspector para comparar la silueta completa en la camara.
@export var mostrar_torso := true
@export var mostrar_parte_inferior := true
@export_category("Pose GoPro")
@export var altura_hombro := 1.40
@export var separacion_hombros := 0.19
@export_range(0.35, 0.7, 0.01) var fraccion_codo := 0.52
@export var apertura_codo := 0.06
@export var flexion_codo := 0.06

var _jugador: Jugador
var _herramienta: Node3D
var _inventario: Inventario
## Los agarres de la herramienta de ahora. Cero si no hay herramienta, uno si es
## de una mano, dos si es de dos.
var _agarres: Array[Marker3D] = []
var _superiores: Array[MeshInstance3D] = []
var _antebrazos: Array[MeshInstance3D] = []
var _manos: Array[MeshInstance3D] = []


func _ready() -> void:
	_jugador = get_parent() as Jugador
	var modelo := _jugador.get_node_or_null("Cuerpo/Modelo") if _jugador != null else null
	_ocultar_pieza(modelo, "Cabeza")
	_ocultar_pieza(modelo, "BrazoIzq")
	_ocultar_pieza(modelo, "BrazoDer")
	if not mostrar_torso:
		_ocultar_pieza(modelo, "Torso")
	if not mostrar_parte_inferior:
		_ocultar_pieza(modelo, "Personaje")
	_inventario = _buscar_inventario()
	_herramienta = _herramienta_en_mano()
	_resolver_agarres()
	_crear_brazos_visibles()


func _process(_delta: float) -> void:
	if _jugador == null:
		return
	# Se pregunta al inventario en cada fotograma y no solo cuando el nodo es
	# invalido, porque aqui el problema no es que la herramienta desaparezca:
	# es que la de ahora sea OTRA. Comparar el nodo es lo que hace que al girar
	# la rueda las manos se queden en el manillar de la desbrozadora y no en el
	# mango de la hoz.
	var en_mano := _herramienta_en_mano()
	if en_mano != _herramienta:
		_herramienta = en_mano
		_resolver_agarres()
	_mostrar_brazos(true)
	if _herramienta == null:
		_posear_manos_sueltas()
		return
	if _agarres.is_empty():
		_resolver_agarres()
	for i in range(2):
		var muneca_local := Vector3.ZERO
		if i < _agarres.size() and is_instance_valid(_agarres[i]):
			muneca_local = _jugador.to_local(_agarres[i].global_position)
		else:
			# Una herramienta de una mano solo tiene un agarre: la otra mano se
			# queda colgando, al lado del cuerpo, como cuando no llevas nada.
			muneca_local = MANOS_SUELTAS * (-1.0 if i == 0 else 1.0)
		var lado := -1.0 if i == 0 else 1.0
		var hombro_local := Vector3(lado * separacion_hombros, altura_hombro, -0.08)
		var codo_local := hombro_local.lerp(muneca_local, fraccion_codo)
		codo_local += Vector3(lado * apertura_codo, -flexion_codo, 0.05)
		var codo := _jugador.to_global(codo_local)
		var hombro := _jugador.to_global(hombro_local)
		_actualizar_segmento(_superiores[i], hombro, codo, 0.028)
		_actualizar_segmento(_antebrazos[i], codo, _jugador.to_global(muneca_local), 0.030)
		_manos[i].global_position = _jugador.to_global(muneca_local)


## Las manos sueltas: los dos brazos al lado del cuerpo. Se usa cuando no hay
## herramienta, y tambien para la mano libre de una herramienta de una mano.
func _posear_manos_sueltas() -> void:
	for i in range(2):
		var lado := -1.0 if i == 0 else 1.0
		var muneca_local := MANOS_SUELTAS * lado
		var hombro_local := Vector3(lado * separacion_hombros, altura_hombro, -0.08)
		var codo_local := hombro_local.lerp(muneca_local, fraccion_codo)
		codo_local += Vector3(lado * apertura_codo, -flexion_codo, 0.05)
		_actualizar_segmento(_superiores[i], _jugador.to_global(hombro_local),
			_jugador.to_global(codo_local), 0.028)
		_actualizar_segmento(_antebrazos[i], _jugador.to_global(codo_local),
			_jugador.to_global(muneca_local), 0.030)
		_manos[i].global_position = _jugador.to_global(muneca_local)


func _mostrar_brazos(visibles: bool) -> void:
	for pieza in _superiores:
		pieza.visible = visibles
	for pieza in _antebrazos:
		pieza.visible = visibles
	for pieza in _manos:
		pieza.visible = visibles


func _crear_brazos_visibles() -> void:
	var chaqueta := _material(Color(0.88, 0.25, 0.055))
	var guante := _material(Color(0.13, 0.29, 0.16))
	for i in range(2):
		_superiores.append(_crear_capsula("MangaSuperior%d" % i, 0.028, chaqueta))
		_antebrazos.append(_crear_capsula("MangaAntebrazo%d" % i, 0.030, chaqueta))
		_manos.append(_crear_mano("Guante%d" % i, guante))


func _crear_capsula(nombre: String, radio: float, material: StandardMaterial3D) -> MeshInstance3D:
	var malla := CapsuleMesh.new()
	malla.radius = radio
	malla.height = radio * 2.0
	malla.radial_segments = 7
	malla.rings = 2
	var nodo := MeshInstance3D.new()
	nodo.name = nombre
	nodo.mesh = malla
	nodo.material_override = material
	add_child(nodo)
	return nodo


func _crear_mano(nombre: String, material: StandardMaterial3D) -> MeshInstance3D:
	var malla := SphereMesh.new()
	malla.radius = 0.050
	malla.height = 0.100
	malla.radial_segments = 8
	malla.rings = 4
	var nodo := MeshInstance3D.new()
	nodo.name = nombre
	nodo.mesh = malla
	nodo.material_override = material
	nodo.scale = Vector3(0.9, 0.8, 1.0)
	add_child(nodo)
	return nodo


func _actualizar_segmento(nodo: MeshInstance3D, desde: Vector3, hasta: Vector3,
		radio: float) -> void:
	var direccion := hasta - desde
	var largo := direccion.length()
	if largo < 0.01:
		return
	var capsula := nodo.mesh as CapsuleMesh
	capsula.height = largo + radio * 2.0
	var direccion_normalizada := direccion / largo
	var eje := Vector3.UP.cross(direccion_normalizada)
	var rotacion := Quaternion.IDENTITY
	if eje.length_squared() < 0.000001:
		if direccion_normalizada.dot(Vector3.UP) < 0.0:
			rotacion = Quaternion(Vector3.RIGHT, PI)
	else:
		var angulo := acos(clampf(Vector3.UP.dot(direccion_normalizada), -1.0, 1.0))
		rotacion = Quaternion(eje.normalized(), angulo)
	nodo.global_transform = Transform3D(Basis(rotacion), (desde + hasta) * 0.5)


func _ocultar_pieza(raiz: Node, nombre: String) -> void:
	if raiz == null:
		return
	var pieza := _buscar_por_nombre(raiz, nombre)
	if pieza is Node3D:
		(pieza as Node3D).visible = false


func _buscar_por_nombre(raiz: Node, nombre: String) -> Node:
	if raiz.name == nombre:
		return raiz
	return raiz.find_child(nombre, true, false)


func _buscar_inventario() -> Inventario:
	for nodo in get_tree().get_nodes_in_group("inventario"):
		if nodo is Inventario:
			return nodo as Inventario
	return null


## La herramienta que hay en la mano ahora mismo. Se pregunta al inventario y no
## al grupo "herramienta" porque el grupo solo lo tiene la equipada: guardada o
## en el suelo ya no esta, y asi un cambio de hueco se nota en el mismo
## fotograma.
func _herramienta_en_mano() -> Node3D:
	if _inventario == null or not is_instance_valid(_inventario):
		_inventario = _buscar_inventario()
		if _inventario == null:
			return null
	return _inventario.herramienta_equipada()


## Los agarres de la herramienta de ahora. Dos si es de dos manos, uno si es de
## una, ninguno si no hay herramienta.
func _resolver_agarres() -> void:
	_agarres.clear()
	if _herramienta == null or not is_instance_valid(_herramienta):
		return
	for nombre in NOMBRES_AGARRE:
		var agarre := _herramienta.get_node_or_null(nombre) as Marker3D
		if agarre != null:
			_agarres.append(agarre)
	if not _agarres.is_empty():
		return
	var suelto := _herramienta.get_node_or_null(NOMBRE_AGARRE_SOLO) as Marker3D
	if suelto != null:
		_agarres.append(suelto)


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	return material
