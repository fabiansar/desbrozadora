extends SceneTree

## Medidor depgsql, NO es un test. Sirve para responder con numeros a "no veo
## frenado ni desgaste": cuanto carga el motor, cuanto baja de vueltas y cuanto
## se gasta el filo por segundo con cada cabezal en cada tipo de vegetacion.
##
##     godot --headless --path . --script tools/medir_cabezales.gd

var _mundo: Node3D
var _jugador: Jugador
var _herramienta: Desbrozadora
var _fails := 0


func _initialize() -> void:
	call_deferred("_ejecutar")


func _ejecutar() -> void:
	_mundo = load("res://scenes/main.tscn").instantiate() as Node3D
	root.add_child(_mundo)
	for _i in 40:
		await physics_frame
	_jugador = _mundo.get_node_or_null("Player") as Jugador
	_herramienta = _mundo.get_node_or_null(
		"Player/Caderas/PivoteDesbrozadora/Desbrozadora") as Desbrozadora
	if _jugador == null or _herramienta == null:
		push_error("main.tscn necesita jugador y desbrozadora")
		quit(1)
		return

	print("\n== carga, vueltas y desgaste por segundo ==")
	print("   donde                cabezal            carga  vueltas  %filo/s  ml/s")
	# El cesped esta por todas partes, asi que es el caso facile: cualquier punto
	# del mapa sirve. Para la maleza y la zarza hay que buscar la planta de verdad.
	await _medir("cesped", _punto_mas_denso(1), 1)

	var punto_maleza := _punto_mas_denso(2)
	await _medir("maleza alta", punto_maleza, 2)
	# La zarza es un Hierba de tipo 3, no una clase propia.
	var zarza := _mundo.get_node_or_null("Zarzas/ZarzaCercana") as Hierba
	if zarza != null and zarza.hojas_en_pie() > 0:
		await _medir("zarza", zarza.global_position + Vector3(0.0, 0.9, 0.0), 3)

	print("\n== la maqueta sigue cortando? (rpm_efectiva > 15%% de las maximas) ==")
	for c in _herramienta.cabezales_disponibles:
		_herramienta.cabezales_disponibles = _uno(c)
		_herramienta._montar_cabezal(0)
		# Antes escribia `_herramienta._desgaste_actual`, un campo privado de la
		# desbrozadora desde una herramienta. Ahora la estacion expone el metodo.
		_herramienta.estacion().reiniciar_desgaste()
		_jugador.global_position = _punto_mas_denso(3)
		_jugador.mirar_a(0.0, deg_to_rad(-30.0))
		await _esperar(25)
		_jugador.global_position.y = 0.95
		await _esperar(25)
		Input.action_press("acelerador")
		await _esperar(90)
		var carga := 0.0
		var min_rpm := 1e9
		for _i in 60:
			carga += clampf(_herramienta.densidad_debajo()
				/ maxf(_herramienta.densidad_corte, 1.0), 0.0, 1.0)
			min_rpm = minf(min_rpm, _herramienta.rpm_efectiva())
			await physics_frame
		Input.action_release("acelerador")
		await _esperar(10)
		# La carga CRUDO, sin dividir. Es lo que hace falta para elegir el
		# divisor bien: hay que saber cuanto pesa de verdad lo mas pesado, que
		# aqui esta saturando a 1,00 con cualquier cabezal.
		print("   tier 3 con %-20s carga=%.2f (cruda %.0f, divisor %.0f)  rpm minima=%.0f" % [
			c.nombre, carga / 60.0, _herramienta.densidad_debajo(),
			_herramienta.densidad_corte, min_rpm])
	_herramienta.cabezales_disponibles = _cabezales()

	print("\n== cuanto tarda cada cabezal en vaciar una pasada de 1 m ==")
	for c in _herramienta.cabezales_disponibles:
		print("   %-20s %5.0f hojas/s (hierba)  %5.0f celdas/s (zarza)"
			% [c.nombre, c.tasa_corte_para(1, 50.0), c.tasa_corte_para(3, 30.0)])

	_mundo.queue_free()
	await process_frame
	quit(0)


