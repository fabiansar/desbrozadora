extends SceneTree

## Se mide lo que ve el jugador, no lo que dicen los arrays. Se capturan tres
## fotos con la misma camara y se comparan: el campo de pie, el campo entero
## cortado (que es lo que el usuario ve al desbrozar) y sin hierba. Comparadas
## contra la ultima se sabe cuanto ocupa cada cosa de verdad.

var mundo: Node3D
var pasos := 0
var cuadros := 0
var de_pie: Image
var cortado: Image
var sin: Image
var hierba


func _initialize() -> void:
	mundo = load("res://scenes/main.tscn").instantiate()
	root.add_child(mundo)
	hierba = mundo.get_node_or_null("Cesped")


func _process(_delta: float) -> bool:
	cuadros += 1
	# El jugador cae desde arriba y las tres fotos tienen que ser desde el mismo
	# sitio, o no se puede comparar nada: hay que esperar a que se asiente.
	if cuadros < 70:
		return false
	cuadros = 0
	# Tres pasos y ya: la foto de pie, la de todo cortado y la de sin hierba.
	# Entremedias se corta el campo entero, que es lo que hace el cabezal pero
	# en plan masivo, para tener las dos fotos con la misma camara.
	match pasos:
		0:
			de_pie = root.get_texture().get_image()
			_preparar_capturas()
			de_pie.save_png("res://capturas/paso1_de_pie.png")
			hierba.cortar(Vector3(0, 0, 0), 500.0)
			pasos = 1
		1:
			cortado = root.get_texture().get_image()
			cortado.save_png("res://capturas/paso2_cortado.png")
			hierba.visible = false
			pasos = 2
		2:
			sin = root.get_texture().get_image()
			sin.save_png("res://capturas/paso3_sin.png")
			_comparar()
			quit(0)
			return true
	return false


func _comparar() -> void:
	var tot := de_pie.get_width() * de_pie.get_height()
	print("hierba: %d hojas   aabb %s"
		% [hierba.total(), str(hierba.caja_del_campo())])
	_medir("campo de pie", de_pie)
	_medir("campo cortado", cortado)
	print("  pixeles de la foto: %d" % tot)
	# Y una muestra de los colores, por si acaso.
	for etiqueta in ["de pie", "cortado", "sin hierba"]:
		var img: Image = de_pie
		if etiqueta == "cortado":
			img = cortado
		elif etiqueta == "sin hierba":
			img = sin
		print("  %-10s  centro %s   abajo %s"
			% [etiqueta, str(img.get_pixel(640, 560)),
				str(img.get_pixel(640, 690))])


func _medir(etiqueta: String, con: Image) -> void:
	var distintos := 0
	var verdes := 0
	var tot := con.get_width() * con.get_height()
	for y in con.get_height():
		for x in con.get_width():
			var c := con.get_pixel(x, y)
			var s := sin.get_pixel(x, y)
			if absf(c.r - s.r) + absf(c.g - s.g) + absf(c.b - s.b) > 0.02:
				distintos += 1
			if c.g > c.r * 1.12 and c.g > c.b * 1.12 and c.g > 0.05:
				verdes += 1
	print("  %-16s ocupa el %5.1f %% de la foto   verde: %5.2f %%"
		% [etiqueta, 100.0 * distintos / tot, 100.0 * verdes / tot])


## Las capturas se guardan en el proyecto, y esa carpeta no existe todavia en un
## clon nuevo, asi que se crea antes de la primera foto.
func _preparar_capturas() -> void:
	DirAccess.make_dir_recursive_absolute("res://capturas")
