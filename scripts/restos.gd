class_name Restos
extends Node3D

## Trozos de vegetation sueltos, CON FISICA. Un unico sistema para las tres
## plantas: al cortar no se conserva la forma, aparecen trozos aqui.
##
## Antes eran particulas de GPU que saltaban y desaparecian a los 1,1 segundos.
## Eso estaba bien para un efecto de chispa, pero no servia para lo que se
## quiere: **los trozos tienen que quedarse en el suelo y poder apartarlos**. Con
## particulas no hay manera, porque una particula no tiene cuerpo, no se posa y
## no se puede empujar. Asi que aqui hay un pool de cuerpos rigidos.
##
## Lo que se gana y lo que se pierde:
##
## - **Se gana**: el amontonado se queda, se puede apartar con la maquina, y el
##   suelo acaba teniendo el aspecto de un trabajo hecho y no de un efecto de
##   chispa.
## - **Se pierde**: cada trozo cuesta un cuerpo rigido. Por eso hay un tope de
##   60 y, cuando se llena, se recicla **el mas antiguo**, que es el que ya ha
##   completado su papel. Al reciclar se nota (el amontonado se renueva por donde
##   mas se ha trabajado), pero es preferible a llenar el campo de cuerpos rigidos
##   hasta que el motor se arrastre.
##
## ## Lo unico que hay en el suelo
##
## Antes habia **dos** sistemas dejando material: estos trozos y `Montes`, que
## guardaba el material acumulado en una rejilla de celdas de 50 cm y lo dibujaba
## con un `MultiMesh` de cajas. Se confundian entre si, y las cajas se veian
## desde lejos como lo que eran: cubos.
##
## **`Montes` esta borrado.** El suelo solo guarda estos trozos. Se pierde una
## cosa: el amontonado ya no crece sin limite, asi que una pasada larga ya no
## levanta un monton de 55 cm que haya que rodear. A cambio el suelo es siempre
## el mismo sitio, sin dos sistemas diciendo cosas distintas, que era el problema
## de verdad.
##
## El pool se crea una vez en `_ready` y se recicla. Instanciar un cuerpo por
## evento de corte era lo que hacia la version de GDScript que se descarta, y con
## varios miles de objetos vivos el coste por fotograma era noticeable.

