extends SceneTree

## Fotos del inventario y de la rueda, para verlos sin jugar.
##
##     godot --path . --script tools/foto_inventario.gd
##
## Sin `--headless`. Son cuatro fotos y dicen mas que un paragraphs:
##   1. La desbrozadora en la mano, que es como estaba el juego antes.
##   2. La rueda con la hoz en la mano.
##   3. Las manos vacias, con la rueda en un hueco que no tiene nada.
##   4. Una herramienta en el suelo y el "E recoger" en pantalla.
##
## Para la 4 el jugador se coloca DELANTE de la herramienta y mira a ella, que es
## como se coge una cosa: no vale con que este en el suelo, tiene que estar
## delante de la cara.

const ESPERA := 30

var mundo: Node3D
var cuadros := 0
var fase := 0
var inv: Inventario


func _initialize() -> void:
	mundo = load("res://scenes/main.tscn").instantiate() as Node3D
	root.add_child(mundo)


func _process(_delta: float) -> bool:
	cuadros += 1
	if cuadros < ESPERA and fase < 4:
		return false
	inv = mundo.get_node_or_null("Player/Inventario") as Inventario
	if inv == null:
		push_error("no hay inventario")
		quit(1)
		return true
	match fase:
		0:
			inv.seleccionar(0)
			fase = 1
			cuadros = 0
		1:
			_guardar("inventario_1_desbrozadora.png")
			inv.seleccionar(1)
			fase = 2
			cuadros = 0
		2:
			_guardar("inventario_2_hoz.png")
			inv.seleccionar(4)
			fase = 3
			cuadros = 0
		3:
			_guardar("inventario_3_manos_vacias.png")
			inv.seleccionar(0)
			inv.soltar_en_mano()
			fase = 4
			cuadros = 0
		4:
			# Se cuentan fotogramas en vez de esperar con `await`. En un
			# SceneTree, un `_process` con un `await` dentro devuelve un
			# coroutine en vez de `false`, y el motor lo lee como "ya no pintes
			# mas" y cierra el bucle: el proceso se acaba aqui, en silencio y con
			# codigo de salida cero. Es una trampa de las que no dan error.
			if cuadros < 60:
				return false
			_colocar_delante()
			fase = 5
			cuadros = 0
		5:
			# Un fotograma despues de colocarse, para que la camara este ya en su
			# sitio: el rayo de la recogida sale de ella, no del ojo.
			_apuntar_a_lo_suelto()
			fase = 6
			cuadros = 0
		6:
			# Un par de fotogramas mas: el inventario mira en `_process`, y aqui
			# hay que darle tiempo a que se entere de hacia donde mira la camara.
			if cuadros < 6:
				return false
			_guardar("inventario_4_suelta.png")
			print("bajo la mirada: %s" % str(inv.objeto_bajo_mirada()))
			# Y una ultima mirando al frente, que es como se lleva una
			# herramienta de verdad: con la vista al suelo, la maleza se come
			# medio encuadre y no se ve ni la desbrozadora ni la hoz.
			var jugador := mundo.get_node_or_null("Player") as Jugador
			if jugador != null:
				jugador.mirar_a(0.0, deg_to_rad(-18.0))
			inv.seleccionar(1)
			fase = 7
			cuadros = 0
		7:
			if cuadros < 20:
				return false
			_guardar("inventario_5_hoz_al_frente.png")
			quit(0)
			return true
	return false


func _guardar(nombre: String) -> void:
	var imagen := root.get_texture().get_image()
	if imagen == null:
		print("no hay imagen")
		return
	DirAccess.make_dir_recursive_absolute("res://capturas")
	imagen.save_png("res://capturas/" + nombre)
	print("guardada capturas/%s" % nombre)


func _suelto() -> RigidBody3D:
	for nodo in get_nodes_in_group("suelto"):
		if nodo is RigidBody3D:
			return nodo as RigidBody3D
	return null


## Se pone a un metro y medio de la herramienta suelta.
func _colocar_delante() -> void:
	var suelo := _suelto()
	var jugador := mundo.get_node_or_null("Player") as Jugador
	if suelo == null or jugador == null:
		return
	var destino := suelo.global_position
	jugador.global_position = Vector3(destino.x, 0.95, destino.z + 1.5)


## Y luego mira exactamente a donde esta, calculando el angulo desde la camara
## con un `atan2`. Con un "-40 grados" a ojo el rayo se va por encima: la camara
## esta a casi dos metros y medio y lleva su propio limite de inclinacion.
func _apuntar_a_lo_suelto() -> void:
	var suelo := _suelto()
	var jugador := mundo.get_node_or_null("Player") as Jugador
	if suelo == null or jugador == null:
		return
	var camara := jugador.get_node_or_null("Cabeza/Camara") as Camera3D
	if camara == null:
		return
	var direccion := (suelo.global_position - camara.global_position).normalized()
	jugador.mirar_a(atan2(-direccion.x, -direccion.z),
		asin(clampf(direccion.y, -1.0, 1.0)))
