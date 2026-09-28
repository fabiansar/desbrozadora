extends SceneTree

## Dice que se ve y que no desde el punto de vista del jugador.
##
##     godot --headless --path . --script tools/ver_encuadre.gd
##
## Nacio de un fallo muy concreto: la desbrozadora estaba a 38 grados por
## debajo de la linea de mira, y el encuadre vertical de un angular de 100
## grados en 16:9 llega a 33,5, asi que no se veia nada, solo la sombra. Ese
## fallo esta arreglado (`CamaraGopro._pitch_limitado` baja la vista para que el
## cabezal no se salga nunca, y la suite lo comprueba en toda la gama de
## inclinacion), asi que esta herramienta ya no hace falta para eso.
##
## Se queda como inspeccion general del encuadre: dice, para cada malla de la
## escena, si entra en la foto, donde cae respecto al centro de la mira y a que
## grados. Es lo que hay que mirar cuando algo no aparece donde deberia.

func _initialize() -> void:
	var mundo = load("res://scenes/main.tscn").instantiate()
	root.add_child(mundo)
	for _i in 25:
		await physics_frame
	var jugador := mundo.get_node("Player") as Jugador
	var cam := jugador.get_node("Cabeza/Camara") as Camera3D
	print("camara: angular %.0f grados, %.2f m sobre el suelo"
		% [cam.fov, cam.global_position.y])
	print("")
	print("%-28s %-8s %-24s %-8s %s" % ["malla", "visible", "local camara", "cuadro", "nota"])
	var dentro := 0
	var fuera := 0
	# El diagnóstico interesa al cuerpo y a la herramienta. Recorrer el mundo
	# entero incluye cientos de fragmentos de terreno y cuadrantes de vegetación,
	# que repiten el mismo origen lógico y saturan el informe.
	for n in _mallas(jugador):
		var vm := n as VisualInstance3D
		if not vm.is_visible_in_tree():
			print("%-12s OCULTA" % n.name)
			continue
		var loc: Vector3 = cam.to_local(vm.global_position)
		var en := cam.is_position_in_frustum(vm.global_position)
		# Angulo respecto al centro de la mira, que es lo que decide si algo
		# entra en el encuadre vertical.
		var hacia := (vm.global_position - cam.global_position).normalized()
		var ang := rad_to_deg((-cam.global_transform.basis.z).angle_to(hacia))
		var nota := "a %.0f grados del centro" % ang
		if en:
			dentro += 1
			nota += "  <-- SE VE"
		else:
			fuera += 1
			if ang > 33.0:
				nota += "  (por debajo del borde inferior)"
		print("%-28s %-8s (%5.2f,%5.2f,%5.2f)   %-8s %s"
			% [n.name, "si", loc.x, loc.y, loc.z, "si" if en else "no", nota])
	var herramienta := _buscar_herramienta()
	if herramienta != null:
		print("")
		print("maquina: origen %s; corte %s; offset de corte local %s"
			% [str(herramienta.global_position), str(herramienta.punto_de_corte()),
				str(herramienta._cabeza_local)])
	print("")
	print("se ven %d mallas y no se ven %d" % [dentro, fuera])
	quit(0)


func _mallas(n: Node) -> Array:
	var r: Array = []
	if n is MeshInstance3D:
		r.append(n)
	for h in n.get_children():
		r.append_array(_mallas(h))
	return r


func _buscar_herramienta() -> Desbrozadora:
	for nodo in get_nodes_in_group("herramienta"):
		if nodo is Desbrozadora:
			return nodo as Desbrozadora
	return null
