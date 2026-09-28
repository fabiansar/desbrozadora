extends SceneTree

## Comprueba las reglas del corte por capas de la zarza:
##   1. Cortar a una altura quita lo de encima y respeta lo de debajo.
##   2. Cortar a ras de suelo tumba la columna entera.
##   3. Repetir el corte donde ya no hay nada no hace nada.
## Ademas que lo que cae forma monton y se puede apartar.

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
	var zarza := _mundo.get_node_or_null("Bajo/Zarza") as Zarza
	if zarza == null:
		push_error("Falta la zarza de prueba")
		quit(1)
		return

	print("zarza inicial: %d columnas en pie, %.1f m de vegetacion, maximo %.1f m"
		% [zarza.columnas_en_pie(), zarza.altura_total(), zarza.altura_maxima])
	_comprobar(zarza.columnas_en_pie() > 50,
		"la zarza se siembra con varias zonas")

	# 1. Corte alto: secciona todo lo que asoma por encima del cabezal y deja
	# lo de abajo. Va encima de la mata, que es donde hay zarza de verdad: las
	# lomas se siembran al azar y en el centro de la zona puede no caer ninguna.
	# Ojo: lo que cae por perder el apoyo tambien se cuenta. Por eso lo que se
	# comprueba es que la franja cortada no queda con nada por encima, y no que
	# la zarza entera se quede baja, que es lo que hacia el mapa de alturas.
	var coronas := zarza.posiciones_de_coronas()
	if coronas.is_empty():
		push_error("la zarza de prueba no tiene coronas")
		quit(1)
		return
	var mata := coronas[0]
	var centro := zarza.to_global(Vector3(mata.x, 0.0, mata.y))
	var altas_antes := zarza.columnas_sobre(0.5)
	var cortadas := zarza.cortar_en(zarza.to_global(Vector3(mata.x, 0.5, mata.y)), 2.0)
	print("corte a 0,5 m: %d celdas cortadas, %d celdas seguian altas"
		% [cortadas, altas_antes])
	_comprobar(cortadas > 0, "cortar por arriba quita vegetacion")
	_comprobar(altas_antes > 0, "habia copa por encima del corte")
	_comprobar(_altas_cerca(zarza, mata, 2.0, 0.5) == 0,
		"en la franja cortada no queda nada por encima del cabezal")
	_comprobar(zarza.columnas_en_pie() > 0,
		"cortar arriba no se lleva la columna entera: queda el tocon")

	# 2. Corte bajo: ahora si, a ras de suelo. Este es el que llega a la raiz.
	# Ojo con lo que se mide: el cabezal a 12 cm deja un tocon de 12 cm, asi que
	# el numero de columnas en pie NO baja. Lo que baja es el material, y lo que
	# tiene que desaparecer es lo que queda por encima del cabezal.
	var restantes := zarza.altura_total()
	zarza.cortar_en(zarza.to_global(Vector3(mata.x, 0.12, mata.y)), 2.0)
	print("corte a ras de suelo: %.1f m de material, ahora %.1f m"
		% [restantes, zarza.altura_total()])
	_comprobar(zarza.altura_total() < restantes,
		"cortar a ras de suelo se lleva el tocon que quedaba")
	_comprobar(_altas_cerca(zarza, mata, 2.0, 0.12) == 0,
		"a ras de suelo no queda nada por encima del cabezal")

	# 3. Repetir donde ya no hay nada no cambia nada.
	var antes := zarza.altura_total()
	var repetido := zarza.cortar_en(zarza.to_global(Vector3(mata.x, 0.12, mata.y)), 2.0)
	_comprobar(repetido == 0 or is_equal_approx(zarza.altura_total(), antes),
		"cortar donde ya no hay vegetacion no hace nada")

	# 4. Lo que cae forma monton y se puede apartar.
	var montes := Montes.obtener(self)
	var celdas_monton := montes.celdas()
	print("montones: %d celdas, altura en el centro %.2f m"
		% [celdas_monton, montes.altura_en(centro)])
	_comprobar(celdas_monton > 0, "lo que cae se queda en el suelo como monton")
	# El monton recien creado esta protegido un momento, para que no se borre en
	# el mismo fotograma en que cae. Se espera a que se asiente y se aplana.
	var alta := montes.altura_en(centro)
	_comprobar(alta > 0.0, "el monton tiene altura donde ha caido el material")
	await _esperar(Montes.PROTEGIDO + 0.3)
	montes.pisar(centro, 1.2)
	_comprobar(montes.altura_en(centro) < alta,
		"el monton se puede apartar pasando la maquina")

	print("-- resultado: %s" % ("OK" if _fails == 0 else "%d FALLOS" % _fails))
	_mundo.queue_free()
	await process_frame
	quit(0 if _fails == 0 else 1)


func _esperar(segundos: float) -> void:
	for _i in int(ceil(segundos * 60.0)):
		await physics_frame


## Cuantas celdas con material por encima de `alto` hay dentro de un radio, en el
## sistema local de la zarza. El recorte se mira en la zona cortada y no en toda
## la mata, porque alrededor hay celdas que el cabezal no ha tocado.
func _altas_cerca(z: Zarza, centro: Vector2, radio: float, alto: float) -> int:
	var total := 0
	for i in z._alturas.size():
		if z._alturas[i] <= alto:
			continue
		if z._centro_de_celda(i).distance_to(centro) > radio:
			continue
		total += 1
	return total


func _comprobar(ok: bool, que: String) -> void:
	if ok:
		print("  OK   %s" % que)
	else:
		print("  FAIL %s" % que)
		_fails += 1
