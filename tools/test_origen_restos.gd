extends SceneTree

## Que sale en el suelo **exactamente** cuando cortas cada una de las tres plantas.
##
##     flatpak run --filesystem=$HOME/Documentos org.godotengine.Godot \
##         --headless --path . --script tools/test_origen_restos.gd
##
## Este archivo nacio buscando de donde salian unas **cajas grandes de color
## crema** que aparecian en el campo. Eran de un segundo sistema, `Montes`, que
## dibujaba el material acumulado con un `MultiMesh` de cajas de 46 cm.
## **Ese sistema esta borrado**: el suelo solo guarda los trozos sueltos de
## `Restos`, motitos de 10 cm con peso, que la maquina aparta al pasar.
##
## Queda la prueba, porque el problema de fondo no eran las cajas: era que **el
## suelo tenia dos sistemas diciendo cosas distintas** y nadie sabia cual mandaba.
## Con uno solo, esto enumera lo que hay y se ve de inmediato si aparece algo que
## no sea un resto.
##
## Enseña tambien algo que no se ve jugando: hay que **cortar avanzando**, porque
## el reparto del material depende de por donde pasa la maquina, y parado casi no
## se acumula.

var _mundo: Node3D
var _d: Desbrozadora
var _fails := 0


func _initialize() -> void:
	call_deferred("_ejecutar")


func _ejecutar() -> void:
	_mundo = load("res://scenes/main.tscn").instantiate() as Node3D
	root.add_child(_mundo)
	await _esperar(40)
	_d = _mundo.get_node_or_null(
		"Player/Caderas/PivoteDesbrozadora/Desbrozadora") as Desbrozadora
	if _d == null:
		push_error("main.tscn necesita desbrozadora")
		quit(1)
		return

	print("\n=== QUE HAY EN EL SUELO ANTES DE CORTAR NADA ===")
	await _inventario("sin cortar")

	# Los nombres tal cual estan en main.tscn, que es donde se buscan.
	for planta in ["Cesped", "MalezaAlta", "Zarzas/ZarzaCercana"]:
		await _barrer(planta)

	print("\n=== LAS TRES PLANTAS JUNTAS, TRAS BARRERLAS ===")
	await _inventario("todo")

	print("\n-- resultado: %s" % ("OK" if _fails == 0 else "%d FALLOS" % _fails))
	_mundo.queue_free()
	await process_frame
	quit(0 if _fails == 0 else 1)


## Pasa la desbrozadora por encima de una planta y corta de verdad.
##
## Colocar la maquina por su **punto de corte** y no por su origen: el morro esta
## a un metro y medio por delante, y con el nodo puesto en el sitio el cabezal
## queda en el aire, mirando al vacio.
func _barrer(planta: String) -> void:
	var nodo := _mundo.get_node_or_null(planta) as Node3D
	if nodo == null:
		print("\n--- %s: NO ESTA EN main.tscn" % planta)
		return
	var mata := nodo as Hierba
	var donde: Vector3 = nodo.global_position
	if mata != null:
		print("\n--- %s: %d hojas de pie, %d dentro de 3 m" % [planta,
			mata.hojas_en_pie(), mata.de_pie(donde, 3.0)])
	# Se pone el morro sobre la planta, con una altura de trabajo normal.
	var objetivo := donde + Vector3(0.0, 0.25, 0.0)
	var jugador := _mundo.get_node_or_null("Player") as Node3D
	if jugador != null:
		jugador.global_position += objetivo - _d.punto_de_corte()
	await physics_frame
	#
	# Y se corta **avanzando**, que es el detalle que hacia que este test saliese
	# a cero. El reparto depende de por donde pasa la maquina: quieto, casi todo el
	# material se queda donde cae y no hay donde mirar. Con 40 pasos de 25 cm la
	# maquina recorre 10 metros y deja una franja entera de escombro.
	Input.action_press("acelerador")
	for _i in 40:
		if jugador != null:
			jugador.global_position += Vector3(0.25, 0.0, 0.0)
		await physics_frame
	Input.action_release("acelerador")
	for _i in 20:
		await physics_frame
	print("    pasada hecha, 10 metros recorridos")
	await _inventario(planta)


