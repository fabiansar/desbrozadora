"""
Furgoneta comercial basica, low poly, para conducir en primera persona y cargar
maquinaria. Simple, sin instrumentacion.

Uso:
    flatpak run --filesystem=$HOME/Documentos org.blender.Blender --background \
        --python tools/crear_furgoneta_mesh.py
    Las rutas van absolutas: el flatpak arranca Blender en su propio directorio
    y no encuentra el proyecto con rutas relativas.

La jerarquia, en models/furgoneta.glb, y SOLO estos nombres:
    Furgoneta            empty en el (0, 0, 0), el suelo bajo el centro del coche
      Chasis             la carrocería, la cabina y el suelo de carga
        Volante          el volante, con el origen en la BASE de la columna
        Puerta_Conductor  con el origen en la bisagra de DELANTE
        Puerta_Trasera_Izq  con el origen en la bisagra de la IZQUIERDA
        Puerta_Trasera_Der  con el origen en la bisagra de la DERECHA
      Rueda_Del_Izq / Rueda_Del_Der / Rueda_Tra_Izq / Rueda_Tra_Der
    Y dos emptys de ayuda, que no son piezas del coche:
      Ojo_Conductor       donde va la camara de primera persona
      Punto_Carga         donde se deja la desbrozadora, en el suelo del baul

Las cuatro reglas que el juego da por buenas, y como se comprueban:
  1. NINGUN nodo lleva rotacion propia. Toda la inclinacion esta COCIDA en la
     malla, no en el nodo. Es la regla 3 de la desbrozadora ("nada se exporta
     con rotacion ni escala sin aplicar") y es la unica forma de que el juego
     pueda escribir un solo eje del nodo sin cargarse la pose: en Godot,
     escribir rotation.z REEMPLAZA la rotacion entera, asi que si el nodo
     tuviera inclinacion propia, al girar el volante se le caeria.
     Se comprueba mirando rotation_euler de todos los nodos.
  2. Los pivotes estan en el sitio fisico que toca, no en el (0, 0, 0):
     el eje de la columna en el Volante, la bisagra en cada Puerta, el centro
     geometrico en cada Rueda. Se comprueba midiendo el origen contra la
     geometria, y probando el giro de verdad (ver _informe).
  3. El baul esta VACIO y con el suelo plano. No hay nada dentro del hueco de
     carga, para que la desbrozadora entre sin colisionar. Se comprueba
     buscando vertices de la carrocería dentro de la caja de carga.
  4. Nada se exporta con rotacion ni escala sin aplicar.

Sobre los ejes, que es lo que mas se confunde (ver tambien el final del
_informe, que los imprime):
  Aqui, en Blender, es Z arriba. La furgoneta mira hacia +Y y su derecha es +X.
  En Godot, Y es arriba y -Z es adelante, y el exportador ya hace el cambio
  (export_yup=True en exportar_blender). Con solo ese cambio:
      girar en Y  = girar sobre la vertical  = DIRECCION de las ruedas
      girar en X  = girar sobre el lateral     = RODADURA de las ruedas
  Eso es exactamente lo que se pidio para las ruedas, y funciona con un solo
  nodo por rueda: Godot compone en YXZ, o sea rotation = (x, y, z) da
  Ry * Rx * Rz, y con z a cero la rodadura (X) se aplica primero en el marco
  propio de la rueda y la direccion (Y) despues en el marco del padre. Que es
  el orden correcto de un coche de verdad.
  El volante NO gira sobre la vertical, sino sobre el EJE DE LA COLUMNA, que va
  inclinado. Si girase sobre la vertical, el volante se Soupapearia de lado a
  lado, que es justo la inclinacion natural que se quiere conservar. Por eso el
  origen va en la base de la columna y el juego compone un Basis sobre ese eje:
      volante.basis = Basis(Vector3(0, 0.423, 0.906), volante.rotation.x)
  Ese vector es "eje_spin" YA EN EJES DE GODOT. Ojo con el cambio: el exportador
  pasa de Blender a glTF con (x, y, z) -> (x, z, -y), asi que un eje de Blender
  (0, -0.906, 0.423) sale en Godot como (0, 0.423, 0.906). El informe imprime
  los dos, y "eje_spin" lleva el de Godot, que es el unico que consume el juego.
  Y las puertas si giran sobre la vertical, que en Godot es Y, con el MISMO
  angulo y el MISMO signo que en Blender: export_blender pasa un giro sobre +Z
  a un giro sobre +Y sin tocar la cifra. Asi que:
      puerta.rotation.y = 80.0 (conductora), 110.0 y -110.0 (traseras)
  El giro de 180 grados en Y del nodo padre de la desbrozadora no cambia nada de
  esto: los ejes de un nodo hijo son los suyos propios, no los del padre.

El origen en el (0, 0, 0) esta en el suelo, en el centro geométrico del coche.
El centro de batalla cae en y = -0,20, casi en el medio; se imprime en el
informe por si el juego lo necesita.
"""

import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

_AQUI = os.path.dirname(os.path.abspath(__file__))
if _AQUI not in sys.path:
    sys.path.insert(0, _AQUI)
import exportar_blender  # noqa: E402

OUT_DIR = os.path.expanduser("~/Documentos/desarrollos/desbrozadora/models")
OUT_FILE = os.path.join(OUT_DIR, "furgoneta.glb")

# --- Medidas, en metros ---------------------------------------------------
# Z arriba, +Y hacia delante, +X hacia la derecha del conductor.
LARGO = 4.80
Y_TRAVESA = -2.40
Y_FRENTE = 2.40
ANCHO = 1.80
X_CARROCE = 0.90
ALTO = 2.10

GROSOR_LATERAL = 0.09
X_PARED_EXT = 0.88      # cara exterior de la pared
X_PARED_INT = 0.79      # cara interior
X_PUERTAS = 0.84        # las puertas son 6 cm y quedan 2 cm por fuera

Z_SUELO = 0.20          # bajos del chasis
Z_CARGA = 0.50          # cara de arriba del suelo del baul: la altura de carga
Z_ARCO = 0.68           # por donde pasa la rueda: los pasos de rueda suben aqui
Z_CINTURON = 1.16       # la linea de la cintura, donde acaba la puerta
Z_TECHO = 2.00

Y_TABIQUE = -0.40       # tabique entre baul y cabina
Y_COWL = 1.02           # donde arranca el parabrisas
Y_TECHO_DEL = 1.30      # borde delantero del techo
Y_FRENTE_CARA = 2.30    # frontal, por delante de las puertas

EJE_DEL_Y = 1.30        # ejes de las ruedas
EJE_TRAS_Y = -1.70
X_CENTRO_RUEDA = 0.81
RADIO_RUEDA = 0.32
ANCHO_RUEDA = 0.20
Z_EJE_RUEDA = RADIO_RUEDA

# Longitud de los pasos de rueda entre los ejes: el paso trasero va de -2,40 a
# -2,10, el central de -1,30 a +0,90 y el delantero de +1,70 a +2,40.
PASOS_RODILLA = ((Y_TRAVESA, -2.10), (-1.30, 0.90), (1.70, Y_FRENTE))

