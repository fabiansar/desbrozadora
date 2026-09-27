"""
Desbrozadora low-poly, vista desde arriba y de frente.

Uso:
    flatpak run org.blender.Blender --background --python tools/crear_desbrozadora.py

Convenciones:
  - Origen en el motor (donde se sujeta con las dos manos), en el (0, 0, 0).
  - El tubo baja hacia -Y y la cabeza de corte queda en la punta, mirando hacia
    +Z (hacia delante). Asi en Godot basta con bajar la cabeza: el modelo entra
    tal cual y el punto de corte es un Empty llamado "Corte".
  - Colores de fabrica: cuerpo verde, tubo negro, empunadura naranja y cabeza
    de corte gris con el carrete de hilo en verde.

La pieza importante para el futuro es "Corte": el Empty va en el centro de la
cabeza, que es donde luego se buscara la hierba que hay que cortar.
"""

import os
import math
import bpy

OUT_DIR = os.path.expanduser("~/Documentos/desarrollos/desbrozadora/models")
OUT_FILE = os.path.join(OUT_DIR, "desbrozadora.glb")

# Medidas en metros. Una desbrozadora de verdad mide sobre 1,7 m de punta a
# punta; el encuadre en primera persona se elige con estos numeros.
LONG_TUBO = 1.05
RADIO_TUBO = 0.024
LONG_MOTOR = 0.30
RADIO_MOTOR = 0.075
RADIO_CABEZAL = 0.105


def material(nombre, rgb, metal=0.0, rugosidad=0.6):
    mat = bpy.data.materials.new(nombre)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (rgb[0], rgb[1], rgb[2], 1.0)
        bsdf.inputs["Metallic"].default_value = metal
        bsdf.inputs["Roughness"].default_value = rugosidad
    mat.diffuse_color = (rgb[0], rgb[1], rgb[2], 1.0)
    return mat


def cilindro(nombre, radio, largo, posicion, mat, vertices=16, eje="Z"):
    """Cilindro con las tapas, que es lo que se ve en un tubular."""
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=vertices, radius=radio, depth=largo, end_fill_type="NGON"
    )
    ob = bpy.context.active_object
    ob.name = nombre
    if eje == "Z":
        ob.rotation_euler = (0.0, math.radians(90.0), 0.0)
    elif eje == "X":
        ob.rotation_euler = (0.0, math.radians(90.0), math.radians(90.0))
    elif eje == "Y":
        # El cilindro nace con el eje en Z; este es el que lo baja hacia abajo.
        ob.rotation_euler = (math.radians(90.0), 0.0, 0.0)
    ob.location = posicion
    ob.data.materials.append(mat)
    for poly in ob.data.polygons:
        poly.use_smooth = True
    return ob


def caja(nombre, tamano, posicion, mat, rotacion=(0.0, 0.0, 0.0)):
    bpy.ops.mesh.primitive_cube_add(size=1.0)
    ob = bpy.context.active_object
    ob.name = nombre
    ob.scale = tamano
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    ob.location = posicion
    ob.rotation_euler = rotacion
    ob.data.materials.append(mat)
    return ob


def toro(nombre, radio_mayor, radio_menor, posicion, mat, eje="Y"):
    bpy.ops.mesh.primitive_torus_add(
        major_radius=radio_mayor, minor_radius=radio_menor,
        major_segments=20, minor_segments=8,
    )
    ob = bpy.context.active_object
    ob.name = nombre
    if eje == "Z":
        ob.rotation_euler = (math.radians(90.0), 0.0, 0.0)
    ob.location = posicion
    ob.data.materials.append(mat)
    for poly in ob.data.polygons:
        poly.use_smooth = True
    return ob