## Lo que hay ahora mismo en el suelo, y si ademas hay algo que no deba.
func _inventario(etiqueta: String) -> void:
	var restos := Restos.obtener(self)

	# 1. Los trozos sueltos.
	var motas := 0
	var tipos := {}
	var mas_grande := Vector3.ZERO
	var mas_chico := Vector3(99.0, 99.0, 99.0)
	var tono_min := Vector3(2.0, 2.0, 2.0)
	var tono_max := Vector3(-1.0, -1.0, -1.0)
	var mas_alto := 0.0
	for n in _nodos_de(restos, "RigidBody3D"):
		var cuerpo := n as RigidBody3D
		var malla := cuerpo.get_node_or_null("Hoja") as MeshInstance3D
		if malla == null:
			for hijo in cuerpo.get_children():
				if hijo is MeshInstance3D:
					malla = hijo as MeshInstance3D
					break
		if malla == null or not malla.visible:
			continue
		motas += 1
		var clase := malla.mesh.get_class() if malla.mesh != null else "sin malla"
		tipos[clase] = int(tipos.get(clase, 0)) + 1
		# El tamano que se ve es la escala de la malla por el de su malla base.
		var caja := malla.mesh.get_aabb().size if malla.mesh != null else Vector3.ZERO
		var visto := caja * malla.scale
		if visto.length() > mas_grande.length():
			mas_grande = visto
		if visto.length() < mas_chico.length():
			mas_chico = visto
		mas_alto = maxf(mas_alto, cuerpo.global_position.y)
		var mat := malla.material_override as StandardMaterial3D
		if mat != null:
			var c := mat.albedo_color
			tono_min = Vector3(
				minf(tono_min.x, c.r), minf(tono_min.y, c.g), minf(tono_min.z, c.b))
			tono_max = Vector3(
				maxf(tono_max.x, c.r), maxf(tono_max.y, c.g), maxf(tono_max.z, c.b))

	var cuenta := restos.recuento()
	print("  [%s] %d trozos, mallas %s" % [etiqueta, motas, str(tipos)])
	if motas > 0:
		print("           de %.0f x %.0f x %.0f cm a %.0f x %.0f x %.0f cm"
			% [mas_chico.x * 100.0, mas_chico.y * 100.0, mas_chico.z * 100.0,
				mas_grande.x * 100.0, mas_grande.y * 100.0, mas_grande.z * 100.0])
		print("           tono de %.2f/%.2f/%.2f a %.2f/%.2f/%.2f"
			% [tono_min.x, tono_min.y, tono_min.z, tono_max.x, tono_max.y, tono_max.z])
		print("           el mas alto esta a %.0f cm del suelo" % (mas_alto * 100.0))
	print("           %d activos, %d dormidos, %d soltados, tope %d"
		% [int(cuenta["activos"]), int(cuenta["dormidos"]),
			int(cuenta["soltados"]), Restos.MAXIMO])

	# 2. Lo que **no** deberia haber. El fallo de las cajas era un segundo sistema
	# dibujando en el suelo, y no se ve mirando solo los restos: se ve mirando que
	# no haya nada mas. Con `Montes` borrado, lo unico que deberia aparecer por ahi
	# son restos y sus hijos.
	var raros := _raros(restos)
	for n in raros:
		print("     RARO: %s (%s)" % [n.name, n.get_class()])
	if raros.is_empty():
		print("     nada raro en el suelo: solo restos")


## Nodos que cuelgan de `Restos` y no son ni un trozo ni su malla ni su golpe.
##
## Antes de que se borrara `Montes`, aqui aparecian sus cajas. Lo que no pase por
## aqui es que se quede un sistema viejo colgando sin que nadie lo mire.
func _raros(raiz: Node) -> Array[Node]:
	var fuera: Array[Node] = []
	for n in raiz.get_children():
		if n is RigidBody3D or n is MeshInstance3D or n is CollisionShape3D:
			continue
		fuera.append(n)
	return fuera


func _nodos_de(nodo: Node, clase: String) -> Array[Node]:
	var fuera: Array[Node] = []
	if nodo == null:
		return fuera
	for c in nodo.get_children():
		if c.get_class() == clase:
			fuera.append(c)
		fuera.append_array(_nodos_de(c, clase))
	return fuera


func _esperar(n: int) -> void:
	for _i in n:
		await physics_frame
