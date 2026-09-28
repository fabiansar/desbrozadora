class_name Aldea
extends Node3D

class Parcela extends RefCounted:
    var id := 0
    var fila := 0
    var columna := 0
    var centro := Vector2.ZERO
    var centro_casa := Vector2.ZERO
    var giro := 0.0
    var largo := 0.0
    var ancho := 0.0

    func contiene(p: Vector2) -> bool:
        var eje := Vector2(cos(giro), sin(giro))
        var normal := Vector2(-sin(giro), cos(giro))
        var delta := p - centro
        return absf(delta.dot(eje)) <= largo * 0.5 \
            and absf(delta.dot(normal)) <= ancho * 0.5


class ZonaOcupada extends RefCounted:
    var centro := Vector2.ZERO
    var tamano := Vector2.ZERO
    var giro := 0.0

    func contiene(p: Vector2) -> bool:
        var eje := Vector2(cos(giro), sin(giro))
        var normal := Vector2(-sin(giro), cos(giro))
        var delta := p - centro
        return absf(delta.dot(eje)) <= tamano.x * 0.5 \
            and absf(delta.dot(normal)) <= tamano.y * 0.5


## Colocador modular de la aldea.
##
## Este nodo no genera geometria. Solo calcula parcelas, carretera y puntos de
## plantacion, e instancia los modelos que existan en el catalogo de Blender.
## Los huecos del catalogo se dejan como Node3D para poder probar el layout
## antes de recibir los .glb definitivos.

@export var terreno: Terreno
@export var origen := Vector2(0.0, 0.0)
@export var giro := 0.0
@export_range(1, 12) var columnas := 4
@export_range(1, 12) var filas := 3
@export var largo_parcela := 15.0
@export var ancho_parcela := 12.0
@export_range(0, 11) var calle_fila := 1
@export var ancho_camino := 4.0
@export var semilla := 20260927

@export_category("Catalogo de modelos")
@export var casas: Array[String] = [
    "res://assets/models/aldea/casa_1.glb",
    "res://assets/models/aldea/casa_2.glb",
    "res://assets/models/aldea/casa_3.glb",
]
@export var arboles: Array[String] = [
    "res://assets/models/aldea/arbol_1.glb",
    "res://assets/models/aldea/arbol_2.glb",
]
@export var arbustos: Array[String] = [
    "res://assets/models/aldea/arbusto_1.glb",
    "res://assets/models/aldea/arbusto_2.glb",
]
@export var muros: Array[String] = [
    "res://assets/models/aldea/muro_recto.glb",
    "res://assets/models/aldea/muro_esquina.glb",
]
@export var caminos: Array[String] = [
    "res://assets/models/aldea/carretera_recta.glb",
    "res://assets/models/aldea/carretera_cruce.glb",
]

var _parcelas: Array[Parcela] = []
var _ocupaciones: Array[ZonaOcupada] = []
var _rng := RandomNumberGenerator.new()
var punto_inicio_furgoneta: Marker3D


func _ready() -> void:
    if terreno == null:
        terreno = get_parent().get_node_or_null("Terreno") as Terreno
    if terreno == null:
        push_error("Aldea: hace falta el terreno")
        return
    _rng.seed = semilla
    _crear_parcelas()
    _colocar_carretera()
    _colocar_parcelas()
    print("Aldea modular: %d parcelas, %d modelos disponibles" % [_parcelas.size(), _modelos_disponibles()])


func _crear_parcelas() -> void:
    _parcelas.clear()
    var eje := Vector2(cos(giro), sin(giro))
    var normal := Vector2(-sin(giro), cos(giro))
    var centro_bloque := origen - eje * columnas * largo_parcela * 0.5 \
        - normal * filas * ancho_parcela * 0.5
    var id := 0
    for fila in filas:
        for columna in columnas:
            var centro := centro_bloque \
                + eje * ((float(columna) + 0.5) * largo_parcela) \
                + normal * ((float(fila) + 0.5) * ancho_parcela)
            var parcela := Parcela.new()
            parcela.id = id
            parcela.fila = fila
            parcela.columna = columna
            parcela.centro = centro
            parcela.centro_casa = centro + normal * 2.0
            parcela.giro = giro
            parcela.largo = largo_parcela
            parcela.ancho = ancho_parcela
            _parcelas.append(parcela)
            id += 1


func _colocar_carretera() -> void:
    var eje := Vector2(cos(giro), sin(giro))
    var normal := Vector2(-sin(giro), cos(giro))
    var inicio := origen - eje * (columnas * largo_parcela * 0.5 + largo_parcela)
    var total := columnas * largo_parcela + largo_parcela * 2.0
    var segmentos := maxi(1, columnas + 2)
    for i in segmentos:
        var a := inicio + eje * (total * float(i) / segmentos) + normal * _fila_offset()
        var b := inicio + eje * (total * float(i + 1) / segmentos) + normal * _fila_offset()
        var punto := a.lerp(b, 0.5)
        _instanciar(caminos, 0, punto, giro, "CaminoRecto_%02d" % i)
        _ocupar(punto, Vector2(a.distance_to(b), ancho_camino), giro)
    var cruce := origen + normal * _fila_offset()
    _instanciar(caminos, 1, cruce, giro, "CaminoCruce")
    _ocupar(cruce, Vector2(ancho_camino, ancho_camino), giro)
    punto_inicio_furgoneta = Marker3D.new()
    punto_inicio_furgoneta.name = "PuntoInicioFurgoneta"
    punto_inicio_furgoneta.position = Vector3(inicio.x, terreno.cota_en(inicio), inicio.y)
    punto_inicio_furgoneta.rotation.y = giro
    add_child(punto_inicio_furgoneta)


