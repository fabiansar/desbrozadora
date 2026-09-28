extends SceneTree

## Recorre las tres zonas de zarza con el jugador y la desbrozadora reales, a
## distintas alturas de cabeza, y comprueba que el trabajo va quitting capas: una
## pasada por arriba quita la copa, y hace falta otra abajo para rematar el tocon.

var _mundo: Node3D
var _jugador: Jugador
var _herramienta: Desbrozadora
var _fails := 0


func _initialize() -> void:
	call_deferred("_ejecutar")


func _ejecutar() -> void:
	_mundo = load("res://scenes/capas_zarza.tscn").instantiate() as Node3D
	root.add_child(_mundo)
	_jugador = _mundo.get_node_or_null("Player") as Jugador
	for nodo in get_nodes_in_group("herramienta"):
		if nodo is Desbrozadora:
			_herramienta = nodo as Desbrozadora
			break
	if _jugador == null or _herramienta == null:
		push_error("La escena necesita jugador y desbrozadora")
		quit(1)
		return
	for _i in 60:
		await physics_frame
	Input.action_press("acelerador")
	var montes := Montes.obtener(self)

	for zona in ["Bajo", "Medio", "Alto"]:
		var zarza := _mundo.get_node_or_null(zona + "/Zarza") as Zarza
		if zarza == null:
			print("%s: sin zarza" % zona)
			continue
		print("-- zona %s: %d columnas, %.1f m, maximo %.1f m"
			% [zona, zarza.columnas_en_pie(), zarza.altura_total(),
			zarza.altura_maxima])
		var inicio := zarza.altura_total()
		# Las pasadas van por encima de la mata, no por el centro de la zona: las
		# lomas se siembran al azar y la zarza no esta repartida por igual, asi que
		# una pasada por el centro puede no tocar nada y parecer que no corta.
		var coronas := zarza.posiciones_de_coronas()
		if coronas.is_empty():
			print("   sin coronas: se salta la zona")
			continue
		var mata := coronas[0]
		# Pasada alta: cruza la zona entera a la altura de la copa.
		await _barrer(zarza, minf(zarza.altura_maxima * 0.6, 0.8), mata.x)
		var tras_arriba := zarza.altura_total()
		print("   pasada alta: %.1f -> %.1f m" % [inicio, tras_arriba])
		_comprobar(tras_arriba < inicio,
			"pasada por arriba quita vegetacion de verdad")
		# Pasada baja, desplazada de lado para tapar lo que dejo la primera.
		await _barrer(zarza, 0.1, mata.x)
		await _barrer(zarza, 0.1, mata.x + 1.1)
		var tras_bajo := zarza.altura_total()
		print("   pasada baja: %.1f -> %.1f m, quedan %d columnas"
			% [tras_arriba, tras_bajo, zarza.columnas_en_pie()])
		_comprobar(tras_bajo < tras_arriba,
			"hace falta una segunda pasada abajo para rematar el tocon")
		print("   montones acumulados: %d celdas" % montes.celdas())

	Input.action_release("acelerador")
	await _esperar(2.0)
	print("final: montones %d celdas, restos %d"
		% [montes.celdas(), int(Restos.obtener(self).recuento()["soltados"])])
	print("-- resultado: %s" % ("OK" if _fails == 0 else "%d FALLOS" % _fails))
	_mundo.queue_free()
	await process_frame
	quit(0 if _fails == 0 else 1)


## Cruza la zona de un lado a otro con la cabeza a la altura pedida, desplazado
## `desplazamiento` metros en X para no pasar siempre por la misma linea.
func _barrer(referencia: Zarza, altura: float, desplazamiento: float) -> void:
	# El cabezal cuelga de la mirada, asi que la altura se pide mirando mas o
	# menos arriba. La maquina no llega muy alto, de ahi el tope.
	var objetivo := clampf(altura / 0.9, 0.0, 1.0)
	_jugador.mirar_a(0.0, deg_to_rad(lerpf(-30.0, 12.0, objetivo)))
	await _esperar(0.2)
	# Coloca al jugador en el borde +Z de la zona, desplazado en X, mirando a -Z.
	# Se mueve lo justo para que el CABEZAL quede en ese punto.
	var punto := _herramienta.punto_de_corte()
	var destino := referencia.to_global(Vector3(desplazamiento, altura,
		referencia.fondo * 0.5 + 1.6))
	var posicion := _jugador.global_position
	posicion.x += destino.x - punto.x
	posicion.z += destino.z - punto.z
	_jugador.global_position = posicion
	await _esperar(0.25)
	Input.action_press("mover_adelante")
	for _f in 320:
		await physics_frame
	Input.action_release("mover_adelante")
	await _esperar(0.3)


func _comprobar(ok: bool, que: String) -> void:
	if ok:
		print("  OK   %s" % que)
	else:
		print("  FAIL %s" % que)
		_fails += 1


func _esperar(segundos: float) -> void:
	for _i in int(ceil(segundos * 60.0)):
		await physics_frame
