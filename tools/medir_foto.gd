extends SceneTree

## La hierba se ve o no se ve. Aqui no hay forma de mirar una foto, asi que se
## mide: se captura el campo, se oculta el nodo de la hierba, se vuelve a
## capturar y se cuentan los pixeles que han cambiado. Si no cambia ninguno, es
## que la hierba no se dibuja aunque el motor no diga nada.

var mundo: Node3D
var cuadros := 0
var fase := 0
var con_hierba: Image
var fuera: Image

## Cuantos fotogramas se da antes de medir. No es un numero de adorno: hay que
## dar tiempo a que la siembra termine y a que los shaders se compilen. Con diez
## fotogramas la foto salia a medio hacer.
const ESPERA := 40


func _initialize() -> void:
	mundo = load("res://scenes/main.tscn").instantiate()
	root.add_child(mundo)


func _process(_delta: float) -> bool:
	cuadros += 1
	if cuadros < ESPERA:
		return false
	match fase:
		0:
			con_hierba = root.get_texture().get_image()
			print("con hierba: %dx%d" % [con_hierba.get_width(), con_hierba.get_height()])
			# El campo de hierba es un Node3D con un MultiMeshInstance3D por
			# cuadrante, no un MultiMeshInstance3D suelto como era antes de
			# partirlo. Si se busca el tipo equivocado, esto revienta con un
			# "Nil" y la foto sale siempre igual, que es justo lo que hay que
			# comprobar.
			var h := mundo.get_node_or_null("Hierba") as Node3D
			if h == null:
				push_error("no esta el campo de hierba en la escena")
				quit(1)
				return true
			h.visible = false
			fase = 1
			cuadros = 0
		1:
			fuera = root.get_texture().get_image()
			fase = 2
			cuadros = 0
		_:
			_medir()
			quit(0)
			return true
	return false


func _medir() -> void:
	var totales := con_hierba.get_width() * con_hierba.get_height()
	var distintos := 0
	var verdes := 0
	var marrones := 0
	var muestra_alto := 0.0
	for y in con_hierba.get_height():
		for x in con_hierba.get_width():
			var a := con_hierba.get_pixel(x, y)
			var b := fuera.get_pixel(x, y)
			var d := absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)
			if d > 0.02:
				distintos += 1
			# Verde de hierba: el canal verde gana con claridad.
			if a.g > a.r * 1.15 and a.g > a.b * 1.15 and a.g > 0.06:
				verdes += 1
			elif a.r > a.g * 1.15 and a.b < a.g and a.r > 0.05:
				marrones += 1
	print("pixeles: %d" % totales)
	print("  cambiados al quitar la hierba: %d (%.1f %%)"
		% [distintos, 100.0 * distintos / float(totales)])
	print("  de color verde: %d (%.1f %%)" % [verdes, 100.0 * verdes / float(totales)])
	print("  de color tierra: %d (%.1f %%)" % [marrones, 100.0 * marrones / float(totales)])
	# El verde que queda sin la hierba es la copa de los arboles y el cielo.
	print("centro de la foto con hierba: %s" % str(con_hierba.get_pixel(640, 500)))
	print("centro de la foto sin hierba: %s" % str(fuera.get_pixel(640, 500)))
	_preparar_capturas()
	con_hierba.save_png("res://capturas/comparada_con_hierba.png")
	fuera.save_png("res://capturas/comparada_sin_hierba.png")
	print("fotos guardadas")


## Las capturas se guardan en el proyecto, y esa carpeta no existe todavia en un
## clon nuevo, asi que se crea antes de la primera foto.
func _preparar_capturas() -> void:
	DirAccess.make_dir_recursive_absolute("res://capturas")
