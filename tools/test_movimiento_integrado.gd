extends SceneTree

## Pruebas integradas del movimiento base en combinaciones de uso real.
##
## Ejecutar solo este recorrido, sin la suite completa:
##   flatpak run --filesystem=$HOME/Documentos org.godotengine.Godot \
##     --headless --path . --script res://tools/test_movimiento_integrado.gd

var _empezado := false
var _correctas := 0
var _fallos := 0
var _mundo: Node3D
var _jugador: Jugador
var _camara: CamaraGopro
var _herramienta: Desbrozadora


func _process(_delta: float) -> bool:
	if not _empezado:
		_empezado = true
		_ejecutar()
	return false


func _ejecutar() -> void:
	print("== prueba integrada de movimiento ==")
	_mundo = load("res://scenes/main.tscn").instantiate()
	root.add_child(_mundo)
	await physics_frame
	_jugador = _mundo.get_node_or_null("Player") as Jugador
	_camara = _mundo.get_node_or_null("Player/Cabeza/Camara") as CamaraGopro
	_herramienta = _buscar_herramienta()
	_comprobar(_jugador != null and _camara != null and _herramienta != null,
		"escena con jugador, camara y herramienta")
	if _jugador == null or _camara == null or _herramienta == null:
		_finalizar()
		return

	_soltar_todo()
	await _esperar(1.5)
	_comprobar(_jugador.is_on_floor(), "inicio apoyado en el suelo")
	_comprobar(absf(_camara.global_position.y - 1.62) < 0.08,
		"altura inicial de camara estable")
	_probar_radio_corte_compartido()

	await _probar_paneo_y_barrido()
	await _probar_wasd_carrera_y_motor()
	await _probar_estrafes()
	await _probar_reversa()
	await _probar_agachado_en_marcha()
	await _probar_salto_mientras_corta()

	_soltar_todo()
	await _esperar(1.2)
	_comprobar(_jugador.is_on_floor(), "fin de recorrido estable en el suelo")
	_comprobar(_vector_finito(_jugador.global_position), "posicion final finita")
	_comprobar(_barrido_en_rango(), "barrido final dentro de los topes del arnes")
	_finalizar()


func _probar_radio_corte_compartido() -> void:
	print("-- radio del cabezal compartido por los campos --")
	_comprobar(_herramienta.radio_corte > 0.5,
		"el radio efectivo deja un ancho de pasada visible (%.2f m)"
		% _herramienta.radio_corte)
	for nombre in ["Hierba", "MalezaAlta"]:
		var campo := _mundo.get_node_or_null(nombre) as Hierba
		_comprobar(campo != null, "%s está disponible para cortar" % nombre)
		if campo == null or campo.total() == 0:
			continue
		var punto := campo.posicion_hoja(campo.total() / 2)
		var de_pie_antes := campo.total_de_pie()
		var cortadas := campo.cortar(punto, _herramienta.radio_corte)
		_comprobar(cortadas > 1,
			"el mismo cabezal deja un parche visible en %s (%d hojas)"
			% [nombre, cortadas])
		_comprobar(campo.total_de_pie() == de_pie_antes - cortadas,
			"el corte se registra correctamente en %s" % nombre)


func _probar_paneo_y_barrido() -> void:
	print("-- paneo, pitch y barrido --")
	_soltar_todo()
	_jugador.rotation.y = 0.0
	_jugador.mirar_a(0.0, 0.0)
	await _esperar(0.6)
	_jugador.mirar_a(deg_to_rad(28.0), deg_to_rad(-30.0))
	await _esperar(0.8)
	_comprobar(_error_camara(deg_to_rad(28.0)) < 2.0,
		"camara panea y alcanza la direccion pedida")
	_comprobar(_camara.is_position_in_frustum(_herramienta.punto_de_corte()),
		"cabezal dentro del encuadre durante paneo y pitch abajo")
	_comprobar(_herramienta.angulo_barrido() > deg_to_rad(20.0),
		"paneo a la izquierda inicia el barrido de la maquina")
	_comprobar(_barrido_en_rango(), "paneo izquierdo respeta el tope del arnes")

	_jugador.mirar_a(deg_to_rad(-35.0), deg_to_rad(15.0))
	await _esperar(1.0)
	_comprobar(_herramienta.angulo_barrido() < -deg_to_rad(20.0),
		"paneo inverso lleva la maquina al lado derecho")
	_comprobar(_barrido_en_rango(), "paneo inverso respeta el tope derecho")
	_comprobar(_camara.is_position_in_frustum(_herramienta.punto_de_corte()),
		"cabezal visible al paneo inverso y mirar arriba")

	print("-- mirar arriba con el motor en marcha --")
	Input.action_press("acelerador")
	_jugador.mirar_a(deg_to_rad(-35.0), deg_to_rad(45.0))
	await _esperar(1.0)
	_comprobar(_herramienta.cortando,
		"el motor sigue activo al levantar la mirada")
	_comprobar(_camara.is_position_in_frustum(_herramienta.punto_de_corte()),
		"el cabezal no desaparece con motor encendido y mirada alta")
	var agarre_i := _herramienta.get_node_or_null("AgarreIzquierdo") as Marker3D
	var agarre_d := _herramienta.get_node_or_null("AgarreDerecho") as Marker3D
	_comprobar(agarre_i != null and _vector_finito(agarre_i.global_position)
		and agarre_d != null and _vector_finito(agarre_d.global_position),
		"ambos objetivos de manos siguen finitos al elevar la maquina")
	_comprobar(_barrido_en_rango(), "mirar arriba con motor no rompe el tope de barrido")
	Input.action_release("acelerador")
	_jugador.mirar_a(0.0, deg_to_rad(-25.0))
	await _esperar(0.8)


