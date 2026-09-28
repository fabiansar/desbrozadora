class_name Inventario
extends Node3D

## Las nueve cosas que llevas encima y la que tienes en la mano.
##
## Es a proposito lo mas tonto que se puede: nueve huecos, un numero, y una rueda
## para elegir. Nada de pesos, ni de tallas, ni de apilado. La desbrozadora
## pesa y la hoz no, y aqui las dos ocupan lo mismo, porque el peso ya se nota
## en como se trabaja con ellas y no hace falta que ademas lo diga un numero.
##
## Lo unico con estado es lo que la herramienta guarda por dentro (gasolina,
## desgaste, revoluciones), y eso NO se pierde al soltarla: el nodo se queda
## vivo en un escondite y solo se mueve de sitio. Si al soltar se destruyera y al
## recoger se creara de cero, tirar la maquina al suelo seria la manera de
## resetearle el deposito, y eso lo haria el primer jugador que la viera.
##
## Por que la rueda y no una tira de cuadrados: la tira obliga a mirar una fila
## de numeros para saber que llevas, y aqui lo que importa es cual de las dos
## cosas que llevas tienes en la mano. La rueda se lee de un vistazo y el
## sector elegido esta donde esta el raton.
##
## Con las manos vacias no hay herramienta, y los brazos se quedan sin nada: es
## un estado de verdad, no un error. Se llega con la rueda, no por accidente.

signal cambio
## Lo que hay que decir en pantalla ahora mismo: el texto y los segundos que
##aguanta. Vacio si no hay nada que decir.
signal aviso(texto: String, segundos: float)

## Cuantos huecos hay. Nueve, y ni uno mas: con la rueda no hace falta mas, y
## son los que se ven a la vez sin que el circulo se llene de rayas.
const HUECOS := 9
## Capa de colision de lo que esta suelto por el suelo. Va en la 4 a proposito:
## el jugador NO la lleva en su mascara, asi que se puede andar por encima de
## una herramienta sin que el suelo se le hunda ni se le falsee el apoyo.
const CAPA_SUELTO := 8
## A que distancia se coge algo del suelo, en metros.
@export var alcance_recogida := 3.0

## El catalogo. Aqui esta lo que se puede llevar, no lo que se lleva: que haya
## una herramienta en la lista no significa que este en los huecos.
@export var catalogo: Array[Herramienta] = []
## Con que se empieza la partida. El 1 es lo que llevas en la mano al abrir el
## juego.
@export var ocupacion_inicial: Array[StringName] = []
## Donde se cuelga la herramienta que llevas en la mano. Es el arnes, el mismo
## de antes, para que la desbrozadora se deje igual que se dejaba.
@export var pivote: NodePath

var _huecos: Array[StringName] = []
var _seleccion := 0
## Que herramienta esta en la mano ahora mismo. Se guarda aparte de los huecos
## a proposito: si `equipar` mirara "_lo que hay en el hueco seleccionado" para
## guardar lo anterior, dependeria de que la seleccion se cambiara DESPUES, y
## cambiandola antes se guardaba la nueva en vez de la vieja: la anterior se
## quedaba en la mano, en el grupo y a la vista, y habia dos herramientas
## montadas a la vez.
var _en_mano: StringName = &""
## id -> nodo vivo, aunque este guardado o en el suelo. Se crean una vez y no se
## vuelven a crear nunca.
var _vivas := {}
## Pivote del arnes y el escondite de las guardadas.
var _pivote: Node3D
var _guardadas: Node3D
## Lo que hay tirado por el mundo, para poder mirarlo sin recorrer la escena.
var _sueltos: Array[RigidBody3D] = []
## Lo que se esta mirando y se podria coger, o null.
var _bajo_mirada: RigidBody3D
var _aviso_texto := ""
var _aviso_restante := 0.0


func _ready() -> void:
	add_to_group("inventario")
	_huecos.resize(HUECOS)
	for i in HUECOS:
		_huecos[i] = ocupacion_inicial[i] if i < ocupacion_inicial.size() else &""
	_pivote = get_node_or_null(pivote) as Node3D
	if _pivote == null:
		_pivote = _subir_buscando(self, "Caderas")
		if _pivote != null:
			_pivote = _pivote.get_node_or_null("PivoteDesbrozadora") as Node3D
	_guardadas = Node3D.new()
	_guardadas.name = "Guardadas"
	add_child(_guardadas)
	equipar(0)
	cambio.emit()


