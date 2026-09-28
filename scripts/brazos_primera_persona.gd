extends Node3D

## Sustituye los brazos de pose del modelo por extremidades que siguen los
## marcadores reales del manillar, sin mover el cuerpo con la herramienta.

const NOMBRES_AGARRE := ["AgarreIzquierdo", "AgarreDerecho"]

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
var _herramienta: Desbrozadora
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
	_herramienta = _buscar_herramienta()
	_resolver_agarres()
	_crear_brazos_visibles()


func _process(_delta: float) -> void:
	if _jugador == null:
		return
	if _herramienta == null or not is_instance_valid(_herramienta):
		_herramienta = _buscar_herramienta()
	if _herramienta == null:
		_mostrar_brazos(true)
		return
	_mostrar_brazos(true)
	if _agarres.size() != 2 or not is_instance_valid(_agarres[0]) \
			or not is_instance_valid(_agarres[1]):
		_resolver_agarres()
	if _agarres.size() != 2:
		return

	for i in range(2):
		var agarre := _agarres[i]
		var muneca := agarre.global_position
		var muneca_local := _jugador.to_local(muneca)
		var lado := -1.0 if i == 0 else 1.0
		var hombro_local := Vector3(lado * separacion_hombros, altura_hombro, -0.08)
		var codo_local := hombro_local.lerp(muneca_local, fraccion_codo)
		codo_local += Vector3(lado * apertura_codo, -flexion_codo, 0.05)
		var codo := _jugador.to_global(codo_local)
		var hombro := _jugador.to_global(hombro_local)
		_actualizar_segmento(_superiores[i], hombro, codo, 0.028)
		_actualizar_segmento(_antebrazos[i], codo, muneca, 0.030)
		_manos[i].global_position = muneca


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


func _buscar_herramienta() -> Desbrozadora:
	for nodo in get_tree().get_nodes_in_group("herramienta"):
		if nodo is Desbrozadora:
			return nodo as Desbrozadora
	return null


func _resolver_agarres() -> void:
	_agarres.clear()
	if _herramienta == null or not is_instance_valid(_herramienta):
		return
	for nombre in NOMBRES_AGARRE:
		var agarre := _herramienta.get_node_or_null(nombre) as Marker3D
		if agarre == null:
			_agarres.clear()
			return
		_agarres.append(agarre)


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	return material