## Tope de trozos vivos.
##
## Subio a 110 cuando los trozos se hicieron mas pequenos, y **se noto que no**:
## el amontonado seguia viéndose igual de apretado que antes. El numero de
## piezas no es lo que hace un monton denso; lo es **donde caen todas al mismo
## tiempo**. Con 110 piezas entrando en un aro de 35 cm sale un donut cerrado, y
## uno de 60 en el mismo sitio ya se ve aireado. Baje a 60.
##
## Subirlo mas no arregla nada y sale caro ademas: el coste esta en los que estan
## DESPERTANDO (cayendo y rodando), y aparcados son un cuerpo congelado que no se
## calcula. De 110 habia seis o siete en movimiento; de 60, tres o cuatro.
const MAXIMO := 60
## Tamano del trozo: una hoja **tumbada**, plana y alargada. Antes era una caja
## de 11 x 3,5 x 4 cm, que de lejos parecia un ladrillo verde, y de cerca una
## caja. Ni una cosa ni la otra: un trozo de planta cortada es una cosa plana que
## cae al suelo y se queda alli.
##
## Y el grosor es de 4 milimetros a proposito. Con 8 mm, y mas todavia con la
## escala que le mete la planta, el amontonado parecia una pila de losas: el
## usuario lo describio como "bloques apilados". Un trozo de hierba mide menos de
## un milimetro de grosor; 4 mm es ya generoso y es lo que hace que no se entierre
## en el suelo ni a traves de el.
const TAMANO := Vector3(0.10, 0.004, 0.03)
## Cuantas siluetas distintas hay. Con una sola, cincuenta trozos son cincuenta
## copias y el amontonado se ve repetido; con cuatro, el amontonado se ve como lo
## que es, que es vegetation troceada sin pulir.
const VARIANTES := 4
## Velocidad horizontal al salir despedido, en metros por segundo. Un salto corto
## y seco, de hoja, no de piedra.
const VELOCIDAD_SALTAR := 0.9
## Cuanto se levanta un trozo al saltar, en metros por segundo.
const ALZA := 0.35
## Velocidad que se le anade al apartar un trozo, en metros por segundo. Ajustada
## para que se note al pasar por encima sin que salga volando el medio campo.
const VELOCIDAD_APARTAR := 0.9
## Tope a la velocidad que puede llevar un trozo por el empuje de la maquina, en
## metros por segundo.
##
## **Este tope no es cosmetico, es un fallo que estaba escondido.** El empuje se
## aplica **sumando** a la velocidad, a proposito: un cuerpo aparcado lleva rato
## fuera del paso de simulacion y ahi el motor se come el impulso sin aplicarlo.
## Pero la maquina llama a `empujar` unas ocho veces por segundo, y sumar sin tope
## son 7,2 m/s: medido, el escombro salia despedido a **doce metros** del cabezal.
##
## Dos metros por segundo es de sobra para que un trozo de hoja se aparte de
## donde pisas, y es la velocidad de alguienapedando. Por encima de eso ya no
## parece que la maquina aparte nada, sino que dispara.
const VELOCIDAD_APARTAR_MAX := 2.0
## Capa de colision de los restos. Van en la 8, apartada, porque el rayo que mide
## la altura del suelo tiene que ver el suelo y no un monticulo de rabitos.
const CAPA := 8
## Por debajo de esta velocidad un trozo ya no se esta moviendo de verdad, y se
## aparca. Ver `_asentar`.
const VELOCIDAD_PARADA := 0.3
## Fotogramas seguidos quieto antes de aparcar un trozo. Son un cuarto de
## segundo: lo justo para que se posen los que caen y lo justo para que un
## empujon de la maquina llegue a buen recaudo.
const FOTOGRAMAS_QUIETO := 15


var _piezas: Array[RigidBody3D] = []
var _mallas: Array[MeshInstance3D] = []
var _materiales: Array[StandardMaterial3D] = []
## Cuando salio cada pieza, para poder reciclar la mas antigua. Cero = libre.
var _nacido: PackedInt64Array = PackedInt64Array()
## Fotogramas seguidos que cada trozo lleva quieto. Ver `_asentar`.
var _quieto: PackedInt32Array = PackedInt32Array()
## Cuantos trozos se han pedido en toda la partida. Para las pruebas.
var _soltados := 0
## Cuantos se han apartado a empujones. Para las pruebas.
var _apartados := 0


func _ready() -> void:
	add_to_group("restos")
	for indice in MAXIMO:
		var pieza := _crear_pieza(indice)
		# Material de fisica propio, y con poca friccion a proposito. Con la de
		# por defecto (1,0) el empujon de la maquina se lo comia el suelo: los
		# trozos salian con 0,9 m/s y no avanzaban ni un centimetro, porque la
		# caja raspando el suelo se frena en el acto. Medido: velocidad si,
		# desplazamiento no. Con poca friccion el escombro sale despedido, que es
		# lo que hace cuando pasas por encima con la maquina echando.
		var fisica := PhysicsMaterial.new()
		fisica.friction = 0.25
		fisica.bounce = 0.1
		pieza.physics_material_override = fisica
		var colision := CollisionShape3D.new()
		var forma := BoxShape3D.new()
		# La colision es una caja aunque el dibujo sea una hoja. No se nota (la hoja
		# va tumbada y es mas ancha que alta) y una hoja con colision de hoja
		# resbalaria por el suelo en vez de quedarse.
		forma.size = TAMANO
		colision.shape = forma
		pieza.add_child(colision)
		var malla := MeshInstance3D.new()
		malla.mesh = _hoja(indice)
		malla.material_override = _crear_material()
		pieza.add_child(malla)
		_piezas.append(pieza)
		_mallas.append(malla)
		_materiales.append(malla.material_override as StandardMaterial3D)
		_nacido.append(0)
		_quieto.append(0)