func _probar_wasd_carrera_y_motor() -> void:
	print("-- W+D, carrera, acelerador y herramienta --")
	_soltar_todo()
	_jugador.rotation.y = 0.0
	_jugador.mirar_a(0.0, deg_to_rad(-25.0))
	await _esperar(0.7)
	var antes := _jugador.global_position
	var fov_antes := _camara.fov
	Input.action_press("mover_adelante")
	Input.action_press("mover_derecha")
	Input.action_press("correr")
	Input.action_press("acelerador")
	await _esperar(0.9)
	var desplazamiento := _jugador.global_position - antes
	_comprobar(desplazamiento.length() > 1.8,
		"W+D con Shift desplaza al jugador (%.2f m)" % desplazamiento.length())
	_comprobar(_jugador.get_correr() and _jugador.get_velocidad_plano() > 4.5,
		"la carrera diagonal mantiene la velocidad de carrera")
	_comprobar(_camara.fov > fov_antes + 5.0,
		"el FOV responde a la carrera durante la diagonal")
	_comprobar(_herramienta.rpm > 5000.0 and _herramienta.cortando,
		"el acelerador mantiene el motor cortando mientras se mueve")
	_comprobar(_barrido_en_rango(), "W+D no saca la maquina del arco de cadera")
	_comprobar(_error_camara(_jugador.get_yaw()) < 4.0,
		"la camara mantiene la mirada mientras el cuerpo gira con W+D")
	_comprobar(_vector_finito(_jugador.global_position)
		and _vector_finito(_herramienta.punto_de_corte()),
		"W+D y acelerador no producen transformaciones invalidas")
	_soltar_todo()
	await _esperar(0.8)


func _probar_estrafes() -> void:
	print("-- A y D con motor encendido --")
	_jugador.rotation.y = 0.0
	_jugador.mirar_a(0.0, deg_to_rad(-25.0))
	await _esperar(0.6)
	var antes_a := _jugador.global_position
	Input.action_press("mover_izquierda")
	Input.action_press("acelerador")
	await _esperar(0.5)
	var dx_a := _jugador.global_position.x - antes_a.x
	_comprobar(dx_a < -0.2, "A desplaza hacia la izquierda (dx=%.2f)" % dx_a)
	_comprobar(_jugador.rotation.y == 0.0,
		"A no gira el torso mientras barre")
	_comprobar(_herramienta.angulo_barrido() > 0.0,
		"A barre la herramienta hacia la izquierda")
	_comprobar(_barrido_en_rango(), "A respeta el tope izquierdo")
	_soltar_todo()
	await _esperar(0.7)

	var antes_d := _jugador.global_position
	Input.action_press("mover_derecha")
	Input.action_press("acelerador")
	await _esperar(0.5)
	var dx_d := _jugador.global_position.x - antes_d.x
	_comprobar(dx_d > 0.2, "D desplaza hacia la derecha (dx=%.2f)" % dx_d)
	_comprobar(_jugador.rotation.y == 0.0,
		"D no gira el torso mientras barre")
	_comprobar(_herramienta.angulo_barrido() < 0.0,
		"D barre la herramienta hacia la derecha")
	_comprobar(_barrido_en_rango(), "D respeta el tope derecho")
	_soltar_todo()
	await _esperar(0.8)


func _probar_reversa() -> void:
	print("-- S, motor y carrera --")
	_jugador.rotation.y = 0.0
	_jugador.mirar_a(0.0, 0.0)
	await _esperar(0.5)
	var yaw_camara := _yaw_camara()
	var z_antes := _jugador.global_position.z
	Input.action_press("mover_atras")
	Input.action_press("correr")
	Input.action_press("acelerador")
	await _esperar(0.6)
	_comprobar(_jugador.global_position.z > z_antes + 0.5,
		"S mueve hacia atras corriendo")
	_comprobar(_jugador.rotation.y == 0.0,
		"S no da la vuelta al cuerpo")
	_comprobar(_error_camara(yaw_camara) < 2.0,
		"la camara no pega un giro de 180 grados con S")
	_comprobar(_herramienta.cortando,
		"la herramienta sigue acelerada durante la marcha atras")
	_soltar_todo()
	await _esperar(0.8)


