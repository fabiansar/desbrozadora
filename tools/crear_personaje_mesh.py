"""Genera el primer operario low-poly para la vista en primera persona.

Uso:
    flatpak run --filesystem=$HOME/Documentos org.blender.Blender --background \
        --python "$PWD/tools/crear_personaje_mesh.py"

El origen de Personaje esta en el suelo, mide en metros y mira hacia +Y en
Blender (hacia -Z en Godot). Cabeza y brazos quedan separados para que Godot
pueda ocultar la cabeza y sustituir los brazos estaticos por brazos que siguen
los dos puños de la desbrozadora.
"""

import math
import os
from pathlib import Path

import bpy
from mathutils import Vector

_AQUI = os.path.dirname(os.path.abspath(__file__))
if _AQUI not in __import__("sys").path:
    __import__("sys").path.insert(0, _AQUI)
import exportar_blender  # noqa: E402

PROJECT_ROOT = Path(__file__).resolve().parents[1]
OUT_FILE = PROJECT_ROOT / "models" / "personaje_trabajo.glb"


def material(nombre, color):
    mat = bpy.data.materials.new(nombre)
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (*color, 1.0)
        bsdf.inputs["Roughness"].default_value = 0.82
    mat.diffuse_color = (*color, 1.0)
    return mat


def caja(nombre, tamano, posicion, mat, bisel=0.0):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=posicion)
    ob = bpy.context.object
    ob.name = nombre
    ob.dimensions = tamano
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    ob.data.materials.append(mat)
    if bisel > 0.0:
        mod = ob.modifiers.new("Chaflan_LowPoly", "BEVEL")
        mod.width = bisel
        mod.segments = 1
        bpy.context.view_layer.objects.active = ob
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return ob


def esfera(nombre, radio, posicion, mat, escala=(1.0, 1.0, 1.0)):
    bpy.ops.mesh.primitive_ico_sphere_add(
        subdivisions=1, radius=radio, location=posicion
    )
    ob = bpy.context.object
    ob.name = nombre
    ob.scale = escala
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    ob.data.materials.append(mat)
    return ob


def cilindro(nombre, radio, p0, p1, mat, lados=8, radio_arriba=None):
    a, b = Vector(p0), Vector(p1)
    largo = (b - a).length
    bpy.ops.mesh.primitive_cone_add(
        vertices=lados,
        radius1=radio,
        radius2=radio if radio_arriba is None else radio_arriba,
        depth=largo,
        location=(a + b) * 0.5,
    )
    ob = bpy.context.object
    ob.name = nombre
    ob.rotation_euler = (b - a).to_track_quat("Z", "Y").to_euler()
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    ob.data.materials.append(mat)
    return ob


def empty(nombre, posicion=(0.0, 0.0, 0.0)):
    ob = bpy.data.objects.new(nombre, None)
    ob.empty_display_type = "PLAIN_AXES"
    bpy.context.collection.objects.link(ob)
    ob.location = posicion
    return ob


def colgar(objeto, padre):
    bpy.context.view_layer.update()
    objeto.parent = padre
    objeto.matrix_parent_inverse = padre.matrix_world.inverted()


def aplicar_mallas():
    for ob in bpy.context.scene.objects:
        if ob.type != "MESH":
            continue
        bpy.ops.object.select_all(action="DESELECT")
        ob.select_set(True)
        bpy.context.view_layer.objects.active = ob
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
        for cara in ob.data.polygons:
            cara.use_smooth = False