func _crear_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.roughness = 0.92
	# Sin cull: la hoja es un plano tumbado y desde abajo no se veria nada, que es
	# justo el angulo desde el que se mira el suelo desde agachado.
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(0.22, 0.32, 0.11)
	return mat


## La hoja del resto: una cinta **curva**, de cinco tramos.
##
## **Lo importante es que este curvada.** Con una almendra de cuatro triangulos
## planos, cincuenta trozos tumbados en el suelo son cincuenta losas horizontales
## apiladas, que es exactamente lo que el usuario reporto: bloques. Un trozo de
## vegetation de verdad nunca esta recto: se dobla, se retuerce y se queda
## apoyado en dos puntos con el hueco por debajo. Cocido en la malla, eso se ve
## desde cualquier angulo y no cuesta nada por fotograma.
##
## `variante` cambia la curva y el retorcido, para que las siluetas no sean la
## misma repetida cincuenta veces. Cuatro variantes, repartidas por indice.
func _hoja(variante: int) -> ArrayMesh:
	var t := SurfaceTool.new()
	t.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tramos := 5
	var largo := TAMANO.x
	var ancho := TAMANO.z
	# Las cuatro curvas, de mas recta a mas cerrada. La primera es casi recta a
	# proposito: de verdad hay trozos que casi no se doblan.
	var curvas := [0.004, 0.016, 0.030, 0.048]
	var torcidos := [0.06, 0.55, 0.18, 0.85]
	var curva: float = curvas[variante % curvas.size()]
	var retorcido: float = torcidos[variante % torcidos.size()]
	for i in tramos + 1:
		var u := float(i) / float(tramos)
		var x := (u - 0.5) * largo
		# El arco: el centro se levanta y las puntas se apoyan. Con esto el trozo
		# se queda apoyado en dos puntos en vez de en toda su extension, que es
		# justo lo que distingue a un trozo de vegetal de una losa.
		var y := sin(u * PI) * curva
		# La hoja se estrecha por los dos extremos, y mas por la punta.
		var semi := (1.0 - pow(absf(u - 0.5) * 2.0, 1.7)) * ancho * 0.5
		# Y el retorcido, que es lo que quita el aire de copia sin coste.
		var giro := retorcido * u
		var dz := cos(giro) * semi
		var dx := sin(giro) * semi
		t.set_normal(Vector3.UP)
		t.set_uv(Vector2(0.0, u))
		t.add_vertex(Vector3(x, y, -dz))
		t.set_normal(Vector3.UP)
		t.set_uv(Vector2(1.0, u))
		t.add_vertex(Vector3(x, y, dz))
	for i in tramos:
		var a := i * 2
		t.add_index(a)
		t.add_index(a + 1)
		t.add_index(a + 2)
		t.add_index(a + 1)
		t.add_index(a + 3)
		t.add_index(a + 2)
	return t.commit()


## Un trozo, aparcado hasta que sale. Se queda dormido en el suelo sin que le
## calcule nada por fotograma.
func _crear_pieza(indice: int) -> RigidBody3D:
	var pieza := RigidBody3D.new()
	pieza.name = "Trozo%d" % indice
	# collision_layer es la CAPA, la 8, que es una capa que no usa nadie mas. La
	# mascara es la de siempre, la 1, para que el trozo **caiga sobre el suelo y
	# se quede encima**: con la mascara a cero no colisiona con nada, ni con el
	# suelo ni con los arboles, y se va derecho al vacio.
	#
	# Y el jugador no los nota porque el jugador esta en la capa 1 y su mascara no
	# incluye la 8: los trozos no le empujan, y el empuje se hace a mano desde
	# `empujar()`. Que en Godot 4 un CharacterBody3D no empuja a los rigidos es
	# justo lo que hace que el empuje tenga que existir.
	pieza.collision_layer = 1 << (CAPA - 1)
	pieza.collision_mask = 1
	# **Pesan, y bastante.** Con 0,04 kg (cuarenta gramos) los empujones de la
	# maquina los movian de un lado a otro y la escena entera notaba un temblor
	# de escombro en cada pasada. Con 0,35 kg se quedan donde caen, y apartarlos
	# cuesta, que es lo que tiene que pasar: apartar un monticulo es trabajo.
	pieza.mass = 0.35
	# El amortiguamiento va alto a proposito. Con 1,6 los trozos se quedan
	# rebotando y deslizando por el suelo con una velocidad residual de 0,2 m/s
	# para siempre, que se ve como un reguero que no para. Un trozo de hierba seca
	# cae, da un bote corto y se queda quieto: eso es lo que hacen estos numeros.
	pieza.linear_damp = 5.0
	pieza.angular_damp = 6.0
	pieza.can_sleep = true
	# Es lo que permite preguntar "esta tocando algo?". Sin esto no hay manera de
	# distinguir un trozo que se ha posado de uno que va lento por el aire, que es
	# el error de aparcar la nieve en mitad del salto.
	pieza.contact_monitor = true
	pieza.max_contacts_reported = 1
	pieza.freeze = true
	add_child(pieza)
	return pieza


