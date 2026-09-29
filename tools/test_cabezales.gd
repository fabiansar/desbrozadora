extends SceneTree

## La logica de los cabezales: eficacia, resistencia y lo que se nota de cada
## una.
##
##     godot --headless --path . --script tools/test_cabezales.gd
##
## Lo que se comprueba, en dos partes:
##
## **1. La tabla.** Que los cuatro cabezales tengan los numeros que dicen
## servir, y sobre todo que la tabla sea coherente como juego: subir de nivel no
## es mejor en todo, es comprar resistencia a cambio de perder velocidad en lo
## blando. Si alguien retoca un numero y rompe esa logica, esta prueba se
## entera antes de que se note jugando.
##
## **2. Que la eficacia se note en el tiempo.** Se corta una zarza de verdad con
## el presupuesto que le tocaria a cada cabezal y se mira cuanto se lleva en el
## mismo numero de fotogramas. Ojo con la tentacion de comparar "cuanto ha
## cortado" entre cabezales sin mas: el disco de tres puntas tiene mas radio que
## el nylon, asi que barre mas sitio y no se puede comparar. Aqui el radio es el
## mismo para todos y lo unico que cambia es el presupuesto, que es justo lo que
## se quiere medir.
##
## Y una tercera cosa que sale de paso, y que es la trampa de este cambio: la
## parte decimal del presupuesto. Un cabezal que puede quitar 100 celdas por
## segundo son 1,67 por fotograma, y sin guardar la parte decimal se cortaria
## una celda cada dos fotogramas: la mitad de la velocidad, sin que se note por
## donde.

var _correctas := 0
var _fallos := 0
const CABEZALES := {
	"hilo": preload("res://resources/cabezales/hilo.tres"),
	"serie": preload("res://resources/cabezales/serie.tres"),
	"disco_2p": preload("res://resources/cabezales/disco_2p.tres"),
	"disco_3p": preload("res://resources/cabezales/disco_3p.tres"),
}
## Hierba, maleza alta, zarza. Todo el archivo habla en estos tres numeros.
const HIERBA := 1
const MALEZA := 2
const ZARZA := 3
const DELTA := 1.0 / 60.0
## La base de corte de la zarza se lee de la planta, no se escribe aqui. Una
## copia de un numero dentro de un test es una copia que se queda vieja sin que
## nadie se entere.
var _base_zarza := 30.0
var base_hierba := 50.0


func _initialize() -> void:
	call_deferred("_ejecutar")


func _ejecutar() -> void:
	_tabla()
	_coherencia_del_juego()
	_tasa_de_corte()
	await _cabeza_de_zarza()

	print("\n-- resultado: %d correctas, %d fallos%s"
		% [_correctas, _fallos, "" if _fallos == 0 else "  <-- MIRAR"])
	quit(0 if _fallos == 0 else 1)


