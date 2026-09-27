class_name Aldea
extends Node3D

## Una aldea de minifundios en una ladera, generada por codigo.
##
## La idea es la de las aldeas de Galicia de verdad, que no son un pueblo con
## calles rectas, sino un puñado de casas sueltas repartidas por bancales,
## cada una con su pedazo de tierra cerrada con un muro de piedra seca. Asi que
## aqui hay tres cosas, y todo lo demas son detalles:
##
## 1. PARCELAS: rectangulos de 12 a 18 m, con las lineas rectas pero el lado
##    largo en la horizontal del terreno, que es como se colocan: si el muro va
##    cuesta arriba, la parcela se cruza con la ladera y el agua se queda
##    dentro. Cada parcela va cerrada con su muro, con un hueco para el paso.
## 2. CASAS: de piedra, con la puerta y las ventanas mirando a la bajada, y el
##    tejado a dos aguas de paja o de pizarra.
## 3. HORREOS: dos, que son los que le dan a una aldea gallega el aire de aldea
##    gallega y no de pueblo de aqui al lado.
##
## La regla que manda en todo el archivo es la misma que en el terreno: **todo
## lo que se apoya en el suelo pregunta al terreno, nunca se pone ahi porque
## si.** Una casa, un muro o un camino van sobre `terreno.cota_en()`, que es la
## misma funcion con la que se ha construido la malla del suelo. Si se usara la
## altura de los vertices de la malla, cada cosa se quedaria flotando medio
## metro en un lado y medio metro enterrada en el otro, y en una ladera con
## terrazas eso se ve a distancia.
##
## Las mallas: todo se mete en un SurfaceTool por material y se saca UNA malla
## por material. Doce casas, tres horreos, veinte parcelas y sus muros son unas
## seis mil caras, y con una malla por casa serian seis mil llamadas de dibujo.
## Con seis, seis.

@export var terreno: Terreno
@export var semilla := 20260927
## Cuantas casas. Menos de cuatro queda triste, mas de catorce empieza a ser un
## pueblo y ya no es una aldea. Con 12 parcelas, cinco casas dejan siete huertos
## vacios, y esos siete son los que hay que desbrozar: si van todos con casa, no
## queda nada que limpiar.
@export var num_casas := 5
## La cuadricula de parcelas. Los muros de por medio son los que separan una de
## otra, y se dibujan UNA vez, que es como se hace un deslinde: entre dos
## parcelas hay un solo muro, no dos que se pisen.
@export var columnas := 4
@export var filas := 3
## Las medidas de una parcela. Un minifundio de aqui son de 600 a 800 m2, y
## el rectangulo sale de ahi: largo en la horizontal del terreno y fondo
## subiendo la ladera.
@export var largo_celda := 15.0
@export var ancho_celda := 12.0
## Numero de linea de muros por la que pasa la calle. El bloque tiene filas + 1
## lineas, y la calle ocupa una de ellas.
@export var calle_fila := 2
@export var alto_muro := 0.95
@export var grosor_muro := 0.5
## El radio que se deja libre alrededor del punto de aparicion. La cuadricula se
## coloca a partir de aqui para que el jugador no aparezca dentro de un huerto.
@export var despeje_centro := 24.0

# --- Estado de la generacion -------------------------------------------------

var _rng := RandomNumberGenerator.new()
# Un SurfaceTool por material. Al final se commitea uno por cada uno.
var _piedra := SurfaceTool.new()
var _madera := SurfaceTool.new()
var _paja := SurfaceTool.new()
var _pizarra := SurfaceTool.new()
var _tierra := SurfaceTool.new()
var _oscuro := SurfaceTool.new()
# Las cajas que colisionan: solo las casas y los horreos. Los muros de las
# parcelas NO colisionan, y es a proposito: un muro de piedra seca de un metro
# se salta, y un trimesh de 4.000 triangulos de media milla de alto hace que
# la maquina se enganche en los bordes y dar saltos cada dos pasos.
var _solido: Array[Dictionary] = []

# La altura del suelo en la figura que se esta construyendo ahora mismo. Se usa
# para la UV vertical, que lleva los metros que hay de piedra encima del suelo,
# y de ahi el musgo del shader saca donde sale el musgo.
var _y0 := 0.0
var _caras := 0

var _solares: Array[Vector3] = []
var _horreos: Array[Vector3] = []
# La cuadricula de parcelas, ya colocada: de donde sale, con que giro va y hacia
# que direcciones. Se guardan porque los muros de por medio hay que trazarlos en
# las lineas de la cuadricula, no alrededor de cada parcela.
var _giro_cuadricula := 0.0
var _origen_cuadricula := Vector2.ZERO
var _eje_cuadricula := Vector2.RIGHT
var _normal_cuadricula := Vector2.UP
var _giros: Array[float] = []
var _parcelas: Array[Dictionary] = []
var _caminos: Array[PackedVector3Array] = []


func _ready() -> void:
	if terreno == null:
		terreno = get_parent().get_node_or_null("Terreno") as Terreno
	if terreno == null:
		push_error("Aldea: hace falta el terreno, que es de donde sale la altura")
		return
	_rng.seed = semilla
	_preparar_mallas()
	_reparto()
	_construir_mascara()
	_generar_caminos()
	_generar_solares()
	_generar_parcelas()
	_generar_casas()
	_generar_horreos()
	_commitir()
	print("Aldea: %d parcelas en %dx%d, %d casas, %d caminos, %d caras en %d mallas. El bloque cae en (%.0f, %.0f), girado %.0f grados"
		% [_parcelas.size(), columnas, filas, _solares.size(), _caminos.size(), _caras,
			_n_mallas(), _origen_cuadricula.x, _origen_cuadricula.y, rad_to_deg(_giro_cuadricula)])


# --- Reparto -----------------------------------------------------------------