func _process(delta: float) -> void:
	if _aviso_restante > 0.0:
		_aviso_restante -= delta
		if _aviso_restante <= 0.0:
			_aviso_texto = ""
			aviso.emit("", 0.0)
	_bajo_mirada = _buscar_bajo_mirada()


func _unhandled_input(evento: InputEvent) -> void:
	if evento is InputEventMouseButton:
		var boton := evento as InputEventMouseButton
		if boton.pressed:
			if boton.button_index == MOUSE_BUTTON_WHEEL_UP:
				mover_seleccion(-1)
			elif boton.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				mover_seleccion(1)
	if evento.is_action_pressed("soltar"):
		soltar_en_mano()
	elif evento.is_action_pressed("recoger"):
		recoger()


# --- Consultas ------------------------------------------------------------

## El numero de hueco que tienes delante. Cambia con la rueda.
func seleccion() -> int:
	return _seleccion


## Lo que hay en un hueco, como recurso. Null si esta vacio.
func herramienta_de(indice: int) -> Herramienta:
	if indice < 0 or indice >= HUECOS:
		return null
	return _catalogo_de(_huecos[indice])


func nombre_de(indice: int) -> String:
	var h := herramienta_de(indice)
	return h.nombre if h != null else ""


func hay_algo(indice: int) -> bool:
	return indice >= 0 and indice < HUECOS and _huecos[indice] != &""


## El nodo de la herramienta que llevas en la mano, o null si no llevas ninguna.
## Los brazos, las pruebas y la interfaz preguntan aqui.
func herramienta_equipada() -> Node3D:
	return _vivas.get(_en_mano, null) as Node3D


## Lo que hay mirando y se podria coger, o null. La interfaz lo lee para poner
## el "E recoger".
func objeto_bajo_mirada() -> RigidBody3D:
	return _bajo_mirada


func aviso_actual() -> String:
	return _aviso_texto


func ids_de_los_huecos() -> Array[StringName]:
	return _huecos.duplicate()


func _catalogo_de(id: StringName) -> Herramienta:
	for h in catalogo:
		if h != null and h.id == id:
			return h
	return null


# --- La rueda -------------------------------------------------------------

## Un giro de la rueda, un hueco. Da igual el sentido: la rueda no se queda
## parada en un extremo, porque los huecos vacios son los que mas se van a usar
## y si al llegar al final se parase habria que dar la vuelta entera.
func mover_seleccion(paso: int) -> void:
	if paso == 0:
		return
	var nuevo := posmod(_seleccion + paso, HUECOS)
	if nuevo == _seleccion:
		return
	_seleccion = nuevo
	equipar(_seleccion)
	cambio.emit()


## Elige un hueco concreto. Es lo que usan las pruebas; el jugador llega aqui
## con la rueda.
func seleccionar(indice: int) -> void:
	if indice < 0 or indice >= HUECOS or indice == _seleccion:
		return
	_seleccion = indice
	equipar(indice)
	cambio.emit()


# --- Equipar y guardar ----------------------------------------------------

## Pone una herramienta en la mano. La que hubiera en ella se guarda.
func equipar(indice: int) -> void:
	if indice < 0 or indice >= HUECOS:
		return
	_guardar(_en_mano)
	var id := _huecos[indice]
	if id == &"":
		# Un hueco vacio son las manos vacias. No es un caso raro ni un fallo:
		# es lo que pasa cuando sueltas lo que llevabas.
		_en_mano = &""
		return
	_en_mano = id
	var nodo := _instancia(id)
	if nodo == null or _pivote == null:
		return
	if nodo.get_parent() != _pivote:
		nodo.reparent(_pivote, false)
	nodo.transform = Transform3D.IDENTITY
	nodo.visible = true
	nodo.process_mode = Node.PROCESS_MODE_INHERIT
	nodo.add_to_group("herramienta")
	_interfaces_de(nodo, true)


