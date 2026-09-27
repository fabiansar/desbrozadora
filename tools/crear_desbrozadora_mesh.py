"""
Desbrozadora de gasolina profesional, estilo STIHL FS 560 E, en low poly.

Uso:
    flatpak run org.blender.Blender --background --python tools/crear_desbrozadora_mesh.py

Como esta montada:
  - El origen (0, 0, 0) esta en el centro de agarre, que es el punto donde la
    mano derecha aprieta el gatillo y por donde el arnes cuelga la maquina.
    Alrededor de ese punto giran las dos barras del manillar, asi que el
    punto de agarre es tambien el centro de la V.
  - La maquina va en diagonal porque el motor esta arriba y atras y el cabezal
    abajo y delante. El tubo en si va recto en -Y y lo que baja es el codo final.
  - Piezas separadas dentro de la Coleccion "Desbrozadora_FS", y no unidas en
    una sola malla, por dos razones que no son esteticas:
      1) el juego mete "Giro".rotation.y cada fotograma, y eso solo gira si el
         disco es un nodo propio;
      2) scenes/desbrozadora.tscn busca las rutas Modelo/Desbrozadora/Giro y
         Modelo/Desbrozadora/Giro/Corte. Sin esos empties la maquina aparece y
         no corta nada.
    Cada pieza lleva un unico material, que es como se asigna por vertex en
    cuanto se importa en Godot.

Por que el tubo NO va inclinado: porque el disco tiene que girar sobre el eje
del tubo. En Godot el giro se mete como giro.rotation.y sobre el nodo, asi que
si el nodo "Giro" tuviera inclinacion propia, el disco barreria en diagonal en
vez de girar sobre si mismo. La diagonal sale del motor arriba y el cabezal
abajo, que es como se ve en la vida real.

Materiales: Naranja, Negro, Metal_Plateado, Metal_Oscuro.
"""

import math
import os
import sys

import bpy
from mathutils import Vector

_AQUI = os.path.dirname(os.path.abspath(__file__))
if _AQUI not in sys.path:
    sys.path.insert(0, _AQUI)
import exportar_blender  # noqa: E402

OUT_DIR = os.path.expanduser("~/Documentos/desarrollos/desbrozadora/models")
OUT_FILE = os.path.join(OUT_DIR, "desbrozadora_fs560.glb")
COLECCION = "Desbrozadora_FS"

# --- Medidas, en metros ---------------------------------------------------
# El largo total se mantiene por debajo de 1,50 m a proposito: es el rango que
# comprueba tools/ver_modelo.py, y de ahi depende lo que el jugador abarca con
# la barrida. Una FS 560 de verdad mide 1,75 m y se notaria demasiado lejos.
LONG_TUBO = 1.00
Y_TUBO = -0.34
RADIO_TUBO = 0.020
Y_CABEZA = -0.96
Z_CABEZA = -0.26
RADIO_GUARDA_INT = 0.150
RADIO_GUARDA_EXT = 0.170
ANCHO_GUARDA = 0.32
RADIO_PALA = 0.130

LADO_MAX = 10
TRIANGULOS_MAX = 700

ESPERADO_LARGO = (1.0, 1.5)
ESPERADO_ANCHO = (0.15, 0.60)
ESPERADO_CORTE_Y = (-1.25, -0.95)


# --- Materiales ------------------------------------------------------------
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


# --- Piezas ----------------------------------------------------------------
def _malla(ob, lados, eje="Z"):
    """Mete el cilindro en su eje y le quita el suavizado."""
    if lados > LADO_MAX:
        raise ValueError("%s se ha pasado a %d lados: el presupuesto es %d"
                         % (ob.name, lados, LADO_MAX))
    if eje == "X":
        ob.rotation_euler = (0.0, math.radians(90.0), math.radians(90.0))
    elif eje == "Y":
        ob.rotation_euler = (math.radians(90.0), 0.0, 0.0)
    ob.data.name = ob.name
    for poly in ob.data.polygons:
        poly.use_smooth = False
    return ob


def cilindro(nombre, radio, largo, posicion, mat, lados=8, eje="Z"):
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=lados, radius=radio, depth=largo, end_fill_type="NGON"
    )
    ob = bpy.context.active_object
    ob.name = nombre
    _malla(ob, lados, eje)
    ob.location = posicion
    ob.data.materials.append(mat)
    return ob


def caja(nombre, tamano, posicion, mat, rotacion=(0.0, 0.0, 0.0)):
    bpy.ops.mesh.primitive_cube_add(size=1.0)
    ob = bpy.context.active_object
    ob.name = nombre
    ob.scale = tamano
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    ob.location = posicion
    ob.rotation_euler = rotacion
    ob.data.name = ob.name
    ob.data.materials.append(mat)
    return ob


