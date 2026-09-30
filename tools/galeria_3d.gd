extends SceneTree

## Galeria de versiones 3D: pone TODOS los modelos de una carpeta en fila, con
## suelo, sol y camara orbitando, e **imprime la ficha tecnica** de cada uno:
## altura, triangulos, animaciones y si encaja en la primera persona.
##
## Es la herramienta para comparar varias versiones de un modelo ANTES de
## integrarlo, y vale igual para personaje, desbrozadoras, cabezales o
## cualquier glb: se le pasa un patron y ella sola pone la fila y saca la ficha.
## La fila NO es el juego; el juego sigue usando su modelo unico en
## `scenes/jugador.tscn`. Elegida la version, la integracion es aparte.
##
## Uso con ventana (para juzgar el aspecto, que no lo mide ninguna prueba):
##     flatpak run --filesystem=$HOME/Documentos org.godotengine.Godot \
##         --path . --script tools/galeria_3d.gd -- [patron]
## Uso sin ventana (solo la ficha, para medir):
##     flatpak run --filesystem=$HOME/Documentos org.godotengine.Godot \
##         --headless --path . --script tools/galeria_3d.gd -- [patron]
##
## `patron` es un glob relativo al proyecto; por defecto `models/pruebas/*.glb`.
##     -- models/pruebas/personaje_v1.*.glb     (las que tienen animacion)
##     -- models/*.glb                          (todos los del proyecto)
##
## Teclas con ventana: TAB cicla la animacion, ESPACIO para/reanuda la orbita.

var _patron := "models/pruebas/*.glb"
var _modelos: Array[Node3D] = []
var _nombres_anim: Array[String] = []
var _plantilla_anim := 0
var _orbita := 0.0
var _orbitando := true
var _cuadro := 0
var _tab_previa := false
var _esp_previa := false
var _raiz: Node3D
var _camara_nodo: Camera3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_patron = args[0]
	_raiz = Node3D.new()
	_raiz.name = "Galeria"
	root.add_child(_raiz)
	_construir_escena()
	_cargar_modelos()


func _construir_escena() -> void:
	var suelo := MeshInstance3D.new()
	var plano := PlaneMesh.new()
	plano.size = Vector2(60.0, 18.0)
	suelo.mesh = plano
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.14, 0.18, 0.12)
	mat.roughness = 1.0
	suelo.material_override = mat
	_raiz.add_child(suelo)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	sol.shadow_enabled = true
	_raiz.add_child(sol)
	var cabecera := Node3D.new()
	cabecera.name = "Orbita"
	_raiz.add_child(cabecera)
	var camara := Camera3D.new()
	camara.fov = 60.0
	camara.position = Vector3(0.0, 1.6, 6.5)
	cabecera.add_child(camara)
	camara.current = true
	_camara_nodo = camara


func _cargar_modelos() -> void:
	var rutas := _listar_por_patron(_patron)
	if rutas.is_empty():
		push_error("ningun .glb cumple el patron: %s" % _patron)
		return
	for i in rutas.size():
		var escena := load(rutas[i]) as PackedScene
		if escena == null:
			continue
		var instancia := escena.instantiate() as Node3D
		if instancia == null:
			continue
		instancia.name = rutas[i].get_file().get_basename()
		instancia.position = Vector3(
			(float(i) - float(rutas.size() - 1) / 2.0) * 1.7, 0.0, 0.0)
		# Los glb de Blender salen mirando a -Y; con la fila en X se gira cada
		# uno +90 para que presente el frente a la camara.
		instancia.rotation.y = PI / 2.0
		_raiz.add_child(instancia)
		_modelos.append(instancia)
		_recolectar_animaciones(instancia)


func _recolectar_animaciones(instancia: Node3D) -> void:
	for n in _descendientes(instancia):
		var ap := n as AnimationPlayer
		if ap == null:
			continue
		for nombre in ap.get_animation_list():
			if not _nombres_anim.has(nombre):
				_nombres_anim.append(nombre)


func _process(delta: float) -> bool:
	_cuadro += 1
	# La ficha se calcula DENTRO del arbol, un cuadro despues de cargar. Hecha
	# en `_initialize` los nodos aun no estan procesados y `global_transform`
	# devuelve identidad: las alturas salen mentirosas. Medir, cuando el motor
	# ya lo coloco todo.
	if _cuadro == 2:
		_imprimir_fichas()
	if _es_headless():
		if _cuadro >= 2:
			quit(0)
		return _cuadro >= 2
	if _orbitando:
		_orbita += delta * 0.3
		_raiz.get_node("Orbita").rotation.y = _orbita
	for n in _modelos:
		_reproducir_en(n, _anim_actual())
	var tab := Input.is_key_pressed(KEY_TAB)
	if tab and not _tab_previa:
		_plantilla_anim = (_plantilla_anim + 1) % maxi(1, _nombres_anim.size())
	_tab_previa = tab
	var esp := Input.is_key_pressed(KEY_SPACE)
	if esp and not _esp_previa:
		_orbitando = not _orbitando
	_esp_previa = esp
	return false


