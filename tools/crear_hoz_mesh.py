"""
Hoz de desbroce manual, low poly.

La otra herramienta del juego. La desbrozadora corta por debajo de la cintura
con motor; esta es para lo de cerca y lo fino, y es lo que se lleva en la mano
cuando no quieres gastar gasolina ni despertar a todo el prado.

Que sea una HOZ y no un cuchillo curvo es lo unico que tiene que leerse bien:
mango corto de madera, virola metalica, y una hoja curva en media luna con el
filo por dentro, que es la silueta que la gente reconoce de una vez. Va en unos
120 triangulos, que es lo que se ve en primera persona sin mirar de cerca.

Uso:
    flatpak run --filesystem=$HOME/Documentos org.blender.Blender --background \
        --python tools/crear_hoz_mesh.py
    Las rutas van absolutas: el flatpak arranca Blender en su propio directorio
    y no encuentra el proyecto con rutas relativas.

La jerarquia, en models/hoz.glb, y SOLO estos nombres:
    Hoz    empty en el (0, 0, 0), en la base del mango
      Mango  el mango de madera
      Virola  la virola metalica que une mango y hoja
      Hoja  la hoja curva, con la Y hacia delante y la Z hacia arriba

Las tres reglas que el juego da por buenas, y como se comprueban:
  1. NINGUN nodo lleva rotacion propia: toda la inclinacion esta COCIDA en la
     malla. Es lo mismo que exige la desbrozadora, y es la unica forma de que
     las rotaciones del juego no se sumen a una inclinacion previa.
  2. La hoja apunta hacia +Y (delante en el mundo del juego) y el filo queda
     por dentro de la curva, mirando a la mano.
  3. El origen del conjunto esta en la BASE del mango, que es donde se agarra,
     para que al equiparla solo haya que colocar el nodo y nada mas.
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

PROJECT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(PROJECT_DIR, "models")
OUT_FILE = os.path.join(OUT_DIR, "hoz.glb")

# --- Medidas, en metros ---------------------------------------------------
# Z arriba, +Y hacia delante, +X hacia la derecha. En Godot, al exportar con
# export_yup, la Y de aqui pasa a ser -Z, o sea "delante" mirando al frente.
LARGO_MANGO = 0.26      # del origen a donde arranca la hoja
RADIO_MANGO = 0.021
RADIO_PUNTO = 0.017
LADOS_MANGO = 8

RADIO_HOJA = 0.17       # el radio de la media luna
ANGULO_HOJA = math.radians(148.0)   # cuanto barre la hoja antes de la punta
TROZOS_HOJA = 9
GROSOR_HOJA = 0.006
ANCHO_HOJA = 0.036      # de canto, en X
ANCHO_PUNTA = 0.016     # la hoja se afila hacia la punta
GROSOR_PUNTA = 0.0025

LARGO_VIROLA = 0.045
RADIO_VIROLA = 0.024


def limpiar():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def material(nombre, color, rugosidad, metalico):
    mat = bpy.data.materials.new(nombre)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (color[0], color[1], color[2], 1.0)
    bsdf.inputs["Roughness"].default_value = rugosidad
    bsdf.inputs["Metallic"].default_value = metalico
    return mat


def malla_de(nombre, caras, material_nombre, coleccion):
    """Crea una malla a partir de una lista de caras (listas de Vector).

    Se soldan los vertices repetidos al pasarlos: la hoja se construye trozo a
    trozo y cada trozo repite los puntos del anterior, asi que sin soldar sale
    una malla con las costuras abiertas y la mitad de vertices duplicados.
    """
    me = bpy.data.meshes.new(nombre)
    indices = {}
    vertices = []
    triangulos = []
    for cara in caras:
        fila = []
        for v in cara:
            clave = (round(v.x, 6), round(v.y, 6), round(v.z, 6))
            if clave not in indices:
                indices[clave] = len(vertices)
                vertices.append(clave)
            fila.append(indices[clave])
        triangulos.append(fila)
    me.from_pydata(vertices, [], triangulos)
    me.validate()
    me.update()
    ob = bpy.data.objects.new(nombre, me)
    ob.data.materials.append(material_nombre)
    coleccion.objects.link(ob)
    return ob


def cuadrilatero(malla, a, b, c, d):
    """Anade un cuadrilatero como dos triangulos, con la normal hacia fuera."""
    malla.append([a, b, c])
    malla.append([a, c, d])


def _anillo(centro, radio, lados, angulo_inicio, angulo_fin, eje="Y"):
    """Puntos de un circulo en el plano que se le pida.

    La hoja se dibuja en el plano YZ (avance y altura) porque es donde se curva
    de verdad; el mango es un cilindro y da igual el plano en que se genere.
    """
    puntos = []
    for i in range(lados):
        t = angulo_inicio + (angulo_fin - angulo_inicio) * (float(i) / (lados - 1))
        if eje == "YZ":
            puntos.append((centro.x, centro.y + radio * math.cos(t),
                           centro.z + radio * math.sin(t)))
        else:
            puntos.append((centro.x + radio * math.cos(t), centro.y,
                           centro.z + radio * math.sin(t)))
    return [Vector(p) for p in puntos]


def construir_mango(coleccion, mat):
    """Mango: un cono de 8 lados, del origen hasta arriba. Va sobre el eje Z."""
    caras = []
    abajo = [Vector((math.cos(t) * RADIO_MANGO, math.sin(t) * RADIO_MANGO, 0.0))
             for t in _angulos(LADOS_MANGO)]
    arriba = [Vector((math.cos(t) * RADIO_PUNTO, math.sin(t) * RADIO_PUNTO,
                      LARGO_MANGO)) for t in _angulos(LADOS_MANGO)]
    for i in range(LADOS_MANGO):
        j = (i + 1) % LADOS_MANGO
        cuadrilatero(caras, abajo[i], abajo[j], arriba[j], arriba[i])
    cuadrilatero(caras, arriba[0], arriba[1], arriba[2], arriba[3])
    cuadrilatero(caras, arriba[4], arriba[5], arriba[6], arriba[7])
    cuadrilatero(caras, abajo[0], abajo[1], abajo[2], abajo[3])
    cuadrilatero(caras, abajo[4], abajo[5], abajo[6], abajo[7])
    return malla_de("Mango", caras, mat, coleccion)


def construir_virola(coleccion, mat):
    """Virola: el casquillo metalico entre el mango y la hoja."""
    caras = []
    z0 = LARGO_MANGO - LARGO_VIROLA
    abajo = [Vector((math.cos(t) * RADIO_VIROLA, math.sin(t) * RADIO_VIROLA, z0))
             for t in _angulos(LADOS_MANGO)]
    arriba = [Vector((math.cos(t) * (RADIO_VIROLA - 0.002),
                      math.sin(t) * (RADIO_VIROLA - 0.002), LARGO_MANGO))
              for t in _angulos(LADOS_MANGO)]
    for i in range(LADOS_MANGO):
        j = (i + 1) % LADOS_MANGO
        cuadrilatero(caras, abajo[i], abajo[j], arriba[j], arriba[i])
    cuadrilatero(caras, arriba[0], arriba[1], arriba[2], arriba[3])
    cuadrilatero(caras, arriba[4], arriba[5], arriba[6], arriba[7])
    cuadrilatero(caras, abajo[0], abajo[1], abajo[2], abajo[3])
    cuadrilatero(caras, abajo[4], abajo[5], abajo[6], abajo[7])
    return malla_de("Virola", caras, mat, coleccion)


def construir_hoja(coleccion, mat):
    """Hoja: media luna solida, con el grosor metido dentro.

    Se recorre el arco y en cada trozo se pone un bloque de caras: canto
    exterior, canto interior, cara de arriba y cara de abajo. Los dos cantos se
    estrechan y adelgazan hacia la punta, que es lo que hace que se lea como un
    filo y no como un tubo cortado.
    """
    # El centro de la media luna esta ABAJO y atras de donde arranca la hoja, de
    # modo que la hoja arranca verticalmente en lo alto del mango y se va
    # doblando hacia delante.
    centro = Vector((0.0, LARGO_MANGO, -RADIO_HOJA))
    caras = []
    for i in range(TROZOS_HOJA - 1):
        t0 = (ANGULO_HOJA) * (float(i) / (TROZOS_HOJA - 1))
        t1 = (ANGULO_HOJA) * (float(i + 1) / (TROZOS_HOJA - 1))
        p0 = centro + Vector((0.0, math.cos(t0), math.sin(t0))) * RADIO_HOJA
        p1 = centro + Vector((0.0, math.cos(t1), math.sin(t1))) * RADIO_HOJA
        # La direccion del canto: del centro hacia fuera, en el plano de la hoja.
        d0 = (p0 - centro).normalized()
        d1 = (p1 - centro).normalized()
        f0 = float(i) / (TROZOS_HOJA - 1)
        f1 = float(i + 1) / (TROZOS_HOJA - 1)
        ancho0 = _interp(ANCHO_HOJA, ANCHO_PUNTA, f0) * 0.5
        ancho1 = _interp(ANCHO_HOJA, ANCHO_PUNTA, f1) * 0.5
        grosor0 = _interp(GROSOR_HOJA, GROSOR_PUNTA, f0) * 0.5
        grosor1 = _interp(GROSOR_HOJA, GROSOR_PUNTA, f1) * 0.5
        # El filo va por el lado de DENTRO de la curva (hacia el centro), y el
        # lomo por el de fuera. Por eso el interior se adelgaza mas: el corte
        # entra hacia la mano.
        i0 = p0 - d0 * (RADIO_HOJA - grosor0 * 2.0)
        i1 = p1 - d1 * (RADIO_HOJA - grosor1 * 2.0)
        # Caras de arriba y de abajo (la "altura" de la hoja es el eje X).
        cuadrilatero(caras,
                     i0 + Vector((-ancho0, 0, 0)), i1 + Vector((-ancho1, 0, 0)),
                     p1 + Vector((-ancho1, 0, 0)), p0 + Vector((-ancho0, 0, 0)))
        cuadrilatero(caras,
                     p0 + Vector((ancho0, 0, 0)), p1 + Vector((ancho1, 0, 0)),
                     i1 + Vector((ancho1, 0, 0)), i0 + Vector((ancho0, 0, 0)))
        # Canto exterior (el lomo) y canto interior (el filo).
        cuadrilatero(caras,
                     p0 + Vector((-ancho0, 0, 0)), p1 + Vector((-ancho1, 0, 0)),
                     p1 + Vector((ancho1, 0, 0)), p0 + Vector((ancho0, 0, 0)))
        cuadrilatero(caras,
                     i0 + Vector((ancho0, 0, 0)), i1 + Vector((ancho1, 0, 0)),
                     i1 + Vector((-ancho1, 0, 0)), i0 + Vector((-ancho0, 0, 0)))
    # Tapa del arranque, para que no se vea el hueco al mirar la hoja de canto.
    p0 = centro + Vector((0.0, math.cos(0.0), math.sin(0.0))) * RADIO_HOJA
    cuadrilatero(caras,
                 p0 + Vector((-ANCHO_HOJA * 0.5, 0, 0)),
                 p0 + Vector((ANCHO_HOJA * 0.5, 0, 0)),
                 p0 - Vector((0.0, 0.0, GROSOR_HOJA)),
                 p0 - Vector((0.0, GROSOR_HOJA, 0.0)))
    return malla_de("Hoja", caras, mat, coleccion)


def _angulos(lados):
    return [2.0 * math.pi * float(i) / float(lados) for i in range(lados)]


def _interp(a, b, t):
    return a + (b - a) * t


def _montar():
    limpiar()
    escena = bpy.context.scene
    raiz = bpy.data.objects.new("Hoz", None)
    escena.collection.objects.link(raiz)

    madera = material("Madera", (0.36, 0.22, 0.11), 0.85, 0.0)
    acero = material("Acero", (0.62, 0.64, 0.68), 0.35, 0.9)

    piezas = [construir_mango(escena.collection, madera),
              construir_virola(escena.collection, acero),
              construir_hoja(escena.collection, acero)]
    for pieza in piezas:
        pieza.parent = raiz
    bpy.context.view_layer.update()
    return _informe(raiz)


def _informe(raiz):
    objetos = bpy.context.scene.objects
    nombres = sorted(o.name for o in objetos)
    print("nodos (%d): %s" % (len(nombres), ", ".join(nombres)))

    fallos = 0
    for nombre in ("Hoz", "Mango", "Virola", "Hoja"):
        if nombre not in nombres:
            print("  [FALLO] falta el nodo %s" % nombre)
            fallos += 1

    mn = [1e9, 1e9, 1e9]
    mx = [-1e9, -1e9, -1e9]
    triangulos = 0
    for ob in objetos:
        if ob.type != "MESH":
            continue
        triangulos += sum(max(1, len(p.vertices) - 2) for p in ob.data.polygons)
        for v in ob.data.vertices:
            for eje in range(3):
                mn[eje] = min(mn[eje], v.co[eje])
                mx[eje] = max(mx[eje], v.co[eje])
    print("  triangulos: %d" % triangulos)
    print("  medidas: %.3f x %.3f x %.3f m" % (mx[0] - mn[0], mx[1] - mn[1],
                                              mx[2] - mn[2]))

    # 1. El origen esta en la BASE DEL MANGO, que es donde se agarra. Se mira el
    #    mango y no el conjunto entero porque la hoja se va por debajo del
    #    origen: en una hoz el filo cae por debajo de la mano, y eso es lo que la
    #    hace LOOKING de hoz. Si se exigiese el conjunto entero en z >= 0, la
    #    hoja tendria que salir hacia arriba y seria un cuchillo.
    mango = objetos.get("Mango")
    if mango is not None:
        bajo = min(v.co.z for v in mango.data.vertices)
        if abs(bajo) > 0.002:
            print("  [FALLO] la base del mango no esta en z=0 (esta en %.3f)" % bajo)
            fallos += 1
        else:
            print("  base del mango en z=%.3f (donde se agarra)" % bajo)
    print("  la hoja baja hasta z=%.3f, por debajo de la mano: es lo que la"
          " hace hoz" % mn[2])

    # 2. Ni una rotacion ni una escala propia en ningun nodo. Con una
    #    inclinacion previa, las rotaciones del juego se suman a ella.
    for ob in objetos:
        if tuple(round(a, 6) for a in ob.rotation_euler) != (0.0, 0.0, 0.0):
            print("  [FALLO] %s lleva rotacion propia: %s"
                  % (ob.name, str(tuple(ob.rotation_euler))))
            fallos += 1
        if tuple(round(a, 6) for a in ob.scale) != (1.0, 1.0, 1.0):
            print("  [FALLO] %s lleva escala propia: %s" % (ob.name, str(tuple(ob.scale))))
            fallos += 1

    # 3. La hoja va hacia delante (+Y) y es mas larga que el mango, que es lo
    #    que la hace reconocible como una hoz y no como un cuchillo.
    hoja = objetos.get("Hoja")
    if hoja is not None:
        if hoja.dimensions.y < LARGO_MANGO * 0.5:
            print("  [FALLO] la hoja no sale hacia delante (Y = %.3f m)"
                  % hoja.dimensions.y)
            fallos += 1
        print("  hoja: %.3f x %.3f x %.3f m" % (hoja.dimensions.x, hoja.dimensions.y,
                                                hoja.dimensions.z))
    largo_total = mx[2] - mn[2]
    print("  largo total: %.3f m" % largo_total)
    if largo_total > 0.75:
        print("  [FALLO] la hoz es demasiado larga para llevarla en la mano")
        fallos += 1

    os.makedirs(OUT_DIR, exist_ok=True)
    exportar_blender.preparar(objetos=list(objetos), eje="Z", a_cero=True)
    exportar_blender.exportar(OUT_FILE)
    print("exportada: %s" % OUT_FILE)
    return fallos


def main():
    fallos = _montar()
    print("---")
    print("RESULTADO: %s" % ("todo correcto" if fallos == 0
                             else "%d problema(s)" % fallos))
    return fallos


if __name__ == "__main__":
    main()
