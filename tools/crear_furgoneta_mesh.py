"""
Furgoneta comercial cerrada, low poly, para conducir en primera persona y llevar
herramienta en el baul. Simple, sin instrumentacion.

La idea es un furgon de reparto de los de antes, con un punto de GAZ-52: morro
corto y redondeado, faros redondos y parabrisas partido en dos por un montante
central. Lo que define al vehiculo es que la parte de atras esta CERRADA: techo
continuo de punta a punta, paredes lisas de chapa vertical de punta a punta, y
las dos hojas de la trasera que cierran el baul. Dentro queda un hueco
rectangular con el suelo plano para la desbrozadora. Todo va en 4.000
triangulos.

Lo que hace de verdad un furgon es que no se vea ni un hueco, y eso no se
comprueba mirando el modelo por fuera sino disparando rayos desde dentro del
baul: si un rayo sale de viaje, por ese lado entra la lluvia. Va en
_informe_cierre, y es la comprobacion que vigila el techo, los costados, el
tabique, las dos hojas y el suelo.

Uso:
    flatpak run --filesystem=$HOME/Documentos org.blender.Blender --background \
        --python tools/crear_furgoneta_mesh.py
    Las rutas van absolutas: el flatpak arranca Blender en su propio directorio
    y no encuentra el proyecto con rutas relativas.

La jerarquia, en models/furgoneta.glb, y SOLO estos nombres:
    Furgoneta            empty en el (0, 0, 0), el suelo bajo el centro del coche
      Chasis             el chasis, la cabina y la caja de carga
        Volante          el volante, con el origen en la BASE de la columna
        Puerta_Conductor  con el origen en la bisagra de DELANTE
        Puerta_Trasera_Izq  con el origen en la bisagra de la IZQUIERDA
        Puerta_Trasera_Der  con el origen en la bisagra de la DERECHA
      Rueda_Del_Izq / Rueda_Del_Der / Rueda_Tra_Izq / Rueda_Tra_Der
    Y dos emptys de ayuda, que no son piezas del coche:
      Ojo_Conductor       donde va la camara de primera persona
      Punto_Carga         donde se deja la desbrozadora, en el suelo de la caja

Las cuatro reglas que el juego da por buenas, y como se comprueban:
  1. NINGUN nodo lleva rotacion propia. Toda la inclinacion esta COCIDA en la
     malla, no en el nodo. Es la regla 3 de la desbrozadora ("nada se exporta
     con rotacion ni escala sin aplicar") y es la unica forma de que el juego
     pueda escribir un solo eje del nodo sin cargarse la pose: en Godot,
     escribir rotation.z REPLAZA la rotacion entera, asi que si el nodo
     tuviera inclinacion propia, al girar el volante se le caeria.
     Se comprueba mirando rotation_euler de todos los nodos.
  2. Los pivotes estan en el sitio fisico que toca, no en el (0, 0, 0):
     el eje de la columna en el Volante, la bisagra en cada Puerta, el centro
     geometrico en cada Rueda. Se comprueba midiendo el origen contra la
     geometria, y probando el giro de verdad (ver _informe).
  3. La caja esta VACIA, con el suelo plano, y la desbrozadora CABE. No hay
     nada de la carroceria dentro del volumen de carga, para que la maquina
     entre sin colisionar; y el volumen se mide contra las medidas reales de
     models/desbrozadora.glb (0,45 x 1,46 x 0,34) con 5 cm de holgura.
     Lo de "cabe" es lo que evita el fallo clasico: un hueco que esta vacio
     porque no cabe nada, que es al reves de lo que hace falta.
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

PROJECT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(PROJECT_DIR, "models")
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

# Las hojas de puerta van por FUERA de la pared y se HUNDEN 1 cm en ella, en vez
# de justo tocarla. Es lo que quita el z-fighting del panel de la puerta del
# conductor: dos caras COPLANARES enfrentadas producen el manchon oscuro de
# sombras, y un centimetro de solape las entierra una dentro de la otra sin que
# se vea nada. Con esto el union de la puerta y la pared no es coplanar.
X_PUERTA_INT = 0.84     # cara interior de la hoja del conductor
Y_PUERTA_TRAS_INT = -2.32  # cara interior de las hojas traseras (en Y)
Y_PARED_TRAS = Y_PUERTA_TRAS_INT + 0.01   # los costados entran 1 cm en la hoja

# Separacion de 5 mm en los cantos de arriba y de abajo de las hojas. Con ella
# el canto de la hoja nunca cae en el mismo plano que la cara del faldon o del
# techo que tiene debajo o encima, que es la otra mitad del z-fighting. Con el
# coche entero mirandolo de cerca no se ve ni el hueco; con el dorso de la mano
# de al lado, se nota menos que la sombra falsa.
HOLGURA_HOJA = 0.005

Z_SUELO = 0.20          # bajos del chasis
Z_CARGA = 0.50          # cara de arriba del suelo de la caja: la altura de carga
Z_ARCO = 0.68           # por donde pasa la rueda: los pasos de rueda suben aqui
Z_CINTURON = 1.16       # la linea de la cintura, donde acaba la puerta
Z_TECHO = 2.00

# La pared de los costados llega hasta la trasera, y las puertas se montan en el
# plano de atras. Para que no se pisen, los costados paran un poco ANTES de la
# trasera y las hojas ocupan ese ultimo centimetro.
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
# Z, coordenada Y del canto de la bisagra y media anchura de la hoja. El signo
# va porque en el mismo eje los dos lados se abren en sentidos contrarios: la
# del conductor abre restando, la trasera izquierda sumando. La Y del canto y
# la anchura son lo que se mide despues, para comprobar que el origen ha caido
# en la bisagra y no en medio de la hoja.
PUERTAS = (
    ("Puerta_Conductor", 80.0, -1.0, -1.0, 1.02, X_CARROCE),
    ("Puerta_Trasera_Izq", 110.0, -1.0, +1.0, Y_TRAVESA, X_CARROCE),
    ("Puerta_Trasera_Der", 110.0, +1.0, -1.0, Y_TRAVESA, X_CARROCE),
)

# La caja de carga se comprueba con este volumen: desde el suelo de carga hasta
# el techo, y entre las caras interiores. Es el hueco rectangular protegido que
# hay que dejar libre. No tiene que haber ni un vertice de la carrocería dentro.
#
# El ancho se queda en 1,36 y no en 1,58 porque el faldon se come 9 cm por lado
# hasta Z_ARCO. Arriba el hueco si llega a 1,58, pero la desbrozadora entra por
# el suelo, y lo que tiene que caber es lo de abajo: 1,36.
#
# El alto sale de Z_TECHO y no se escribe a mano, para que si alguien baja el
# techo no se quede el volumen de comprobacion pidiendo una caja mas alta que la
# de verdad, que es como un hueco "vacio" que en realidad no existe.
CARGA = {"x": (-0.68, 0.68), "y": (-2.35, -0.45),
         "z": (Z_CARGA + 0.02, Z_TECHO - 0.02)}

# Lo que hay que meter en la caja, medido sobre models/desbrozadora.glb. Se
# comprueba que cabe con 5 cm de holgura por lado, que es lo que haria falta
# para que la carga entre y salga sin rozar. Sin esto la caja "__esta vacia__"
# queria decir vacia de desbrozadora incluida, que es justo lo que no.
DESBROZADORA = {"x": 0.45, "y": 1.46, "z": 0.34}
HOLGURA_CARGA = 0.05

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


def _arreglar_malla(ob, holgura=1e-4):
    """Quita vertices duplicados y deja las normales hacia fuera.

    Sin esto, unir 40 cajas deja puntitos sueltos y aristas con la normal
    cruzada en las uniones: son las caras que se dibujan unas encima de otras y
    producen el patron de rayas y sombras oscuras. Es el "remove_doubles" y el
    "normals_make_consistent" del pedido, aqui sobre la malla ya unida, que es
    donde estan los problemas y no antes.

    remove_doubles es la version moderna de reclaim_doubles. Se mide en metros:
    0,1 mm es de sobra para unir lo que hay que unir y no de menos para no
    comerse aristas de verdad.
    """
    try:
        bpy.ops.object.select_all(action="DESELECT")
        ob.select_set(True)
        bpy.context.view_layer.objects.active = ob
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.mesh.remove_doubles(threshold=holgura)
        bpy.ops.mesh.normals_make_consistent(inside=False)
        bpy.ops.object.mode_set(mode="OBJECT")
    except Exception as exc:  # noqa: BLE001
        print("  aviso: no se ha limpiado la malla de %s (%s)" % (ob.name, exc))


# --- La carrocería --------------------------------------------------------
def _materiales():
    return {
        "blanco": material("Blanco", (0.86, 0.86, 0.84), 0.0, 0.45),
        "grafito": material("Grafito", (0.20, 0.21, 0.23), 0.0, 0.55),
        "cristal": material("Cristal", (0.07, 0.09, 0.11), 0.0, 0.15),
        "negro": material("Negro", (0.05, 0.05, 0.06), 0.0, 0.70),
        "plata": material("Metal_Plata", (0.66, 0.68, 0.71), 0.45, 0.45),
        "asiento": material("Asiento", (0.14, 0.15, 0.18), 0.0, 0.75),
        "suelo": material("Suelo_Caja", (0.30, 0.29, 0.26), 0.0, 0.80),
        "ambar": material("Ambar", (0.95, 0.52, 0.04), 0.0, 0.30),
        "rojo": material("Rojo", (0.50, 0.05, 0.05), 0.0, 0.30),
        "faro": material("Faro", (0.82, 0.86, 0.92), 0.0, 0.20),
    }


def pieza_chasis(m):
    """Carroceria, cabina, caja CERRADA y asiento, todo en una sola malla.

    Es un furgon comercial de los de antes: morro corto, faros redondos,
    parabrisas partido en dos por un montante, y detras un baul completamente
    cerrado, con techo continuo, paredes lisas de chapa y suelo plano.

    Lo que hace de verdad un furgon es que no se vea ni un hueco. Por eso las
    paredes de los costados van de Z_ARCO hasta ALTO, una sola caja cada una, y
    el techo llega de punta a punta. La trasera la cierran las dos hojas.

    Los faldones van partidos en tres tramos porque las ruedas tienen que verse
    por su paso. Por eso el lateral empieza en Z_ARCO y no en Z_CARGA: si
    bajase hasta el suelo, la rueda quedaria enterrada en el.
    """
    piezas = []
    x_carroce = (X_PARED_EXT + X_PARED_INT) / 2.0
    x_techo = X_CARROCE

    # Suelo: la cara de arriba (Z_CARGA) es el suelo del baul, y es una sola
    # plancha recta de punta a punta, sin nada encima.
    piezas.append(caja("Bandeja", (1.38, LARGO, Z_CARGA - Z_SUELO),
                       (0.0, 0.0, (Z_CARGA + Z_SUELO) / 2.0), m["suelo"]))

    for lado, signo in (("Izq", -1.0), ("Der", 1.0)):
        # Faldones bajos, en los tres tramos que quedan entre las ruedas.
        for i, (y0, y1) in enumerate(PASOS_RODILLA):
            piezas.append(caja(
                "Faldon_%s_%d" % (lado, i),
                (X_PARED_EXT - 0.69, y1 - y0, Z_ARCO - Z_CARGA),
                (signo * (X_PARED_EXT + 0.69) / 2.0, (y0 + y1) / 2.0,
                 (Z_ARCO + Z_CARGA) / 2.0),
                m["blanco"]))

        # Costado del furgon: UNA caja lisa, de punta a punta, y de Z_ARCO hasta
        # ALTO. Esto es lo que hace la furgoneta: chapa vertical sin huecos ni
        # tablas. Arriba se mete 5 cm dentro del techo y por detras para en
        # Y_PARED_TRAS, de modo que ninguna arista queda coplanar con el techo
        # ni con las hojas de las puertas. Ver HUNDIR_UNION.
        piezas.append(caja(
            "Pared_%s" % lado,
            (GROSOR_LATERAL, Y_TABIQUE - Y_PARED_TRAS, Z_TECHO + 0.05 - Z_ARCO),
            (signo * x_carroce, (Y_TABIQUE + Y_PARED_TRAS) / 2.0,
             (Z_TECHO + 0.05 + Z_ARCO) / 2.0),
            m["blanco"]))

        # Pilar B entre la puerta y el baul.
        piezas.append(caja(
            "PilarB_%s" % lado, (GROSOR_LATERAL, 0.12, Z_TECHO - Z_CINTURON),
            (signo * x_carroce, Y_TABIQUE + 0.06,
             (Z_TECHO + Z_CINTURON) / 2.0),
            m["blanco"]))

        # Guardafango delantero, que llega a la linea del capot.
        piezas.append(caja(
            "Guardafango_%s" % lado,
            (GROSOR_LATERAL, Y_FRENTE - Y_TECHO_DEL, 1.22 - Z_ARCO),
            (signo * x_carroce, (Y_FRENTE + Y_TECHO_DEL) / 2.0,
             (1.22 + Z_ARCO) / 2.0),
            m["blanco"]))

        # Pilar A, el montante del parabrisas.
        piezas.append(barra(
            "PilarA_%s" % lado, 0.10, 0.10,
            (signo * x_carroce, Y_COWL, Z_CINTURON),
            (signo * x_carroce, Y_TECHO_DEL, Z_TECHO),
            m["blanco"]))

        # Piloto trasero en el costado. Ahora la trasera esta cerrada por las
        # hojas, asi que el piloto si tiene sitio.
        piezas.append(caja("Piloto_%s" % lado, (0.05, 0.26, 0.16),
                           (signo * (X_PARED_EXT + 0.025), Y_TRAVESA + 0.34,
                            1.24), m["rojo"]))

        # Retrovisor: brazo y cristal. Ahora que la caja va a lo ancho del coche
        # el brazo tiene que ser CORTO, porque si no los espejos se salen del
        # contrato de anchura: el cristal acaba en 1,09 y el coche mide 2,18.
        # El brazo entra 5 mm dentro del cristal para que su union no sea
        # coplanar, que es el truco de siempre.
        piezas.append(caja("Brazo_espejo_%s" % lado, (0.18, 0.07, 0.06),
                           (signo * (X_PARED_EXT + 0.085), 0.98, 1.26),
                           m["grafito"]))
        piezas.append(caja("Espejo_%s" % lado, (0.05, 0.15, 0.24),
                           (signo * (X_PARED_EXT + 0.185), 0.98, 1.28),
                           m["grafito"]))

    # Tabique: la pared entre baul y cabina. Sube hasta el techo, asi que el
    # baul queda cerrado por delante tambien y hace de habitáculo separado.
    piezas.append(caja("Tabique", (1.58, 0.08, Z_TECHO + 0.05 - Z_CARGA),
                       (0.0, Y_TABIQUE, (Z_TECHO + 0.05 + Z_CARGA) / 2.0),
                       m["grafito"]))

    # Techo CONTINUO: de la trasera a Y_TECHO_DEL, a la misma altura, y con el
    # ancho completo para que remate a ras con los costados. Esta caja es la
    # que convierte el baul en un hueco cerrado por arriba.
    piezas.append(caja("Techo", (2.0 * x_techo, Y_TECHO_DEL - Y_TRAVESA,
                                 ALTO - Z_TECHO),
                       (0.0, (Y_TECHO_DEL + Y_TRAVESA) / 2.0,
                        (ALTO + Z_TECHO) / 2.0), m["blanco"]))

    # Morro corto y redondeado: frontal, capot, rejilla y paragolpes. El capot
    # dura poco, que es lo que hace que la cabina parezca adelantada.
    piezas.append(caja("Frontal", (2.0 * x_carroce - GROSOR_LATERAL, 0.10,
                                   0.46), (0.0, 2.30, 0.67), m["blanco"]))
    piezas.append(barra("Capot", 1.58, 0.08, (0.0, Y_COWL, Z_CINTURON),
                        (0.0, Y_FRENTE_CARA, 0.96), m["blanco"]))
    piezas.append(barra("Parabrisas", 1.58, 0.06, (0.0, Y_COWL, Z_CINTURON),
                        (0.0, Y_TECHO_DEL, Z_TECHO), m["cristal"]))
    # Montante del medio: el parabrisas partido en dos, marca de la epoca. Sin
    # este, el cristal se lee como el de un turismo moderno.
    piezas.append(barra("Montante_Parabrisas", 0.07, 0.07,
                        (0.0, Y_COWL - 0.02, Z_CINTURON + 0.03),
                        (0.0, Y_TECHO_DEL + 0.03, Z_TECHO - 0.02),
                        m["blanco"]))
    piezas.append(caja("Rejilla", (0.86, 0.06, 0.22), (0.0, 2.36, 0.60),
                       m["grafito"]))
    # Faros redondos: el detalle mas inconfundible. Un cilindro con el eje en Y
    # se ve de frente como un circulo perfecto, que es lo que se busca.
    for lado, signo in (("Izq", -1.0), ("Der", 1.0)):
        piezas.append(cilindro("Faro_%s" % lado, 0.13, 0.10,
                               (signo * 0.52, 2.33, 0.88), m["faro"],
                               lados=10, eje="Y"))
        piezas.append(cilindro("Aro_Faro_%s" % lado, 0.15, 0.06,
                               (signo * 0.52, 2.29, 0.88), m["plata"],
                               lados=10, eje="Y"))
    piezas.append(caja("Paragolpes_Del", (X_CARROCE, 0.20, 0.24),
                       (0.0, 2.32, 0.32), m["grafito"]))
    piezas.append(caja("Paragolpes_Tras", (X_CARROCE, 0.16, 0.24),
                       (0.0, Y_TRAVESA + 0.08, 0.32), m["grafito"]))

    # Salpicadero: la cara de arriba es la linea de la cintura. Se queda corto
    # en Y a proposito, para que el aro del volante quede por detras de el y no
    # se solapen: el volante sale de la parte de atras del salpicadero.
    piezas.append(caja("Salpicadero", (1.50, 0.24, 0.30), (0.0, 0.90, 1.01),
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
    _arreglar_malla(chasis)
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

    Aqui es donde estaba el z-fighting de las sombras oscuras, y era por la
    union, no por la puerta: la hoja y el faldon de la carroceria terminaban
    los dos en Z_CARGA, en el mismo plano, y ahi se dibujaban uno encima del
    otro. Por eso el bajo de la hoja sube HOLGURA_HOJA: queda enterrado dentro
    del faldon y las dos caras dejan de coincidir. El resto de la hoja se hunde
    4 cm en el costado, con el mismo truco. Ademas se le pasa _arreglar_malla.
    """
    x = -(X_PUERTA_INT + X_CARROCE) / 2.0
    canto = X_CARROCE - X_PUERTA_INT
    bisagra = Vector((-X_CARROCE, 1.02, 1.00))
    y0, y1 = -0.34, 1.02
    z_vent = 1.88
    z_bajo = Z_CARGA + HOLGURA_HOJA

    piezas = [
        caja("Faldon", (canto, y1 - y0, Z_CINTURON - z_bajo),
             (x, (y0 + y1) / 2.0, (Z_CINTURON + z_bajo) / 2.0), m["blanco"]),
        caja("Marco_Frente", (canto, 0.10, z_vent - Z_CINTURON),
             (x, 0.87, (z_vent + Z_CINTURON) / 2.0), m["blanco"]),
        caja("Marco_Tras", (canto, 0.10, z_vent - Z_CINTURON),
             (x, -0.23, (z_vent + Z_CINTURON) / 2.0), m["blanco"]),
        caja("Marco_Superior", (canto, 1.20, 0.10),
             (x, 0.37, z_vent - 0.05), m["blanco"]),
        caja("Marco_Inferior", (canto, 1.36, 0.06),
             (x, 0.34, Z_CINTURON + 0.03), m["blanco"]),
        caja("Cristal", (0.03, 1.10, 0.56), (x, 0.37, 1.50), m["cristal"]),
        caja("Manija", (0.05, 0.16, 0.05), (x - 0.045, -0.24, 1.10), m["grafito"]),
    ]
    puerta = unir("Puerta_Conductor", piezas, origen=bisagra)
    redondear(puerta, 0.014)
    _arreglar_malla(puerta)
    puerta["abertura_grados"] = 80.0
    puerta["signo_abertura"] = -1.0
    return puerta