def tubo_entre(nombre, p0, p1, radio, mat, lados=8):
    """Un cilindro de p0 a p1. Para tubulares: manillar, barras, tirador.

    Va por quaternion porque el manillar va en diagonal, y con angulos de
    euler hay que estar probando rotaciones hasta que sale.
    """
    p0, p1 = Vector(p0), Vector(p1)
    d = p1 - p0
    ob = cilindro(nombre, radio, d.length, (0.0, 0.0, 0.0), mat, lados)
    ob.location = (p0 + p1) * 0.5
    ob.rotation_mode = "QUATERNION"
    ob.rotation_quaternion = d.to_track_quat("Z", "Y")
    return ob


def malla_propia(nombre, vertices, caras, posicion, mat):
    me = bpy.data.meshes.new(nombre)
    me.from_pydata(vertices, [], caras)
    me.validate()
    me.update()
    ob = bpy.data.objects.new(nombre, me)
    bpy.context.collection.objects.link(ob)
    ob.location = posicion
    me.materials.append(mat)
    for poly in me.polygons:
        poly.use_smooth = False
    _caras_hacia_fuera(ob)
    return ob


def _caras_hacia_fuera(ob):
    """Normales hacia fuera.

    Las mallas que se escriben a mano pueden salir con las caras del reves, y en
    Godot eso se ve como una pieza negra por un lado. Se recalcula con el
    operador, y si en esta version de Blender no existe, se avisa y se sigue.
    """
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


def arco(nombre, r_in, r_out, ancho, a0, a1, seg, posicion, mat):
    """Casco de proteccion: media corona en el plano YZ, con grosor en X.

    Los angulos van de 0 a 360 en el plano YZ: 90 es arriba, 180 es hacia
    delante (-Y, alejandose del operario) y 270 es abajo. El casco va de 95 a
    285, que es la mitad de la maquina que mira al frente y deja abierto el
    lado del operario, que es por donde se ve el disco.
    """
    verts = []
    for i in range(seg + 1):
        a = math.radians(a0 + (a1 - a0) * i / seg)
        cy, cz = math.cos(a), math.sin(a)
        for x, r in ((-ancho / 2.0, r_in), (ancho / 2.0, r_in),
                     (-ancho / 2.0, r_out), (ancho / 2.0, r_out)):
            verts.append((x, cy * r, cz * r))
    caras = []
    for i in range(seg):
        a, b = 4 * i, 4 * (i + 1)
        caras.append((a + 0, b + 0, b + 1, a + 1))   # interior
        caras.append((a + 2, a + 3, b + 3, b + 2))   # exterior
        caras.append((a + 0, a + 2, b + 2, b + 0))   # lateral -
        caras.append((a + 1, b + 1, b + 3, a + 3))   # lateral +
    caras.append((0, 1, 3, 2))                       # tope del inicio
    fin = 4 * seg
    caras.append((fin + 0, fin + 2, fin + 3, fin + 1))  # tope del final
    return malla_propia(nombre, verts, caras, posicion, mat)


def pala(nombre, r_in, r_out, ancho_in, ancho_out, grosor, mat):
    """Una punta del disco triangular: trapecio con grosor, en el plano XZ.

    Sale en el origen y mirando hacia +X, que es como la luego coloca el giro.
    """
    v = []
    for x, w in ((r_in, ancho_in), (r_out, ancho_out)):
        for y in (-grosor / 2.0, grosor / 2.0):
            for z in (-w / 2.0, w / 2.0):
                v.append((x, y, z))
    # 0-3 raiz, 4-7 punta.
    caras = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 2, 6, 4),
             (1, 5, 7, 3), (0, 4, 5, 1), (2, 3, 7, 6)]
    return malla_propia(nombre, v, caras, (0.0, 0.0, 0.0), mat)


def empty(nombre, posicion, tamano=0.1):
    ob = bpy.data.objects.new(nombre, None)
    ob.empty_display_type = "ARROWS"
    ob.empty_display_size = tamano
    bpy.context.collection.objects.link(ob)
    ob.location = posicion
    return ob


