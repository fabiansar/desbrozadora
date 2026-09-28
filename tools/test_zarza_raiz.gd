extends SceneTree

## La garantia de la zarza: **una pasada de verdad tumba una raiz**.
##
##     godot --headless --path . --script tools/test_zarza_raiz.gd
##
## Las demas pruebas de zarza (`test_zarza_conexion.gd`, `test_zarza_capas.gd`)
## cortan llamando a `cortar_en()` con el punto que se les pasa. Eso demuestra que
## la MECANICA esta bien, pero no que se pueda jugar. Si el cabezal no llegara a
## la altura a la que hay que cortar la raiz, el jugador se pasaria la partida
## quitando copas y no podria terminar nunca, y ninguna de esas pruebas lo
## detectaria.
##
## Aqui no se simula nada: se carga `main.tscn`, se anda con el jugador hasta una
## raiz, se corta por arriba, luego a la base, y se mira que la raiz solo muere en
## la segunda pasada.
##
## Tres cosas de este archivo que costaron una hora:
##
## 1. Al colocar al jugador se compensa con la POSICION DEL CABEZAL, no con una
##    rotacion a ojo. Asi el cabezal cae encima de la raiz este donde este, y si
##    mañana se cambia el alcance la prueba sigue valiendo.
## 2. El morro solo baja del todo **con el acelerador pulsado**: al trabajar, la
##    maquina echa el peso del cuerpo sobre el. Sin acelerar se queda a nueve
##    centimetros del suelo y no corta nada, aunque el jugador mire de narices.
## 3. Las esperas llevan `await` y son de CIENTOS de fotogramas. El motor tarda
##    0,85 s en subir a sus vueltas, asi que con cuarenta fotogramas sigue parado
##    y la prueba falla por el motivo equivocado. Y una corrutina llamada sin
##    `await` no espera: se queda suspendida en su primer `await physics_frame` y
##    el codigo sigue como si nada. Sin ponerlo, la prueba pasaba sin esperar.
##
## Y el rango de trabajo del morro, medido con el motor echado, que es lo que
## hace falta para elegir la inclinacion de cada pasada:
##
##     mirando arriba 55 grados   morro a 1,34 m
##     mirando arriba 35 grados   morro a 1,97 m
##     mirando arriba 15 grados   morro a 0,94 m
##     mirando de frente          morro a 0,09 m
##     mirando abajo 10 o mas     morro a 0,00 m  (apoyado en el suelo)
##
## O sea que el morro recorre de 0 a 2 m, y con el motor echado **cualquier
## mirada hacia abajo lo deja en el suelo**. Por eso la pasada alta de esta
## prueba mira un poco ARRIBA, y no "menos abajo": por debajo de 0 grados el
## morro esta ya en tierra y la pasada es una pasada de raiz.

var _mundo: Node3D
var _fails := 0
var _jugador: Jugador
var _herramienta: Desbrozadora
var _zarza: Zarza


func _initialize() -> void:
	call_deferred("_ejecutar")