## 1. Los numeros de cada cabezal, tal cual.
func _tabla() -> void:
	print("== la tabla de cada cabezal ==")
	print("   cabezal             niv  ef: hier male zar  |  res: hier male zar")
	for nombre in ["hilo", "serie", "disco_2p", "disco_3p"]:
		var c: CabezalDesbrozadora = CABEZALES[nombre]
		print("   %-18s %2d      %d    %d    %d  |       %d    %d    %d" % [
			c.nombre, c.nivel,
			c.eficacia_de(HIERBA), c.eficacia_de(MALEZA), c.eficacia_de(ZARZA),
			c.resistencia_de(HIERBA), c.resistencia_de(MALEZA), c.resistencia_de(ZARZA)])

	var hilo: CabezalDesbrozadora = CABEZALES["hilo"]
	_ok("el nylon es de nivel 1", hilo.nivel == 1, "(%d)" % hilo.nivel)
	_ok("el nylon es el mas rapido con la hierba", hilo.eficacia_de(HIERBA) == 5,
		"(%d)" % hilo.eficacia_de(HIERBA))
	_ok("el nylon contra la maleza aguanta de regular", hilo.resistencia_de(MALEZA) == 3,
		"(%d)" % hilo.resistencia_de(MALEZA))
	_ok("el nylon contra la zarza aguanta lo justo", hilo.resistencia_de(ZARZA) == 5,
		"(%d)" % hilo.resistencia_de(ZARZA))
	_ok("pero contra la maleza y la zarza es el mas lento",
		hilo.eficacia_de(MALEZA) == 2 and hilo.eficacia_de(ZARZA) == 1,
		"(%d, %d)" % [hilo.eficacia_de(MALEZA), hilo.eficacia_de(ZARZA)])

	var serie: CabezalDesbrozadora = CABEZALES["serie"]
	_ok("la cuchilla de serie es intermedia", serie.nivel == 2
		and serie.eficacia_de(HIERBA) == 3 and serie.eficacia_de(MALEZA) == 3
		and serie.eficacia_de(ZARZA) == 3)

	var dos: CabezalDesbrozadora = CABEZALES["disco_2p"]
	_ok("el disco de dos puntas abre mas maleza que el nylon",
		dos.eficacia_de(MALEZA) > hilo.eficacia_de(MALEZA),
		"(%d > %d)" % [dos.eficacia_de(MALEZA), hilo.eficacia_de(MALEZA)])

	var tres: CabezalDesbrozadora = CABEZALES["disco_3p"]
	_ok("el disco de tres puntas es de nivel 3", tres.nivel == 3)
	_ok("y es el que mejor abre maleza y zarza",
		tres.eficacia_de(MALEZA) >= dos.eficacia_de(MALEZA)
		and tres.eficacia_de(ZARZA) >= dos.eficacia_de(ZARZA),
		"(%d, %d)" % [tres.eficacia_de(MALEZA), tres.eficacia_de(ZARZA)])


## Lo que hace que la tabla sea un juego y no una lista de numeros sueltos.
func _coherencia_del_juego() -> void:
	print("\n== la logica de subir de nivel ==")
	var hilo: CabezalDesbrozadora = CABEZALES["hilo"]
	var dos: CabezalDesbrozadora = CABEZALES["disco_2p"]
	var tres: CabezalDesbrozadora = CABEZALES["disco_3p"]

	# El gasto del filo y el frenado salen de la misma resistencia, y por eso
	# tienen que contar la misma historia.
	_ok("la resistencia decide cuanto se gasta el filo",
		is_equal_approx(hilo.desgaste_por_hoja_para(ZARZA),
			tres.desgaste_por_hoja_para(ZARZA) * 2.5),
		"(nylon %.2f, tres puntas %.2f)" % [
			hilo.desgaste_por_hoja_para(ZARZA), tres.desgaste_por_hoja_para(ZARZA)])
	_ok("y tambien cuanto frena el motor",
		is_equal_approx(hilo.frenado_para(ZARZA), 1.0)
		and tres.frenado_para(ZARZA) < 0.5,
		"(nylon %.2f, tres puntas %.2f)" % [
			hilo.frenado_para(ZARZA), tres.frenado_para(ZARZA)])

	# El trade-off: contra la maleza y la zarza, cada peldño es mejor que el
	# anterior. Si alguien sube un numero y rompe esta regla, el juego se
	# contradice a si mismo.
	for tipo in [MALEZA, ZARZA]:
		_ok("contra el tipo %d cada peldño aguanta mas que el anterior" % tipo,
			hilo.resistencia_de(tipo) > dos.resistencia_de(tipo)
			and dos.resistencia_de(tipo) > tres.resistencia_de(tipo),
			"(%d, %d, %d)" % [hilo.resistencia_de(tipo), dos.resistencia_de(tipo),
				tres.resistencia_de(tipo)])

	# Y el precio: el mejor cabezal para la maleza es el peor para la hierba. Si
	# algumun dia se tocaran esas cifras para que un cabezal ganase en todo, el
	# juego dejaria de ser una decision.
	_ok("el mejor con la maleza es el peor con la hierba",
		tres.eficacia_de(MALEZA) > hilo.eficacia_de(MALEZA)
		and tres.eficacia_de(HIERBA) < hilo.eficacia_de(HIERBA),
		"(maleza %d > %d, hierba %d < %d)" % [
			tres.eficacia_de(MALEZA), hilo.eficacia_de(MALEZA),
			tres.eficacia_de(HIERBA), hilo.eficacia_de(HIERBA)])
	_ok("la hierba es lo blando: nadie la aguanta mal",
		tres.resistencia_de(HIERBA) <= hilo.resistencia_de(HIERBA) + 1,
		"(%d, %d)" % [hilo.resistencia_de(HIERBA), tres.resistencia_de(HIERBA)])

	# Todo cabezal corta de todo. Antes habia una lista de "esto no lo puedes
	# cortar", y con el nylon puesto no se podia ni rozar la maleza, cuando el
	# nylon la abre de pena. La pregunta ahora no es si puede, sino cuanto.
	for nombre in CABEZALES:
		var c: CabezalDesbrozadora = CABEZALES[nombre]
		var todos := c.puede_cortar(HIERBA) and c.puede_cortar(MALEZA) \
			and c.puede_cortar(ZARZA)
		_ok("%s corta cualquier vegetacion" % c.nombre, todos)