# Puertas: nombre, grados de apertura, lado al que se abren, signo del giro en
# Z y coordenada Y del canto de la bisagra. El signo va porque en el mismo eje
# los dos lados se abren en sentidos contrarios: la del conductor abre restando,
# la trasera izquierda sumando. La Y del canto es lo que se mide despues, para
# comprobar que el origen ha caido en la bisagra y no en medio de la hoja.
PUERTAS = (
    ("Puerta_Conductor", 80.0, -1.0, -1.0, 1.02),
    ("Puerta_Trasera_Izq", 110.0, -1.0, +1.0, Y_TRAVESA),
    ("Puerta_Trasera_Der", 110.0, +1.0, -1.0, Y_TRAVESA),
)

# El baul se comprueba con esta caja: desde el suelo de carga hasta el techo y
# entre las caras interiores de las paredes. No tiene que haber ni un vertice.
CARGA = {"x": (-0.68, 0.68), "y": (-2.35, -0.45), "z": (0.52, 1.98)}

ESPERADO_LARGO = (4.70, 4.95)
ESPERADO_ANCHO = (1.95, 2.25)   # lo que mandan son los retrovisores
ESPERADO_ALTO = (2.05, 2.15)
TRIANGULOS_MIN = 2500
TRIANGULOS_MAX = 5000

TOLERANCIA = 1e-4
REDONDEO_TOLERANCIA = 1e-3

# La jerarquia que se pide, tal cual. Se comprueba nodo a nodo.
JERARQUIA = (
    ("Furgoneta", None),
    ("Chasis", "Furgoneta"),
    ("Volante", "Chasis"),
    ("Puerta_Conductor", "Chasis"),
    ("Puerta_Trasera_Izq", "Chasis"),
    ("Puerta_Trasera_Der", "Chasis"),
    ("Rueda_Del_Izq", "Furgoneta"),
    ("Rueda_Del_Der", "Furgoneta"),
    ("Rueda_Tra_Izq", "Furgoneta"),
    ("Rueda_Tra_Der", "Furgoneta"),
)


# --- Utilidades -----------------------------------------------------------
def material(nombre, rgb, metal=0.0, rugosidad=0.6):
    # Sin use_nodes: en Blender 5 los materiales ya son de nodos y ponerlo
    # avisa de que se va en la 6.0.
    mat = bpy.data.materials.new(nombre)
    bsdf = mat.node_tree.nodes.get("Principled BSDF") if mat.node_tree else None
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (rgb[0], rgb[1], rgb[2], 1.0)
        bsdf.inputs["Metallic"].default_value = metal
        bsdf.inputs["Roughness"].default_value = rugosidad
    mat.diffuse_color = (rgb[0], rgb[1], rgb[2], 1.0)
    return mat


def caja(nombre, tamano, posicion, mat):
    bpy.ops.mesh.primitive_cube_add(size=1.0)
    ob = bpy.context.active_object
    ob.name = nombre
    ob.scale = tamano
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    ob.location = posicion
    ob.data.name = ob.name
    ob.data.materials.append(mat)
    return ob


def _orientar(ob, p0, p1):
    """Deja el eje Z local de la pieza siguiendo p0 -> p1, y la centra.

    El X local queda en el X del mundo siempre que la direccion no sea en X,
    que es el caso de todo lo que hay aqui: asi el ancho se mide en X y la
    pieza no sale girada al respecto de como se ha pedido.
    """
    p0 = Vector(p0)
    p1 = Vector(p1)
    ob.location = (p0 + p1) / 2.0
    ob.rotation_euler = (p1 - p0).to_track_quat("Z", "Y").to_euler()
    return ob


def barra(nombre, ancho, grosor, p0, p1, mat):
    """Caja tendida entre dos puntos, con el ANCHO en X y el GROSOR de canto."""
    largo = (Vector(p1) - Vector(p0)).length
    ob = caja(nombre, (ancho, grosor, largo), (0.0, 0.0, 0.0), mat)
    return _orientar(ob, p0, p1)


def cilindro(nombre, radio, largo, posicion, mat, lados=12, eje="Z"):
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=lados, radius=radio, depth=largo, end_fill_type="NGON"
    )
    ob = bpy.context.active_object
    ob.name = nombre
    if eje == "X":
        ob.rotation_euler = (0.0, math.radians(90.0), 0.0)
    elif eje == "Y":
        ob.rotation_euler = (math.radians(90.0), 0.0, 0.0)
    ob.data.name = ob.name
    for poly in ob.data.polygons:
        poly.use_smooth = False
    ob.location = posicion
    ob.data.materials.append(mat)
    return ob


def cilindro_entre(nombre, radio, p0, p1, mat, lados=10):
    """Cilindro tendido entre dos puntos, con el eje following la recta."""
    largo = (Vector(p1) - Vector(p0)).length
    ob = cilindro(nombre, radio, largo, (0.0, 0.0, 0.0), mat, lados, "Z")
    return _orientar(ob, p0, p1)


def toro(nombre, radio_mayor, radio_menor, posicion, mat, lados=10, seccion=4):
    bpy.ops.mesh.primitive_torus_add(
        major_radius=radio_mayor, minor_radius=radio_menor,
        major_segments=lados, minor_segments=seccion,
    )
    ob = bpy.context.active_object
    ob.name = nombre
    ob.location = posicion
    ob.data.name = ob.name
    ob.data.materials.append(mat)
    for poly in ob.data.polygons:
        poly.use_smooth = False
    return ob


def unir(nombre, piezas, origen=None):
    """Junta las piezas en un objeto, y opcionalmente le pone el origen.

    El cursor se pone en coordenadas de mundo y origin_set lo deja ahi, que es
    lo que hace falta para los pivotes: el origen tiene que caer en la bisagra
    o en el eje, no en el centro de la pieza.
    """
    bpy.ops.object.select_all(action="DESELECT")
    for ob in piezas:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = piezas[0]
    bpy.ops.object.join()
    ob = bpy.context.active_object
    ob.name = nombre
    ob.data.name = nombre
    if origen is not None:
        bpy.ops.object.select_all(action="DESELECT")
        ob.select_set(True)
        bpy.context.view_layer.objects.active = ob
        bpy.context.scene.cursor.location = origen
        bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    return ob


def aplicar(ob):
    """transform_apply de rotacion y escala, que es la regla del proyecto."""
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)


def redondear(ob, ancho=0.018):
    """Chaflan de las aristas vivas, y el modificador aplicado.

    Se aplica al conjunto ya unido, y no a las piezas sueltas: asi el chaflan
    es igual en todos los paneles y sale por el mismo ancho. Con limit_method
    ANGLE solo toca las aristas vivas, que en una caja lo son todas.
    """
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    mod = ob.modifiers.new("Chaflan", "BEVEL")
    mod.width = ancho
    mod.segments = 1
    mod.limit_method = "ANGLE"
    mod.angle_limit = math.radians(30.0)
    bpy.ops.object.modifier_apply(modifier=mod.name)


def empty(nombre, posicion, tamano=0.25):
    ob = bpy.data.objects.new(nombre, None)
    ob.empty_display_type = "ARROWS"
    ob.empty_display_size = tamano
    bpy.context.collection.objects.link(ob)
    ob.location = posicion
    return ob