## Las parcelas son una CUADRICULA, y no por gusto. Van a ser el marco del
## juego: un vecino te puede pedir que le desbrozes una, y para eso tiene que
## haber forma de decir "la parcela 7" y de llegar a ella. Con los huertos
## sueltos que habia antes no habia ni numero ni manera de señalar uno, y
## ademas los muros de dos parcelas vecinas se cruzaban por el medio.
##
## La cuadricula se gira con la horizontal del terreno, que es como se parcelan
## las laderas: el lado largo de cada parcela va en la horizontal y el corto se
##|sube la pendiente. Asi el bancal queda tumbado y no clavado en la ladera.
func _reparto() -> void:
	_rng.seed = semilla
	var sitio := _sitio_del_bloque()
	var giro: float = sitio["giro"]
	var origen: Vector2 = sitio["origen"]
	_giro_cuadricula = giro
	_origen_cuadricula = origen
	_eje_cuadricula = Vector2(cos(giro), sin(giro))
	_normal_cuadricula = Vector2(-sin(giro), cos(giro))
	# Las parcelas, de fila en fila. El identificador es el numero que se le
	# puede dar a un vecino, y va por filas, que es como se cuentan de verdad.
	var id := 0
	for f in filas:
		for c in columnas:
			var centro := origen \
				+ _eje_cuadricula * ((float(c) + 0.5) * largo_celda - largo_celda * float(columnas) * 0.5) \
				+ _normal_cuadricula * ((float(f) + 0.5) * ancho_celda - ancho_celda * float(filas) * 0.5)
			_parcelas.append({
				"id": id,
				"fila": f,
				"columna": c,
				"centro": centro,
				"largo": largo_celda,
				"ancho": ancho_celda,
				"giro": giro,
				"casa": false,
			})
			id += 1
	_elegir_casas()


## Donde se coloca el bloque entero, y con que giro.
##
## No se busca un sitio llano para cada parcela por separado, que es como se
## hacia antes y daba una aldea suelta. Se busca un sitio llano para el bloque,
## midiendo lo que se aleja el terreno del PLANO que mejor le encaja. En una
## ladera que es toda unplane, asi que el residuo es pequeno y da lo mismo en
## todas partes; lo que busca es un sitio sin un bulto o un hoyo en medio, que es
## donde los muros y las casas se descuadran.
func _sitio_del_bloque() -> Dictionary:
	var medio_c := float(columnas) * largo_celda * 0.5
	var medio_f := float(filas) * ancho_celda * 0.5
	var alcance := sqrt(medio_c * medio_c + medio_f * medio_f) + 6.0
	var mejor := {"giro": 0.0, "origen": Vector2.ZERO, "plano": 1e9}
	var n := 26
	for i in n:
		for j in n:
			var centro := Vector2(
				-110.0 + 220.0 * (float(i) + 0.5) / float(n),
				-110.0 + 220.0 * (float(j) + 0.5) / float(n))
			var giro := _giro_de_horizontal(centro)
			# Que el bloque quepa en el mapa, y que no se coma el punto de
			# aparicion. Se mide en el sistema del bloque, que es donde estan sus
			# lados, y no con un circulo: medirlo con un circulo obligaba a que el
			# bloque entero cabiera en un anillo y no cabia nunca, y el bloque se
			# quedaba en el origen, justo encima del jugador.
			# Y con un tope de distancia. El llano mas bueno del mapa estaba a
			# cien metros y, aunque se viera, era un paseo largo hasta el primer
			# muro. A 62 el bloque entero queda a menos de noventa.
			if centro.length() > 62.0:
				continue
			var u := centro.dot(Vector2(cos(giro), sin(giro)))
			var v := centro.dot(Vector2(-sin(giro), cos(giro)))
			if absf(u) + medio_c > 116.0 or absf(v) + medio_f > 116.0:
				continue
			var du := maxf(0.0, absf(u) - medio_c)
			var dv := maxf(0.0, absf(v) - medio_f)
			if sqrt(du * du + dv * dv) < despeje_centro:
				continue
			# Y que se VEA desde donde aparece el jugador. Sin esta comprobacion
			# la aldea se colocaba en el sitio mas llano del mapa, que era el mas
			# apartado, y desde el punto de aparicion se veia un tejado de nueve:
			# el resto de la aldea quedaba detras de un lomo, y el jugador
			# aparecia en un prado sin nada alrededor.
			if not _se_ve_desde_el_juego(centro, giro):
				continue
			# Entre llanos se elige el mas CERCA. Solo con el residuo salia el
			# sitio mas llano del mapa, que era el mas apartado del jugador. El
			# peso es pequeno a proposito: medio metro de desnivel vale mas que
			# veinte metros de distancia, pero no que sesenta.
			var residuo := _residuo_del_plano(centro, giro, alcance) + centro.length() * 0.006
			if residuo < mejor["plano"]:
				mejor = {"giro": giro, "origen": centro, "plano": residuo}
	return mejor


## Si desde el punto de aparicion se ve el bloque, o si por el camino se pone
## un lomo. Se traza la visual desde el ojo del jugador hasta lo alto de una
## casa en el centro del bloque, y se mira que el terreno no se suba por encima
## de esa linea.
func _se_ve_desde_el_juego(centro: Vector2, giro: float) -> bool:
	var ojo := Vector2(0.0, 2.5)
	var objetivo := centro
	var altura := terreno.cota_en(objetivo) + 3.0
	var pasos := 20
	for i in range(1, pasos):
		var t := float(i) / float(pasos - 1)
		var p := ojo.lerp(objetivo, t)
		var linea: float = ojo.y + (altura - ojo.y) * t
		if terreno.cota_en(p) > linea - 0.15:
			return false
	return true


## Lo que se sale el terreno del plano que mejor le encaja, en los nueve puntos
## de una malla tres por tres sobre el bloque. Con un plano de referencia queda
## la pendiente general, y lo que sobra es lo que de verdad molesta: el bulto.
func _residuo_del_plano(centro: Vector2, giro: float, alcance: float) -> float:
	var eje := Vector2(cos(giro), sin(giro))
	var normal := Vector2(-sin(giro), cos(giro))
	var alturas: Array[float] = []
	for j: float in [-1.0, 0.0, 1.0]:
		for i: float in [-1.0, 0.0, 1.0]:
			var p := centro + eje * (i * alcance * 0.8) + normal * (j * alcance * 0.8)
			alturas.append(terreno.cota_en(p))
	var suma := 0.0
	for h in alturas:
		suma += h
	var media := suma / alturas.size()
	var residuo := 0.0
	for h in alturas:
		residuo = maxf(residuo, absf(h - media))
	return residuo