def pieza_puerta_trasera(nombre, lado, m):
    """Hoja trasera, con el origen en el BORDE VERTICAL DE AFUERA.

    Son las dos hojas que cierran la trasera, cada una la mitad del ancho, y no
    un porton de caja: la caja esta cerrada y lo que se abre son las dos hojas
    de una furgoneta de reparto. El origen va en el canto de fuera de cada hoja,
    que es la bisagra, para que abran hacia fuera en Z local de 0 a 110 grados.

    La hoja ocupa el plano de la trasera, por DETRAS de los costados, y por eso
    los costados entran 1 cm hacia dentro (Y_PARED_TRAS): si los dos llegaran a
    Y_TRAVESA se pisarian en el canto y apareceria el mismo z-fighting que en la
    puerta del conductor. Arriba y abajo lleva HOLGURA_HOJA para no quedar
    coplanar con el techo ni con el faldon.
    """
    signo = -1.0 if lado == "Izq" else 1.0
    canto = Y_TRAVESA - Y_PUERTA_TRAS_INT
    y = (Y_TRAVESA + Y_PUERTA_TRAS_INT) / 2.0
    z0 = Z_CARGA + HOLGURA_HOJA
    z1 = Z_TECHO - HOLGURA_HOJA
    # Media anchura de la hoja, de la bisagra al centro. Se queda a 1 mm del eje
    # para que las dos hojas no se toquen de canto al cerrar.
    x_hoja = X_CARROCE - 0.001
    x = signo * x_hoja / 2.0
    bisagra = Vector((signo * X_CARROCE, Y_TRAVESA, (z0 + z1) / 2.0))

    piezas = [
        caja("Chapa", (x_hoja, canto, z1 - z0),
             (x, y, (z0 + z1) / 2.0), m["blanco"]),
    ]
    # Un par de nervios por fuera, que es lo que se ve de una hoja de chapa con
    # marco. Van pegados al canto, no embebidos, y por eso no rozan con nada.
    for i, zz in enumerate((z0 + 0.34, z1 - 0.34)):
        piezas.append(caja("Nervio%d" % (i + 1), (0.05, 0.03, z1 - z0 - 0.68),
                           (x, Y_TRAVESA - 0.015, zz), m["grafito"]))
    piezas.append(caja("Manija", (0.05, 0.05, 0.16),
                       (signo * 0.07, Y_TRAVESA - 0.02, (z0 + z1) / 2.0),
                       m["grafito"]))

    puerta = unir(nombre, piezas, origen=bisagra)
    redondear(puerta, 0.014)
    _arreglar_malla(puerta)
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
    # SIN chaflan, y a proposito. En el resto del coche el chaflan es lo que
    # quita el aspecto tosco de las cajas, pero en la rueda se lleva 352 de los
    # 520 triangulos, que son 1.400 de los 5.000 del coche, y no aporta nada:
    # el perfil de la rueda ya lo da el poligono de 12 lados, que es justo el
    # corte low poly que se quiere.
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
    fallos += _informe_cierre(objetos)
    fallos += _informe_transform(objetos)

    print("--- ejes para el juego (aqui Z es arriba) ---")
    print("  ruedas: la vertical es Z, el lateral es X")
    print("           en Godot, sin giro en la escena: direccion = rotation.y,"
          " rodadura = rotation.x")
    for nombre, grados, lado, signo, y_bisagra, x_hoja in PUERTAS:
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
    for nombre, grados, lado, signo, y_bisagra, x_hoja in PUERTAS:
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
                      _distancia_a_la_bisagra(puerta, org, y_bisagra, x_hoja),
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
    """La caja tiene que estar vacia, con el suelo plano, y que quepa la maquina."""
    print("--- caja de carga ---")
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
    # hueco en una rejilla y se mira a que altura para: tiene que
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
    # Y que la desbrozadora quepa. Sin esto, "__el hueco esta vacio__" de arriba
    # queria decir vacio de desbrozadora INCLUIDA, que es justo lo contrario de
    # lo que hace falta. Se mide el hueco contra la maquina con 5 cm de holgura.
    hueco = {"x": CARGA["x"][1] - CARGA["x"][0],
             "y": CARGA["y"][1] - CARGA["y"][0],
             "z": CARGA["z"][1] - CARGA["z"][0]}
    print("  hueco %.2f x %.2f x %.2f m, desbrozadora %.2f x %.2f x %.2f m"
          % (hueco["x"], hueco["y"], hueco["z"], DESBROZADORA["x"],
             DESBROZADORA["y"], DESBROZADORA["z"]))
    for eje in ("x", "y", "z"):
        fallos += _ok("cabe la desbrozadora de ancho, de largo y de alto"
                      if eje == "x" else "  (y por " + eje + ")",
                      hueco[eje] - DESBROZADORA[eje] - 2.0 * HOLGURA_CARGA,
                      0.0, 4.0)
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