func _colocar_parcelas() -> void:
    var eje := Vector2(cos(giro), sin(giro))
    var normal := Vector2(-sin(giro), cos(giro))
    for parcela in _parcelas:
        var centro := parcela.centro
        var rot := parcela.giro
        var id := parcela.id
        var casa := parcela.centro_casa
        _instanciar(casas, id % maxi(1, casas.size()), casa, rot,
            "Casa_%02d" % id)
        _ocupar(casa, Vector2(6.0, 5.0), rot)
        _colocar_muros(parcela, eje, normal)
        var giro_arbol := rot + _rng.randf_range(-0.25, 0.25)
        _instanciar(arboles, id % maxi(1, arboles.size()),
            centro - eje * (largo_parcela * 0.32) + normal * (ancho_parcela * 0.25),
            giro_arbol,
            "Arbol_%02d" % id)
        _instanciar(arbustos, id % maxi(1, arbustos.size()),
            centro + eje * (largo_parcela * 0.28) - normal * (ancho_parcela * 0.28),
            rot + _rng.randf_range(-0.25, 0.25),
            "Arbusto_%02d" % id)


func _colocar_muros(parcela: Parcela, eje: Vector2, normal: Vector2) -> void:
    var centro := parcela.centro
    var mitad_largo := parcela.largo * 0.5
    var mitad_ancho := parcela.ancho * 0.5
    var id := parcela.id
    var esquinas := [
        centro - eje * mitad_largo - normal * mitad_ancho,
        centro + eje * mitad_largo - normal * mitad_ancho,
        centro + eje * mitad_largo + normal * mitad_ancho,
        centro - eje * mitad_largo + normal * mitad_ancho,
    ]
    for lado in 4:
        var a: Vector2 = esquinas[lado]
        var b: Vector2 = esquinas[(lado + 1) % 4]
        var punto := a.lerp(b, 0.5)
        var rot := atan2(b.y - a.y, b.x - a.x)
        _instanciar(muros, 0, punto, rot, "Muro_%02d_%d" % [id, lado],
            Vector3(a.distance_to(b), 1.0, 1.0))
        _instanciar(muros, 1, a, rot, "Esquina_%02d_%d" % [id, lado])


func _fila_offset() -> float:
    return (float(calle_fila) + 0.5 - float(filas) * 0.5) * ancho_parcela


func _ocupar(p: Vector2, tam: Vector2, rot: float) -> void:
    var zona := ZonaOcupada.new()
    zona.centro = p
    zona.tamano = tam
    zona.giro = rot
    _ocupaciones.append(zona)


func _instanciar(catalogo: Array[String], indice: int, p: Vector2, rot: float,
        nombre: String, escala := Vector3.ONE) -> Node3D:
    var nodo: Node3D
    if not catalogo.is_empty() and indice >= 0 and indice < catalogo.size() \
            and ResourceLoader.exists(catalogo[indice]):
        var escena := load(catalogo[indice]) as PackedScene
        if escena != null:
            nodo = escena.instantiate() as Node3D
    if nodo == null:
        nodo = Node3D.new()
        nodo.set_meta("placeholder", true)
        nodo.set_meta("asset_path", catalogo[indice] if not catalogo.is_empty() else "")
    nodo.name = nombre
    nodo.position = Vector3(p.x, terreno.cota_en(p), p.y)
    nodo.rotation.y = rot
    nodo.scale = escala
    add_child(nodo)
    return nodo


func _modelos_disponibles() -> int:
    var total := 0
    for catalogo in [casas, arboles, arbustos, muros, caminos]:
        for ruta in catalogo:
            if ResourceLoader.exists(ruta):
                total += 1
    return total


## API usada por Hierba y Bosque para no sembrar dentro de una parcela.
func dentro(p: Vector2) -> bool:
    for parcela in _parcelas:
        if parcela.contiene(p):
            return true
    return false


## Zonas ocupadas por casa o carretera. La hierba usa esta consulta, mientras
## que Bosque.dentro() sigue excluyendo la parcela completa.
func ocupada(p: Vector2) -> bool:
    for ocupacion in _ocupaciones:
        if ocupacion.contiene(p):
            return true
    return false


## Total de parcelas y consulta estable para futuros encargos por identificador.
func numero_parcelas() -> int:
    return _parcelas.size()


func parcela_por_id(id: int) -> Parcela:
    if id < 0 or id >= _parcelas.size():
        return null
    return _parcelas[id]