## Las casas van en las primeras parcelas de la cuadricula, que son las del
## borde de la bajada, que es donde se instala la gente. Una por parcela, y en
## las que el terreno este mas llano, porque una casa con las cuatro esquinas en
## sitios distintos se cae.
func _elegir_casas() -> void:
	var orden: Array[Dictionary] = []
	for parcela in _parcelas:
		var c: Vector2 = parcela["centro"]
		orden.append({"p": parcela, "plano": _desnivel_around(c, 7.0)})
	orden.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["plano"] < b["plano"])
	for i in mini(num_casas, orden.size()):
		var parcela: Dictionary = orden[i]["p"]
		var c: Vector2 = parcela["centro"]
		parcela["casa"] = true
		# La casa a un lado de la parcela, no en el centro: la entrada mira a la
		# bajada y detras queda el huerto, que es como se hace.
		var sitio := c + Vector2(
			_rng.randf_range(-3.0, 3.0), _rng.randf_range(-2.5, 2.5))
		if _desnivel_around(sitio, 6.0) > 1.3:
			sitio = c
		_solares.append(Vector3(sitio.x, terreno.cota_en(sitio), sitio.y))
		_giros.append(_giro_de_horizontal(sitio) + PI * 0.5)


## El desnivel maximo en un circulo, que es la medida de "llano" que se usa aqui.
## Se mira en cruz y no en el circulo entero: con ocho muestras basta y sale
## ocho veces mas barato, y son miles de llamadas.
func _desnivel_around(p: Vector2, radio: float) -> float:
	var minimo := terreno.cota_en(p)
	var maximo := minimo
	for i in 8:
		var a := TAU * float(i) / 8.0
		var h := terreno.cota_en(p + Vector2(cos(a), sin(a)) * radio)
		minimo = minf(minimo, h)
		maximo = maxf(maximo, h)
	return maximo - minimo


## El giro con el que una parcela debe colocarse para que su lado largo vaya en
## la horizontal del terreno, o sea, perpendicular a la pendiente. Sale de la
## diferencia de alturas a los lados, que es la pendiente en esa direccion.
func _giro_de_horizontal(p: Vector2) -> float:
	var e := 2.0
	var gx := terreno.cota_en(p + Vector2(e, 0.0)) - terreno.cota_en(p - Vector2(e, 0.0))
	var gz := terreno.cota_en(p + Vector2(0.0, e)) - terreno.cota_en(p - Vector2(0.0, e))
	# El vector de la pendiente; la horizontal es perpendicular a el.
	return atan2(gx, gz) + PI * 0.5


func _muy_cerca(p: Vector2, puntos: Array[Vector2], distancia: float) -> bool:
	for q in puntos:
		if p.distance_to(q) < distancia:
			return true
	return false


## La mascara: un mapa de celdas de donde NO se siembra nada, que son las
## parcelas. Sin esto la hierba crece dentro de los huertos y los arboles
## aparecen en mitad de un solar, y una aldea con la hierba metida dentro de los
## recintos no es una aldea: es un pueblo de bloques con un prado.
##
## No es un mapa por parcela sino UNO de todo el pueblo, porque quien lo
## consulta es la siembra, y va a preguntar cientos de miles de veces. Preguntar
## parcela por parcela serian millones de cuentas; con el mapa es una division
## y una mirada a la tabla.
var _mascara := PackedByteArray()
var _mascara_celda := 1.5
var _mascara_min := Vector2.ZERO
var _mascara_ancho := 0
var _mascara_alto := 0


func _construir_mascara() -> void:
	var minimo := Vector2(INF, INF)
	var maximo := Vector2(-INF, -INF)
	for parcela in _parcelas:
		var c: Vector2 = parcela["centro"]
		var r: float = maxf(parcela["largo"], parcela["ancho"]) * 0.5
		minimo.x = minf(minimo.x, c.x - r)
		minimo.y = minf(minimo.y, c.y - r)
		maximo.x = maxf(maximo.x, c.x + r)
		maximo.y = maxf(maximo.y, c.y + r)
	# Se agranda un poco, para que la mascara llegue al borde de las parcelas y
	# no se quede un dedo de cesped pegado al muro.
	minimo -= Vector2(1.0, 1.0)
	maximo += Vector2(1.0, 1.0)
	_mascara_min = minimo
	_mascara_ancho = maxi(1, int(ceil((maximo.x - minimo.x) / _mascara_celda)))
	_mascara_alto = maxi(1, int(ceil((maximo.y - minimo.y) / _mascara_celda)))
	_mascara.resize(_mascara_ancho * _mascara_alto)
	for parcela in _parcelas:
		var centro: Vector2 = parcela["centro"]
		var largo: float = parcela["largo"]
		var ancho: float = parcela["ancho"]
		var giro: float = parcela["giro"]
		var cs := cos(giro)
		var sn := sin(giro)
		for j in _mascara_alto:
			for i in _mascara_ancho:
				# El centro de la celda, en coordenadas de la parcela.
				var q := Vector2(minimo.x + _mascara_celda * (float(i) + 0.5),
					minimo.y + _mascara_celda * (float(j) + 0.5)) - centro
				var u := q.x * cs + q.y * sn
				var v := -q.x * sn + q.y * cs
				if absf(u) < largo * 0.5 and absf(v) < ancho * 0.5:
					_mascara[j * _mascara_ancho + i] = 1


## Si un punto cae dentro de una parcela. Lo miran la hierba y el bosque antes
## de sembrar o plantar.
func dentro(p: Vector2) -> bool:
	if _mascara.is_empty():
		return false
	var i := int((p.x - _mascara_min.x) / _mascara_celda)
	var j := int((p.y - _mascara_min.y) / _mascara_celda)
	if i < 0 or j < 0 or i >= _mascara_ancho or j >= _mascara_alto:
		return false
	return _mascara[j * _mascara_ancho + i] == 1


# --- Los caminos -------------------------------------------------------------