# --- Que el furgon este cerrado ---------------------------------------------
# El hueco interior por el que se dispara la rejilla de rayos. Va DESPEGADO de
# las paredes por dentro: los muros de chapa, el tabique y las hojas de la
# trasera estan todos mas alla de estas coordenadas, asi que ningun rayo puede
# empezar ya dentro de un solido (que es cuando ray_cast se hace el loco y no ve
# ni el punto de partida).
#
# X se queda en el ancho del suelo (1,38) y no en el de la chapa: por fuera de la
# plancha no hay suelo, y un rayo hacia abajo ahi sale por debajo, que no es un
# hueco del furgon sino el sitio donde esta la rueda.
# Z empieza en Z_ARCO, por encima de los pasos de rueda, para que los rayos de
# los costados midan la chapa y no se estrella antes contra una rueda.
HUECO_X = (-0.68, 0.68)
HUECO_Y = (-2.30, -0.50)
HUECO_Z = (Z_ARCO + 0.02, Z_TECHO - 0.05)
PASO_REJILLA = 0.08


def _ejes(lo, hi, paso):
    """Los valores de un eje, del centro hacia fuera, en pasos de `paso`."""
    valores = []
    n = int((hi - lo) / paso)
    for i in range(n + 1):
        v = lo + i * paso
        if v > hi + 1e-9:
            break
        valores.append(v)
    return valores