## Se coloca al jugador en un punto, acelera un rato con cada cabezal y mide lo
## que se ve: la carga, las vueltas y cuanto baja el filo.
func _medir(donde: String, punto: Vector3, _tipo: int) -> void:
	for indice in _herramienta.cabezales_disponibles.size():
		var cab: CabezalDesbrozadora = _herramienta.cabezales_disponibles[indice]
		_herramienta.cabezales_disponibles = _uno(cab)
		_herramienta._montar_cabezal(0)
		# Antes escribia `_herramienta._desgaste_actual`, un campo privado de la
		# desbrozadora desde una herramienta. Ahora la estacion expone el metodo.
		_herramienta.estacion().reiniciar_desgaste()
		_jugador.global_position = punto
		_jugador.mirar_a(0.0, deg_to_rad(-30.0))
		await _esperar(25)
		_jugador.global_position.y = 0.95
		await _esperar(25)

		Input.action_press("acelerador")
		await _esperar(40)
		# Se promedia un poco porque el motor esta entrando todavia.
		var carga := 0.0
		var vueltas := 0.0
		var muestras := 0
		var mora_antes := _herramienta.combustible_litros
		var desgaste_antes := _herramienta.desgaste_cabezal
		# Y hay que ANDAR. Quieto, el cabezal se come el disco en el primer
		# segundo y despues no hay nada que cortar: el desgaste medido con el
		# jugador parado sale a cero y parece que el filo no se gasta, cuando lo
		# que pasa es que no hay hierba debajo. En una vuelta de tres metros hay
		# vegetacion nueva entrando por delante todo el rato, que es como se
		# trabaja de verdad.
		for _i in 120:
			var angulo := float(_i) * 0.052
			_jugador.global_position = punto + Vector3(
				cos(angulo) * 1.5, 0.0, sin(angulo) * 1.5)
			carga += clampf(_herramienta.densidad_debajo()
				/ maxf(_herramienta.densidad_corte, 1.0), 0.0, 1.0)
			vueltas += _herramienta.rpm_efectiva()
			muestras += 1
			await physics_frame
		var mora := mora_antes - _herramienta.combustible_litros
		Input.action_release("acelerador")
		await _esperar(15)
		var segundos := 120.0 / 60.0
		var desgaste := (desgaste_antes - _herramienta.desgaste_cabezal) / segundos
		print("   %-20s %-18s %5.2f  %5.0f  %6.3f  %6.1f"
			% [donde, cab.nombre, carga / float(muestras), vueltas / float(muestras),
				desgaste, mora * 1000.0])
		_herramienta.cabezales_disponibles = _cabezales()


## Un array de un solo cabezal, del tipo que pide el export. El array tiene que
## ser tipado o Godot no deja asignarlo.
func _uno(c: CabezalDesbrozadora) -> Array[CabezalDesbrozadora]:
	var a: Array[CabezalDesbrozadora] = [c]
	return a


## Los cuatro, para poder dejar el array como estaba.
func _cabezales() -> Array[CabezalDesbrozadora]:
	var a: Array[CabezalDesbrozadora] = [
		load("res://resources/cabezales/serie.tres"),
		load("res://resources/cabezales/hilo.tres"),
		load("res://resources/cabezales/disco_2p.tres"),
		load("res://resources/cabezales/disco_3p.tres"),
	]
	return a


## Donde hay de verdad vegetacion del tipo pedido.
##
## No vale con coger el nodo y medir en su origen: las plantas se siembran
## repartidas por el mapa y el nodo esta en el (0,0,0) del mundo, asi que medir
## ahi es medir un descampado y todas las filas salen iguales. Se recorre el mapa
## buscando el punto con mas densidad de ese tipo.
func _punto_mas_denso(tipo: int) -> Vector3:
	var mejor := Vector3(20.0, 0.9, 20.0)
	var mejor_densidad := 0.0
	for nodo in _mundo.find_children("*", "Hierba", true, false):
		var h := nodo as Hierba
		if h == null or h.tipo_vegetacion() != tipo:
			continue
		for gx in 12:
			for gz in 12:
				var x := -45.0 + float(gx) * 8.0
				var z := -45.0 + float(gz) * 8.0
				var d := h.densidad_bajo(Vector3(x, 0.3, z), 1.0)
				if d > mejor_densidad:
					mejor_densidad = d
					mejor = Vector3(x, 0.9, z)
	return mejor


func _esperar(cuadros: int) -> void:
	for _i in cuadros:
		await physics_frame