## Un camino principal que sube desde abajo y va pasando por todas las casas, y
## un ramal para cada casa desde su puerta. Lo de "ir pasando" es lo de menos:
## empieza en la casa mas baja y cada vez tira a la mas cercana que le queda,
## y sale un camino serpenteante como los de verdad.
func _generar_caminos() -> void:
	# La calle va sobre una LINEA DE MUROS de la cuadricula, y el muro de esa
	# linea se abre a lo ancho de la calzada. Asi la calle es la linea y el muro
	# esta a los dos lados, como en las aldeas de verdad, donde el camino
	# central se fue abriendo y comiendose los deslindes.
	#
	# Antes el camino se trazaba de casa en casa con el vecino mas cercano, y
	# con las parcelas sueltas eso salia bien. Con la cuadricula cruzaba los
	# huertos por el medio y se pasaba por encima de los muros, que es
	# justamente una de las cosas que faltaban por tener sentido.
	var medio_c := float(columnas) * largo_celda * 0.5
	var medio_f := float(filas) * ancho_celda * 0.5
	var y := -medio_f + float(calle_fila) * ancho_celda
	var salida := medio_c + 34.0
	var ruta := PackedVector3Array()
	for i in 9:
		var u := -salida + (salida * 2.0) * float(i) / 8.0
		var p := _origen_cuadricula + _eje_cuadricula * u + _normal_cuadricula * y
		ruta.push_back(Vector3(p.x, terreno.cota_en(p) + 0.05, p.y))
	_caminos.append(ruta)
	# Y dos ramales fuera del bloque, que son por donde se entra y por donde se
	# sale, para que la calle no se quede cortada en seco en el primer muro.
	for lado: float in [-1.0, 1.0]:
		var p0 := _origen_cuadricula + _eje_cuadricula * (lado * salida) \
			+ _normal_cuadricula * y
		var p1 := p0 + _normal_cuadricula * (lado * 26.0)
		_caminos.append(PackedVector3Array([
			Vector3(p0.x, terreno.cota_en(p0) + 0.05, p0.y),
			Vector3(p1.x, terreno.cota_en(p1) + 0.05, p1.y),
		]))


# --- Las parcelas y sus muros ------------------------------------------------

## Un muro de piedra seca. Cada parcela va cerrada, menos un hueco para pasar.
##
## Un muro no es un rectangulo, es una tira que sigue el suelo: la base se apoya
## en el terreno en cada punto y la parte de arriba va a saltos, con un escalon
## cada dos metros. Esa parte escalonada es la que hace que un muro de piedra se
## reconozca como un muro de piedra y no como un mutilo de goma.
func _muro(p0: Vector2, p1: Vector2, alto: float, grosor: float, hueco: float) -> void:
	var largo := p0.distance_to(p1)
	if largo < 0.4:
		return
	var dir := (p1 - p0) / largo
	var lado := Vector2(-dir.y, dir.x)
	var tramos := maxi(1, int(largo / 2.0))
	var corte_a := 0.0
	var corte_b := largo
	if hueco > 0.0:
		var mitad := hueco * 0.5
		corte_a = clampf(largo * 0.5 - mitad, 0.05, largo - 0.05)
		corte_b = clampf(largo * 0.5 + mitad, 0.05, largo - 0.05)
	for tramo in 2:
		var a := 0.0
		var b := largo
		if tramo == 0:
			b = corte_a
		else:
			a = corte_b
		if b - a < 0.3:
			continue
		_tramo_de_muro(p0 + dir * a, p0 + dir * b, dir, lado, alto, grosor)
	# Las dos esquinas de cada extremo, mas altas y mas anchas, que es de donde
	# sale el aspecto de muro bien hecho.
	for e: Vector2 in [p0, p1]:
		_piedrecas(e, alto * 1.25, grosor * 1.3)


func _tramo_de_muro(a: Vector2, b: Vector2, dir: Vector2, lado: Vector2,
		alto: float, grosor: float) -> void:
	var largo := a.distance_to(b)
	var n := maxi(1, int(largo / 2.0))
	var anterior := PackedVector3Array()
	for i in n + 1:
		var p := a.lerp(b, float(i) / float(n))
		var h := terreno.cota_en(p)
		# La parte de arriba va a escalones: se queda con la parte alta del
		# tramo, y como los tramos son de dos metros, se ven los escalones.
		var top := h + alto
		if i > 0:
			top = maxf(top, anterior[1].y)
		# El muro se estrecha al subir, que es como se hacen: la base ancha y
		# arriba mas estrecho, para que el peso lo lleve abajo.
		var g_bajo := grosor * 0.5
		var g_alto := grosor * 0.5 * 0.72
		var actual := PackedVector3Array([
			Vector3(p.x - lado.x * g_bajo, h, p.y - lado.y * g_bajo),
			Vector3(p.x + lado.x * g_bajo, h, p.y + lado.y * g_bajo),
			Vector3(p.x + lado.x * g_alto, top, p.y + lado.y * g_alto),
			Vector3(p.x - lado.x * g_alto, top, p.y - lado.y * g_alto),
		])
		if i > 0:
			# Solo las caras de fuera. Las de dentro no se ven nunca y son la
			# mitad de los triangulos.
			_cara(_piedra, anterior[0], anterior[1], actual[1], actual[0],
				Vector3(-lado.x, 0.0, -lado.y))
			_cara(_piedra, actual[3], actual[2], anterior[2], anterior[1],
				Vector3(lado.x, 0.0, lado.y))
			_cara(_piedra, anterior[3], anterior[2], actual[2], actual[3], Vector3.UP)
		anterior = actual
	_y0 = terreno.cota_en(a)


## El remate de las esquinas: cuatro o cinco piedras sueltas, mas claras y mas
## anchas que el muro. Es lo que hace que un muro parezca de piedra puesta y no
## saliente de un teton.
func _piedrecas(p: Vector2, alto: float, grosor: float) -> void:
	var suelo := terreno.cota_en(p)
	var n := 4
	for i in n:
		var f := (float(i) + 0.7) / float(n) - 0.2
		var ancho := grosor * _rng.randf_range(0.55, 0.8)
		var alto_piedra := alto * _rng.randf_range(0.17, 0.26)
		var y := suelo + alto * f
		var d := (f - 0.5) * grosor * 0.9
		var giro := _rng.randf_range(-0.25, 0.25)
		_y0 = suelo
		_caja(_piedra, Vector3(p.x + sin(giro) * d, y, p.y + cos(giro) * d),
			Vector3(grosor * _rng.randf_range(0.7, 1.0), alto_piedra, ancho), giro)


