extends SceneTree

## Captura la pose de trabajo mirando al cabezal para iterar cuerpo y anclaje.

const ESPERA_FOTOGRAMAS := 75
const SALIDA := "res://capturas/personaje_primera_persona.png"

var _mundo: Node3D
var _fotogramas := 0


func _initialize() -> void:
	_mundo = load("res://scenes/main.tscn").instantiate()
	root.add_child(_mundo)


func _process(_delta: float) -> bool:
	_fotogramas += 1
	if _fotogramas == 2:
		var jugador := _mundo.get_node("Player") as Jugador
		jugador.mirar_a(0.0, deg_to_rad(-80.0))
	if _fotogramas < ESPERA_FOTOGRAMAS:
		return false
	var imagen := root.get_texture().get_image()
	if imagen == null:
		push_error("no se pudo capturar la vista de primera persona")
		quit(1)
		return true
	var ruta := ProjectSettings.globalize_path(SALIDA)
	var error := imagen.save_png(ruta)
	if error != OK:
		push_error("no se pudo guardar %s (error %d)" % [ruta, error])
		quit(1)
		return true
	print("captura en primera persona: %s (%dx%d)"
		% [ruta, imagen.get_width(), imagen.get_height()])
	quit(0)
	return true
