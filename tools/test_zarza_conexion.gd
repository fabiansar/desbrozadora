extends SceneTree

## La mecanica de la zarza: raiz, enganches y lo que cae cuando se pierde el
## apoyo.
##
##     godot --headless --path . --script tools/test_zarza_conexion.gd
##
## Se prueban las reglas de verdad, no que haya numeros bonitos:
##
##   1. Siembra: hay coronas, hay enganches, y el enredo da lineas cruzadas.
##   2. Corte a media altura: cae lo que hay por encima de la franja.
##   3. Corte a la base de UNA mata: cae lo que solo se sostenia con ella, y la
##      parte que se sostenia con la OTRA sigue en pie. Esta es la regla que dijo
##      el jugador: si el enganche es con otro anclaje al suelo, el de arriba no
##      desaparece.
##   4. Mientras quede una corona, la zarza no esta muerta: la raiz no muere.
##   5. Corte donde ya no hay nada: no pasa nada, y da igual.

var correctas := 0
var fallos := 0


func _initialize() -> void:
	# Diferido y no directo: mientras el arbol no ha arrancado, `root` todavia no
	# esta dentro del arbol, y un nodo que se le anade no se da cuenta. Por eso
	# una zarza creada en `_initialize` se queda fuera de la escena y todo lo que
	# pida su transformada global da error.
	call_deferred("_ejecutar")


func _ejecutar() -> void:
	_prueba_siembra()
	_prueba_corte_medio()
	_prueba_dos_matas()
	_prueba_zarza_muerta()
	print("-- resultado: %s" % ("OK" if fallos == 0 else "%d FALLOS" % fallos))
	quit(0 if fallos == 0 else 1)


## Zarza de dos matas, sin enredo para que los territorios de cada raiz queden
## limpios. Con enredo las dos zonas se cruzan y no se puede afirmar nada de
## donde cae cada cosa; el enredo se prueba por separado.
##
## Se anade al arbol porque `_ready` es quien siembra, y porque `cortar_en` pide
## `to_global()`: una zarza suelta, fuera del arbol, no tiene donde caerse.
func _zarza(matas: int, enredio: float) -> Zarza:
	var z := Zarza.new()
	z.semilla = 4242
	z.ancho = 9.0
	z.fondo = 9.0
	z.altura_maxima = 2.0
	z.densidad = 1.0
	z.matas = matas
	z.enredio = enredio
	z.dejar_tocon = true
	z.altura_tocon = 0.0
	root.add_child(z)
	return z


func _ok(que: String, condicion: bool, detalle: String = "") -> void:
	if condicion:
		correctas += 1
		print("  OK   %s" % que)
	else:
		fallos += 1
		print("  FAIL %s %s" % [que, detalle])


func _prueba_siembra() -> void:
	print("== siembra: corona, enganches y enredo ==")
	var z := _zarza(2, 0.0)
	var coronas := z.posiciones_de_coronas()
	_ok("hay dos coronas", coronas.size() > 1, "(%d)" % coronas.size())
	_ok("la zarza se siembra con vegetacion", z.columnas_en_pie() > 50,
		"(%d columnas)" % z.columnas_en_pie())
	_ok("nada se cae solo al sembrar", z.columnas_en_pie() == _todas(z),
		"(%d de %d)" % [z.columnas_en_pie(), _todas(z)])
	var enredos := 0
	for i in z._enganche.size():
		var mascara := 0
		for d in 4:
			if z._enganche[i] & (1 << d) != 0:
				mascara += 1
		if mascara >= 2:
			enredos += 1
	_ok("cada celda se agarra a alguna corona", enredos > 0,
		"(%d celdas con dos enganches o mas)" % enredos)


## Cuantas celdas con mas de `alto` metros de material hay dentro de un radio.
## El recorte se mira en la zona cortada y no en toda la zarza, porque alrededor
## hay celdas que el cabezal no ha tocado y que siguen tan altas como estaban.
func _altas_en(z: Zarza, centro: Vector2, radio: float, alto: float) -> int:
	var total := 0
	for i in z._alturas.size():
		if z._alturas[i] <= alto:
			continue
		if z._centro_de_celda(i).distance_to(centro) > radio:
			continue
		total += 1
	return total


## Cuantas celdas tienen algo de estructura, sin llegar a mirar alturas.
func _todas(z: Zarza) -> int:
	var total := 0
	for i in z._cana.size():
		if z._cana[i] == 1 and z._alturas[i] > Zarza.MIN_ALTURA:
			total += 1
	return total


