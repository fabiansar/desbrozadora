class_name VersionPantalla
extends CanvasLayer

## Cartel con el nombre y la version, al arrancar, que se quita solo.
##
## No esta en el panel de la herramienta a proposito. Ese cuelga de la
## desbrozadora y va con ella, y esto es de la escena: el numero del programa
## es del programa, no de la maquina que llevas en la mano.
##
## El texto se arma con **la version de la configuracion**, no con una constante
## escrita aqui. Si las dos cosas se escriben a mano, subir la version obliga a
## tocar dos sitios y siempre se olvida uno.

## Segundos que se ve antes de quitarse.
const SEGUNDOS := 2.5


var _etiqueta: Label
## Segundos que lleva puesto. Los lleva el propio cartel con un contador y no con
## un `Tween` porque el proyecto ya se comio ese problema: un `Tween` o un
## `await` sin esperar se quedan parados en el primer fotograma, y en headless
## no se ve. Ver `tools/test_version_pantalla.gd`.
var _edad := 0.0
## Cuando ya se ha ido, para no seguir procesando.
var _terminado := false


func _ready() -> void:
	# Por encima del panel de la herramienta, que esta en la capa 10.
	layer = 100
	_etiqueta = _construir_cartel()


func _process(delta: float) -> void:
	if _terminado:
		return
	_avanzar(delta)


## El reloj, suelto del `_process` para poder probarlo sin esperar los dos
## segundos y medio de verdad.
func _avanzar(delta: float) -> void:
	if _terminado:
		return
	_edad += delta
	if _etiqueta != null and _edad >= SEGUNDOS:
		# Se quita de golpe, sin desvanecido. Un desvanecido seccionaria el
		# cartel a mitad de partida mientras el jugador esta mirando, y no
		# compensa estorbar a cambio de cuatro lineas.
		_terminado = true
		_etiqueta.visible = false
		set_process(false)


## Lo que pone el cartel. exposed para la prueba.
func texto_del_cartel() -> String:
	var nombre := str(ProjectSettings.get_setting("application/config/name", "Desbrozadora"))
	var version := str(ProjectSettings.get_setting("application/config/version", ""))
	if version.is_empty():
		# No es un caso teorico: si alguien borra la linea de `project.godot` el
		# ejecutable sigue arrancando igual, sin version y sin avisar. Aqui al
		# menos se ve que falta.
		push_warning("Falta application/config/version en project.godot.")
		return "%s  (sin version)" % nombre
	return "%s   v%s" % [nombre, version]


## Si el cartel sigue en pantalla. Para la prueba.
func esta_visible() -> bool:
	return not _terminado


func _construir_cartel() -> Label:
	# El cartel va arriba del todo y no en el centro de verdad: en el centro se
	# mezcla con lo que se esta haciendo al arrancar, que es mirar alrededor.
	var relleno := MarginContainer.new()
	relleno.set_anchors_preset(Control.PRESET_FULL_RECT)
	relleno.add_theme_constant_override("margin_top", 64)

	var centro := CenterContainer.new()
	relleno.add_child(centro)

	var etiqueta := Label.new()
	etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	etiqueta.add_theme_font_size_override("font_size", 26)
	etiqueta.add_theme_color_override("font_color", Color(0.92, 0.90, 0.84))
	# Con contorno, porque el cartel sale contra el cielo y contra un cesped
	# iluminado, y las dos cosas se comen un gris claro.
	etiqueta.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	etiqueta.add_theme_constant_override("outline_size", 6)
	etiqueta.text = texto_del_cartel()
	centro.add_child(etiqueta)

	add_child(relleno)
	return etiqueta