def _rejilla_cierre():
    """Los puntos desde los que sale un rayo, con la direccion de cada uno.

    Se barre cada CARA del hueco con una rejilla, no con un punto suelto: seis
    rayos por punto se dejan pasar un agujero de milagro, y un agujero de milagro
    es justo el fallo que este test existe para cazar. Con la rejilla, un trozo
    de pared que falte se ve siempre, porque el hueco tiene tamano y los rayos
    barren toda la superficie.
    """
    xs = _ejes(*HUECO_X, PASO_REJILLA)
    ys = _ejes(*HUECO_Y, PASO_REJILLA)
    zs = _ejes(*HUECO_Z, PASO_REJILLA)
    y_medio = (HUECO_Y[0] + HUECO_Y[1]) / 2.0
    disparos = []
    for z in zs:                      # techo y suelo
        for x in xs:
            for y in ys:
                disparos.append(((x, y, z), (0.0, 0.0, 1.0)))
                disparos.append(((x, y, z), (0.0, 0.0, -1.0)))
    for z in zs:                      # costados
        for y in ys:
            disparos.append(((0.0, y, z), (1.0, 0.0, 0.0)))
            disparos.append(((0.0, y, z), (-1.0, 0.0, 0.0)))
    for z in zs:                      # tabique delante y las dos hojas detras
        for x in xs:
            disparos.append(((x, y_medio, z), (0.0, 1.0, 0.0)))
            disparos.append(((x, y_medio, z), (0.0, -1.0, 0.0)))
    return disparos