## **Aparca los trozos que ya se han parado.**
##
## No es una chapuza de rendimiento, aunque tambien lo es: un trozo tumbado en el
## suelo no tiene que estar despertando al motor de fisicas. Pero sobre todo es
## porque un cuerpo rigido apoyado **no se para nunca del todo**: el resolutor de
## contactos le devuelve una velocidad residual de unos 0,2 m/s para siempre, y
## se ve como un reguero de trozos que se arrastra despacio sin que nada los
## empuje. Medido: con amortiguacion alta seguian a 0,176 m/s a los tres
## segundos, y no dormian jamas.
##
## En cuanto un trozo va lento, esta bajo y lleva un rato abajo, se congela. Lo
## que se ve es un monticulo de verdad, quieto, y el apartado lo vuelve a
## despertar cuando la maquina pasa por encima.
func _physics_process(_delta: float) -> void:
	for n in _piezas.size():
		if _nacido[n] == 0:
			continue
		var pieza := _piezas[n]
		if pieza.freeze:
			continue
		# Y tiene que estar TOCANDO algo. Un trozo recien soltado va lento al
		# principio (el impulso es corto) y esta a la altura del corte, que puede
		# ser medio metro: si la unica condicion fuera "va lento", se aparcaba en
		# el aire y se quedaba ahi colgado para siempre. Preguntar por el contacto
		# es la unica forma de saber que de verdad se ha posado.
		#
		# El giro NO se mira, a proposito. Un trozo tumbado se queda girando
		# milimetricamente para siempre por el resolutor de contactos, y con el
		# giro en la condicion nunca llegaba a aparcarse: se quedaba despierto
		# para siempre, coste de CPU incluido.
		if pieza.get_contact_count() == 0 or pieza.linear_velocity.length() > VELOCIDAD_PARADA:
			_quieto[n] = 0
			continue
		# Y tiene que llevar **varios fotogramas** quieto, no uno. Esto no es
		# tiene un detalle: `empujar()` da su impulso y este proceso corre en el
		# mismo fotograma, asi que con "un fotograma quieto" el empuje se
		# deshacia en el acto y el escombro no se movia nunca. Medido: cuatro
		# empujones seguidos no movian ni un milimetro. Con un cuarto de segundo
		# de margen, un trozo que se posa se aparca y uno que se empuja sale
		# volando y se aparca cuando aterriza.
		_quieto[n] += 1
		if _quieto[n] < FOTOGRAMAS_QUIETO:
			continue
		pieza.freeze = true
		pieza.linear_velocity = Vector3.ZERO
		pieza.angular_velocity = Vector3.ZERO


## Devuelve el unico gestor de restos de la partida, creandolo si la escena aun
## no lo tiene. Cualquier vegetation puede llamarlo al cortar y no necesita saber
## donde esta colgado, que es lo que evita cablear el nodo en cada escena.
static func obtener(arbol: SceneTree) -> Restos:
	for nodo in arbol.get_nodes_in_group("restos"):
		if nodo is Restos:
			return nodo as Restos
	var nuevo := Restos.new()
	nuevo.name = "Restos"
	arbol.root.add_child(nuevo)
	return nuevo