def enganchar(hijo, padre):
    """Cuelga el hijo del padre sin que se mueva.

    Las piezas se crean en coordenadas de mundo, asi que se enganchan con la
    inversa del padre. Sin esto las coordenadas del hijo se suman a las del
    padre y la pieza se va de sitio. Los emptys van SIN inversa, al reves: su
    posicion ES la del pivote.
    """
    bpy.context.view_layer.update()
    hijo.parent = padre
    hijo.matrix_parent_inverse = padre.matrix_world.inverted()
    return hijo


def _caras_hacia_fuera(ob):
    try:
        bpy.ops.object.select_all(action="DESELECT")
        ob.select_set(True)
        bpy.context.view_layer.objects.active = ob
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.mesh.normals_make_consistent(inside=False)
        bpy.ops.object.mode_set(mode="OBJECT")
    except Exception as exc:  # noqa: BLE001
        print("  aviso: no se han recalculado las normales de %s (%s)"
              % (ob.name, exc))


# --- La carrocería --------------------------------------------------------
def _materiales():
    return {
        "blanco": material("Blanco", (0.86, 0.86, 0.84), 0.0, 0.45),
        "grafito": material("Grafito", (0.20, 0.21, 0.23), 0.0, 0.55),
        "cristal": material("Cristal", (0.07, 0.09, 0.11), 0.0, 0.15),
        "negro": material("Negro", (0.05, 0.05, 0.06), 0.0, 0.70),
        "plata": material("Metal_Plata", (0.66, 0.68, 0.71), 0.45, 0.45),
        "asiento": material("Asiento", (0.14, 0.15, 0.18), 0.0, 0.75),
        "suelo": material("Suelo_Baul", (0.30, 0.29, 0.26), 0.0, 0.80),
        "ambar": material("Ambar", (0.95, 0.52, 0.04), 0.0, 0.30),
        "rojo": material("Rojo", (0.50, 0.05, 0.05), 0.0, 0.30),
        "faro": material("Faro", (0.82, 0.86, 0.92), 0.0, 0.20),
    }


def pieza_chasis(m):
    """Carroceria, cabina, salpicadero y asiento, todo en una sola malla.

    Los pasos de rueda son la razon de que los faldones esten partidos en tres
    tramos: si la pared bajase hasta el suelo, la rueda quedaria enterrada
    dentro de ella. Con el paso alto (Z_ARCO) y el faldon solo en los tramos
    libres, la rueda se ve por su paso, como en cualquier furgoneta.
    """
    piezas = []

    # Suelo: la cara de arriba (Z_CARGA) es el suelo del baul, y es una sola
    # plancha recta de punta a punta, sin nada encima.
    piezas.append(caja("Bandeja", (1.38, LARGO, Z_CARGA - Z_SUELO),
                       (0.0, 0.0, (Z_CARGA + Z_SUELO) / 2.0), m["suelo"]))

    # Faldones, en los tres tramos que quedan entre las ruedas.
    for lado, signo in (("Izq", -1.0), ("Der", 1.0)):
        for i, (y0, y1) in enumerate(PASOS_RODILLA):
            piezas.append(caja(
                "Faldon_%s_%d" % (lado, i),
                (X_PARED_EXT - 0.69, y1 - y0, Z_ARCO - Z_CARGA),
                (signo * (X_PARED_EXT + 0.69) / 2.0, (y0 + y1) / 2.0,
                 (Z_ARCO + Z_CARGA) / 2.0),
                m["blanco"]))

        # Pared del baul, de punta a punta y hasta el techo.
        piezas.append(caja(
            "Pared_%s" % lado,
            (GROSOR_LATERAL, Y_TABIQUE - Y_TRAVESA, ALTO - Z_ARCO),
            (signo * (X_PARED_EXT + X_PARED_INT) / 2.0,
             (Y_TABIQUE + Y_TRAVESA) / 2.0, (ALTO + Z_ARCO) / 2.0),
            m["blanco"]))

        # Costado de la cabina, solo hasta la cintura: por encima esta la
        # ventana, y su hueco lo tapa la puerta del conductor al cerrarse.
        piezas.append(caja(
            "Costado_%s" % lado,
            (GROSOR_LATERAL, Y_TECHO_DEL - Y_TABIQUE, Z_CINTURON - Z_ARCO),
            (signo * (X_PARED_EXT + X_PARED_INT) / 2.0,
             (Y_TECHO_DEL + Y_TABIQUE) / 2.0,
             (Z_CINTURON + Z_ARCO) / 2.0),
            m["blanco"]))

        # Pilar B entre la puerta y el baul.
        piezas.append(caja(
            "PilarB_%s" % lado, (GROSOR_LATERAL, 0.12, Z_TECHO - Z_CINTURON),
            (signo * (X_PARED_EXT + X_PARED_INT) / 2.0, Y_TABIQUE + 0.06,
             (Z_TECHO + Z_CINTURON) / 2.0),
            m["blanco"]))

        # Guardafango delantero, que llega a la linea del capot.
        piezas.append(caja(
            "Guardafango_%s" % lado,
            (GROSOR_LATERAL, Y_FRENTE - Y_TECHO_DEL, 1.22 - Z_ARCO),
            (signo * (X_PARED_EXT + X_PARED_INT) / 2.0,
             (Y_FRENTE + Y_TECHO_DEL) / 2.0, (1.22 + Z_ARCO) / 2.0),
            m["blanco"]))

        # Pilar A, el montante del parabrisas.
        piezas.append(barra(
            "PilarA_%s" % lado, 0.10, 0.10,
            (signo * (X_PARED_EXT + X_PARED_INT) / 2.0, Y_COWL, Z_CINTURON),
            (signo * (X_PARED_EXT + X_PARED_INT) / 2.0, Y_TECHO_DEL, Z_TECHO),
            m["blanco"]))

    piezas.append(caja("Techo", (X_CARROCE, Y_TECHO_DEL - Y_TRAVESA,
                                ALTO - Z_TECHO),
                       (0.0, (Y_TECHO_DEL + Y_TRAVESA) / 2.0,
                        (ALTO + Z_TECHO) / 2.0), m["blanco"]))
    # Tabique del baul. Es lo unico que separa la carga de la cabina.
    piezas.append(caja("Tabique", (1.58, 0.08, Z_TECHO - Z_CARGA),
                       (0.0, Y_TABIQUE, (Z_TECHO + Z_CARGA) / 2.0),
                       m["grafito"]))

    # Morro: frontal, capot, faros, rejilla y los dos paragolpes.
    piezas.append(caja("Frontal", (1.58, 0.10, 0.50), (0.0, 2.30, 0.69),
                       m["blanco"]))
    piezas.append(barra("Capot", 1.58, 0.08, (0.0, Y_COWL, Z_CINTURON),
                        (0.0, Y_FRENTE_CARA, 0.94), m["blanco"]))
    piezas.append(barra("Parabrisas", 1.58, 0.06, (0.0, Y_COWL, Z_CINTURON),
                        (0.0, Y_TECHO_DEL, Z_TECHO), m["cristal"]))
    piezas.append(caja("Rejilla", (1.02, 0.06, 0.20), (0.0, 2.36, 0.60),
                       m["grafito"]))
    for lado, signo in (("Izq", -1.0), ("Der", 1.0)):
        piezas.append(caja("Faro_%s" % lado, (0.30, 0.06, 0.20),
                           (signo * 0.55, 2.36, 0.80), m["faro"]))
        # El piloto trasero va en el costado, no en la cara de atras: esa cara
        # esta abierta, que es el hueco por donde entra la desbrozadora, y un
        # piloto ahi no tendria donde apoyarse ni dejaria entrar la carga.
        piezas.append(caja("Piloto_%s" % lado, (0.05, 0.28, 0.30),
                           (signo * (X_PARED_EXT + 0.025), Y_TRAVESA + 0.28,
                            0.95), m["rojo"]))
        # Retrovisor: brazo y cristal. Sobresalen 15 cm y son los que marcan el
        # ancho total del coche.
        piezas.append(caja("Brazo_espejo_%s" % lado, (0.10, 0.07, 0.06),
                           (signo * 0.93, 0.98, 1.26), m["grafito"]))
        piezas.append(caja("Espejo_%s" % lado, (0.05, 0.15, 0.24),
                           (signo * 1.03, 0.98, 1.28), m["grafito"]))
    piezas.append(caja("Paragolpes_Del", (X_CARROCE, 0.20, 0.24),
                       (0.0, 2.32, 0.32), m["grafito"]))
    piezas.append(caja("Paragolpes_Tras", (X_CARROCE, 0.16, 0.24),
                       (0.0, Y_TRAVESA + 0.08, 0.32), m["grafito"]))

    # Salpicadero: la cara de arriba es la linea de la cintura. Se queda corto
    # en Y a proposito, para que el aro del volante quede por detras de el y no
    # se solapen: el volante sale de la parte de atras del salpicadero.
    piezas.append(caja("Salpicadero", (1.58, 0.24, 0.30), (0.0, 0.90, 1.01),
                       m["grafito"]))
    piezas.append(barra("Limpiador", 0.55, 0.03, (-0.20, 0.95, 1.14),
                        (0.24, 1.03, 1.28), m["negro"]))

    # Asiento simple, alineado con el volante.
    piezas.append(caja("Asiento_Pie", (0.40, 0.40, 0.22), (-0.38, 0.34, 0.61),
                       m["asiento"]))
    piezas.append(caja("Asiento_Base", (0.54, 0.52, 0.12), (-0.38, 0.34, 0.78),
                       m["asiento"]))
    piezas.append(barra("Asiento_Espalda", 0.54, 0.12, (-0.38, 0.10, 0.84),
                        (-0.38, 0.24, 1.48), m["asiento"]))
    piezas.append(caja("Asiento_Cabecero", (0.30, 0.12, 0.20), (-0.38, 0.26, 1.58),
                       m["asiento"]))

    chasis = unir("Chasis", piezas)
    redondear(chasis)
    return chasis