def _informe_cierre(objetos):
    """Comprueba que la caja de carga no tiene ni un hueco.

    Dos cosas, y las dos se miran desde DENTRO del baul:

    1. Que la caja llegue a la misma altura que la cabina. Si el techo de la
       carga se queda mas abajo, el baul no es un furgon sino una caja con
       techo a medio hacer, aunque por fuera no se note tanto.

    2. Que no se escape ni un rayo. Se barre con una rejilla las seis caras del
       hueco y tiene que rebotar en algo en TODOS los disparos. Un rayo que sale
       de viaje por un lado es, literalmente, un hueco: por ahi entra la lluvia.
       Es la comprobacion que de verdad distingue un furgon de una caja abierta
       con las paredes puestas, y por eso mira tambien hacia abajo, que es donde
       se cuelan los agujeros en el suelo.
    """
    print("--- cierre del furgon ---")
    fallos = 0
    chasis = objetos.get("Chasis")

    # 1. La caja tiene que subir hasta la linea de la cabina.
    z_caja = -1e9
    z_cabina = -1e9
    for v in chasis.data.vertices:
        mundo = chasis.matrix_world @ v.co
        if mundo.y < Y_TABIQUE:
            z_caja = max(z_caja, mundo.z)
        else:
            z_cabina = max(z_cabina, mundo.z)
    print("  techo de la carga en z = %.3f, techo de la cabina en z = %.3f"
          % (z_caja, z_cabina))
    if abs(z_caja - z_cabina) <= TOLERANCIA * 10.0:
        print("  [OK] la caja llega a la misma altura que la cabina")
    else:
        print("  [FALLO] la caja para en z = %.3f y la cabina llega a"
              " z = %.3f: el baul no cierra por arriba" % (z_caja, z_cabina))
        fallos += 1

    # 2. Ningun rayo puede salirse del baul.
    contexto = bpy.context.evaluated_depsgraph_get()
    depsgraph = contexto.view_layer.depsgraph
    disparos = _rejilla_cierre()
    fugas = []
    donde = {}
    for punto, d in disparos:
        ok, _loc, _nrm, _idx, objeto, _matriz = contexto.scene.ray_cast(
            depsgraph, Vector(punto), Vector(d))
        if ok:
            donde[objeto.name] = donde.get(objeto.name, 0) + 1
        else:
            fugas.append((punto, d))
    print("  %d rayos barriendo las seis caras del hueco interior"
          % len(disparos))
    print("  rebotan en: %s" % ", ".join("%s (%d)" % (nombre, n)
                                         for nombre, n in sorted(donde.items())))
    if fugas:
        for punto, d in fugas[:12]:
            print("  [FALLO] hueco: por (%.2f, %.2f, %.2f) se escapa un rayo"
                  " hacia (%.0f, %.0f, %.0f)" % (punto + d))
        if len(fugas) > 12:
            print("  [FALLO] ... y %d fugas mas" % (len(fugas) - 12))
        fallos += 1
    else:
        print("  [OK] techo, costados, tabique, puertas y suelo sin huecos")
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


