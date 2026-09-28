class_name Restos
extends Node3D

## Trozos de vegetation sueltos. Es un unico sistema generico para todo lo que se
## corta, sea hierba, maleza o zarza: al cortar no se conserva la forma de la planta,
## sino que aparecen restos aqui.
##
## Son particulas de GPU, no objetos. Antes cada resto era un nodo con su propia
## simulacion en GDScript, y con varios miles vivos el coste por fotograma era
## notable. Ademas se quedaban flotando en el aire, porque un resto que habia
## tocado el suelo dejaba de moverse pero se quedaba dibujado para siempre. Con
## particulas cada resto tiene un tiempo de vida y desaparece solo: no hay manera
## de que queden suspendidos.
##
## No se usa RigidBody3D a proposito. El reparto de lo que cae lo decide el juego;
## aqui solo hace falta el efecto visual del montillo.

## Trozos por peticion maxima.
const MAXIMO_POR_PEDIDO := 24
## Tiempo de vida de un trozo, en segundos. Es lo que garantiza que no queden
## restos colgados: al terminarse, la particula desaparece.
const VIDA := 1.1
## Emisores disponibles. Se recyclean: hay un maximo de peticiones simultaneas.
const EMISORES := 48

var _pool: Array[GPUParticles3D] = []
## Cuantos emisores estan ocupados ahora mismo.
var _ocupados := 0
## Total de trozos pedidos en la partida. Para las pruebas.
var _pedidos := 0
var _material: StandardMaterial3D
var _malla: BoxMesh


func _ready() -> void:
	add_to_group("restos")
	_crear_material()
	for i in EMISORES:
		_pool.append(_crear_emisor("Emisor%d" % i))


func _crear_material() -> void:
	_malla = BoxMesh.new()
	_malla.size = Vector3.ONE * 0.09
	_material = StandardMaterial3D.new()
	_material.vertex_color_use_as_albedo = true
	_material.roughness = 0.95
	_material.albedo_color = Color(0.22, 0.32, 0.11)


func _crear_emisor(nombre: String) -> GPUParticles3D:
	var emisor := GPUParticles3D.new()
	emisor.name = nombre
	emisor.amount = MAXIMO_POR_PEDIDO
	emisor.lifetime = VIDA
	emisor.one_shot = true
	emisor.explosiveness = 1.0
	emisor.emitting = false
	emisor.local_coords = false
	emisor.draw_order = GPUParticles3D.DRAW_ORDER_LIFETIME
	emisor.visibility_aabb = AABB(Vector3(-3, -1, -3), Vector3(6, 6, 6))

	var proceso := ParticleProcessMaterial.new()
	proceso.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	proceso.emission_sphere_radius = 0.08
	proceso.direction = Vector3.UP
	proceso.spread = 45.0
	proceso.initial_velocity_min = 1.2
	proceso.initial_velocity_max = 2.6
	proceso.gravity = Vector3(0.0, -9.8, 0.0)
	proceso.damping_min = 0.5
	proceso.damping_max = 1.2
	proceso.angular_velocity_min = -420.0
	proceso.angular_velocity_max = 420.0
	proceso.scale_min = 0.5
	proceso.scale_max = 1.3
	emisor.process_material = proceso

	var dibujo := QuadMesh.new()
	dibujo.size = Vector2(0.09, 0.05)
	var mat := _material.duplicate() as StandardMaterial3D
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	dibujo.material = mat
	emisor.draw_pass_1 = dibujo
	add_child(emisor)
	return emisor


## Devuelve el unico gestor de restos de la partida, creandolo si la escena aun
## no lo tiene. Cualquier vegetation puede llamarlo al cortar y no necesita saber
## donde esta colgado, que es lo que evita cablear el nodo en cada escena.
static func obtener(arbol: SceneTree) -> Restos:
	for nodo in arbol.get_nodes_in_group("restos"):
		if nodo is Restos:
			return nodo as Restos
	var nuevo := Restos.new()
	nuevo.name = "Restos"
	arbol.root.add_child(nuevo)
	return nuevo


## Suelta restos desde un punto, que es el punto donde ha ocurrido el corte.
##
## `cantidad` es cuantos trozos aparecen, `direccion` hacia donde salen despedidos,
## `tono` el color de la planta cortada y `escala` el tamano. La posicion de la que
## parten es la del corte, no la del suelo, que es lo que hace que salten.
func soltar(origen: Vector3, cantidad: int, direccion: Vector3, tono: Color,
		escala: float = 1.0) -> int:
	var pedidas := clampi(cantidad, 1, MAXIMO_POR_PEDIDO)
	var emisor := _tomar_emisor()
	if emisor == null:
		return 0
	emisor.position = origen
	emisor.amount = pedidas
	# El escape lateral se aplica girando la direccion de emision, que es como se
	# ve el escombros saliendo hacia el lado por el que avanza la maquina.
	var proceso := emisor.process_material as ParticleProcessMaterial
	# El color de la particion va en el material de proceso, no en el emisor: un
	# GPUParticles3D no tiene modulate, que es de los CanvasItem.
	proceso.color = tono
	var apuntada := direccion
	apuntada.y = 0.0
	if apuntada.length() > 0.01:
		apuntada = apuntada.normalized()
	else:
		apuntada = Vector3.FORWARD
	proceso.direction = apuntada
	proceso.gravity = Vector3(0.0, -9.8, 0.0)
	proceso.scale_min = 0.5 * escala
	proceso.scale_max = 1.3 * escala
	emisor.restart()
	emisor.emitting = true
	_pedidos += pedidas
	return pedidas


## Emisor libre para este pedido. Cuando se agotan, se recicla el mas antiguo: es
## preferible pisar un monticulo a que deje de salirPicker al desbrozar.
func _tomar_emisor() -> GPUParticles3D:
	for emisor in _pool:
		if not emisor.emitting:
			return emisor
	var reciclado := _pool[_ocupados % _pool.size()]
	_ocupados += 1
	return reciclado


## Devuelve un grupo de particulas compatible con GPUParticles3D.
func recuento() -> Dictionary:
	var activos := 0
	for emisor in _pool:
		if emisor.emitting:
			activos += 1
	return {"soltados": _pedidos, "activos": activos}


## Corta toda la actividad de restos en curso.
func limpiar() -> void:
	_pedidos = 0
	_ocupados = 0
	for emisor in _pool:
		emisor.emitting = false
