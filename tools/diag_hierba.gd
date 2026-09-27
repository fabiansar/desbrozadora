extends SceneTree


## Diagnostico de por que no se ve la hierba. Todas las pruebas anteriores
## miran los arrays del juego, que estan bien, pero no miran lo que de verdad
## llega al servidor de dibujo. Esto pregunta eso.

var mundo: Node3D
var _frames := 0


func _initialize() -> void:
	mundo = load("res://scenes/main.tscn").instantiate()
	root.add_child(mundo)


func _process(_delta: float) -> bool:
	_frames += 1
	# _ready corre cuando el nodo entra en el arbol, que es despues de
	# _initialize. Hay que esperar un par de fotogramas para que el multimesh
	# este creado.
	if _frames < 3:
		return false
	_mirar()
	quit(0)
	return true


func _mirar() -> void:
	# La hierba ya no es un MultiMeshInstance3D: es un gestor que reparte las
	# hojas en cuadrados, cada uno con su propio MultiMesh. Por eso aqui se
	# mira el primer cuadrado y no el nodo de la hierba.
	var hierba := mundo.get_node_or_null("Hierba") as Node3D
	if hierba == null:
		print("NO HAY NODO Hierba")
		quit(1)
		return

	print("--- el nodo ---")
	print("  visible en el arbol: %s" % hierba.is_visible_in_tree())
	print("  visible: %s" % hierba.visible)
	print("  transform: %s" % str(hierba.global_transform.origin))
	var cuadrados: Array[MultiMeshInstance3D] = []
	for c in hierba.get_children():
		if c is MultiMeshInstance3D:
			cuadrados.append(c as MultiMeshInstance3D)
	print("  cuadrados: %d" % cuadrados.size())
	if cuadrados.is_empty():
		print("NO HAY CUADRANTES CON MULTIMESH")
		quit(1)
		return
	print("  material: %s" % str(hierba.material_compartido()))

	# Como esta partido el campo. El reparto tiene que salir cuadrado: ni un
	# cuadrado vacio, ni uno con casi todas las hojas, y las cajas todas del
	# tamano del lado.
	var suma := 0
	var minimo := 1 << 30
	var maximo := 0
	var caja_max := 0.0
	for c in cuadrados:
		var n := c.multimesh.instance_count
		suma += n
		minimo = mini(minimo, n)
		maximo = maxi(maximo, n)
		caja_max = maxf(caja_max, maxf(c.custom_aabb.size.x, c.custom_aabb.size.z))
	print("  hojas repartidas: %d (min %d, max %d por cuadrado)"
		% [suma, minimo, maximo])
	print("  lado de la caja mayor: %.1f m (el cuadrado es de %.0f)"
		% [caja_max, hierba.lado_cuadrante])
	print("  visibles ahora mismo: %d de %d"
		% [hierba.cuadrantes_visibles(), cuadrados.size()])

	var primero := cuadrados[0]


	var mm := primero.multimesh

	print("--- el multimesh ---")
	print("  instancias: %d" % mm.instance_count)
	print("  malla: %s" % str(mm.mesh))
	if mm.mesh != null:
		print("  vertices de la malla: %d" % mm.mesh.get_surface_count())
		print("  aabb de la malla: %s" % str(mm.mesh.get_aabb()))
	print("  formateado: %d  datos propios: %s"
		% [mm.transform_format, str(mm.use_custom_data)])
	# El aabb del recurso MultiMesh sale a cero porque no lo calcula el motor
	# solo con los datos propios. Da igual: el que manda para el culling es el
	# custom_aabb del nodo, que se ha puesto a mano al montar el cuadrado.
	print("  custom_aabb del nodo: %s" % str(primero.custom_aabb))
	print("  tamano del custom_aabb: %.1f x %.1f x %.1f m"
		% [primero.custom_aabb.size.x, primero.custom_aabb.size.y,
			primero.custom_aabb.size.z])

	# Lo importante: si el servidor guardo de verdad lo que se le ha puesto. Las
	# transformadas de instancia salen a identidad a proposito: donde se coloca
	# cada hoja es el shader, con los datos propios, no el motor.
	print("--- lo que hay dentro ---")
	print("  (las transformadas son identidad: el shader coloca cada hoja)")
	var total := mm.instance_count
	var muestra: Array[int] = [0, 1, total / 2, total - 1]
	for i in muestra:
		if i < 0 or i >= total:
			continue
		var t := mm.get_instance_transform(i)
		var d := mm.get_instance_custom_data(i)
		print("  instancia %d/%d: origen %s  escala %s  color %s"
			% [i, total, str(t.origin.round()), str(t.basis.get_scale().round()),
				str(d)])

	# Y una pregunta incomoda: si esto devuelve la identidad, el servidor no
	# esta guardando nada y da igual cuantas hojas contemos por codigo.
	var prueba := MultiMesh.new()
	prueba.transform_format = MultiMesh.TRANSFORM_3D
	prueba.use_custom_data = true
	prueba.instance_count = 1
	prueba.set_instance_transform(0, Transform3D(Basis().scaled(Vector3(9, 9, 9)),
		Vector3(1, 2, 3)))
	prueba.set_instance_custom_data(0, Color(0.25, 0.5, 0.75, 1.0))
	print("--- multimesh de prueba (escala 9, origen 1,2,3) ---")
	var leido := prueba.get_instance_transform(0)
	print("  leido: origen %s  escala %s" % [str(leido.origin), str(leido.basis.get_scale())])
	print("  aabb: %s" % str(prueba.get_aabb()))
	print("  datos leidos: %s" % str(prueba.get_instance_custom_data(0)))
	quit(0)