## Los cuatro muros de cada parcela, con el hueco en un lado. Y dentro, unos
## lomos de tierra levantada, que es la labranza: cuatro hileras paralelas al
## lado largo de la parcela.
func _generar_parcelas() -> void:
	# Los muros van por LINEAS DE CUADRICULA, no alrededor de cada parcela. Es la
	# diferencia entre un deslinde y un amasijo: con un muro por parcela, el de la
	# parcela de al lado caia encima del de esta, los dos con su grosor, y en las
	# juntas se veian dos paredes peleandose por el mismo metro de suelo.
	#
	# Asi se recorre la cuadricula entera: una pasada por las columnas de muro y
	# otra por las filas. Cada linea se parte en los tramos de cada parcela, y ahi
	# es donde va el paso: el hueco de una parcela es un tramo de la linea, y como
	# el tramo es suyo y solo suyo, no hay dos parcelas pidiendo paso a la vez en el mismo muro.
	var medio_c := float(columnas) * largo_celda * 0.5
	var medio_f := float(filas) * ancho_celda * 0.5
	for c in columnas + 1:
		var x := -medio_c + float(c) * largo_celda
		for f in filas:
			var y0 := -medio_f + float(f) * ancho_celda
			_muro_de_cuadricula(x, y0, x, y0 + ancho_celda, 0.0)
	for f in filas + 1:
		var y := -medio_f + float(f) * ancho_celda
		# En la linea de la calle el muro se abre a lo ancho de la calzada, y en
		# las demas lineas solo para el paso de una parcela, que es un hueco
		# estrecho de 1,8 m.
		var hueco := 5.0 if f == calle_fila else 1.8
		for c in columnas:
			var x0 := -medio_c + float(c) * largo_celda
			_muro_de_cuadricula(x0, y, x0 + largo_celda, y, hueco)
	# Y los lomos de labranza dentro de cada parcela, que ya no hacen falta para
	# que la parcela se entienda: son la tierra que hay labrada.
	for parcela in _parcelas:
		var centro: Vector2 = parcela["centro"]
		for f in 4:
			var t := (float(f) + 0.7) / 4.4 - 0.5
			_lomo(centro + _eje_cuadricula * (largo_celda * 0.42)
					+ _normal_cuadricula * (ancho_celda * t),
				centro - _eje_cuadricula * (largo_celda * 0.42)
					+ _normal_cuadricula * (ancho_celda * t), 0.45, 0.5, _tierra)


## Un tramo de muro de la cuadricula, en coordenadas de la cuadricula (x a lo
## largo del eje, y subiendo la normal).
##
## El paso va solo en las lineas de fila, y por tanto cada parcela tiene uno y
## solo uno, en el muro de arriba. En las lineas de columna no, que si no dos
## parcelas vecinas estarian pidiendo el hueco al mismo tiempo en el mismo muro.
## Por eso el parametro se pasa explicito en las dos pasadas y no se decide
## aqui: el que sabe si este tramo es de fila o de columna es quien lo traza.
func _muro_de_cuadricula(x0: float, y0: float, x1: float, y1: float, hueco: float) -> void:
	var a := _origen_cuadricula + _eje_cuadricula * x0 + _normal_cuadricula * y0
	var b := _origen_cuadricula + _eje_cuadricula * x1 + _normal_cuadricula * y1
	_muro(a, b, alto_muro, grosor_muro, hueco)


## Una tira de tierra pegada al terreno, de `ancho`, que se eleva `alto`.
##
## Con `alto` a cero es un camino, y con `alto` a medio metro es un lomo de
## labranza. Los dos son la misma figura, y por eso es una sola funcion: un
## camino sobre una ladera con terrazas no puede ser un rectangulo plano, tiene
## que ir en la cinta,Follow la curva del terreno, o se ve elapezamiento.
func _lomo(a: Vector2, b: Vector2, ancho: float, alto: float,
		t: SurfaceTool) -> void:
	var largo := a.distance_to(b)
	if largo < 0.5:
		return
	var dir := (b - a) / largo
	var lado := Vector2(-dir.y, dir.x) * (ancho * 0.5)
	var anterior := PackedVector3Array()
	var n := maxi(1, int(ceil(largo / 2.0)))
	for i in n + 1:
		var p := a.lerp(b, float(i) / float(n))
		var h := terreno.cota_en(p) + 0.04
		var actual := PackedVector3Array([
			Vector3(p.x - lado.x, h, p.y - lado.y),
			Vector3(p.x + lado.x, h, p.y + lado.y),
			Vector3(p.x + lado.x, h + alto, p.y + lado.y),
			Vector3(p.x - lado.x, h + alto, p.y - lado.y),
		])
		if i > 0:
			_cara(t, anterior[0], anterior[1], actual[1], actual[0],
				Vector3(-dir.x, 0.0, -dir.y))
			_cara(t, actual[3], actual[2], anterior[2], anterior[1],
				Vector3(dir.x, 0.0, dir.y))
			if alto > 0.0:
				_cara(t, actual[2], actual[3], anterior[3], anterior[2], Vector3.UP)
		anterior = actual
	_y0 = terreno.cota_en(a)


## Los caminos, en tierra batida. Van primero porque las parcelas se apoyan en
## ellos: la puerta de cada parcela esta donde toca el camino, no al azar.
func _generar_solares() -> void:
	for ruta in _caminos:
		for i in ruta.size() - 1:
			_lomo(Vector2(ruta[i].x, ruta[i].z), Vector2(ruta[i + 1].x, ruta[i + 1].z),
				2.2, 0.0, _tierra)


# --- Las casas ---------------------------------------------------------------