func _prueba_corte_medio() -> void:
	print("== corte a media altura ==")
	var z := _zarza(1, 0.0)
	# El corte va encima de la mata, que es donde de verdad hay zarza. Cortar en
	# el centro geometrico no cortaria nada, porque las lomas se siembran al azar
	# y en el centro puede no caer ninguna.
	var mata := z.posiciones_de_coronas()[0]
	var antes := z.altura_total()
	var centro := z.to_global(Vector3(mata.x, 0.9, mata.y))
	var afectadas := z.cortar_en(centro, 1.4)
	_ok("el corte quita vegetacion de verdad", afectadas > 0, "(%d celdas)" % afectadas)
	_ok("en la franja cortada no queda nada por encima del cabezal",
		_altas_en(z, mata, 1.4, 0.95) == 0,
		"(%d celdas altas)" % _altas_en(z, mata, 1.4, 0.95))
	_ok("queda el palmo de abajo, que no se lleva la pasada entera",
		z.altura_total() < antes, "de %.1f a %.1f m" % [antes, z.altura_total()])
	_ok("la corona sigue viva: un corte alto no mata la raiz",
		z.coronas_en_pie() > 0, "(%d coronas)" % z.coronas_en_pie())


## La regla del jugador, tal cual: si el enganche de arriba es con otro anclaje
## al suelo, al cortarle el apoyo de una mata lo de arriba no desaparece.
func _prueba_dos_matas() -> void:
	print("== corte a la base de una mata con dos raices ==")
	var z := _zarza(2, 0.0)
	var coronas := z.posiciones_de_coronas()
	if coronas.size() < 2:
		_ok("hay dos coronas que atacar", false, "(%d)" % coronas.size())
		return
	var primera := coronas[0]
	var segunda := coronas[1]
	# Cuanta masa hay de cada lado de la linea que une las dos coronas. Es una
	# forma burda pero sin ambigüedad de contar "lo que se sostenia con la otra".
	var cerca_primera := 0
	var cerca_segunda := 0
	for i in z._alturas.size():
		if z._alturas[i] <= Zarza.MIN_ALTURA:
			continue
		var p := z._centro_de_celda(i)
		if p.distance_to(primera) <= p.distance_to(segunda):
			cerca_primera += 1
		else:
			cerca_segunda += 1
	print("   reparto: %d celdas del lado de A, %d del lado de B"
		% [cerca_primera, cerca_segunda])
	var en_pie_antes := z.columnas_en_pie()
	var coronas_antes := z.coronas_en_pie()
	# Corte a ras de suelo, encima de la primera corona, como quien baja el morro
	# a rematar la base.
	z.cortar_en(z.to_global(Vector3(primera.x, 0.05, primera.y)), 0.7)
	var en_pie_despues := z.columnas_en_pie()
	var queda_lado_b := 0
	for i in z._alturas.size():
		if z._alturas[i] <= Zarza.MIN_ALTURA:
			continue
		var p := z._centro_de_celda(i)
		if p.distance_to(segunda) < p.distance_to(primera):
			queda_lado_b += 1
	_ok("cortar la base de una mata tumba lo que se sostenia con ella",
		en_pie_despues < en_pie_antes, "de %d a %d columnas"
		% [en_pie_antes, en_pie_despues])
	_ok("la parte que se sostenia con la otra mata sigue en pie",
		queda_lado_b > 0, "(%d celdas siguen en pie del lado de B)" % queda_lado_b)
	_ok("la corona cortada ya no cuenta como viva",
		z.coronas_en_pie() < coronas_antes, "de %d a %d"
		% [coronas_antes, z.coronas_en_pie()])
	_ok("mientras quede una corona, la zarza no esta muerta",
		z.coronas_en_pie() > 0 and en_pie_despues > 0,
		"(%d coronas, %d columnas)" % [z.coronas_en_pie(), en_pie_despues])
	# Y al rematar la segunda, la zarza si queda limpia.
	z.cortar_en(z.to_global(Vector3(segunda.x, 0.05, segunda.y)), 0.7)
	_ok("sin coronas no queda nada en pie", z.columnas_en_pie() == 0,
		"(%d columnas)" % z.columnas_en_pie())


func _prueba_zarza_muerta() -> void:
	print("== sin material, sin trabajo ==")
	var z := _zarza(1, 0.0)
	var mata := z.posiciones_de_coronas()[0]
	z.cortar_en(z.to_global(Vector3(mata.x, 0.0, mata.y)), 0.2)
	var cortadas := z.cortar_en(z.to_global(Vector3(mata.x, 0.0, mata.y)), 0.2)
	_ok("cortar donde ya no hay nada no hace nada", cortadas == 0,
		"(%d celdas)" % cortadas)
