class_name Bosque
extends Node3D

## Reparte arboles por el mapa para tener referencias de movimiento: sin algo
## alrededor, al andar no se nota ni la velocidad ni las curvas.
##
## Los arboles son de 6 caras (tronco con 6 lados y la copa con un cono de 6),
## que es lo que hace que Dontstar/Valheim parezcan low poly. Aqui no hace
## falta ni strive: son unos 50.

## Escena de arbol.
@export var arbol: PackedScene
## Cuantos poner.
@export var cuantos := 55
## Radio interior: nada mas cerca de donde aparecer, que si no sales con un
## arbol en la cara.
@export var radio_min := 9.0
## Radio exterior.
@export var radio_max := 65.0
## Separacion minima entre troncos, para que no nazcan dos pegados.
@export var separacion := 4.0
## Semilla. Con la misma semilla sale siempre el mismo bosque, que es lo que
## hace falta para poder comparar unas pruebas con otras.
@export var semilla := 20260926


func _ready() -> void:
	if arbol == null:
		arbol = load("res://scenes/arbol.tscn") as PackedScene
	if arbol == null:
		push_warning("Bosque: no encuentro la escena del arbol")
		return
	_generar()


func _generar() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla
	# Tres verdes de hoja. Se crean una vez y se reparten; si no, al cambiar el
	# material de un arbol cambiaria el de todos los demas. Se hace con un
	# bucle y no con map() porque map() devuelve un Array sin tipo y Godot no
	# deja meterlo en un Array[StandardMaterial3D].
	var verdes: Array[StandardMaterial3D] = []
	for c in [Color(0.129, 0.322, 0.114), Color(0.176, 0.400, 0.145),
			Color(0.106, 0.259, 0.129), Color(0.212, 0.435, 0.157)]:
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.95
		verdes.append(m)

	var puestos: Array[Vector2] = []
	var intentos := 0
	while puestos.size() < cuantos and intentos < cuantos * 30:
		intentos += 1
		# Raiz cuadrada para repartir por igual: si se cogiese el angulo al
		# azar, los arboles se amontonarian en el centro y el horizonte quedaria
		# vacio, que es justo al reves de lo que se quiere.
		var ang := rng.randf() * TAU
		var rad := sqrt(rng.randf_range(radio_min * radio_min, radio_max * radio_max))
		var punto := Vector2(cos(ang), sin(ang)) * rad
		var cerca := false
		for p in puestos:
			if p.distance_to(punto) < separacion:
				cerca = true
				break
		if cerca:
			continue
		puestos.append(punto)
		_poner(punto, rng, verdes)

	print("Bosque: %d arboles repartidos entre %.0f y %.0f m"
		% [puestos.size(), radio_min, radio_max])


func _poner(p: Vector2, rng: RandomNumberGenerator, verdes: Array[StandardMaterial3D]) -> void:
	var n: Node3D = arbol.instantiate()
	# Cada arbol un poco mas alto, ancho o bajo que otro. Sin esto el bosque
	# parece una regiment y se nota muchisimo que son copias.
	var alto := rng.randf_range(0.75, 1.45)
	var gordo := rng.randf_range(0.8, 1.2)
	n.position = Vector3(p.x, 0.0, p.y)
	n.scale = Vector3(gordo, alto, gordo)
	n.rotation.y = rng.randf() * TAU
	# La copa Alta se aparta un poco hacia un lado: el arbol se ve torcido, que
	# es lo que pasa con los de verdad.
	var copa := n.get_node_or_null("CopaAlta")
	if copa is Node3D:
		(copa as Node3D).position.x = rng.randf_range(-0.25, 0.25)
		(copa as Node3D).position.z = rng.randf_range(-0.25, 0.25)
	var hoja: StandardMaterial3D = verdes[rng.randi_range(0, verdes.size() - 1)]
	for nombre in ["CopaBaja", "CopaAlta"]:
		var m := n.get_node_or_null(nombre) as MeshInstance3D
		if m != null:
			m.material_override = hoja
	add_child(n)