## Una casa: cuatro muros de piedra, tejado a dos aguas y los huecos. Media
## aldea con paja y media con pizarra, que es como esta Galicia partida por la
## rainia, y ademas asi se ven las dos cosas.
func _generar_casas() -> void:
	for i in _solares.size():
		var solar := _solares[i]
		var giro: float = _giros[i]
		var paja := i % 2 == 0
		# De 7 a 9 m de largo y de 5 a 6 de fondo.
		var largo := _rng.randf_range(7.0, 9.0)
		var fondo := _rng.randf_range(5.0, 6.0)
		var altura := _rng.randf_range(2.5, 2.9)
		_y0 = solar.y
		_muros_de_casa(solar, giro, largo, fondo, altura)
		_prisma(solar, giro, largo, fondo, altura, 0.7, 0.85,
			_paja if paja else _pizarra)
		_huecos(solar, giro, largo, fondo, altura, paja)
		_solido.append({"centro": solar + Vector3.UP * (altura * 0.5),
			"tam": Vector3(largo, altura, fondo), "giro": giro})
		# Y la colision del tejado, que si no se puede andar por debajo de el.
		_solido.append({"centro": solar + Vector3.UP * (altura + 0.5),
			"tam": Vector3(largo * 0.95, 1.2, fondo * 0.95), "giro": giro})


## Los cuatro muros, cada uno con su grosor, y sin que se crucen en las
## esquinas: los dos largos van por dentro y los cortos por fuera.
##
## Los muros no son cajas. Antes lo eran: cuatro cajas planas a la altura del
## solar, y en una ladera la esquina de abajo se hundia en el terreno y la de
## arriba se quedaba en el aire. Ahora cada muro se traza con `_muro()`, que es
## el mismo camino que siguen los muros de las parcelas: va mirando el suelo y
## sube y baja a escalones. Una casa con el zocalo clavado en la ladera.
func _muros_de_casa(solar: Vector3, giro: float, largo: float, fondo: float,
		altura: float) -> void:
	var grosor := 0.45
	var eje := Vector2(cos(giro), sin(giro))
	var normal := Vector2(-sin(giro), cos(giro))
	var centro := Vector2(solar.x, solar.z)
	var y0 := _y0
	# Los dos largos, por dentro, y los dos cortos por fuera, para que no se
	# crucen en las esquinas.
	for lado: float in [-1.0, 1.0]:
		var linea := centro + normal * (lado * (fondo * 0.5 - grosor * 0.5))
		_muro(linea - eje * (largo * 0.5), linea + eje * (largo * 0.5),
			altura, grosor, 0.0)
	for lado: float in [-1.0, 1.0]:
		var linea := centro + eje * (lado * (largo * 0.5 - grosor * 0.5))
		_muro(linea - normal * (fondo * 0.5 - grosor * 0.5),
			linea + normal * (fondo * 0.5 - grosor * 0.5), altura, grosor, 0.0)
	_y0 = y0


## El tejado a dos aguas: dos faldones y dos hastiales.
##
## El caballete va en el centro del ancho, con la altura que toque para una
## pendiente de unos 40 grados, que es lo que aguanta la lluvia sin que el agua
## se meta por la union. Y el vuelo es solo en el sentido de la cumbrera, que
## es donde se ve el tejado desde la bajada; en los laterales el alero llega
## justo a la pared, que es como se hacen las casas de piedra.
func _prisma(base: Vector3, giro: float, largo: float, fondo: float, alto: float,
		vuelo: float, caballete: float, t: SurfaceTool) -> void:
	var f := fondo * 0.5
	var l := largo * 0.5 + vuelo
	var pendiente := atan(caballete / f)
	var largo_faldon := sqrt(f * f + caballete * caballete) * 1.06
	for lado: float in [-1.0, 1.0]:
		# El faldon, inclinado. El centro va a media altura del faldon, a media
		# anchura: de ahi sale la inclinacion, y con el vuelo de sobra para que
		# los faldones se pisen en la caballera.
		#
		# El signo de la inclinacion es lo unico que separa un tejado de una
		# cebada: los dos faldones tienen que CAER hacia fuera y juntarse arriba
		# en la caballera. Con el signo al reves los dos bajan hacia el centro y
		# se forma una V en medio, que de lejos no se lee como tejado sino como
		# dos losas torcidas, y la caballera se queda flotando por encima sin
		# tocar nada.
		_caja_inclinada(t,
			base + Vector3.UP * (alto + caballete * 0.5) + Vector3(-sin(giro), 0.0, cos(giro)) * (lado * f * 0.5),
			Vector3(l * 2.0, 0.14, largo_faldon), giro, lado * pendiente)
		# El hastial, que es el triangulito de debajo. Va en piedra, porque el
		# hastial se cierra con la pared. Y es un TRIANGULO de verdad, con su
		# funcion: si se pasa como un cuadrilatero con el ultimo punto repetido,
		# sale un triangulo de area cero que el motor dibuja o no segun le
		# apetece.
		var e := Vector3(cos(giro), 0.0, sin(giro)) * (largo * 0.5) * lado
		var n := Vector3(-sin(giro), 0.0, cos(giro)) * lado
		_tri(_piedra, base + e + n * f, base + e - n * f,
			base + e + Vector3.UP * (alto + caballete), e.normalized())
	# La caballera, que remata las dos losas por arriba.
	_caja_inclinada(t, base + Vector3.UP * (alto + caballete + 0.05),
		Vector3(l * 2.0, 0.16, 0.3), giro, 0.0)


## La puerta, las ventanas y, si el tejado es de pizarra, la chimenea.
##
## Los huecos van un centimetro por delante de la pared, para que no se pelen.
## Y la chimenea sale solo con pizarra: una casa de paja no tiene humo, porque
## no se enciende fuego dentro, y meterle una es un error de bulto.
func _huecos(solar: Vector3, giro: float, largo: float, fondo: float,
		altura: float, paja: bool) -> void:
	var eje := Vector3(cos(giro), 0.0, sin(giro))
	var normal := Vector3(-sin(giro), 0.0, cos(giro))
	# La fachada: la pared que mira a la bajada.
	var fachada := solar + normal * (fondo * 0.5)
	# La puerta, en el centro, con su dintel de piedra.
	_caja(_madera, fachada + normal * 0.04, Vector3(0.95, 2.05, 0.08), giro)
	_caja(_piedra, fachada + normal * 0.02 + Vector3.UP * 2.05,
		Vector3(1.35, 0.22, 0.36), giro)
	# Dos ventanas a los lados, con su alféizar de losa.
	for lado: float in [-1.0, 1.0]:
		var ventana := fachada + eje * (lado * (largo * 0.32))
		_caja(_piedra, ventana + normal * 0.05 + Vector3.UP * 1.0,
			Vector3(0.9, 0.2, 0.32), giro)
		_caja(_oscuro, ventana + normal * 0.06 + Vector3.UP * 1.35,
			Vector3(0.7, 0.7, 0.06), giro)
		_caja(_piedra, ventana + normal * 0.09 + Vector3.UP * 1.0,
			Vector3(1.0, 0.12, 0.42), giro)
	if not paja:
		var chimenea := fachada - normal * (fondo * 0.3) - eje * (largo * 0.3)
		_caja(_piedra, chimenea + Vector3.UP * (altura * 0.4),
			Vector3(0.55, altura * 1.5, 0.55), giro)
		_caja(_oscuro, chimenea + Vector3.UP * (altura * 1.13),
			Vector3(0.36, 0.1, 0.36), giro)