func _anim_actual() -> String:
	if _nombres_anim.is_empty():
		return ""
	return _nombres_anim[_plantilla_anim % _nombres_anim.size()]


func _reproducir_en(nodo: Node, nombre: String) -> void:
	if nombre.is_empty():
		return
	for c in nodo.get_children():
		var ap := c as AnimationPlayer
		if ap != null and ap.has_animation(nombre) \
				and ap.current_animation != nombre:
			ap.play(nombre)
		_reproducir_en(c, nombre)


## Ficha tecnica de lo que se puede MEDIR. El aviso de compatibilidad importa:
## la primera persona del juego oculta piezas del modelo POR NOMBRE (`Cabeza`,
## `BrazoIzq`, `BrazoDer`, `Torso`, `Personaje`) y pone brazos IK encima. Un
## modelo de **malla unica** (`PersonajeLowPoly` sobre un `Skeleton3D`) no tiene
## esas piezas, asi que no se le puede tapar solo la cabeza y los brazos: o
## entra con brazos propios animados (y habria que quitar los IK), o hay que
## trocearlo en Blender con esos nombres. Eso se decide al integrar, no aqui.
func _imprimir_fichas() -> void:
	print("== galeria: %d modelos (%s) ==" % [_modelos.size(), _patron])
	if not _nombres_anim.is_empty():
		print("   animaciones: %s" % ", ".join(_nombres_anim))
	for m in _modelos:
		var caja := _aabb_mundo(m)
		var tri := 0
		var verts := 0
		var huesos := 0
		var una_malla := 0
		for n in _descendientes(m):
			var sk := n as Skeleton3D
			if sk != null:
				huesos = sk.get_bone_count()
			var mi := n as MeshInstance3D
			if mi == null or mi.mesh == null:
				continue
			una_malla += 1
			for s in mi.mesh.get_surface_count():
				var arrays := mi.mesh.surface_get_arrays(s)
				var idx: Array = arrays[Mesh.ARRAY_INDEX]
				var va: Array = arrays[Mesh.ARRAY_VERTEX]
				verts += va.size()
				tri += (idx.size() / 3) if idx.size() > 0 else int(va.size() / 3)
		var piezas := _piezas_primera_persona(m)
		print("   %-26s alto %.2f m | %5d tri | huesos %2d | mallas %d | %s"
			% [m.name, caja.size.y, tri, huesos, una_malla,
				("partes: " + piezas) if piezas != "" else "MALLA UNICA \u2192 no tapa 1ra persona"])


func _piezas_primera_persona(m: Node) -> String:
	var hay: Array[String] = []
	for nombre in ["Cabeza", "BrazoIzq", "BrazoDer", "Torso", "Personaje"]:
		for n in _descendientes(m):
			# Coincidencia EXACTA de nodo, no begins_with: "PersonajeLowPoly"
			# empieza por "Personaje" pero no es la pieza `Personaje` del
			# modelo de a trozos. Comparar exacto es lo que distingue los dos
			# tipos de modelo.
			if String(n.name) == nombre:
				hay.append(nombre)
				break
	return ", ".join(hay)


func _aabb_mundo(nodo: Node3D) -> AABB:
	var fuera := AABB()
	var first := true
	for n in _descendientes(nodo):
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var caja := mi.global_transform * mi.mesh.get_aabb()
		fuera = caja if first else fuera.merge(caja)
		first = false
	return fuera


func _descendientes(nodo: Node) -> Array[Node]:
	var fuera: Array[Node] = []
	for c in nodo.get_children():
		fuera.append(c)
		fuera.append_array(_descendientes(c))
	return fuera


## Patron simple: glob con estrella sobre `*.glb`, o una carpeta (se toman
## todos sus glb). Se resuelve contra `res://`.
func _listar_por_patron(patron: String) -> Array[String]:
	var fuera: Array[String] = []
	if DirAccess.dir_exists_absolute("res://" + patron):
		return _listar_carpeta(patron + "/*.glb")
	return _listar_carpeta(patron)


func _listar_carpeta(glob: String) -> Array[String]:
	var fuera: Array[String] = []
	var dir := DirAccess.open("res://")
	if dir == null:
		return fuera
	var carpeta := glob.get_base_dir()
	var filtro := glob.get_file()
	dir.change_dir(carpeta)
	for f in dir.get_files():
		if f.begins_with(".") or not f.match(filtro):
			continue
		fuera.append("res://%s/%s" % [carpeta, f])
	fuera.sort()
	return fuera


func _es_headless() -> bool:
	return DisplayServer.get_name() == "headless"
