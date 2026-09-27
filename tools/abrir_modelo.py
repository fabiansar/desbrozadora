"""
Abre Blender con ventana y un modelo importado, para verlo a ojo.

Uso:
    flatpak run --filesystem=$HOME/Documentos org.blender.Blender --python tools/abrir_modelo.py -- models/desbrozadora_100x.glb
    flatpak run --filesystem=$HOME/Documentos org.blender.Blender --python tools/abrir_modelo.py -- models/maquina.blend

Por que hace falta un script y no vale con pasar el fichero: Blender no abre un
.gltf o .glb como argumento de linea de ordenes, da error de "File format is
not supported". Hay que importarlo con el operador, y de paso se encuadra la
maquina en la vista para que no salga en miniatura.
"""

import os
import sys

import bpy


def abrir(ruta):
    # Se vacia la escena de arranque: si no, el Cube y la luz de fabrica se
    # quedan encima de la maquina y al mirarla no sabes que estas viendo. Se
    # borran objeto a objeto y no con read_factory_settings, que en ventana
    # se lleva por delante la disposicion de las areas.
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob, do_unlink=True)
    if ruta.lower().endswith((".glb", ".gltf")):
        bpy.ops.import_scene.gltf(filepath=ruta)
    else:
        bpy.ops.wm.open_mainfile(filepath=ruta)
    # Encuadrar: sin esto la maquina sale en un rincon y hay que buscarla.
    for area in bpy.context.window.screen.areas:
        if area.type != "VIEW_3D":
            continue
        for region in area.regions:
            if region.type != "WINDOW":
                continue
            with bpy.context.temp_override(area=area, region=region):
                bpy.ops.view3d.view_all()
    print("abierto:", ruta, "-", len(bpy.context.scene.objects), "nodos")


if __name__ == "__main__":
    argv = sys.argv
    rutas = argv[argv.index("--") + 1:] if "--" in argv else []
    for ruta in rutas:
        abrir(os.path.abspath(ruta))