func _probar_agachado_en_marcha() -> void:
	print("-- agacharse y correr mientras corta --")
	_jugador.rotation.y = 0.0
	_jugador.mirar_a(0.0, deg_to_rad(-25.0))
	await _esperar(0.6)
	var altura_parado := _altura_camara_relativa()
	Input.action_press("acelerador")
	await _esperar(0.9)
	var altura_motor := _altura_camara_relativa()
	var z_antes := _jugador.global_position.z
	Input.action_press("mover_adelante")
	Input.action_press("correr")
	Input.action_press("agacharse")
	await _esperar(0.65)
	var bajada := altura_motor - _altura_camara_relativa()
	_comprobar(bajada > 0.40 and bajada < 0.70,
		"agacharse baja la camara una altura (%.2f m)" % bajada)
	_comprobar(_jugador.get_correr() and _jugador.get_velocidad_plano() > 4.5,
		"W+Shift+Ctrl conserva carrera y avance")
	_comprobar(_jugador.global_position.z < z_antes - 1.0,
		"W+Shift+Ctrl avanza mientras se agacha")
	_comprobar(_herramienta.cortando,
		"se puede seguir cortando mientras se agacha y corre")
	_comprobar(_barrido_en_rango(), "agachado corriendo mantiene el barrido limitado")
	_comprobar(_camara.is_position_in_frustum(_herramienta.punto_de_corte()),
		"el cabezal sigue visible agachado, corriendo y cortando")
	Input.action_release("mover_adelante")
	Input.action_release("correr")
	Input.action_release("agacharse")
	await _esperar(0.7)
	_comprobar(absf(_altura_camara_relativa() - altura_motor) < 0.12,
		"la camara vuelve al nivel de motor encendido al levantarse")
	Input.action_release("acelerador")
	await _esperar(0.9)
	_comprobar(absf(_altura_camara_relativa() - altura_parado) < 0.12,
		"la camara vuelve a la altura normal al soltar el acelerador")


func _probar_salto_mientras_corta() -> void:
	print("-- salto, avance y acelerador --")
	_jugador.rotation.y = 0.0
	_jugador.mirar_a(0.0, 0.0)
	await _esperar(0.5)
	Input.action_press("mover_adelante")
	Input.action_press("saltar")
	Input.action_press("acelerador")
	await _esperar(0.18)
	_comprobar(_jugador.velocity.y > 0.0, "Espacio salta mientras avanza")
	_comprobar(_herramienta.cortando, "la maquina no se para al saltar")
	Input.action_release("saltar")
	await _esperar(0.8)
	Input.action_release("mover_adelante")
	Input.action_release("acelerador")
	await _esperar(1.0)
	_comprobar(_jugador.is_on_floor(), "aterriza sin quedarse atascado")
	_comprobar(_vector_finito(_jugador.global_position), "el salto no genera NaN")


func _buscar_herramienta() -> Desbrozadora:
	for nodo in get_nodes_in_group("herramienta"):
		if nodo is Desbrozadora:
			return nodo as Desbrozadora
	return null


func _esperar(segundos: float) -> void:
	var cuadros := maxi(1, int(ceil(segundos * Engine.physics_ticks_per_second)))
	for _i in cuadros:
		await physics_frame
		await process_frame


func _soltar_todo() -> void:
	for accion in ["mover_adelante", "mover_atras", "mover_izquierda",
			"mover_derecha", "correr", "agacharse", "saltar", "acelerador"]:
		Input.action_release(accion)


func _barrido_en_rango() -> bool:
	var angulo := _herramienta.angulo_barrido()
	return angulo >= -deg_to_rad(_herramienta.max_right_angle) - 0.04 \
		and angulo <= deg_to_rad(_herramienta.max_left_angle) + 0.04


func _yaw_camara() -> float:
	var delante := -_camara.global_transform.basis.z
	return atan2(-delante.x, -delante.z)


func _altura_camara_relativa() -> float:
	return _camara.global_position.y - _jugador.global_position.y


func _error_camara(yaw: float) -> float:
	return absf(rad_to_deg(wrapf(_yaw_camara() - yaw, -PI, PI)))


func _vector_finito(valor: Vector3) -> bool:
	return is_finite(valor.x) and is_finite(valor.y) and is_finite(valor.z)


func _comprobar(condicion: bool, nombre: String) -> void:
	if condicion:
		_correctas += 1
		print("  OK   ", nombre)
	else:
		_fallos += 1
		printerr("  FAIL ", nombre)


func _finalizar() -> void:
	_soltar_todo()
	print("== resultado: %d correctas, %d fallos ==" % [_correctas, _fallos])
	quit(1 if _fallos > 0 else 0)
