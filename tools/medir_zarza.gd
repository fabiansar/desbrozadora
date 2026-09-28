extends SceneTree

## ¿Se ve la zarza de `main.tscn`? Aqui no hay forma de mirar una foto a ojo, asi
## que se mide como `medir_foto.gd` mide la hierba: se captura, se oculta el nodo
## de las zarzas, se vuelve a capturar y se cuentan los pixeles que cambian. Si no
## cambia ninguno, la zarza esta sembrada pero no se pinta o no entra en
## encuadre, y las dos cosas se confunden a simple vista.
##
##     godot --path . --script tools/medir_zarza.gd
##
## Sin `--headless`. Se miden tres cosas, que son tres fallos distintos:
##
##   1. Cuanto pinta la zarza sola, con el prado vacio. Si esto es cero, no se
##      dibuja: el fallo esta en la zarza.
##   2. Cuanto se ve desde los ojos del jugador, con todo encendido. Si esto es
##      cero, la zarza se dibuja pero no entra en el encuadre, o la maleza alta
##      la tapa: el fallo esta en donde esta puesta.
##   3. Cuanto tapa la maleza alta, que es de donde venia el "no veo nada".
##
## OJO al comparar con el viento puesto: las hojas se mueven en todos los
## fotogramas y cualquier pixel puede cambiar solo por eso. Por eso la medicion
## de "sola" va con los campos apagados, y la del jugador se compara con la
## misma escena sin zarza en el mismo estado de viento.

const ESPERA := 40

var mundo: Node3D
var cuadros := 0
var fase := 0
var vista: Camera3D
# Con todo encendido, desde los ojos del jugador.
var ojos_si: Image
var ojos_no: Image
# Con todo encendido pero sin maleza alta.
var ojos_limpio_si: Image
var ojos_limpio_no: Image
# Con el prado vacio, desde una camara alta.
var sola_si: Image
var sola_no: Image


func _initialize() -> void:
	mundo = load("res://scenes/main.tscn").instantiate()
	root.add_child(mundo)


func _process(_delta: float) -> bool:
	cuadros += 1
	if cuadros < ESPERA:
		return false
	match fase:
		0:
			ojos_si = _foto()
			_apagar("Zarzas")
		1:
			ojos_no = _foto()
			_encender("Zarzas")
			_apagar("MalezaAlta")
		2:
			ojos_limpio_si = _foto()
			_apagar("Zarzas")
		3:
			ojos_limpio_no = _foto()
			_encender("Zarzas")
			_apagar("Hierba")
			_apagar("MalezaAlta")
			_apagar("Bosque")
			_vista_alta()
		4:
			sola_si = _foto()
			_apagar("Zarzas")
		5:
			sola_no = _foto()
			_informar()
			quit(0)
			return true
	fase += 1
	cuadros = 0
	return false


func _foto() -> Image:
	return root.get_texture().get_image()


func _apagar(nombre: String) -> void:
	var n := mundo.get_node_or_null(NodePath(nombre)) as Node3D
	if n != null:
		n.visible = false


func _encender(nombre: String) -> void:
	var n := mundo.get_node_or_null(NodePath(nombre)) as Node3D
	if n != null:
		n.visible = true


## Camara por encima de la maleza, mirando a la mancha de zarzas. Sin esto no hay
## forma de distinguir "no se dibuja" de "esta debajo de la maleza".
func _vista_alta() -> void:
	var cam_jugador := mundo.get_node_or_null("Player/Cabeza/Camara") as Camera3D
	if cam_jugador != null:
		cam_jugador.current = false
	vista = Camera3D.new()
	mundo.add_child(vista)
	vista.current = true
	vista.fov = 70.0
	var desde := Vector3(0.0, 4.5, 6.0)
	vista.global_position = desde
	vista.look_at_from_position(desde, Vector3(0.0, 1.0, -14.0), Vector3.UP)


func _informar() -> void:
	var total := _pixeles(ojos_si)
	var sola := _diferencia(sola_si, sola_no)
	var vista_juego := _diferencia(ojos_si, ojos_no)
	var limpio := _diferencia(ojos_limpio_si, ojos_limpio_no)
	var maleza := _diferencia(ojos_si, ojos_limpio_si)
	print("=== la zarza de main.tscn ===")
	print("1. sola en el prado, sin cesped ni maleza: %d px (%.2f %%)"
		% [sola, 100.0 * sola / float(total)])
	print("2. desde los ojos del jugador, con todo: %d px (%.2f %%)"
		% [vista_juego, 100.0 * vista_juego / float(total)])
	print("3. desde los ojos, sin maleza alta:        %d px (%.2f %%)"
		% [limpio, 100.0 * limpio / float(total)])
	print("4. lo que tapa la maleza alta:             %d px (%.2f %%)"
		% [maleza, 100.0 * maleza / float(total)])
	for n in get_nodes_in_group("zarzas"):
		var z := n as Zarza
		var m := z.get_node_or_null("Zarza") as MultiMeshInstance3D
		if m == null:
			print("  %-16s SIN MALLA" % z.name)
			continue
		print("  %-16s a %5.1f m, %.1f m de alto, %4d columnas, %d instancias"
			% [z.name, z.global_position.length(), z.altura_maxima,
			z.columnas_en_pie(), m.multimesh.instance_count])
	DirAccess.make_dir_recursive_absolute("res://capturas")
	ojos_si.save_png("res://capturas/zarza_juego_si.png")
	ojos_no.save_png("res://capturas/zarza_juego_no.png")
	ojos_limpio_si.save_png("res://capturas/zarza_juego_sin_maleza.png")
	sola_si.save_png("res://capturas/zarza_sola.png")
	print("fotos en capturas/")


func _pixeles(img: Image) -> int:
	return img.get_width() * img.get_height()


func _diferencia(a: Image, b: Image) -> int:
	var distintos := 0
	for y in a.get_height():
		for x in a.get_width():
			var p := a.get_pixel(x, y)
			var q := b.get_pixel(x, y)
			if absf(p.r - q.r) + absf(p.g - q.g) + absf(p.b - q.b) > 0.02:
				distintos += 1
	return distintos