# --- Los horreos -------------------------------------------------------------

## Un horreo: un granero sobre patas de piedra, con el cuerpo de madera y el
## tejado de dos losas de pizarra. Es lo mas caracteristico de una aldea
## gallega, y lo que mas distingue este escenario de un pueblo cualquiera.
func _generar_horreos() -> void:
	for i in 2:
		var sitio := _sitio_para_horreo()
		if sitio == Vector3.ZERO:
			continue
		_horreos.append(sitio)
		_y0 = sitio.y
		_horreo(sitio, _giro_de_horizontal(Vector2(sitio.x, sitio.z)) + PI * 0.5)


## Busca un sitio llano que no este ya ocupado. Si no lo encuentra, no pone
## hórreo y ya esta: mejor dos que tres con uno en la pendiente.
func _sitio_para_horreo() -> Vector3:
	var mejor := Vector3.ZERO
	var mejor_plano := 1.2
	# Ahora los hórreos se buscan ALREDEDOR de la cuadricula, que es donde
	# tienen sentido: en la era de la aldea, no en mitad de un huerto.
	var medio_c := float(columnas) * largo_celda * 0.5
	var medio_f := float(filas) * ancho_celda * 0.5
	var alcance := sqrt(medio_c * medio_c + medio_f * medio_f) + 14.0
	for intento in 400:
		var p := _origen_cuadricula + Vector2(
			_rng.randf_range(-alcance, alcance), _rng.randf_range(-alcance, alcance))
		if p.length() > 112.0:
			continue
		var plano := _desnivel_around(p, 5.0)
		if plano >= mejor_plano:
			continue
		var libre := true
		for s in _solares:
			if Vector2(s.x, s.z).distance_to(p) < 14.0:
				libre = false
		# Y lejos del otro hórreo. Sin esto los dos acababan en el mismo sitio:
		# la busqueda parte del mismo estado del azar y el segundo hórreo
		#(findia el mismo llano que el primero.
		for h in _horreos:
			if Vector2(h.x, h.z).distance_to(p) < 26.0:
				libre = false
		for parcela in _parcelas:
			if libre:
				var c: Vector2 = parcela["centro"]
				var r: float = maxf(parcela["largo"], parcela["ancho"]) * 0.5 + 5.0
				if c.distance_to(p) < r:
					libre = false
		if not libre:
			continue
		mejor = Vector3(p.x, terreno.cota_en(p), p.y)
		mejor_plano = plano
		if mejor_plano < 0.35:
			break
	return mejor


func _horreo(sitio: Vector3, giro: float) -> void:
	var patas := 1.7
	var ancho := 1.7
	var fondo := 1.9
	var cuerpo_alto := 1.5
	# El zocalo de piedra, que es donde se apoya todo el peso.
	_caja(_piedra, sitio, Vector3(ancho + 0.7, 0.35, fondo + 0.7), giro)
	# Las patas, cuatro, con la parte de abajo mas ancha que la de arriba, como
	# un tronco. De verdad se clavan en el suelo en vez de apoyarse en un
	# zocalo, pero con el zocalo se ahorra el hueco de debajo.
	var eje := Vector3(cos(giro), 0.0, sin(giro))
	var normal := Vector3(-sin(giro), 0.0, cos(giro))
	var pronto := sitio + Vector3.UP * 0.35
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var pata := pronto + eje * (sx * (ancho * 0.5 - 0.15)) \
				+ normal * (sz * (fondo * 0.5 - 0.15))
			_caja(_piedra, pata, Vector3(0.44, patas * 0.5, 0.44), giro)
			_caja(_piedra, pata + Vector3.UP * (patas * 0.5),
				Vector3(0.3, patas * 0.5, 0.3), giro)
	var cuerpo := pronto + Vector3.UP * patas
	_caja(_madera, cuerpo, Vector3(ancho, cuerpo_alto, fondo), giro)
	_prisma(cuerpo + Vector3.UP * cuerpo_alto, giro, ancho, fondo, 0.0, 0.35, 0.55, _pizarra)
	_solido.append({"centro": cuerpo + Vector3.UP * (cuerpo_alto * 0.5),
		"tam": Vector3(ancho, cuerpo_alto, fondo), "giro": giro})
	_solido.append({"centro": cuerpo + Vector3.UP * (cuerpo_alto + 0.4),
		"tam": Vector3(ancho, 1.0, fondo), "giro": giro})
	# Un par de peldanos de piedra, que es como se sube a un hórreo.
	for peldano in 3:
		_caja(_piedra, sitio + normal * (fondo * 0.5 + 0.6) + Vector3.UP * (0.35 + float(peldano) * 0.45),
			Vector3(0.6, 0.22, 0.6), giro)


# --- Las piezas basicas ------------------------------------------------------

## Una caja con la base en el suelo, girada alrededor de la vertical. Es la
## pieza base: los muros, las puertas, las ventanas, las patas, los cuerpos.
func _caja(t: SurfaceTool, base: Vector3, tam: Vector3, giro: float) -> void:
	_caja_giro(t, base + Vector3.UP * (tam.y * 0.5), tam, giro, 0.0)


