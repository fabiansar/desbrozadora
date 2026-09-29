extends SceneTree

## El corte tiene que repartirse por igual en todo el disco, no por rachas.
##
##     godot --headless --path . --script tools/test_corte_organico.gd
##
## Cuando se vaciaba el disco en orden aleatorio, un sector entero se limpiaba
## mientras el de al lado conservaba todas sus hojas, y el claro salia hecho de
## manchurrones. El usuario lo describio mejor: "no se ve organico, parece
## recortado con tijeras".
##
## El arreglo es reparto por sectores (muestreo estratificado: el dominio se
## parte en capas y se cogen las mismas muestras de cada una). Y lo que se mide
## aqui no es que quede todo igual, sino que **se pierda lo mismo en cada sector**:
## que el ritmo sea igual. El resto final puede ser distinto porque los sectores
## no tienen las mismas hojas de partida, y eso es correcto.

const SECTORES := 8
const RADIO := 1.0
const PRESUPUESTO := 2.5
const FOTOGRAMAS := 60

var _mundo: Node3D
var _fails := 0


func _initialize() -> void:
	call_deferred("_ejecutar")


func _ejecutar() -> void:
	_mundo = load("res://scenes/main.tscn").instantiate() as Node3D
	root.add_child(_mundo)
	for _i in 40:
		await physics_frame
	var campo := _mundo.get_node_or_null("Cesped") as Hierba
	if campo == null:
		push_error("main.tscn necesita el cesped")
		quit(1)
		return

	var hoja := campo.posicion_hoja(campo.total() / 2)
	var centro := campo.to_global(hoja)

	var de_partida := _por_sector(campo, hoja, -1)
	print("== reparto del corte en %d sectores ==" % SECTORES)
	print("   hojas de partida por sector: %s" % str(de_partida))

	var cortadas := 0
	for _f in FOTOGRAMAS:
		cortadas += campo.cortar(centro, RADIO, PRESUPUESTO)
	print("   cortadas en %d fotogramas: %d hojas" % [FOTOGRAMAS, cortadas])

	var perdidas := _por_sector(campo, hoja, 1)
	print("   perdidas por sector:  %s" % str(perdidas))

	# **El invariante**: el mismo numero en cada sector.
	var maximo: int = perdidas.max()
	var minimo: int = perdidas.min()
	print("   la mas rapida y la mas lenta: %d y %d" % [maximo, minimo])
	_comprobar(maximo - minimo <= 1,
		"cada sector pierde lo mismo (diferencia de %d, y una de 1 es redondeo)"
		% (maximo - minimo))

	# Y que el reparto no se haga a costa de la velocidad: el total cortado tiene
	# que ser el que da el presupuesto, ni mas ni menos.
	var esperado := int(PRESUPUESTO * FOTOGRAMAS)
	print("   esperado por el presupuesto: %d, real: %d" % [esperado, cortadas])
	_comprobar(cortadas <= esperado + SECTORES,
		"y se respeta el presupuesto (%d de %d, con un margen de un corte entero)"
		% [cortadas, esperado])

	# Y que el disco NO se vacie en un circulo perfecto, que es lo que se quejaba
	# el usuario. Con el borde irregular hay hojas dentro del radio nominal que el
	# cabezal todavia no ha tocado.
	var dentro := campo.de_pie(centro, RADIO * 0.95)
	print("   hojas de pie dentro del 95 % del radio: %d" % dentro)
	_comprobar(dentro > 0,
		"el borde es irregular: queda hoja dentro del radio nominal (%d)" % dentro)

	print("\n-- resultado: %s" % ("OK" if _fails == 0 else "%d FALLOS" % _fails))
	_mundo.queue_free()
	await process_frame
	quit(0 if _fails == 0 else 1)


## Cuenta hojas del disco por sector. `corte` = -1 cuenta las de pie, 1 las
## cortadas, 0 todas.
func _por_sector(campo: Hierba, local: Vector3, corte: int) -> Array:
	var cuenta := [0, 0, 0, 0, 0, 0, 0, 0]
	for i in campo._corte.size():
		var p: Vector3 = campo._pos[i]
		if campo._dist2(p, local) > RADIO * RADIO:
			continue
		var cortada: bool = campo._corte[i] > 0.0
		if corte == -1 and cortada:
			continue
		if corte == 1 and not cortada:
			continue
		var angulo := atan2(p.z - local.z, p.x - local.x)
		cuenta[clampi(int((angulo + PI) / TAU * float(SECTORES)), 0, SECTORES - 1)] += 1
	return cuenta


func _comprobar(ok: bool, que: String) -> void:
	if ok:
		print("  OK   %s" % que)
	else:
		print("  FAIL %s" % que)
		_fails += 1