def construir():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    piel = material("Piel_Calida", (0.72, 0.39, 0.23))
    naranja = material("Chaqueta_Naranja", (0.88, 0.25, 0.055))
    amarillo = material("Reflectante_Amarillo", (0.96, 0.72, 0.12))
    verde = material("Pantalon_Petroleo", (0.055, 0.19, 0.16))
    bota = material("Botas_Cuero", (0.12, 0.075, 0.045))
    guante = material("Guantes_Verde", (0.13, 0.29, 0.16))
    casco = material("Casco_Amarillo", (0.98, 0.58, 0.045))
    blanco = material("Ojos_Blancos", (0.94, 0.91, 0.82))
    negro = material("Pupilas", (0.035, 0.025, 0.02))

    raiz = empty("Personaje")
    cabeza = empty("Cabeza", (0.0, 0.0, 1.0))
    torso = empty("Torso")
    brazo_izq = empty("BrazoIzq")
    brazo_der = empty("BrazoDer")

    piezas = []
    piezas_torso = []
    piezas.append(caja("Caderas", (0.34, 0.25, 0.20), (0.0, 0.0, 0.88), verde, 0.035))
    pieza = caja("Chaqueta", (0.36, 0.24, 0.65), (0.0, 0.0, 1.23), naranja, 0.055)
    piezas.append(pieza)
    piezas_torso.append(pieza)
    pieza = caja("Cremallera", (0.025, 0.018, 0.47), (0.0, 0.131, 1.22), verde)
    piezas.append(pieza)
    piezas_torso.append(pieza)

    # Dos bandas grandes y limpias para leer la ropa de trabajo a distancia.
    for lado_y in (-1.0, 1.0):
        y = lado_y * 0.127
        pieza = caja("Banda_Reflectante", (0.34, 0.014, 0.045),
                     (0.0, y, 1.30), amarillo)
        piezas.append(pieza)
        piezas_torso.append(pieza)
        pieza = caja("Banda_Manga", (0.13, 0.20, 0.045),
                     (0.0, y * 0.9, 1.03), amarillo)
        piezas.append(pieza)
        piezas_torso.append(pieza)

    # Postura relajada de trabajo: pies algo separados y uno adelantado. Desde
    # la lente GoPro, una postura simétrica y con los tobillos juntos hacía que
    # las piernas se solaparan y parecieran una sola pieza.
    for lado, signo, avance in (("Izq", -1.0, 0.18), ("Der", 1.0, -0.04)):
        cadera_x = signo * 0.13
        rodilla_x = signo * 0.15
        tobillo_x = signo * 0.18
        piezas.append(cilindro("Muslo_" + lado, 0.105,
                               (cadera_x, 0.0, 0.86),
                               (rodilla_x, avance * 0.35, 0.49), verde, 7, 0.085))
        piezas.append(cilindro("Pantorrilla_" + lado, 0.082,
                               (rodilla_x, avance * 0.35, 0.50),
                               (tobillo_x, avance, 0.17), verde, 7, 0.065))
        piezas.append(caja("Bota_" + lado, (0.16, 0.31, 0.15),
                            (tobillo_x, avance + 0.065, 0.075), bota, 0.025))
        piezas.append(caja("Puntera_" + lado, (0.145, 0.13, 0.06),
                            (tobillo_x, avance + 0.19, 0.03), amarillo, 0.012))

    # Cara expresiva y casco. En primera persona se oculta solo este grupo:
    # el modelo completo sigue disponible para la vista de Blender.
    piezas.append(esfera("Cara", 1.0, (0.0, 0.015, 1.76), piel,
                         (0.145, 0.13, 0.17)))
    piezas.append(caja("Visera_Casco", (0.37, 0.28, 0.045),
                        (0.0, 0.035, 1.89), casco, 0.025))
    piezas.append(esfera("Casco", 1.0, (0.0, -0.015, 1.91), casco,
                         (0.16, 0.15, 0.07)))
    for x in (-0.060, 0.060):
        piezas.append(esfera("Ojo", 0.043, (x, 0.133, 1.785), blanco,
                             (0.82, 0.65, 1.0)))
        piezas.append(esfera("Pupila", 0.021, (x + 0.004, 0.168, 1.783), negro,
                             (0.8, 0.65, 1.0)))
    piezas.append(esfera("Nariz", 0.035, (0.0, 0.153, 1.735), piel,
                         (0.8, 0.75, 0.85)))

    # Brazos de pose neutra para que el GLB se vea completo en Blender. Godot
    # los apaga y usa segmentos que terminan exactamente en los marcadores de
    # los puños, aunque la maquina barra o cambie de inclinacion.
    for lado, s, grupo in (("Izq", -1.0, brazo_izq), ("Der", 1.0, brazo_der)):
        hombro = Vector((s * 0.19, 0.0, 1.43))
        codo = Vector((s * 0.275, 0.25, 1.21))
        muneca = Vector((s * 0.20, 0.54, 1.10))
        mano = Vector((s * 0.20, 0.62, 1.10))
        brazos = [
            cilindro("Manga_Superior_" + lado, 0.060, hombro, codo,
                     naranja, 8, 0.050),
            esfera("Codo_" + lado, 0.055, codo, naranja),
            cilindro("Manga_Antebrazo_" + lado, 0.050, codo, muneca,
                     naranja, 8, 0.042),
            esfera("Guante_" + lado, 0.062, mano, guante,
                   (0.9, 1.0, 0.75)),
        ]
        for pieza in brazos:
            colgar(pieza, grupo)

    for pieza in piezas:
        padre = cabeza if pieza.name in (
            "Cara", "Visera_Casco", "Casco", "Ojo", "Pupila", "Nariz"
        ) else torso if pieza in piezas_torso else raiz
        colgar(pieza, padre)

    bpy.context.view_layer.update()
    aplicar_mallas()
    bpy.context.view_layer.update()

    # Comprobaciones ligeras del contrato de escala y origen.
    vertices = [ob.matrix_world @ v.co
                for ob in bpy.context.scene.objects if ob.type == "MESH"
                for v in ob.data.vertices]
    if not vertices:
        raise RuntimeError("el personaje no tiene geometria")
    minimo_z = min(p.z for p in vertices)
    maximo_z = max(p.z for p in vertices)
    triangulos = sum(max(1, len(poly.vertices) - 2)
                     for ob in bpy.context.scene.objects if ob.type == "MESH"
                     for poly in ob.data.polygons)
    print("personaje: alto %.2f m, base z=%.3f, %d triangulos"
          % (maximo_z - minimo_z, minimo_z, triangulos))
    if abs(minimo_z) > 0.02 or not 1.75 <= maximo_z <= 2.05:
        raise RuntimeError("escala o apoyo del personaje fuera de rango")

    bpy.ops.object.select_all(action="DESELECT")
    raiz.select_set(True)
    bpy.context.view_layer.objects.active = raiz
    OUT_FILE.parent.mkdir(parents=True, exist_ok=True)
    exportar_blender.exportar(str(OUT_FILE))
    print("exportado:", OUT_FILE)


if __name__ == "__main__":
    construir()
