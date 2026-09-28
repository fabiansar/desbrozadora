extends CanvasLayer

## Panel temporal de telemetria de la herramienta. Solo consume la señal publica;
## no lee ni modifica el estado interno de la simulacion.

var _rpm: Label
var _rpm_barra: ProgressBar
var _carga: Label
var _carga_barra: ProgressBar
var _combustible: Label
var _combustible_barra: ProgressBar
var _cabezal: Label
var _desgaste: Label
var _desgaste_barra: ProgressBar


func _ready() -> void:
	layer = 10
	_construir_panel()
	call_deferred("_conectar_herramienta")


func _conectar_herramienta() -> void:
	# Se conecta a SU PROPIO padre y no a lo que encuentre en el grupo
	# "herramienta". Con la hoz equipada hay dos herramientas en el mundo, y
	# buscar en el grupo podia dar con la desbrozadora guardada: el panel se
	# connectaba a una maquina que no era la que llevaba el operario.
	var herramienta := get_parent() as Desbrozadora
	if herramienta == null:
		return
	herramienta.telemetria_actualizada.connect(_actualizar)
	_actualizar(herramienta.rpm, herramienta.rpm_efectiva(), herramienta.rpm_maximas,
		herramienta.resistencia(), herramienta.combustible_litros,
		herramienta.combustible_maximo_litros, herramienta.nombre_cabezal,
		herramienta.desgaste_cabezal)


func _construir_panel() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(18.0, 18.0)
	panel.custom_minimum_size = Vector2(240.0, 0.0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fondo := StyleBoxFlat.new()
	fondo.bg_color = Color(0.035, 0.055, 0.045, 0.88)
	fondo.set_corner_radius_all(5)
	fondo.content_margin_left = 12.0
	fondo.content_margin_right = 12.0
	fondo.content_margin_top = 9.0
	fondo.content_margin_bottom = 9.0
	panel.add_theme_stylebox_override("panel", fondo)
	add_child(panel)

	var filas := VBoxContainer.new()
	filas.add_theme_constant_override("separation", 3)
	panel.add_child(filas)
	var titulo := Label.new()
	titulo.text = "DESBROZADORA"
	titulo.add_theme_color_override("font_color", Color(0.83, 0.88, 0.78))
	filas.add_child(titulo)
	var ayuda := Label.new()
	ayuda.text = "Q · cambiar cabezal con motor parado"
	ayuda.add_theme_font_size_override("font_size", 12)
	ayuda.add_theme_color_override("font_color", Color(0.7, 0.74, 0.66))
	filas.add_child(ayuda)

	var fila_rpm := _crear_fila(filas, "RPM")
	_rpm = fila_rpm[0] as Label
	_rpm_barra = fila_rpm[1] as ProgressBar
	var fila_carga := _crear_fila(filas, "CARGA")
	_carga = fila_carga[0] as Label
	_carga_barra = fila_carga[1] as ProgressBar
	var fila_combustible := _crear_fila(filas, "GASOLINA")
	_combustible = fila_combustible[0] as Label
	_combustible_barra = fila_combustible[1] as ProgressBar
	var fila_cabezal := _crear_fila(filas, "CABEZA")
	_cabezal = fila_cabezal[0] as Label
	var fila_desgaste := _crear_fila(filas, "FILO")
	_desgaste = fila_desgaste[0] as Label
	_desgaste_barra = fila_desgaste[1] as ProgressBar


func _crear_fila(contenedor: VBoxContainer, nombre: String) -> Array:
	var etiqueta := Label.new()
	etiqueta.text = "%s  —" % nombre
	etiqueta.add_theme_color_override("font_color", Color(0.94, 0.95, 0.9))
	contenedor.add_child(etiqueta)
	var barra := ProgressBar.new()
	barra.min_value = 0.0
	barra.max_value = 1.0
	barra.show_percentage = false
	barra.custom_minimum_size = Vector2(210.0, 12.0)
	barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	contenedor.add_child(barra)
	return [etiqueta, barra]


func _actualizar(rpm_sin_carga: float, rpm_cargadas: float, rpm_maximas: float,
		resistencia: float, combustible_litros: float,
		combustible_maximo_litros: float, nombre_cabezal: String,
		desgaste_cabezal: float) -> void:
	_rpm.text = "RPM  %d / %d" % [roundi(rpm_cargadas), roundi(rpm_sin_carga)]
	_rpm_barra.value = clampf(rpm_cargadas / maxf(rpm_maximas, 1.0), 0.0, 1.0)
	_carga.text = "CARGA  %d %%" % roundi(resistencia * 100.0)
	_carga_barra.value = clampf(resistencia, 0.0, 1.0)
	_combustible.text = "GASOLINA  %.2f / %.2f L" % [
		combustible_litros, combustible_maximo_litros]
	_combustible_barra.value = clampf(
		combustible_litros / maxf(combustible_maximo_litros, 0.001), 0.0, 1.0)
	_cabezal.text = "CABEZA  %s" % nombre_cabezal
	_desgaste.text = "FILO  %d %%" % roundi(desgaste_cabezal * 100.0)
	_desgaste_barra.value = clampf(desgaste_cabezal, 0.0, 1.0)