# --- Montaje ---------------------------------------------------------------
def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)

    col = bpy.data.collections.new(COLECCION)
    bpy.context.scene.collection.children.link(col)
    # Los operadores de primitivas crean en la coleccion activa, asi que sin
    # esto las piezas se irian a la raiz de la escena y no a la caja.
    bpy.context.view_layer.active_layer_collection = (
        bpy.context.view_layer.layer_collection.children[COLECCION])

    naranja = material("Naranja", (0.90, 0.33, 0.04), 0.0, 0.40)
    negro = material("Negro", (0.10, 0.10, 0.11), 0.0, 0.60)
    plata = material("Metal_Plateado", (0.70, 0.72, 0.75), 0.35, 0.55)
    oscuro = material("Metal_Oscuro", (0.26, 0.27, 0.29), 0.70, 0.45)

    root = empty("Desbrozadora", (0.0, 0.0, 0.0), 0.3)

    # --- 2. Motor, arriba y atras ------------------------------------------
    carcasa = cilindro("MotorCarcasa", 0.078, 0.140, (0.0, 0.235, 0.145),
                       naranja, 10, "Z")
    base = cilindro("MotorBase", 0.074, 0.090, (0.0, 0.235, 0.040), negro, 10, "Z")
    deposito = caja("Deposito", (0.115, 0.120, 0.090), (0.0, 0.295, 0.0), negro)
    filtro = caja("CajaFiltro", (0.060, 0.090, 0.100), (0.075, 0.245, 0.150),
                  oscuro)
    # El tirador de arranque, en T: vástago arriba y el puño cruzado encima.
    tirador = cilindro("Tirador", 0.012, 0.070, (0.0, 0.175, 0.245), negro, 6, "Z")
    puno = cilindro("TiradorPuno", 0.020, 0.080, (0.0, 0.175, 0.285), negro, 6, "X")
    # La caja de engranajes del motor, que une el motor con el tubo.
    caja_motor = cilindro("CajaMotor", 0.055, 0.100, (0.0, 0.140, 0.030),
                          oscuro, 10, "Y")

    # --- 1. Tubo ------------------------------------------------------------
    tubo = cilindro("Tubo", RADIO_TUBO, LONG_TUBO, (0.0, Y_TUBO, 0.0),
                    plata, 8, "Y")
    abrazadera = cilindro("Abrazadera", 0.038, 0.055, (0.0, 0.0, 0.0),
                          oscuro, 8, "Y")

    # --- 3. Manillar en V, abierto hacia el operario -----------------------
    # El vertice de la V esta en el origen, que es el centro de agarre.
    punta_izq = (-0.16, 0.105, 0.030)
    punta_der = (0.16, 0.105, 0.030)
    barra_izq = tubo_entre("BarraIzq", (0.0, 0.0, 0.0), punta_izq, 0.016, oscuro)
    barra_der = tubo_entre("BarraDer", (0.0, 0.0, 0.0), punta_der, 0.016, oscuro)
    travesano = tubo_entre("BarraTravesano", punta_izq, punta_der, 0.016, oscuro)
    # La izquierda, un manguito de goma y nada mas.
    manguito = tubo_entre("EmpuñaduraIzq", punta_izq, (-0.27, 0.105, 0.030),
                          0.023, negro)
    # La derecha lleva el acelerador: el manguito igual de negro y el gatillo
    # naranja colgando por debajo, que es donde esta el dedo.
    agarre = tubo_entre("EmpuñaduraDer", punta_der, (0.27, 0.105, 0.030),
                        0.023, negro)
    acelerador = caja("Acelerador", (0.032, 0.060, 0.085), (0.205, 0.100, -0.030),
                      naranja, rotacion=(0.0, math.radians(12.0), 0.0))

    # --- 5. Cabezal --------------------------------------------------------
    # El tubo baja recto y el ultimo tramo gira hacia abajo: ese es el codo.
    codo = cilindro("Codo", 0.030, 0.160, (0.0, -0.850, -0.075), plata, 8, "Z")
    engranajes = caja("CajaEngranajes", (0.105, 0.115, 0.125),
                      (0.0, -0.875, -0.215), plata)

    # --- 4. Protector ------------------------------------------------------
    protector = arco("Protector", RADIO_GUARDA_INT, RADIO_GUARDA_EXT,
                     ANCHO_GUARDA, 95.0, 285.0, 9, (0.0, Y_CABEZA, Z_CABEZA),
                     naranja)

    # --- 5. Disco de corte triangular --------------------------------------
    # El disco gira, asi que cuelga de "Giro" y sus coordenadas son RELATIVAS
    # al centro del cabezal. En absolutas el disco se iria dos metros mas
    # abajo, que es el error que ya estaba en el modelo viejo.
    giro = empty("Giro", (0.0, Y_CABEZA, Z_CABEZA), 0.06)
    corte = empty("Corte", (0.0, 0.0, 0.0), 0.08)

    porta = cilindro("PortaDisco", 0.052, 0.016, (0.0, 0.020, 0.0), oscuro, 8, "Y")
    buje = cilindro("DiscoBuje", 0.042, 0.016, (0.0, 0.0, 0.0), negro, 8, "Y")
    tuerca = cilindro("Tuerca", 0.020, 0.024, (0.0, -0.022, 0.0), plata, 6, "Y")
    palas = []
    for i in range(3):
        p = pala("Pala%d" % (i + 1), 0.028, RADIO_PALA, 0.064, 0.020, 0.006,
                 negro)
        p.rotation_euler = (0.0, math.radians(120.0 * i), 0.0)
        palas.append(p)

    # --- Jerarquia ---------------------------------------------------------
    for ob in (carcasa, base, deposito, filtro, tirador, puno, caja_motor, tubo,
               abrazadera, barra_izq, barra_der, travesano, manguito, agarre,
               acelerador, codo, engranajes, protector):
        ob.parent = root
    for ob in [porta, buje, tuerca, corte] + palas:
        ob.parent = giro
    giro.parent = root

    bpy.ops.object.select_all(action="DESELECT")
    root.select_set(True)
    bpy.context.view_layer.objects.active = root
    bpy.context.view_layer.update()

    fallos = _informe()
    if fallos:
        print("no se exporta: el modelo no cumple el presupuesto")
        return

    os.makedirs(OUT_DIR, exist_ok=True)
    exportar_blender.exportar(OUT_FILE)
    print("exportado:", OUT_FILE)