## Lo mismo pero centrada en `centro` y con inclinacion, que es lo que hace
## falta para un faldon de tejado: girar una caja alrededor de la vertical no
## sirve, porque un tejado lo que tiene es pendiente.
##
## El orden de los giros importa: primero la inclinacion en el eje local y
## luego el giro de la casa. Al reves, un tejado con inclinacion se queda
## horizontal al girar la casa, y se ve en cuanto la casa mira al otro lado.
func _caja_inclinada(t: SurfaceTool, centro: Vector3, tam: Vector3, giro: float,
		inclinacion: float) -> void:
	_caja_giro(t, centro, tam, giro, inclinacion)


func _caja_giro(t: SurfaceTool, centro: Vector3, tam: Vector3, giro: float,
		inclinacion: float) -> void:
	var h := tam * 0.5
	var c := [
		Vector3(-h.x, -h.y, -h.z), Vector3(h.x, -h.y, -h.z),
		Vector3(h.x, -h.y, h.z), Vector3(-h.x, -h.y, h.z),
		Vector3(-h.x, h.y, -h.z), Vector3(h.x, h.y, -h.z),
		Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z),
	]
	var v := PackedVector3Array()
	for i in 8:
		v.push_back(centro + c[i].rotated(Vector3.RIGHT, inclinacion).rotated(Vector3.UP, giro))
	# Solo cinco caras: la de abajo no se ve nunca, y en 300 cajas son 600
	# triangulos que el motor dibuja sin que nadie los mire.
	_cara(t, v[4], v[5], v[6], v[7], _rot(Vector3.UP, giro, inclinacion))
	_cara(t, v[1], v[0], v[4], v[5], _rot(Vector3.RIGHT, giro, inclinacion))
	_cara(t, v[3], v[2], v[6], v[7], _rot(Vector3.LEFT, giro, inclinacion))
	_cara(t, v[2], v[1], v[5], v[6], _rot(Vector3.BACK, giro, inclinacion))
	_cara(t, v[0], v[3], v[7], v[4], _rot(Vector3.FORWARD, giro, inclinacion))


func _rot(v: Vector3, giro: float, inclinacion: float) -> Vector3:
	return v.rotated(Vector3.RIGHT, inclinacion).rotated(Vector3.UP, giro)


## Un cuadrilatero. Los cuatro puntos van en cualquier orden: se mira hacia
## donde apunta la cara y, si hace falta, se le da la vuelta, que es mucho mas
## seguro que acertar con el orden a la primera.
##
## OJO con el sentido de las espirales, que es lo unico que hay que tener claro
## en todo el proyecto. En Godot la cara del frente es la que se ve en HORARIO
## desde el lado de la normal, o sea, que la normal geometrica del triangulo
## apunta AL CONTRARIO de por donde se mira. Por eso el `PlaneMesh` (que se ve
## desde arriba) sale con la normal geometrica en -Y. Con el otro sentido, el
## terreno se dibuja de cara al suelo: desde arriba no se ve nada, y con el
## culling puesto no se nota, porque lo que se ve desde abajo es el interior.
func _cara(t: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		fuera: Vector3) -> void:
	var n := (b - a).cross(d - a)
	var p0 := a
	var p1 := b
	var p2 := c
	var p3 := d
	if n.dot(fuera) > 0.0:
		p1 = d
		p2 = c
		p3 = b
	_pintar(t, p0, p1, p2, fuera)
	_pintar(t, p0, p2, p3, fuera)


## Un triangulo suelto, con la misma vuelta de espiral que `_cara`. Los
## hastiales del tejado y las faldas de los horreos lo usan.
func _tri(t: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, fuera: Vector3) -> void:
	if (b - a).cross(c - a).dot(fuera) > 0.0:
		_pintar(t, a, c, b, fuera)
	else:
		_pintar(t, a, b, c, fuera)


func _pintar(t: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3,
		normal: Vector3) -> void:
	for p: Vector3 in [p0, p1, p2]:
		t.set_normal(normal)
		# La UV vertical lleva los metros de piedra que hay encima del suelo, y
		# de ahi el shader saca el musgo. Sin esto el musgo sale a la misma
		# altura del mundo en todos los muros, y en una ladera eso quiere decir
		# musgo flotando en el aire.
		t.set_uv(Vector2(p.x + p.z, maxf(p.y - _y0, 0.0)))
		t.add_vertex(p)
	_caras += 1


# --- Los materiales y las mallas ---------------------------------------------

func _preparar_mallas() -> void:
	for t: SurfaceTool in [_piedra, _madera, _paja, _pizarra, _tierra, _oscuro]:
		t.begin(Mesh.PRIMITIVE_TRIANGLES)


func _commitir() -> void:
	var pares := [
		[_piedra, _material_piedra()],
		[_madera, _plano(Color(0.24, 0.16, 0.11), 0.85)],
		[_paja, _plano(Color(0.52, 0.43, 0.22), 0.98)],
		[_pizarra, _plano(Color(0.17, 0.18, 0.21), 0.7)],
		[_tierra, _plano(Color(0.33, 0.27, 0.19), 0.95)],
		[_oscuro, _plano(Color(0.09, 0.09, 0.11), 0.45)],
	]
	var n := 0
	for par in pares:
		var t: SurfaceTool = par[0]
		var malla := t.commit()
		if malla == null or malla.get_surface_count() == 0:
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = malla
		mi.material_override = par[1]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(mi)
		n += 1
	# Y la colision: una caja por casa y por hórreo, dentro de un cuerpo quieto.
	# Los muros de las parcelas no colisionan, por lo de arriba.
	#
	# El cuerpo quieto no es opcional: un CollisionShape3D colgado de un Node3D
	# se queda colgando sin avisar de nada, y se atraviesa la aldea andando. Solo
	# colisiona si cuelga de un CollisionObject3D.
	var cuerpo := StaticBody3D.new()
	cuerpo.name = "Solidos"
	add_child(cuerpo)
	for s in _solido:
		var col := CollisionShape3D.new()
		var forma := BoxShape3D.new()
		forma.size = s["tam"]
		col.shape = forma
		col.position = s["centro"]
		col.rotation.y = s["giro"]
		cuerpo.add_child(col)


func _n_mallas() -> int:
	var n := 0
	for c in get_children():
		if c is MeshInstance3D:
			n += 1
	return n


func _material_piedra() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/piedra.gdshader")
	return m


func _plano(color: Color, rugosidad: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rugosidad
	m.metallic = 0.0
	return m