## Suelta restos desde un punto, que es el punto donde ha ocurrido el corte.
##
## `cantidad` es cuantos trozos aparecen, `direccion` hacia donde salen despedidos,
## `tono` el color de la planta cortada y `escala` el tamano. La posicion de la que
## parten es la del corte, no la del suelo, que es lo que hace que salten.
func soltar(origen: Vector3, cantidad: int, direccion: Vector3, tono: Color,
		escala: float = 1.0) -> int:
	if not is_inside_tree() or _piezas.is_empty():
		return 0
	var pedidas := clampi(cantidad, 1, 6)
	var apartada := direccion
	apartada.y = 0.0
	if apartada.length() > 0.01:
		apartada = apartada.normalized()
	else:
		apartada = Vector3.FORWARD
	# Y el sitio del que salen. Antiguamente era el punto de corte, que esta a la
	# altura del filo: el escombro aparecia dentro del cabezal y, con el
	# amontonado creciendo a cada pasada, la maquina parecia meterse en un monton
	# y subir. Ahora caen **en el suelo y al lado**, que es donde acaba un trozo de
	# vegetal de verdad.
	#
	# Y **repartidas, no en corona**. El aro de 15 a 50 cm, con muchas piezas
	# entrando por fotograma, hacia que todas caeran en la misma corona y el
	# amontonado salia con forma de dona: un aro de material con un agujero en el
	# medio. Ademas el sitio de aparicion es aleatorio, asi que el amontonado se
	# ve distinto cada vez y se nota que es amontonado y no un aro pintado.
	#
	# El radio va hasta 90 cm y no mas, porque la pieza sale disparada y tiene que
	# **caer** cerca: si nace a metro y medio, aparece de la nada y se ve el truco.
	var suelo := _suelo_bajo(origen)
	for _n in pedidas:
		var lado := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
		if lado.length() < 0.01:
			lado = apartada
		_soltar_uno(_tomar_pieza(),
			Vector3(origen.x, suelo, origen.z) + lado.normalized() * randf_range(0.12, 0.9),
			apartada, tono, escala)
	_soltados += pedidas
	return pedidas


func _soltar_uno(indice: int, origen: Vector3, direccion: Vector3, tono: Color,
		escala: float) -> void:
	var pieza := _piezas[indice]
	# Se suelta un poco por encima del corte, para no nacer dentro del suelo.
	pieza.global_position = origen
	# **La orientacion es lo mas importante de como se ve esto.** Con los angulos
	# de inclinacion y alabeo limitados a unos grados, los cincuenta trozos salian
	# tumbados y horizontales, todos en el mismo plano, unos encima de otros: una
	# pila de losas. Los restos de verdad son un enredo, inclinados unos contra
	# otros, con alguno de canto. Con la orientacion libre en los tres ejes, la
	# mitad se ven de cara y la mitad de canto, y el amontonado se lee como
	# vegetation troceada.
	pieza.global_rotation = Vector3(
		randf_range(-1.2, 1.2), randf_range(0.0, TAU), randf_range(-1.2, 1.2))
	# Y el tamano varía de un trozo a otro. Con todos del mismo tamano el
	# amontonado parece trabajo de ceil: cincuenta copias. Con la mitad de tamano
	# mezclados, hay finos y gruesos, que es lo que hay en un Cesped recién cortado.
	var va := randf_range(0.55, 1.35)
	_mallas[indice].scale = Vector3(va * escala, escala, va * escala)
	# El color es lo que hace que se note de que planta salio cada trozo, y con
	# algo de dispersion para que el amontonado no sea una mancha de un solo
	# verde: se aclara y se oscurece un poco cada uno, como pasa con el vegetal
	# seco, que no es del mismo color hoja a hoja.
	# El color con dispersion. Ademas de aclarar y oscurecer, uno de cada cinco se
	# desatura un poco, como las hojas secas: un amontonado donde todos los trozos
	# son exactamente el mismo verde parece un charco de pintura, y elCesped
	# recien cortado tiene desde verde hasta pajizo en la misma mata.
	var mat := _materiales[indice]
	var claro := randf_range(0.74, 1.26)
	var gris := randf_range(0.0, 0.35)
	var mezcla := Color(tono.r, tono.g, tono.b).lerp(Color(tono.r, tono.g, tono.b)
		 * 0.5 + Color(0.28, 0.26, 0.16) * 0.5, gris)
	mat.albedo_color = Color(mezcla.r * claro, mezcla.g * claro, mezcla.b * claro)
	_nacido[indice] = Time.get_ticks_msec()
	pieza.freeze = false
	# El salto se pide en velocidad, no en newtons-segundo. Con la masa antigua el
	# impulso daba un metro por segundo; con 0,35 kg daria ocho, y un trozo que sale
	# disparado a ocho metros por segundo parece una bala, no una hoja.
	# La fuerza del salto se reparte. Con la misma para todas, las piezas salen
	# como un chorro y caen en el mismo sitio; con dispersion, unas se quedan
	# junto al corte y otras van soltandose, que es lo que hace un amontonado
	# abierto.
	pieza.linear_velocity = direccion * VELOCIDAD_SALTAR * randf_range(0.55, 1.5) \
			+ Vector3.UP * ALZA * randf_range(0.7, 1.4)
	pieza.angular_velocity = Vector3(
		randf_range(-6.0, 6.0), randf_range(-4.0, 4.0), randf_range(-6.0, 6.0))


