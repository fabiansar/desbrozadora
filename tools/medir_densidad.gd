extends SceneTree

## Cuanta hierba se aguanta sin que baje el ritmo. Se mide el tiempo de
## fotograma de verdad, con la grafica, en vez de suponer.

var mundo: Node3D
var fase := 0
var config := 0
var esperas := 0
var tiempos: Array = []
# Lo que trae la escena, que es lo que se juega de verdad. Se guarda aparte
# porque las medidas de abajo cambian la densidad y el radio sobre la marcha.
var densidad_juego := 30.0
var radio_juego := 34.0


func _initialize() -> void:
	mundo = load("res://scenes/main.tscn").instantiate()
	root.add_child(mundo)
	var jugador := mundo.get_node_or_null("Player")
	if jugador != null:
		jugador.visible = false
	var h := mundo.get_node_or_null("Cesped")
	if h != null:
		densidad_juego = h.densidad
		radio_juego = h.radio


func _medidas() -> Array:
	# [densidad, radio]. El primero es **el que trae la escena**, leido al
	# arrancar, para tener la cifra del campo tal como se juega y que no se
	# quede vieja si alguien cambia la hierba en el Inspector. Los demas suben
	# la densidad y bajan el radio, manteniendo un numero de hojas parecido al
	# campo real, para ver donde se rompe.
	return [[densidad_juego, radio_juego], [30.0, 20.0], [60.0, 20.0],
		[100.0, 20.0], [160.0, 20.0], [100.0, 14.0], [160.0, 14.0]]


func _process(delta: float) -> bool:
	var h := mundo.get_node_or_null("Cesped")
	match fase:
		0:
			var d: Array = _medidas()[config]
			h.densidad = d[0]
			h.radio = d[1]
			h.regenerar()
			esperas = 0
			fase = 1
		1:
			# Calentamiento: los primeros fotogramas pagan la subida de la
			# textura del viento y la del buffer de instancias.
			esperas += 1
			if esperas >= 25:
				tiempos = []
				fase = 2
		2:
			tiempos.append(delta)
			if tiempos.size() >= 40:
				var orden := tiempos.duplicate()
				orden.sort()
				var mediana: float = orden[int(orden.size() / 2)]
				var peor: float = orden[orden.size() - 1]
				print("  %3d hojas/m2  radio %2.0f m  %7d hojas  %8d triangulos   mediana %5.1f ms (%4.0f fps)   peor %5.1f ms"
					% [h.densidad, h.radio, h.total(), h.total() * 6,
						mediana * 1000.0, 1.0 / mediana, peor * 1000.0])
				config += 1
				if config >= _medidas().size():
					print("fin")
					quit(0)
					return true
				fase = 0
	return false