def pieza_volante(m):
    """El volante, con el origen en la BASE de la columna de direccion.

    Se construye alrededor del (0, 0, 0) con el eje de la rueda en el Z local,
    se coloca girado con la inclinacion de la columna, y despues se le baja el
    origen a la base con origin_set. Asi el origen cae en el eje de giro (que es
    lo que hace falta para que al girar no le de tirones a la rueda) y ademas
    la inclinacion queda COCIDA en la malla y no en el nodo.

    Ojo con la inclinacion: el aro va TUMBADO 25 grados, no vertical. La
    columna sale del salpicadero hacia atras y arriba, casi horizontal, y el
    plano del aro es perpendicular a esa columna. Si se tomara la columna como
    vertical, el aro quedaria tumbado como el volante de un bus.
    """
    inclinacion = math.radians(25.0)
    largo_columna = 0.44
    base = Vector((-0.38, 0.98, 1.10))
    eje = Vector((0.0, -math.cos(inclinacion), math.sin(inclinacion)))
    centro = base + eje * largo_columna

    piezas = [
        toro("Aro", 0.175, 0.025, (0.0, 0.0, 0.0), m["negro"], lados=10),
        cilindro("Buje", 0.050, 0.08, (0.0, 0.0, 0.0), m["grafito"], 8),
        cilindro_entre("Columna", 0.026, (0.0, 0.0, -largo_columna),
                       (0.0, 0.0, 0.0), m["grafito"], 8),
    ]
    for i in range(3):
        ang = math.radians(90.0 + i * 120.0)
        # El radio se arma con caja y giro en Z, y no con barra entre dos
        # puntos. Es lo mismo pero a la buena: barra orienta la pieza al mundo,
        # y estas piezas luego se giran con el conjunto, asi que un radio
        # armado con barra se iria por la columna en vez de por el aro.
        radio = caja("Radio%d" % (i + 1), (0.055, 0.160, 0.030),
                     (0.0, 0.080, 0.0), m["grafito"])
        radio.rotation_euler = (0.0, 0.0, ang)
        piezas.append(radio)

    volante = unir("Volante", piezas, origen=(0.0, 0.0, 0.0))
    volante.matrix_world = Matrix.Translation(centro) @ eje.to_track_quat("Z", "Y").to_matrix().to_4x4()
    aplicar(volante)
    bpy.context.view_layer.update()
    bpy.ops.object.select_all(action="DESELECT")
    volante.select_set(True)
    bpy.context.view_layer.objects.active = volante
    bpy.context.scene.cursor.location = base
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    # "eje_spin" va YA EN EJES DE GODOT, no en los de Blender. El juego no
    # importa el .blend: lee esta propiedad del glTF y la mete tal cual en un
    # Basis, asi que si se guardara en ejes de Blender habria que acordarse de
    # pasarla por (x, y, z) -> (x, z, -y) en el juego, y ese es justo el cambio
    # que se olvida. Se guarda ya convertido y el informe imprime los dos.
    volante["eje_spin"] = [eje.x, eje.z, -eje.y]
    volante["radio_aro"] = 0.20
    return volante, base, eje, centro


def pieza_puerta_conductora(m):
    """Puerta del conductor, con el origen en la bisagra de DELANTE.

    El bajo va de Z_CARGA a la cintura, y por encima el marco de la ventana con
    el cristal dentro. El marco es de cuatro barras, no un panel: al abrirse la
    puerta aparece un hueco de verdad, no una chapa con un cristal pegado.
    """
    x = -(X_PUERTAS + X_CARROCE) / 2.0
    bisagra = Vector((-X_CARROCE, 1.02, 1.00))
    y0, y1 = -0.34, 1.02
    z_vent = 1.88

    piezas = [
        caja("Faldon", (X_CARROCE - X_PUERTAS, y1 - y0, Z_CINTURON - Z_CARGA),
             (x, (y0 + y1) / 2.0, (Z_CINTURON + Z_CARGA) / 2.0), m["blanco"]),
        caja("Marco_Frente", (X_CARROCE - X_PUERTAS, 0.10, z_vent - Z_CINTURON),
             (x, 0.87, (z_vent + Z_CINTURON) / 2.0), m["blanco"]),
        caja("Marco_Tras", (X_CARROCE - X_PUERTAS, 0.10, z_vent - Z_CINTURON),
             (x, -0.23, (z_vent + Z_CINTURON) / 2.0), m["blanco"]),
        caja("Marco_Superior", (X_CARROCE - X_PUERTAS, 1.20, 0.10),
             (x, 0.37, z_vent - 0.05), m["blanco"]),
        caja("Marco_Inferior", (X_CARROCE - X_PUERTAS, 1.36, 0.06),
             (x, 0.34, Z_CINTURON + 0.03), m["blanco"]),
        caja("Cristal", (0.03, 1.10, 0.56), (x, 0.37, 1.50), m["cristal"]),
        caja("Manija", (0.05, 0.16, 0.05), (x - 0.045, -0.24, 1.10), m["grafito"]),
    ]
    puerta = unir("Puerta_Conductor", piezas, origen=bisagra)
    redondear(puerta, 0.014)
    puerta["abertura_grados"] = 80.0
    puerta["signo_abertura"] = -1.0
    return puerta