## Indice de un trozo libre. Cuando no hay ninguno se recicla **el mas antiguo**,
## que es el unico criterio que no necesita saber nada de donde mira el jugador.
## Es tambien el que mejor queda: el monticulo se renueva por la parte por la que
## mas se ha trabajado, que es justo por la que se vuelve a pasar.
func _tomar_pieza() -> int:
	for n in _piezas.size():
		if _nacido[n] == 0:
			return n
	var mas_vieja := 0
	for n in range(1, _nacido.size()):
		if _nacido[n] < _nacido[mas_vieja]:
			mas_vieja = n
	return mas_vieja


## **Aparta los trozos que hay alrededor.** Esto es lo que no se podia hacer con
## particulas.
##
## No se usa la colision del motor para esto (los trozos tienen la mascara a
## cero, ver `_crear_pieza`), sino una comprobacion de distancia. La razon es que
## el jugador es un `CharacterBody3D` y en Godot 4 un cuerpo de ese tipo **no
## empuja a los rigidos**: se atraviesan sin que se note. Para que empujan hay que
## hacerlo a mano, y una comprobacion de distancia sobre 50 trozos es gratis.
##
## Devuelve cuantos ha apartado, que es lo que usan las pruebas.
func empujar(centro: Vector3, radio: float, direccion: Vector3,
		fuerza: float = 1.0) -> int:
	if not is_inside_tree() or radio <= 0.0:
		return 0
	var empujados := 0
	var avance := Vector3(direccion.x, 0.0, direccion.z)
	if avance.length() < 0.01:
		avance = Vector3.FORWARD
	var r2 := radio * radio
	for n in _piezas.size():
		if _nacido[n] == 0:
			continue
		var pieza := _piezas[n]
		var d := pieza.global_position - centro
		d.y = 0.0
		if d.length_squared() > r2:
			continue
		# Hacia fuera del centro, mas un empujon en la direccion de avance. Asi el
		# trozo sale despedido hacia delante y hacia los lados, que es como se ve
		# cuando pasas por encima con la maquina echando.
		var fuera := d
		if fuera.length() < 0.01:
			# Justo debajo no hay "fuera" que normalizar, asi que se usa el avance.
			fuera = avance
		var total := fuera.normalized() + avance * 0.6
		if total.length() < 0.01:
			continue
		# Y el empujon va como VELOCIDAD SUMADA, no con `apply_central_impulse`.
		# Medido: el impulso no movia ni un milimetro, y la velocidad si. La
		# diferencia es que un cuerpo aparcado lleva rato fuera del paso de
		# simulacion, y ahi el motor se come el impulso sin aplicarlo. Sumarle a
		# la velocidad hace lo mismo y no depende de en que estado este el cuerpo.
		# Para un trozo de escombro la diferencia entre "impulso" y "le damos
		# algo de prisa" es que no se nota, y asi el codigo dice la verdad.
		var velocidad := total.normalized() * (fuerza * VELOCIDAD_APARTAR)
		pieza.freeze = false
		pieza.sleeping = false
		# Sumar, pero **con tope**. Ver `VELOCIDAD_APARTAR_MAX`: sin esto, ocho
		# empujones en un segundo dejaban el trozo a siete metros por segundo.
		pieza.linear_velocity = (pieza.linear_velocity + velocidad).limit_length(
			VELOCIDAD_APARTAR_MAX * fuerza)
		pieza.angular_velocity += Vector3(
			randf_range(-2.0, 2.0), randf_range(-2.0, 2.0), randf_range(-2.0, 2.0))
		empujados += 1
	_apartados += empujados
	return empujados


