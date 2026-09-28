extends SceneTree

## Foto del campo para verlo de verdad. Se ejecuta SIN --headless, que es como
## el motor usa la grafica de verdad en vez del servidor de mentira.

var mundo: Node3D
var cuadros := 0


func _initialize() -> void:
	mundo = load("res://scenes/main.tscn").instantiate()
	root.add_child(mundo)


func _process(_delta: float) -> bool:
	cuadros += 1
	if cuadros < 12:
		return false
	var hierb := mundo.get_node_or_null("Hierba") as Hierba
	if hierb == null:
		push_error("no esta el campo de hierba en la escena")
		quit(1)
		return true
	print("hierba: %d hojas, visible %s, aabb %s"
		% [hierb.total(), str(hierb.is_visible_in_tree()),
			str(hierb.caja_del_campo())])
	var imagen := root.get_texture().get_image()
	if imagen == null:
		print("no hay imagen")
	else:
		_preparar_capturas()
		imagen.save_png("res://capturas/desde_arriba.png")
		print("foto guardada: %dx%d" % [imagen.get_width(), imagen.get_height()])
	quit(0)
	return true


## Las capturas se guardan en el proyecto, y esa carpeta no existe todavia en un
## clon nuevo, asi que se crea antes de la primera foto.
func _preparar_capturas() -> void:
	DirAccess.make_dir_recursive_absolute("res://capturas")