## Mete la herramienta del hueco actual en el escondite: sigue viva, pero no se
## ve ni corre. El nodo NO se destruye, y con el no se destruye lo que tenga
## dentro (la gasolina, el desgaste, las revoluciones).
func _guardar(id: StringName) -> void:
	if id == &"":
		return
	var nodo := _vivas.get(id, null) as Node3D
	if nodo == null:
		return
	nodo.remove_from_group("herramienta")
	nodo.process_mode = Node.PROCESS_MODE_DISABLED
	if nodo.get_parent() != _guardadas:
		nodo.reparent(_guardadas, false)
	nodo.visible = false
	_interfaces_de(nodo, false)


## Apaga y enciende los `CanvasLayer` de una herramienta, que son sus paneles.
##
## Esto va aparte de `visible` del nodo porque un CanvasLayer NO hereda la
## visibilidad de su padre: es otra capa de dibujo, y ocultar el nodo 3D no la
## tapa. Sin esto, al cambiar a la hoz se quedaba el panel de la desbrozadora
## encima, con sus revoluciones y su gasolina congeladas, dando la impresion de
## que llevas las dos herramientas.
func _interfaces_de(nodo: Node, visibles: bool) -> void:
	for hijo in nodo.get_children():
		if hijo is CanvasLayer:
			(hijo as CanvasLayer).visible = visibles
		_interfaces_de(hijo, visibles)


## El nodo de una herramienta, creandolo la primera vez que se usa. A partir de
## ahi siempre es el mismo.
func _instancia(id: StringName) -> Node3D:
	if _vivas.has(id):
		return _vivas[id] as Node3D
	var datos := _catalogo_de(id)
	if datos == null or datos.escena == null:
		return null
	var nodo := datos.escena.instantiate() as Node3D
	if nodo == null:
		return null
	nodo.name = datos.nombre
	_guardadas.add_child(nodo)
	nodo.process_mode = Node.PROCESS_MODE_DISABLED
	nodo.visible = false
	_vivas[id] = nodo
	return nodo


# --- Soltar y recoger -----------------------------------------------------

## Lo que llevas en la mano se cae al suelo. Con las manos vacias no hace nada,
## y lo dice, para que no parezca que el juego se ha comido la pulsacion.
func soltar_en_mano() -> void:
	var id := _huecos[_seleccion]
	if id == &"":
		_avisar("no llevas nada en la mano", 1.2)
		return
	var nodo := _vivas.get(id, null) as Node3D
	var datos := _catalogo_de(id)
	if nodo == null or datos == null:
		_avisar("esa herramienta no se puede soltar", 1.2)
		return
	var mundo := _nodo_del_mundo()
	if mundo == null:
		return
	# El cuerpo es lo unico nuevo: una caja con masa, en la CAPA_SUELTO, para
	# que caiga, se pare y se pueda mirar. El nodo de la herramienta se cuelga
	# dentro, con la misma transformada que tenia en la mano, y asi la maquina
	# se suelta donde estaba y no aparece en otro sitio.
	var cuerpo := RigidBody3D.new()
	cuerpo.name = "Suelto_%s" % datos.nombre
	cuerpo.collision_layer = CAPA_SUELTO
	cuerpo.collision_mask = 1
	cuerpo.mass = 4.0
	cuerpo.add_to_group("suelto")
	var forma := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = datos.caja
	forma.shape = caja
	cuerpo.add_child(forma)
	mundo.add_child(cuerpo)
	# Se suelta un poco hacia un lado, no justo debajo de la mano. Sin esto, dos
	# herramientas soltadas en el mismo sitio aparecen ENCAJADAS, la fisica las
	# separa de un empujon y las manda cada una a un lado; y al mirar al suelo
	# para coger una te pilla la otra, que ha quedado mas cerca. Con medio palmo de
	# lateral la segunda ya cae al lado de la primera, que es como se sueltan de
	# verdad: una en cada mano.
	var mano := nodo.global_transform.basis
	var fuera := mano.x * 0.30 + mano.z * randf_range(-0.15, 0.15)
	cuerpo.global_transform = nodo.global_transform.translated(
		nodo.global_transform.basis.inverse() * fuera)
	nodo.reparent(cuerpo, true)
	# Se para de trabajar mientras esta en el suelo: si se le dejara correr, la
	# desbrozadora seguiria midiendo la resistencia y moviendo el cabezal sin
	# manos que lo sostengan.
	nodo.remove_from_group("herramienta")
	nodo.process_mode = Node.PROCESS_MODE_DISABLED
	nodo.visible = true
	_interfaces_de(nodo, false)
	cuerpo.set_meta("herramienta", id)
	# Un empujon hacia delante y hacia arriba, para que salga de las manos y no
	# caiga recta por la gravedad: se suelta, no se teletransporta.
	var hacia := -cuerpo.global_transform.basis.z
	cuerpo.linear_velocity = hacia * 1.2 + Vector3.UP * 0.6
	cuerpo.angular_velocity = Vector3(0.0, 1.0, 0.4) * 0.8
	_sueltos.append(cuerpo)
	_huecos[_seleccion] = &""
	_en_mano = &""
	_avisar("suelta: %s" % datos.nombre, 1.0)
	cambio.emit()