func _ejecutar() -> void:
	_mundo = load("res://scenes/main.tscn").instantiate() as Node3D
	root.add_child(_mundo)
	await _esperar(40)

	_jugador = _mundo.get_node_or_null("Player") as Jugador
	_herramienta = _mundo.get_node_or_null(
		"Player/Caderas/PivoteDesbrozadora/Desbrozadora") as Desbrozadora
	_zarza = _mundo.get_node_or_null("Zarzas/ZarzaCercana") as Zarza
	if _jugador == null or _herramienta == null or _zarza == null:
		push_error("main.tscn necesita jugador, desbrozadora y una zarza")
		quit(1)
		return

	print("== una pasada de verdad tumba una raiz ==")
	if _zarza.posiciones_de_coronas().is_empty():
		_comprobar(false, "la zarza tiene raiz que atacar")
		quit(1)
		return
	_comprobar(true, "la zarza tiene raiz que atacar")
	print("   arranca con %d raices y %d columnas en pie"
		% [_zarza.coronas_en_pie(), _zarza.columnas_en_pie()])

	# 1) Ponerse encima de una raiz, del lado de dentro, y dejar que el cuerpo se
	# asiente en el suelo. Una pasada es de pie, no desde el aire.
	await _ir_sobre_la_raiz(0, deg_to_rad(-30.0))

	# 2) La pasada por arriba: abre paso, quita la copa y NO toca la raiz. Es el
	# trabajo que no vale, y por eso tiene que quedarse sin hacer nada.
	var raices_antes := _zarza.coronas_en_pie()
	var columnas_antes := _zarza.columnas_en_pie()
	var material_antes := _zarza.altura_total()
	# Mirar un poco ARRIBA, no "menos abajo": el morro va de 0 a 2 m segun la
	# mirada, y por debajo de 0 grados ya esta en el suelo. A +8 grados el morro
	# queda a media mata: se lleva la copa y deja un tocon que sigue sujetando la
	# raiz, que es justo el "trabajo que no vale" del que habla el juego.
	await _ir_sobre_la_raiz(0, deg_to_rad(8.0))
	var altura_alta := _herramienta.punto_de_corte().y
	print("   pasada por arriba, con el morro a %.2f m:" % altura_alta)
	_comprobar(altura_alta > 0.20 and altura_alta < 0.85,
		"el morro se puede parar a media mata (%.2f m)" % altura_alta)
	await _cortar(150)
	print("      quedan %d raices y %d columnas"
		% [_zarza.coronas_en_pie(), _zarza.columnas_en_pie()])
	_comprobar(_zarza.coronas_en_pie() == raices_antes,
		"una pasada por arriba no quita ninguna raiz")
	# Se mide el MATERIAL y no el numero de columnas. Una pasada alta deja un
	# tocon de medio metro en cada celda, y las celdas siguen en pie: cuentan
	# igual que antes. Lo que baja es la altura, y lo que de verdad se va al suelo
	# es la copa.
	# El margen es pequeno a proposito: una pasada quieta cubre un disco de un
	# metro en una mata de nueve, asi que aunque localmente se caiga casi toda la
	# copa, el total del campo se mueve poco. Lo que no puede pasar es que no se
	# caiga nada.
	_comprobar(_zarza.altura_total() < material_antes * 0.95,
		"pero si se lleva la copa (%.1f -> %.1f m de material)"
		% [material_antes, _zarza.altura_total()])

	# 3) La pasada buena: el morro al suelo, mirando de narices y con el motor
	# echado. Ahi la raiz no sobrevive.
	await _ir_sobre_la_raiz(0, deg_to_rad(-85.0))
	var raices_previas := _zarza.coronas_en_pie()
	# El morro se mide DURANTE el corte, no antes: es al trabajar cuando la maquina
	# echa el peso del cuerpo y lo hunde. Antes de acelerar esta a nueve
	# centimetros del suelo aunque el jugador mire de narices, y ese numero
	# Ledia a que no se podia llegar a la raiz.
	var altura_baja := await _cortar(200)
	print("   pasada a la base, con el morro a %.3f m:" % altura_baja)
	_comprobar(altura_baja < 0.06,
		"el morro llega a ras de suelo sin hundirse (%.3f m)" % altura_baja)
	print("      quedan %d raices y %d columnas"
		% [_zarza.coronas_en_pie(), _zarza.columnas_en_pie()])
	_comprobar(_zarza.coronas_en_pie() < raices_previas,
		"una pasada a la base SI quita la raiz (%d -> %d)"
		% [raices_previas, _zarza.coronas_en_pie()])
	_comprobar(_zarza.columnas_en_pie() < columnas_antes * 0.7,
		"y con ella cae la mata de encima (%d -> %d columnas)"
		% [columnas_antes, _zarza.columnas_en_pie()])

	print("-- resultado: %s" % ("OK" if _fails == 0 else "%d FALLOS" % _fails))
	_mundo.queue_free()
	await process_frame
	quit(0 if _fails == 0 else 1)


## Coloca al jugador para que el CABEZAL quede encima de una raiz, mirando con
## la inclinacion pedida, y espera a que el cuerpo se asiente.
func _ir_sobre_la_raiz(indice: int, pitch: float) -> void:
	var coronas := _zarza.posiciones_de_coronas()
	if indice >= coronas.size():
		return
	var destino := _zarza.to_global(Vector3(coronas[indice].x, 0.0, coronas[indice].y))
	# Primero a una distancia prudente, para que el morro este cerca, y luego se
	# corrige con la posicion real del cabezal.
	_jugador.global_position = Vector3(destino.x, 0.95, destino.z + 0.8)
	_jugador.mirar_a(0.0, pitch)
	await _esperar(20)
	_jugador.global_position += destino - _herramienta.punto_de_corte()
	_jugador.global_position.y = 0.95
	_jugador.mirar_a(0.0, pitch)
	await _esperar(20)
	for _i in 60:
		await physics_frame


## Acelera y deja que la maquina trabaje. Con el motor echado el morro se hunde
## solo, asi que hay que dar tiempo a que las vueltas suban antes de medir nada.
##
## Devuelve la altura MAS BAJA que ha tenido el morro durante la pasada, que es
## lo que importa: el punto de corte real de ese rato.
func _cortar(cuadros: int) -> float:
	Input.action_press("acelerador")
	await _esperar(30)
	var mas_baja := _herramienta.punto_de_corte().y
	await _esperar(cuadros)
	mas_baja = minf(mas_baja, _herramienta.punto_de_corte().y)
	Input.action_release("acelerador")
	await _esperar(20)
	return mas_baja


func _esperar(cuadros: int) -> void:
	for _i in cuadros:
		await physics_frame


func _comprobar(ok: bool, que: String) -> void:
	if ok:
		print("  OK   %s" % que)
	else:
		print("  FAIL %s" % que)
		_fails += 1