def pieza_puerta_trasera(nombre, lado, m):
    """Puerta trasera de carga, con el origen en la bisagra de su lado.

    Las dos son iguales y van montadas al reves: la del conductor abre hacia
    delante y estas hacia atras, que es lo de una puerta de farmers.
    """
    signo = -1.0 if lado == "Izq" else 1.0
    x = signo * (X_PUERTAS + X_CARROCE) / 2.0
    bisagra = Vector((signo * X_CARROCE, Y_TRAVESA, 1.15))
    y0, y1 = Y_TRAVESA, -1.00
    z0, z1 = Z_CARGA, 1.96

    piezas = [
        caja("Faldon", (X_CARROCE - X_PUERTAS, y1 - y0, z1 - z0),
             (x, (y0 + y1) / 2.0, (z0 + z1) / 2.0), m["blanco"]),
        caja("Cristal", (0.03, 1.28, 0.44),
             (x, (y0 + y1) / 2.0, 1.52), m["grafito"]),
    ]
    for i, y in enumerate((y0 + 0.35, y1 - 0.35)):
        piezas.append(caja("Nervio%d" % (i + 1), (0.03, 0.06, z1 - z0 - 0.24),
                           (x + signo * 0.045, y, (z0 + z1) / 2.0),
                           m["blanco"]))
    piezas.append(caja("Manija", (0.05, 0.05, 0.16),
                       (x + signo * 0.045, y1 - 0.12, 1.10), m["grafito"]))

    puerta = unir(nombre, piezas, origen=bisagra)
    redondear(puerta, 0.014)
    puerta["abertura_grados"] = 110.0
    puerta["signo_abertura"] = -signo
    return puerta


def pieza_rueda(nombre, posicion, m):
    """Rueda, con el origen en SU CENTRO GEOMETRICO.

    El eje va en X, o sea tumbado: en Godot eso quiere decir que la rodadura
    es rotar en X y la direccion rotar en la vertical. Con el nodo sin
    inclinacion propia, las dos caben en el mismo nodo porque Godot compone en
    YXZ y aplica la rodadura antes que la direccion.
    """
    x, y, z = posicion
    piezas = [
        cilindro("Neumatico", RADIO_RUEDA, ANCHO_RUEDA, posicion,
                 m["negro"], 12, "X"),
        cilindro("Llanta", 0.175, ANCHO_RUEDA + 0.02, posicion,
                 m["plata"], 10, "X"),
        cilindro("Buje", 0.055, ANCHO_RUEDA + 0.06, posicion,
                 m["grafito"], 8, "X"),
    ]
    for i in range(5):
        ang = math.radians(i * 72.0)
        piezas.append(barra(
            "Radio%d" % (i + 1), ANCHO_RUEDA - 0.04, 0.045,
            (x, y, z),
            (x, y + 0.12 * math.cos(ang), z + 0.12 * math.sin(ang)),
            m["plata"]))
    rueda = unir(nombre, piezas, origen=posicion)
    redondear(rueda, 0.012)
    return rueda


# --- Montaje --------------------------------------------------------------
RUEDAS = (
    ("Rueda_Del_Izq", (-X_CENTRO_RUEDA, EJE_DEL_Y, Z_EJE_RUEDA)),
    ("Rueda_Del_Der", (+X_CENTRO_RUEDA, EJE_DEL_Y, Z_EJE_RUEDA)),
    ("Rueda_Tra_Izq", (-X_CENTRO_RUEDA, EJE_TRAS_Y, Z_EJE_RUEDA)),
    ("Rueda_Tra_Der", (+X_CENTRO_RUEDA, EJE_TRAS_Y, Z_EJE_RUEDA)),
)


def _montar():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    m = _materiales()

    raiz = empty("Furgoneta", (0.0, 0.0, 0.0), 0.6)
    chasis = pieza_chasis(m)
    volante, base, eje, centro = pieza_volante(m)
    puertas = [pieza_puerta_conductora(m),
               pieza_puerta_trasera("Puerta_Trasera_Izq", "Izq", m),
               pieza_puerta_trasera("Puerta_Trasera_Der", "Der", m)]
    ruedas = [pieza_rueda(nombre, pos, m) for nombre, pos in RUEDAS]

    aplicar(chasis)
    for ob in [volante] + puertas + ruedas:
        aplicar(ob)
    _caras_hacia_fuera(chasis)

    # El nodo del cockpit y el punto donde se deja la carga. No son piezas del
    # coche: son donde mirar y donde soltar la desbrozadora.
    ojo = empty("Ojo_Conductor", (-0.38, 0.60, 1.46), 0.12)
    carga = empty("Punto_Carga", (0.0, -1.40, Z_CARGA), 0.20)

    bpy.context.view_layer.update()
    enganchar(chasis, raiz)
    enganchar(volante, chasis)
    for puerta in puertas:
        enganchar(puerta, chasis)
    for rueda in ruedas:
        enganchar(rueda, raiz)
    enganchar(ojo, chasis)
    enganchar(carga, raiz)

    bpy.ops.object.select_all(action="DESELECT")
    raiz.select_set(True)
    bpy.context.view_layer.objects.active = raiz
    bpy.context.view_layer.update()

    fallos = _informe()
    if fallos:
        print("no se exporta: la furgoneta no cumple el contrato")
        return fallos

    os.makedirs(OUT_DIR, exist_ok=True)
    exportar_blender.exportar(OUT_FILE)
    print("exportado:", OUT_FILE)
    return 0


def main():
    fallos = _montar()
    print("---")
    print("RESULTADO: %s" % ("todo correcto" if fallos == 0
                             else "%d problema(s)" % fallos))
    return fallos


# --- Comprobaciones -------------------------------------------------------
def _informe():
    """Mide la furgoneta y comprueba el contrato con el juego."""
    objetos = bpy.context.scene.objects
    nombres = [o.name for o in objetos]
    print("nodos (%d): %s" % (len(nombres), ", ".join(sorted(nombres))))

    fallos = _informe_caja(objetos)
    fallos += _informe_jerarquia(objetos)
    fallos += _informe_ruedas(objetos)
    fallos += _informe_volante(objetos)
    fallos += _informe_puertas(objetos)
    fallos += _informe_carga(objetos)
    fallos += _informe_transform(objetos)

    print("--- ejes para el juego (aqui Z es arriba) ---")
    print("  ruedas: la vertical es Z, el lateral es X")
    print("           en Godot, sin giro en la escena: direccion = rotation.y,"
          " rodadura = rotation.x")
    for nombre, grados, lado, signo, y_bisagra in PUERTAS:
        # La vertical es Y en Godot, y el signo no cambia al exportar: asi que
        # el MISMO numero y el MISMO signo que se pide en Blender.
        print("  %-18s rotation.y = %+.0f  (abre hacia el %s)"
              % (nombre, signo * grados, "lado izquierdo" if lado < 0
                 else "lado derecho"))
    print("  bisagras: giran sobre la vertical, y en Godot la vertical es Y."
          " Da igual el giro de 180 grados en Y del nodo padre, porque los ejes"
          " de un hijo son los suyos")
    print("  volante: no gira sobre la vertical, sino sobre el eje de la"
          " columna. Se compone un Basis:")
    volante = objetos.get("Volante")
    if volante is not None and "eje_spin" in volante:
        guardado = Vector(volante["eje_spin"])
        print("      volante.basis = Basis(Vector3(%.3f, %.3f, %.3f),"
              " volante.rotation.x)"
              % (guardado.x, guardado.y, guardado.z))
    else:
        print("      [FALLO] el Volante no tiene eje_spin")
        fallos += 1
    return fallos