## Coge lo que se esta mirando. Va al primer hueco libre y ademas a la mano,
## porque se coge con la mano. Sin hueco no se puede coger, y se dice, porque
## si no el jugador creeria que el juego esta roto.
func recoger() -> bool:
	if _bajo_mirada == null or not is_instance_valid(_bajo_mirada):
		return false
	var libre := _primer_hueco_libre()
	if libre < 0:
		_avisar("no te cabe nada mas", 1.2)
		return false
	var id := StringName(str(_bajo_mirada.get_meta("herramienta", &"")))
	if id == &"":
		return false
	var datos := _catalogo_de(id)
	if datos == null:
		return false
	_sueltos.erase(_bajo_mirada)
	_bajo_mirada.queue_free()
	_bajo_mirada = null
	_huecos[libre] = id
	_seleccion = libre
	equipar(libre)
	_avisar("cogida: %s" % datos.nombre, 1.0)
	cambio.emit()
	return true


func _primer_hueco_libre() -> int:
	for i in HUECOS:
		if _huecos[i] == &"":
			return i
	return -1


## Si queda algun hueco donde meter algo. Lo consulta la interfaz para no
## ofrecer "E recoger" cuando no cabe de ninguna manera.
func hay_hueco_libre() -> bool:
	return _primer_hueco_libre() >= 0


## Lo que hay en el suelo y se puede coger, mirando desde los ojos del jugador.
##
## Un rayo, no un area alrededor del cuerpo: con un area cogias lo que tuvieras
## al lado sin mirar, y lo que se coge es siempre lo que estas mirando.
func _buscar_bajo_mirada() -> RigidBody3D:
	var espacio := get_world_3d().direct_space_state
	var camara := _camara_del_jugador()
	if espacio == null or camara == null:
		return null
	var desde := camara.global_position
	var consulta := PhysicsRayQueryParameters3D.create(desde,
		desde - camara.global_transform.basis.z * alcance_recogida)
	consulta.collision_mask = CAPA_SUELTO
	consulta.collide_with_areas = false
	consulta.collide_with_bodies = true
	var golpe := espacio.intersect_ray(consulta)
	if golpe.is_empty():
		return null
	var cuerpo := golpe.get("collider") as RigidBody3D
	if cuerpo == null or not cuerpo.is_in_group("suelto"):
		return null
	return cuerpo


func _camara_del_jugador() -> Camera3D:
	var jugador := _subir_buscando(self, "Player")
	if jugador == null:
		return null
	return jugador.get_node_or_null("Cabeza/Camara") as Camera3D


## Donde se cuelga lo que se cae: el mundo, no el jugador. Se sube dos niveles
## desde aqui (Inventario -> Player -> Mundo) y, si eso no esta, se usa la escena
## actual. Un objeto suelto que colgase del jugador se moveria con el.
func _nodo_del_mundo() -> Node3D:
	var padre := get_parent()
	if padre == null:
		return null
	var mundo := padre.get_parent() as Node3D
	if mundo != null:
		return mundo
	var escena := get_tree().current_scene as Node3D
	return escena if escena != null else null


func _avisar(texto: String, segundos: float) -> void:
	_aviso_texto = texto
	_aviso_restante = segundos
	aviso.emit(texto, segundos)


func _subir_buscando(desde: Node, nombre: String) -> Node:
	var n := desde
	while n != null:
		if n.name == nombre:
			return n
		n = n.get_parent()
	return null