## Para las pruebas y para el interfaz: cuantos trozos hay vivos, cuantos se han
## pedido y cuantos se han apartado.
func recuento() -> Dictionary:
	var vivos := 0
	var en_suelo := 0
	for n in _piezas.size():
		if _nacido[n] == 0:
			continue
		vivos += 1
		# "En el suelo" es "no se esta moviendo", y eso incluye los aparcados: un
		# trozo congelado esta en el suelo por definicion.
		if _piezas[n].freeze or _piezas[n].linear_velocity.length() < 0.05:
			en_suelo += 1
	return {"soltados": _soltados, "activos": vivos, "apartados": _apartados,
		"en_suelo": en_suelo}


## A que altura esta el suelo bajo un punto, en coordenadas de mundo.
##
## Se lanza un rayo por peticion, y solo para los trozos que se sueltan, que son
## pocos por fotograma. La mascara es la misma que usa la maquina para su apoyo
## (suelo, jugador y arboles) y **deja fuera la capa 8, que es la de estos
## mismos restos**: si se incluyera, un trozo recien tirado seria el "suelo" del
## siguiente, y el escombro se apilaria solo cada vez mas alto.
func _suelo_bajo(punto: Vector3) -> float:
	if not is_inside_tree():
		return punto.y
	var espacio := get_world_3d().direct_space_state
	var origen := Vector3(punto.x, punto.y + 1.5, punto.z)
	var q := PhysicsRayQueryParameters3D.create(origen, origen + Vector3.DOWN * 6.0)
	q.collision_mask = 1 | 2 | 4
	var golpe: Dictionary = espacio.intersect_ray(q)
	return punto.y if golpe.is_empty() else float(golpe["position"].y)


## Masa de un trozo, en kilos. Para las pruebas: con 40 gramos el amontonado se
## empujaba solo y temblaba con cada pasada. Un numero de juego, no un detalle.
func masa_de_un_trozo() -> float:
	return _piezas[0].mass if not _piezas.is_empty() else 0.0


## Indices de los trozos que estan vivos. Para las pruebas: recorrer los 50 huecos
## a pelo mezclaria los que estan en uso con los aparcados en el origen del
## gestor, y la media de distancia saldria falseada por 44 trozos que nadie ha
## soltado nunca.
func indices_vivos() -> PackedInt32Array:
	var salida := PackedInt32Array()
	for n in _piezas.size():
		if _nacido[n] != 0:
			salida.append(n)
	return salida




## Donde ha quedado un trozo, para las pruebas.
func posicion_de(indice: int) -> Vector3:
	return _piezas[indice].global_position




## Corta toda la actividad de restos en curso.
func limpiar() -> void:
	_soltados = 0
	_apartados = 0
	for n in _piezas.size():
		_nacido[n] = 0
		_quieto[n] = 0
		var pieza := _piezas[n]
		pieza.freeze = true
		pieza.linear_velocity = Vector3.ZERO
		pieza.angular_velocity = Vector3.ZERO