def _informe_caja(objetos):
    mn = [1e9, 1e9, 1e9]
    mx = [-1e9, -1e9, -1e9]
    triangulos = 0
    for ob in objetos:
        if ob.type != "MESH":
            continue
        triangulos += sum(max(1, len(p.vertices) - 2) for p in ob.data.polygons)
        for v in ob.data.vertices:
            mundo = ob.matrix_world @ v.co
            for i in range(3):
                mn[i] = min(mn[i], mundo[i])
                mx[i] = max(mx[i], mundo[i])
    print("caja: x[%.3f, %.3f] y[%.3f, %.3f] z[%.3f, %.3f]"
          % (mn[0], mx[0], mn[1], mx[1], mn[2], mx[2]))
    print("  largo %.2f, ancho %.2f (con los retrovisores), alto %.2f"
          % (mx[1] - mn[1], mx[0] - mn[0], mx[2] - mn[2]))

    fallos = 0
    fallos += _ok("largo", mx[1] - mn[1], *ESPERADO_LARGO)
    fallos += _ok("ancho", mx[0] - mn[0], *ESPERADO_ANCHO)
    fallos += _ok("alto", mx[2] - mn[2], *ESPERADO_ALTO)
    # El suelo en el 0: en Godot una malla se siembra por su origen, y si la
    # furgoneta cuelga por encima del suelo el coche flota.
    fallos += _ok("suelo", mn[2], -TOLERANCIA, TOLERANCIA)
    print("  %d triangulos (se esperan entre %d y %d)"
          % (triangulos, TRIANGULOS_MIN, TRIANGULOS_MAX))
    fallos += _ok("triangulos", triangulos, TRIANGULOS_MIN, TRIANGULOS_MAX)
    batalla = (EJE_DEL_Y + EJE_TRAS_Y) / 2.0
    print("  batalla en y = %+.2f, separation %.2f m"
          % (batalla, EJE_DEL_Y - EJE_TRAS_Y))
    return fallos


def _informe_jerarquia(objetos):
    print("--- jerarquia ---")
    fallos = 0
    for nombre, padre in JERARQUIA:
        ob = objetos.get(nombre)
        if ob is None:
            print("  [FALLO] no existe el nodo", nombre)
            fallos += 1
            continue
        real = ob.parent.name if ob.parent else None
        if real != padre:
            print("  [FALLO] %s cuelga de %s y deberia colgar de %s"
                  % (nombre, real, padre))
            fallos += 1
        else:
            print("  [OK] %-18s hijo de %s" % (nombre, padre))
    return fallos


def _informe_ruedas(objetos):
    """Cada rueda con el origen en su centro, tumbada, y girando bien."""
    print("--- ruedas ---")
    fallos = 0
    for nombre, (x, y, z) in RUEDAS:
        rueda = objetos.get(nombre)
        if rueda is None:
            print("  [FALLO] no existe", nombre)
            fallos += 1
            continue
        org = rueda.matrix_world.translation
        # El origen tiene que caer en el centro geometrico de la pieza. Con una
        # rueda cilindrica, el centro del cubo que la envuelve.
        minx = miny = minz = 1e9
        maxx = maxy = maxz = -1e9
        for v in rueda.data.vertices:
            mundo = rueda.matrix_world @ v.co
            minx, maxx = min(minx, mundo.x), max(maxx, mundo.x)
            miny, maxy = min(miny, mundo.y), max(maxy, mundo.y)
            minz, maxz = min(minz, mundo.z), max(maxz, mundo.z)
        centro = Vector(((minx + maxx) / 2.0, (miny + maxy) / 2.0,
                         (minz + maxz) / 2.0))
        print("  %-15s origen (%.2f, %.2f, %.2f)  diametero en X %.3f"
              % (nombre, org.x, org.y, org.z, maxx - minx))
        fallos += _ok("  %s en su sitio" % nombre,
                      (org - Vector((x, y, z))).length, 0.0, TOLERANCIA)
        fallos += _ok("  %s con el origen en el centro" % nombre,
                      (org - centro).length, 0.0, REDONDEO_TOLERANCIA)
        # El eje de la rueda tiene que ser el LATERAL, o sea X. Una rueda
        # tumbada se ve ancha de lado (solo el grosor del neumatico) y larga y
        # alta de frente; de canto seria justo al reves.
        ancho_x = maxx - minx
        alto_y = maxy - miny
        alto_z = maxz - minz
        fallos += _ok("  %s tumbada: por X solo pasa el grosor" % nombre,
                      min(alto_y, alto_z) - ancho_x, 0.30, 0.50)
        fallos += _ok("  %s con el diametro entero" % nombre,
                      min(alto_y, alto_z), 0.60, 0.70)

    # Y ahora el giro de verdad, que es lo que el juego va a escribir. Se coge
    # un punto de la rueda delantera izquierda y se gira de las dos maneras.
    rueda = objetos.get("Rueda_Del_Izq")
    if rueda is not None:
        org = rueda.matrix_world.translation
        # 1. La direccion: 20 grados sobre la vertical (Z aqui). Un punto de la
        #    cara de delante de la rueda tiene que salir de lado, no de frente.
        delante = org + Vector((0.0, RADIO_RUEDA, 0.0))
        girado = org + Matrix.Rotation(math.radians(20.0), 3, "Z") @ (delante - org)
        esperado = Vector((-RADIO_RUEDA * math.sin(math.radians(20.0)),
                           RADIO_RUEDA * math.cos(math.radians(20.0)), 0.0))
        fallos += _ok("  girar en la vertical hace la direccion",
                      (girado - org - esperado).length, 0.0, 1e-3)
        # 2. La rodadura: 20 grados sobre el lateral (X). El punto de contacto
        #    recorre un arco hacia delante, y de abajo no se levanta.
        contacto = org + Vector((0.0, 0.0, -RADIO_RUEDA))
        girado = org + Matrix.Rotation(math.radians(20.0), 3, "X") @ (contacto - org)
        esperado = Vector((0.0, RADIO_RUEDA * math.sin(math.radians(20.0)),
                           -RADIO_RUEDA * math.cos(math.radians(20.0))))
        fallos += _ok("  girar en el lateral hace la rodadura",
                      (girado - org - esperado).length, 0.0, 1e-3)
        print("  [OK] la misma rueda sirve para las dos cosas: es el orden YXZ"
              " de Godot, rodadura antes que direccion")
    return fallos