## La eficacia se nota en el tiempo: mismo radio, mismo numero de fotogramas, y
## solo cambia el presupuesto.
func _tasa_de_corte() -> void:
	print("\n== la eficacia se nota en el tiempo ==")
	var hilo: CabezalDesbrozadora = CABEZALES["hilo"]
	var tres: CabezalDesbrozadora = CABEZALES["disco_3p"]
	# Las dos bases se LEEN de las plantas. Escribir el numero aqui seria volver a
	# meter una copia que se queda vieja: si alguien cambia la base en
	# vegetacion.gd, esta comprobacion seguiria diciendo 200 y no se enteraria
	# nadie de que el corte habia cambiado de escala.
	var hierba := Hierba.new()
	base_hierba = hierba.tasa_corte_base()
	hierba.free()
	var h3 := Hierba.new()
	h3.tipo = ZARZA
	_base_zarza = h3.tasa_corte_base()
	h3.free()
	# 50 hojas por segundo es un tercio de lo que se pisa andando (unos 150), asi
	# que con eficacia 1 no se llega. Si esta base sube de 150, la eficacia deja
	# de decidir nada y todos los cabezales se sienten igual.
	_ok("la base esta por debajo de lo que se pisa andando",
		base_hierba < 150.0, "(%.0f hojas/s)" % base_hierba)
	_ok("el nylon corre mas con la hierba",
		hilo.tasa_corte_para(HIERBA, base_hierba)
		> tres.tasa_corte_para(HIERBA, base_hierba),
		"(%.0f > %.0f hojas/s)" % [hilo.tasa_corte_para(HIERBA, base_hierba),
			tres.tasa_corte_para(HIERBA, base_hierba)])
	_ok("el disco de tres puntas corre mas con la maleza y la zarza",
		tres.tasa_corte_para(MALEZA, base_hierba) > hilo.tasa_corte_para(MALEZA, base_hierba)
		and tres.tasa_corte_para(ZARZA, _base_zarza) > hilo.tasa_corte_para(ZARZA, _base_zarza),
		"(maleza %.0f > %.0f, zarza %.0f > %.0f celdas/s)" % [
			tres.tasa_corte_para(MALEZA, base_hierba),
			hilo.tasa_corte_para(MALEZA, base_hierba),
			tres.tasa_corte_para(ZARZA, _base_zarza),
			hilo.tasa_corte_para(ZARZA, _base_zarza)])

