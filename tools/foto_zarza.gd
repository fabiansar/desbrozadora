extends SceneTree

## Foto de la escena de capas de zarza, desde una camara alta, para comprobar si
## la zarza se dibuja de verdad. Sin --headless, que con el servidor de mentira no
## se ve nada.
##
## OJO con el orden: la camara se pone ANTES de contar fotogramas. Leer el texture
## dentro de _process devuelve el fotograma anterior, asi que si se anade la camara
## en el mismo cuadro en el que se guarda la foto, sale la foto de antes.

var mundo: Node3D
var cuadros := 0
var vista: Camera3D


func _initialize() -> void:
	mundo = load("res://scenes/capas_zarza.tscn").instantiate()
	root.add_child(mundo)
	# La camara del jugador se apaga y se pone una alta mirando la zona, para ver
	# la zarza entera sin depender de donde mire el jugador.
	var cam_jugador := mundo.get_node_or_null("Player/Cabeza/Camara") as Camera3D
	if cam_jugador != null:
		cam_jugador.current = false
	vista = Camera3D.new()
	vista.projection = Camera3D.PROJECTION_ORTHOGONAL
	vista.size = 26.0
	mundo.add_child(vista)
	vista.global_position = Vector3(0.0, 14.0, 8.0)
	vista.look_at_from_position(Vector3(0.0, 14.0, 8.0), Vector3(0.0, 0.0, -8.0),
		Vector3.UP)
	vista.current = true


func _process(_delta: float) -> bool:
	cuadros += 1
	if cuadros < 30:
		return false
	print("camara activa: %s en %s" % [str(vista.current),
		str(vista.global_position.round())])
	for n in get_nodes_in_group("zarzas"):
		var z := n as Zarza
		var m := z.get_node_or_null("Zarza") as MultiMeshInstance3D
		var instancias := 0
		if m != null:
			instancias = m.multimesh.instance_count
		print("%s: %d columnas, %d instancias, aabb %s"
			% [z.name, z.columnas_en_pie(), instancias,
			str(m.custom_aabb) if m != null else "-"])
		# Inspección de la malla: si el ArrayMesh se quedase sin vertices, el
		# MultiMesh no tiene nada que dibujar aunque las instancias valgan.
		if m != null:
			var mm := m.multimesh
			var malla := mm.mesh
			if malla == null:
				print("   la malla es NULA")
			else:
				print("   superficies %d" % malla.get_surface_count())
				if malla.get_surface_count() > 0:
					print("   vertices %d, indices %d" % [
						malla.surface_get_array_len(0),
						malla.surface_get_index_count(0)])
					var arr := malla.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array
					print("   primer vertice %s" % str(arr[0] if arr.size() > 0 else Vector3.ZERO))
			print("   instancia 0: %s" % str(mm.get_instance_transform(0)))
			print("   color 0: %s" % str(mm.get_instance_custom_data(0)))
			print("   material: %s" % str(m.material_override))
	var imagen := root.get_texture().get_image()
	if imagen == null:
		print("no hay imagen")
		return true
	var ruta := "/home/n41b4f/Documentos/desarrollos/desbrozadora/capturas/zarza_vista2.png"
	imagen.save_png(ruta)
	print("guardada %s" % ruta)
	return true