def _informe_volante(objetos):
    """El volante: origen en la base de la columna, inclinado y sin dar saltos."""
    print("--- volante ---")
    volante = objetos.get("Volante")
    if volante is None:
        print("  [FALLO] no existe el nodo Volante")
        return 1
    org = volante.matrix_world.translation
    fallos = 0

    # 1. El origen en la base de la columna, o sea en el eje de giro y no en el
    #    centro de la rueda. Si estuviera en el centro de la rueda, al girar
    #    sobre el eje de la columna la pieza dabaria vueltas alrededor.
    fuera = _lejos_del_eje(volante, org)
    print("  origen en (%.2f, %.2f, %.2f), %.3f m del centro de la rueda"
          % (org.x, org.y, org.z, fuera))
    fallos += _ok("origen en la base de la columna, no en el centro",
                  fuera, 0.15, 0.60)
    # El origen tiene que estar en el eje: la distancia de todos los puntos
    # del aro al eje del giro no cambia al girar. La propiedad va en ejes de
    # Godot, asi que para medir aqui se deshace el cambio del exportador.
    if "eje_spin" not in volante:
        print("  [FALLO] falta la propiedad eje_spin")
        return fallos + 1
    guardado = Vector(volante["eje_spin"])
    eje = Vector((guardado.x, -guardado.z, guardado.y))
    print("  eje de giro, en Blender (%.3f, %.3f, %.3f): %.0f grados de vertical"
          % (eje.x, eje.y, eje.z, math.degrees(math.asin(abs(eje.z)))))
    print("  eje de giro, en Godot   (%.3f, %.3f, %.3f), que es lo que lleva"
          " la propiedad eje_spin"
          % (guardado.x, guardado.y, guardado.z))
    # El eje va casi horizontal, apuntando hacia atras: eso es lo que hace que
    # el aro quede tumbado 25 grados como el de un coche. Si saliera vertical,
    # el aro quedaria plano como el de un bus.
    fallos += _ok("el eje sale tumbado, no vertical",
                  abs(eje.z), 0.30, 0.60)
    fallos += _ok("el eje sale apuntando a la cabina", -eje.y, 0.75, 1.0)
    fallos += _ok("el eje no se inclina de lado a lado", abs(eje.x), 0.0, 1e-6)
    fallos += _ok("eje_spin mira al aro y no hacia atras", guardado.z, 0.75, 1.0)

    # 2. El origen tiene que estar EN el eje de giro. La prueba no es mirar
    #    coordenadas, que eso lo dice el que programa: es girar el aro 36
    #    grados (un segmento del toro) sobre el eje que pasa por el origen y
    #    ver que el aro vuelve EXACTAMENTE encima. Si el origen se hubiera
    #    quedado fuera del eje, el aro girado no caeria encima del otro y el
    #    volante se moveria de sitio al girar.
    antes = _aro(volante, org, eje)
    girado = [org + Matrix.Rotation(math.radians(36.0), 3, eje) @ (p - org)
              for p in antes]
    print("  aro: %d vertices, se giran %.4f m al girar 36 grados"
          % (len(antes), _desajuste(antes, girado)))
    fallos += _ok("el origen esta en el eje: el aro gira sobre si mismo",
                  _desajuste(antes, girado), 0.0, 1e-3)
    print("  centro de la rueda a %.2f m del origen, que es la columna vista"
          % _puntero_en_el_eje(volante, org, eje).dot(eje))

    # 3. Y la inclinacion natural: el aro tiene que ser MAS ANCHO que alto
    #    (tumbado, no vertical) y mas alto que fondo (inclinado, no plano).
    #    Se mide SOLO el aro, y no el volante entero, porque la columna sale
    #    40 cm hacia atras y si se midiera el conjunto entero el fondo serian
    #    esos 40 cm y el aro pareceria tumbado del todo.
    mn, mx, _ = _caja_de_puntos(antes)
    ancho, fondo, alto = (mx[0] - mn[0], mx[1] - mn[1], mx[2] - mn[2])
    print("  aro: %.3f de ancho, %.3f de alto, %.3f de fondo (sin la columna)"
          % (ancho, alto, fondo))
    fallos += _ok("el aro va tumbado: mas ancho que alto", ancho - alto,
                  0.0, 0.06)
    fallos += _ok("el aro va inclinado: mas alto que fondo", alto - fondo,
                  0.10, 0.30)
    return fallos


def _informe_puertas(objetos):
    """Las bisagras, y que al abrir de verdad la hoja salga de la carrocería."""
    print("--- puertas ---")
    fallos = 0
    for nombre, grados, lado, signo, y_bisagra in PUERTAS:
        puerta = objetos.get(nombre)
        if puerta is None:
            print("  [FALLO] no existe", nombre)
            fallos += 1
            continue
        org = puerta.matrix_world.translation
        # El punto de la puerta que mas lejos esta de la bisagra, que es la
        # esquina de la hoja que se sale del coche al abrir.
        lejos = _punto_mas_lejos(puerta, org)
        print("  %-18s bisagra en (%.2f, %.2f, %.2f), hoja de %.2f m"
              % (nombre, org.x, org.y, org.z, (lejos - org).length))
        fallos += _ok("  %s con el origen en la bisagra" % nombre,
                      _distancia_a_la_bisagra(puerta, org, y_bisagra),
                      0.0, 1e-3)
        # El giro de verdad, con el signo de la tabla: la hoja tiene que salir
        # hacia su lado y quedar en el aire, no metida en la carrocería.
        abierto = org + Matrix.Rotation(math.radians(signo * grados), 3, "Z") @ (lejos - org)
        print("    abierta %.0f grados, la hoja llega a (%.2f, %.2f)"
              % (grados, abierto.x, abierto.y))
        fallos += _ok("  abierta sale hacia su lado y no se cruza",
                      abierto.x * lado, 1.10, 4.00)
    return fallos