## El presupuesto se respeta de verdad, y ahi esta la garantia de que un cabezal
## no se come la mata de una tacada.
##
## Ojo con como se mide la diferencia entre cabezales, que es donde esta la
## trampa: NO vale comparar "cuanto ha cortado en un segundo", porque el total no
## depende de la tasa. El disco se vacia igual de tiempo o de mas rapido, pero un
## segundo con el nylon y un segundo con un disco de tres puntas se llevan lo
## mismo, porque los dos llegan al final. Lo que cambia es **cuantos fotogramas
## hace falta para vaciarlo**, y eso es lo que se mide aqui.
func _cabeza_de_zarza() -> void:
	print("\n== cuantos fotogramas tarda cada cabezal en vaciar la misma pasada ==")
	var hilo: CabezalDesbrozadora = CABEZALES["hilo"]
	var dos: CabezalDesbrozadora = CABEZALES["disco_2p"]
	var tres: CabezalDesbrozadora = CABEZALES["disco_3p"]
	var base := _base_zarza
	print("   base del tier 3: %.0f hojas/s, presupuesto del nylon: %.2f por fotograma"
		% [base, hilo.tasa_corte_para(ZARZA, base) * DELTA])

	var primer_mordisco := await _mordisco(hilo.tasa_corte_para(ZARZA, base) * DELTA)
	_ok("el nylon no se come la mata de una tacada",
		primer_mordisco <= 4, "(%d hojas en el primer fotograma)" % primer_mordisco)

	var f_nylon := await _fotogramas_para_vaciar(hilo.tasa_corte_para(ZARZA, base) * DELTA)
	var f_dos := await _fotogramas_para_vaciar(dos.tasa_corte_para(ZARZA, base) * DELTA)
	var f_tres := await _fotogramas_para_vaciar(tres.tasa_corte_para(ZARZA, base) * DELTA)
	print("   nylon %d fotogramas | dos puntas %d | tres puntas %d"
		% [f_nylon, f_dos, f_tres])
	_ok("cada peldaño abre mas rapido el tier 3 que el anterior",
		f_tres < f_dos and f_dos < f_nylon, "(%d, %d, %d)" % [f_nylon, f_dos, f_tres])
	# Medido: con el reparto por sectores salen 19 fotogramas con el nylon y 10 con
	# el disco de tres puntas, o sea 1,9 veces, cuando la eficacia es de 1 contra 4.
	# No sale 4 porque los ocho sectores se vacian a la vez y manda el mas lento: el
	# reparto por sectores pone un suelo de granularidad, y con 2,5 hojas por
	# fotograma entre ocho sectores hay hasta tres fotogramas de espera en la cola.
	#
	# El umbral es 1,5 y no 1,0 porque lo que se quiere comprobar es que los niveles
	# se distinguen; a 1,0 pasarian todos los cabezales por el mismo, que es lo que
	# hay que cazar.
	_ok("el disco de tres puntas es mucho mas rapido que el nylon",
		f_nylon > f_tres * 1.5,
		"(%.1f veces: %d contra %d)" % [float(f_nylon) / maxf(float(f_tres), 1.0),
			f_nylon, f_tres])

	# La parte decimal, que es la trampa de este cambio. Con un ritmo de 100 hojas
	# por segundo son 1,67 por fotograma, y un presupuesto de 1,67 tiene que vaciar
	# el disco en menos fotogramas que uno de 1. Sin guardar la parte decimal,
	# int(1,67) es 1 y se pierde un 40 % de la velocidad sin que se note por donde:
	# el numero del recurso dice una cosa y el juego hace otra.
	var entero := await _fotogramas_para_vaciar(1.0)
	var decimal := await _fotogramas_para_vaciar(1.0 + 0.6667)
	print("   con 1,00 hoja por fotograma %d | con 1,67 %d" % [entero, decimal])
	_ok("un presupuesto de 1,67 va mas rapido que uno de 1 (la parte decimal se guarda)",
		decimal < entero, "(%d < %d)" % [decimal, entero])

	# Y sin presupuesto se corta todo de golpe, que es lo que necesitan la hoz y
	# las pruebas que miran la geometria del corte.
	var mata := await _tier3()
	var punto := mata.global_position + Vector3(0.0, 0.6, 0.0)
	var antes := mata.hojas_en_pie()
	var de_golpe := mata.cortar(punto, 1.0, -1.0)
	_ok("sin presupuesto el corte sigue siendo de una tacada",
		de_golpe > 0 and mata.hojas_en_pie() < antes,
		"(%d hojas, %d -> %d en pie)" % [de_golpe, antes, mata.hojas_en_pie()])
	_ok("y un presupuesto de cero no corta nada", mata.cortar(punto, 1.0, 0.0) == 0)
	mata.queue_free()
	await process_frame


