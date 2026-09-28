extends SceneTree

## Foto de la escena de pruebas de zarza, para ver la mecanica sin tener que
## entrar en primera persona. Se hacen tres: como esta, con el cabezal pasado por
## arriba, y con el cabezal pasado a ras de suelo. Lo que hay que mirar es si la
## zarza alta se queda de pie despues de la pasada baja en las de una sola mata,
## y si la de tres matas se va tumbando por partes.
##
##     godot --path . --script tools/foto_pruebas_zarza.gd
##
## Sin `--headless`. Se apaga el viento antes de medir, porque las hojas se
## mueven en todos los fotogramas y las fotos no salen comparables si no.

const ESPERA := 24

var mundo: Node3D
var cuadros := 0
var fase := 0
var vista: Camera3D


func _initialize() -> void:
	mundo = load("res://scenes/pruebas_zarza.tscn").instantiate() as Node3D
	root.add_child(mundo)


func _process(_delta: float) -> bool:
	cuadros += 1
	if cuadros < ESPERA:
		return false
	match fase:
		0:
			_preparar_vista()
			fase = 1
			cuadros = 0
		1:
			_guardar("pruebas_zarza_0_antes.png")
			# Pasada por arriba: abre paso, quita la copa y NO tumba el zarzal, porque la
			# raiz sigue viva. Es el trabajo que no vale.
			for z in get_nodes_in_group("zarzas"):
				var zarza := z as Zarza
				zarza.cortar_en(zarza.to_global(Vector3(0.0, 0.8, 0.0)),
					zarza.ancho * 0.5)
			fase = 2
			cuadros = 0
		2:
			_guardar("pruebas_zarza_1_pasada_alta.png")
			# Pasada a ras de suelo, donde esta la raiz. A dos centimetros, porque a
			# diez el cabezal deja un tocon y el tocon sigue siendo una raiz: eso es
			# exactamente lo que pasa de verdad y por eso hay que llegar al suelo.
			for z in get_nodes_in_group("zarzas"):
				var zarza := z as Zarza
				for corona in zarza.posiciones_de_coronas():
					zarza.cortar_en(zarza.to_global(Vector3(corona.x, 0.02, corona.y)), 0.8)
			fase = 3
			cuadros = 0
		3:
			_guardar("pruebas_zarza_2_pasada_raiz.png")
			for z in get_nodes_in_group("zarzas"):
				var zarza := z as Zarza
				print("%-16s %d columnas, %6.1f m, %d/%d raices en pie"
					% [zarza.name, zarza.columnas_en_pie(), zarza.altura_total(),
					zarza.coronas_en_pie(), zarza.coronas_totales()])
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


## Camara alta mirando la fila de zarzas. La del jugador se apaga, y el jugador
## no se dibuja, para que lo que se ve sea la zarza y no el entrepiernas.
func _preparar_vista() -> void:
	var cam_jugador := mundo.get_node_or_null("Player/Cabeza/Camara") as Camera3D
	if cam_jugador != null:
		cam_jugador.current = false
	var cuerpo := mundo.get_node_or_null("Player/Cuerpo")
	if cuerpo != null:
		(cuerpo as Node3D).visible = false
	vista = Camera3D.new()
	mundo.add_child(vista)
	vista.current = true
	vista.fov = 75.0
	var desde := Vector3(0.0, 11.0, 8.0)
	vista.global_position = desde
	vista.look_at_from_position(desde, Vector3(0.0, 0.8, -10.0), Vector3.UP)