def empty(nombre, posicion, tamano=0.1):
    ob = bpy.data.objects.new(nombre, None)
    ob.empty_display_type = "ARROWS"
    ob.empty_display_size = tamano
    bpy.context.collection.objects.link(ob)
    ob.location = posicion
    return ob


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)

    verde = material("Verde", (0.16, 0.42, 0.14), 0.0, 0.45)
    negro = material("Negro", (0.07, 0.07, 0.08), 0.1, 0.55)
    naranja = material("Naranja", (0.85, 0.35, 0.05), 0.0, 0.5)
    gris = material("Gris", (0.35, 0.36, 0.38), 0.6, 0.35)
    amarillo = material("Amarillo", (0.90, 0.72, 0.10), 0.0, 0.5)

    root = empty("Desbrozadora", (0.0, 0.0, 0.0), 0.3)

    # --- Motor: el cacharro de arriba, donde esta el motor -----------------
    motor = cilindro(
        "Motor", RADIO_MOTOR, LONG_MOTOR, (0.0, -0.06, -0.16), verde, 18, "Z"
    )
    # El deposito de combustible, que es lo que mas se ve de una desbrozadora
    # real de mochila... esta es de las de motor en la mano.
    deposito = caja(
        "Deposito", (0.11, 0.09, 0.16), (0.0, 0.02, -0.30), verde
    )
    tapa = cilindro("Tapa", 0.030, 0.020, (0.0, 0.02, -0.39), negro, 12, "Z")

    # --- Empuñadura y arco: lo que sujeta las dos manos -------------------
    # Barra en arco (tipo bicicleta) a la derecha, que es como se ve en las
    # fotos: el arco de la derecha con el mando del acelerador.
    barra = caja(
        "Barra", (0.30, 0.030, 0.030), (0.135, -0.115, -0.10), negro,
        rotacion=(0.0, math.radians(-12.0), 0.0),
    )
    mando = cilindro(
        "Mando", 0.028, 0.045, (0.245, -0.135, -0.075), naranja, 12, "Z"
    )
    # Pieza de transicion del motor al tubo.
    cuello = cilindro("Cuello", 0.042, 0.10, (0.0, -0.10, -0.30), verde, 14, "Z")

    # --- Tubo -------------------------------------------------------------
    # El tubo baja hacia -Y: se crea con el eje en Z y se gira 90 grados en X.
    tubo = cilindro(
        "Tubo", RADIO_TUBO, LONG_TUBO, (0.0, -0.62, -0.35), negro, 14, "Y"
    )

    # --- Cabezal de corte --------------------------------------------------
    # Va en la punta del tubo y mira hacia +Z (hacia delante), que es por donde
    # se corta. Es la pieza que mas se ve trabajando.
    cabeza = cilindro(
        "Cabeza", RADIO_CABEZAL, 0.075, (0.0, -1.10, -0.35), gris, 20, "Z"
    )
    # Reborde que protege la mano: es lo que separa el motor de la vegetacion.
    reborde = toro(
        "Reborde", RADIO_CABEZAL + 0.012, 0.014, (0.0, -1.02, -0.35), negro
    )
    # Carrete de hilo: dos rodeles con el bobinado entre ellos. Estas tres van
    # en coordenadas RELATIVAS al centro de la cabeza, porque cuelgan del
    # Empty "Giro", que ya esta colocado en la punta del tubo. Ponerlas en
    # absolutas las mandaba dos metros mas abajo.
    carrete_a = cilindro("CarreteA", 0.062, 0.010, (0.0, -0.075, 0.0), verde, 16, "Z")
    carrete_b = cilindro("CarreteB", 0.062, 0.010, (0.0, 0.075, 0.0), verde, 16, "Z")
    bobina = cilindro("Bobina", 0.048, 0.140, (0.0, 0.0, 0.0), amarillo, 16, "Z")

    # --- Puntos de referencia ---------------------------------------------
    # El centro de la cabeza. Es donde luego se buscara que hay que cortar, asi
    # que se llama de forma que se entienda de un vistazo.
    corte = empty("Corte", (0.0, 0.0, 0.0), 0.08)
    # Origen del giro: el carrete de hilo gira sobre este eje.
    giro = empty("Giro", (0.0, -1.10, -0.35), 0.05)

    piezas = [motor, deposito, tapa, barra, mando, cuello, tubo, cabeza, reborde]
    for ob in piezas:
        ob.parent = root
    # El carrete gira: se cuelga de "Giro", no de la raiz. Como "Giro" esta
    # desplazado, hay que guardar la inversa de su matriz; si no, las piezas
    # se suman al padre y el carrete aparece dos metros mas abajo.
    for ob in (carrete_a, carrete_b, bobina, corte):
        ob.parent = giro
    giro.parent = root

    bpy.ops.object.select_all(action="DESELECT")
    root.select_set(True)
    bpy.context.view_layer.objects.active = root

    os.makedirs(OUT_DIR, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=OUT_FILE,
        export_format="GLB",
        use_selection=False,
        export_yup=True,
        export_apply=True,
    )
    print("exportado:", OUT_FILE)


if __name__ == "__main__":
    main()