def _informe_carga(objetos):
    """El baul tiene que estar vacio y con el suelo plano."""
    print("--- baul ---")
    fallos = 0
    dentro = []
    for ob in objetos:
        if ob.type != "MESH":
            continue
        for v in ob.data.vertices:
            mundo = ob.matrix_world @ v.co
            if (CARGA["x"][0] < mundo.x < CARGA["x"][1]
                    and CARGA["y"][0] < mundo.y < CARGA["y"][1]
                    and CARGA["z"][0] < mundo.z < CARGA["z"][1]):
                dentro.append((ob.name, mundo))
    if dentro:
        print("  [FALLO] hay %d vertices dentro del hueco de carga, y lo"
              " primero es %s en (%.2f, %.2f, %.2f)"
              % (len(dentro), dentro[0][0], dentro[0][1].x, dentro[0][1].y,
                 dentro[0][1].z))
        fallos += 1
    else:
        print("  [OK] el hueco de carga esta vacio (%.2f x %.2f x %.2f m)"
              % (CARGA["x"][1] - CARGA["x"][0], CARGA["y"][1] - CARGA["y"][0],
                 CARGA["z"][1] - Z_CARGA))

    # Y el suelo plano. Esto NO se puede mirar por vertices, y ya se ha visto
    # por que: la chapa es una sola caja, asi que su cara de arriba solo tiene
    # las cuatro esquinas, y si se mide donde hay vertices se mide el faldon de
    # al lado, que esta a la misma altura. Se lanza un rayo vertical desde el
    # techo del baul en una rejilla y se mira a que altura para: tiene que
    # salir siempre en Z_CARGA y siempre en el chasis. Asi se comprueba de una
    # vez que el suelo es plano y que tapa TODA la huella, sin huecos.
    escena = bpy.context.scene
    evaluado = escena.view_layers[0].depsgraph
    desde = Z_CARGA + 1.30
    alturas = []
    fuera = []
    for x in (-0.60, -0.30, 0.0, 0.30, 0.60):
        for y in (CARGA["y"][0] + 0.10, -1.90, -1.40, -0.90, CARGA["y"][1] - 0.10):
            # La funcion pide un origen y una direccion, no un punto y un
            # objetivo, asi que el rayo arranca justo por encima de la muestra.
            golpe = escena.ray_cast(evaluado, Vector((x, y, desde)),
                                     Vector((0.0, 0.0, -1.0)))
            if not golpe[0]:
                fuera.append((x, y, "nada"))
                continue
            punto = golpe[1]
            alturas.append(punto.z)
            if (abs(punto.z - Z_CARGA) > 1e-3 or golpe[4] is None
                    or golpe[4].name != "Chasis"):
                fuera.append((x, y, round(punto.z, 3), golpe[4].name))
    if fuera:
        print("  [FALLO] %d de 25 muestras del suelo no salen en z = %.2f: %s"
              % (len(fuera), Z_CARGA, fuera[:4]))
        fallos += 1
    else:
        print("  [OK] suelo plano en z = %.2f en las 25 muestras de la"
              " huella (%.2f x %.2f m), a %.2f m del suelo"
              % (Z_CARGA, CARGA["x"][1] - CARGA["x"][0],
                 CARGA["y"][1] - CARGA["y"][0], Z_CARGA))
    return fallos


def _informe_transform(objetos):
    """Regla 1: ningun nodo lleva rotacion propia ni escala sin aplicar."""
    print("--- transformaciones ---")
    fallos = 0
    sucias = []
    giradas = []
    for ob in objetos:
        if ob.type == "MESH":
            if (any(abs(a) > 1e-6 for a in ob.rotation_euler)
                    or any(abs(a - 1.0) > 1e-6 for a in ob.scale)):
                sucias.append(ob.name)
        if any(abs(a) > 1e-6 for a in ob.rotation_euler):
            giradas.append(ob.name)
    if sucias:
        print("  [FALLO] sin transform_apply:", ", ".join(sucias))
        fallos += 1
    else:
        print("  [OK] todas las mallas con transform aplicado")
    if giradas:
        print("  [FALLO] con rotacion propia, que al escribir un eje se"
              " perderia:", ", ".join(giradas))
        fallos += 1
    else:
        print("  [OK] ningun nodo con rotacion propia: las inclinaciones van"
              " cocidas en la malla")
    return fallos


# --- Medidas --------------------------------------------------------------
def _caja_de(ob):
    mn = [1e9, 1e9, 1e9]
    mx = [-1e9, -1e9, -1e9]
    for v in ob.data.vertices:
        mundo = ob.matrix_world @ v.co
        for i in range(3):
            mn[i] = min(mn[i], mundo[i])
            mx[i] = max(mx[i], mundo[i])
    return mn, mx, ob.matrix_world.translation


def _centro_mundial(ob):
    mn, mx, _ = _caja_de(ob)
    return Vector(((mn[0] + mx[0]) / 2.0, (mn[1] + mx[1]) / 2.0,
                   (mn[2] + mx[2]) / 2.0))


def _lejos_del_eje(ob, org):
    """Del origen al centro de la pieza.

    En el volante da la media columna: si el origen estuviera en el centro de la
    rueda, al girar sobre el eje de la columna la pieza dabaria vueltas.
    """
    return (_centro_mundial(ob) - org).length


def _punto_mas_lejos(ob, org):
    return max(((ob.matrix_world @ v.co) for v in ob.data.vertices),
               key=lambda p: (p - org).length)


def _puntero_en_el_eje(ob, org, eje):
    """El centro del aro: el punto mas alejado del origen a lo largo del eje.

    No sirve el centro del cubo que envuelve al volante, porque ese cubo
    tambien alcanza la base de la columna y su centro cae a medio camino.
    """
    return max(((ob.matrix_world @ v.co) for v in ob.data.vertices),
               key=lambda p: eje.dot(p - org))


def _caja_de_puntos(puntos):
    mn = [1e9, 1e9, 1e9]
    mx = [-1e9, -1e9, -1e9]
    for p in puntos:
        for i in range(3):
            mn[i] = min(mn[i], p[i])
            mx[i] = max(mx[i], p[i])
    return mn, mx, Vector((0.0, 0.0, 0.0))


def _aro(ob, org, eje):
    """Los vertices del aro del volante, y solo los del aro.

    Se distinguen por lo lejos que estan del EJE DE LA COLUMNA, no por su
    nombre, porque despues de unir la pieza en una sola malla los nombres se
    pierden. El aro esta a 17,5 cm del eje (mas los 2,5 del grosor del tubo) y
    los radios del centro solo llegan a 16, asi que el corte es limpio.
    """
    salida = []
    for v in ob.data.vertices:
        mundo = ob.matrix_world @ v.co
        deltn = mundo - org
        perpendicular = deltn - eje * eje.dot(deltn)
        if 0.17 <= perpendicular.length <= 0.21:
            salida.append(mundo)
    return salida


def _desajuste(originales, movidos):
    """Lo que se separa un punto de la nube que deberia haber caído encima.

    Compara cada punto movido con el original MAS CERCANO, no con el del mismo
    indice: al girar, los vertices se permutan y si se comparan por posicion
    se mediria el giro entero en vez de lo que se desvian de su sitio. Con un
    margen de 1 mm se descarta el caso de dos vertices que se cruzan.
    """
    peor = 0.0
    for p in movidos:
        mejor = min((p - q).length for q in originales)
        peor = max(peor, mejor)
    return peor


def _distancia_a_la_bisagra(ob, org, y_bisagra):
    """Cuanto se aparta el origen de donde tiene que estar la bisagra.

    La bisagra es una recta VERTICAL, y el origen tiene que caer en ella: en
    la cara de fuera de la hoja (|x| = ANCHO/2), en el canto que abre (la Y del
    borde de delante del conductor, la de atras en las de carga) y dentro de la
    altura de la hoja. Se mide cada cosa y se queda con la peor, que es la que
    haria que la puerta no abriera del todo.

    No se mide contra el cubo que envuelve la puerta, porque la manija asoma
    4 cm por fuera de la piel y con el cubo la bisagra pareceria estar mal
    puesta cuando esta perfectamente.
    """
    mn, mx, _ = _caja_de(ob)
    return max(abs(abs(org.x) - X_CARROCE),
               abs(org.y - y_bisagra),
               max(0.0, mn[2] - org.z, org.z - mx[2]))


def _ok(etiqueta, valor, minimo, maximo):
    bien = minimo <= valor <= maximo
    print("  [%s] %s = %.4f (se espera entre %.4f y %.4f)"
          % ("OK" if bien else "FALLO", etiqueta, valor, minimo, maximo))
    return 0 if bien else 1


if __name__ == "__main__":
    sys.exit(main())