## Cuantas hojas se quitan en el PRIMER fotograma. Es donde se nota si el
## presupuesto se respeta de verdad: si el cabezal se come el disco entero, el
## presupuesto no se esta aplicando y da igual lo que digan los numeros.
func _mordisco(presupuesto: float) -> int:
	var mata := await _tier3()
	var cortadas := mata.cortar(mata.global_position + Vector3(0.0, 0.6, 0.0), 1.0,
		presupuesto)
	mata.queue_free()
	return cortadas


## Fotogramas que tarda el cabezal en vaciar la pasada. Se mide con matas
## nuevas cada vez, todas con la misma semilla, para que sea mata contra mata.
##
## Ojo con el final: se para cuando **deja de cambiar el material cortado**, no
## cuando el numero de hojas enteras se queda quieto.
##
## Con un presupuesto de media hoja por fotograma hay fotogramas que dan cero por
## redondeo, asi que parar en el primero parece que la pasada se acabo enseguida.
## Y como una hoja se queda ahora A MEDIAS (el borde del claro se deshace en varios
## pasos, para que no salga un circulo con tijeras), contar hojas enteras se queda
## quieto antes de que se haya terminado: con el criterio viejo, el nylon y el disco
## de dos puntas salian a 26 fotogramas los dos, y el budget de 1,67 salia mas
## lento que el de 1.0. Los tres median ruido.
func _fotogramas_para_vaciar(presupuesto: float) -> int:
	var mata := await _tier3()
	var punto := mata.global_position + Vector3(0.0, 0.6, 0.0)
	var fotogramas := 0
	var quieto := 0
	var anterior := mata.material_cortado()
	var empezo := false
	while fotogramas < 400 and quieto < 8:
		fotogramas += 1
		mata.cortar(punto, 1.0, presupuesto)
		var ahora := mata.material_cortado()
		if ahora > anterior:
			empezo = true
		# Y no se puede dar por terminada una pasada que no ha empezado. El total
		# arranca en cero, y con el nylon (media hoja por fotograma) hay
		# fotogramas en los que no pasa nada: sin este guardia la cuenta se
		# acababa en ocho fotogramas para todos los cabezales, que es ruido puro.
		if empezo:
			quieto = quieto + 1 if ahora >= anterior else 0
		anterior = ahora
	mata.queue_free()
	return fotogramas


## Una mata de tier 3 (zarza) montada en el arbol. Es la misma hoja que el
## cesped con otros numeros: no hay ningun codigo de zarza, y por eso esta prueba
## no necesita la clase que se borro.
func _tier3() -> Hierba:
	var h := Hierba.new()
	h.tipo = 3
	h.radio = 9.0
	h.densidad = 60.0
	h.altura = 2.4
	h.semilla = 4242
	root.add_child(h)
	await process_frame
	return h


func _ok(que: String, condicion: bool, detalle: String = "") -> void:
	if condicion:
		_correctas += 1
		print("  OK   %s" % que)
	else:
		_fallos += 1
		print("  FAIL %s %s" % [que, detalle])
