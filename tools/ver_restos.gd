extends Node3D

## Mira los restos de cerca, que es la unica manera de juzgarlos.
##
## **Por que esto existe.** Los restos se ven desde la camara de la maquina, a
## cuatro o cinco metros y con el amontonado entero en pantalla. A esa distancia
## un trozo de 10 cm son unos pixeles, y da igual que sean curvos o rectos: se ve
## una alfombra verde. Cuando el usuario dijo "lo veo igual que antes" tenia toda
## la razon, y la razon era la distancia, no el codigo.
##
## Aqui se sueltan **`n` trozos en el suelo plano, con la camara a un palmo**, y
## se sueltan en tres tandas, para que se vea tambien como se amontonan. Se puede
## girar con las flechas y acercarse y alejarse con la rueda.
##
##     flatpak run --filesystem=$HOME/Documentos org.godotengine.Godot \\
##         --path . --script tools/ver_restos.gd -- [n] [altura] [metros]
##
## Sin argumentos: 60 trozos, camara a 40 cm, a tres metros del monton.
##
## Las tres variables estan aqui arriba del todo, no enterradas en el codigo,
## porque el dia que esto haya servido para algo ya se puede borrar entero.

var _n := 60
var _distancia := 3.0
var _altura := 0.4
var _angulo := 0.0


func _ready() -> void:
	# Los argumentos del "--" de la linea de ordenes, por si hay que cambiar algo
	# sin abrir el fichero.
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_n = maxi(int(args[0]), 1)
	if args.size() > 1:
		_altura = maxf(float(args[1]), 0.08)
	if args.size() > 2:
		_distancia = maxf(float(args[2]), 0.4)

	_crear_suelo()
	var camara := _crear_camara()
	_crear_luz()

	# Las tres tandas, con una espera en medio, que es como se ve de verdad: el
	# amontonado crece a golpes, no de una tacada.
	for tanda in 3:
		for _i in _n / 3:
			_soltar_uno()
		if tanda < 2:
			await get_tree().create_timer(0.8).timeout

	print("=== %d restos sueltos, camara a %.2f m, a %.1f m ===" % [_n, _altura, _distancia])
	print("   gira con las flechas izquierda y derecha")
	print("   acerca y aleja con la rueda del raton, o con ARRIBA y ABAJO")
	get_viewport().size = Vector2i(1280, 720)
	camara.make_current()
	_camara = camara


var _camara: Camera3D


func _crear_suelo() -> void:
	var suelo := StaticBody3D.new()
	var malla := MeshInstance3D.new()
	malla.mesh = BoxMesh.new()
	malla.mesh.size = Vector3(12.0, 0.2, 12.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.19, 0.24, 0.12)
	mat.roughness = 1.0
	malla.material_override = mat
	malla.position.y = -0.1
	suelo.add_child(malla)
	add_child(suelo)


func _crear_luz() -> void:
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-52.0, -38.0, 0.0)
	sol.light_energy = 1.15
	add_child(sol)
	var relleno := DirectionalLight3D.new()
	relleno.rotation_degrees = Vector3(-14.0, 150.0, 0.0)
	relleno.light_energy = 0.35
	relleno.light_specular = 0.0
	add_child(relleno)


func _crear_camara() -> Camera3D:
	var camara := Camera3D.new()
	camara.fov = 55.0
	camara.far = 200.0
	add_child(camara)
	return camara


func _soltar_uno() -> void:
	var pos := Vector3(
		randf_range(-0.45, 0.45), 0.02, randf_range(-0.45, 0.45))
	Restos.obtener(self).soltar(pos, 1, Vector3(0.0, 0.0, 1.0),
		Color(0.31, 0.46, 0.14), randf_range(0.7, 1.5))


func _process(delta: float) -> void:
	if _camara == null:
		return
	if Input.is_key_pressed(KEY_LEFT):
		_angulo -= delta * 1.4
	if Input.is_key_pressed(KEY_RIGHT):
		_angulo += delta * 1.4
	if Input.is_key_pressed(KEY_UP):
		_altura = maxf(_altura - delta * 0.5, 0.08)
	if Input.is_key_pressed(KEY_DOWN):
		_altura += delta * 0.5
	# Sin rueda de raton: hace falta que la ventana tenga el foco, y en flatpak a
	# veces no lo hay. Las flechas y ARRIBA/ABAJO llegan siempre, y por eso estan.
	_camara.position = Vector3(
		sin(_angulo) * _distancia, _altura, cos(_angulo) * _distancia)
	_camara.look_at(Vector3(0.0, 0.03, 0.0), Vector3.UP)