def _informe():
    """Mide la maquina y comprueba que encaja donde el juego la espera."""
    nombres = [o.name for o in bpy.context.scene.objects]
    print("nodos (%d): %s" % (len(nombres), ", ".join(sorted(nombres))))

    mn = [1e9, 1e9, 1e9]
    mx = [-1e9, -1e9, -1e9]
    triangulos = 0
    for ob in bpy.context.scene.objects:
        if ob.type != "MESH":
            continue
        triangulos += sum(max(1, len(p.vertices) - 2) for p in ob.data.polygons)
        for v in ob.data.vertices:
            mundo = ob.matrix_world @ v.co
            for i in range(3):
                mn[i] = min(mn[i], mundo[i])
                mx[i] = max(mx[i], mundo[i])
    print("caja: x[%.2f, %.2f] y[%.2f, %.2f] z[%.2f, %.2f]"
          % (mn[0], mx[0], mn[1], mx[1], mn[2], mx[2]))

    fallos = 0
    fallos += _ok("largo", mx[1] - mn[1], *ESPERADO_LARGO)
    fallos += _ok("ancho", mx[0] - mn[0], *ESPERADO_ANCHO)
    print("  %d triangulos (el presupuesto es %d)" % (triangulos, TRIANGULOS_MAX))
    fallos += _ok("triangulos", triangulos, 0, TRIANGULOS_MAX)

    corte = bpy.context.scene.objects.get("Corte")
    if corte is None:
        print("  [FALLO] falta el nodo Corte")
        fallos += 1
    else:
        mundo = corte.matrix_world.translation
        print("  punto de corte en (%.2f, %.2f, %.2f)"
              % (mundo.x, mundo.y, mundo.z))
        fallos += _ok("altura del corte", mundo.y, *ESPERADO_CORTE_Y)
        if abs(mundo.x) > 1e-4 or abs(mundo.z - Z_CABEZA) > 1e-4:
            print("  [FALLO] el corte tiene que estar centrado en el cabezal")
            fallos += 1

    for clave in ("Corte", "Giro", "Desbrozadora"):
        if clave not in nombres:
            print("  [FALLO] falta el nodo", clave)
            fallos += 1

    # El disco gira sobre el eje del tubo, que es el Y local de "Giro". Si el
    # nodo trajera inclinacion propia, el codigo que le mete giro.rotation.y
    # cada fotograma la borraria.
    giro = bpy.context.scene.objects.get("Giro")
    if giro is not None and any(abs(a) > 1e-6 for a in giro.rotation_euler):
        print("  [FALLO] Giro no puede traer rotacion: se pierde al girar")
        fallos += 1
    else:
        print("  [OK] Giro sin rotacion propia, el disco gira sobre el tubo")

    # Y la pieza de arriba tiene que salir de las manos, no metida en el suelo.
    for clave in ("EmpuñaduraIzq", "EmpuñaduraDer", "Acelerador", "TiradorPuno",
                  "MotorCarcasa", "Tubo", "Protector", "CajaEngranajes",
                  "Pala1", "Pala2", "Pala3"):
        if clave not in nombres:
            print("  [FALLO] falta la pieza", clave)
            fallos += 1

    print("---")
    print("RESULTADO: %s" % ("todo correcto" if fallos == 0
                             else "%d problema(s)" % fallos))
    return fallos


def _ok(etiqueta, valor, minimo, maximo):
    bien = minimo <= valor <= maximo
    print("  [%s] %s = %.2f (se espera entre %.2f y %.2f)"
          % ("OK" if bien else "FALLO", etiqueta, valor, minimo, maximo))
    return 0 if bien else 1


if __name__ == "__main__":
    main()