def _distancia_a_la_bisagra(ob, org, y_bisagra, x_hoja):
    """Cuanto se aparta el origen de donde tiene que estar la bisagra.

    La bisagra es una recta VERTICAL, y el origen tiene que caer en ella: en
    la cara de fuera de la hoja, en el canto que abre (la Y del borde de
    delante del conductor, la de atras en los portones) y dentro de la altura
    de la hoja. Se mide cada cosa y se queda con la peor, que es la que haria
    que la puerta no abriera del todo.

    La cara de fuera se pasa como x_hoja y NO como una constante, porque ahora
    la puerta del conductor cuelga de la cabina estrecha y los portones de la
    caja ancha: cada hoja tiene la suya y las dos son distintas.

    No se mide contra el cubo que envuelve la hoja, porque la manija asoma
    4 cm por fuera de la piel y con el cubo la bisagra pareceria estar mal
    puesta cuando esta perfectamente.
    """
    mn, mx, _ = _caja_de(ob)
    return max(abs(abs(org.x) - x_hoja),
               abs(org.y - y_bisagra),
               max(0.0, mn[2] - org.z, org.z - mx[2]))


def _ok(etiqueta, valor, minimo, maximo):
    bien = minimo <= valor <= maximo
    print("  [%s] %s = %.4f (se espera entre %.4f y %.4f)"
          % ("OK" if bien else "FALLO", etiqueta, valor, minimo, maximo))
    return 0 if bien else 1


if __name__ == "__main__":
    sys.exit(main())
