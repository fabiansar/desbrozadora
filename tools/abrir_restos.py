"""
Abre Blender con ventana y la familia de restos importada y REPARTIDA, para
verla a ojo.

Uso:
    flatpak run --filesystem=$HOME/Documentos org.blender.Blender \
        --python "$PWD/tools/abrir_restos.py" -- "$PWD/models/restos.glb"

Por que no vale `tools/abrir_modelo.py` aqui: en `restos.glb` las ocho piezas
tienen el origen CENTRADO en su propio volumen (es lo que pide el juego: cada
trozo es una particula que rota sobre su origen), asi que al importarlas caen
todas en el (0, 0, 0) y se ve un amasijo. Este visor las separa en una fila
SOLO para mirarlas: el .glb no se toca y el juego sigue cargando las mallas por
su cuenta.
"""

import os
import sys

import bpy

PROJECT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RUTA = os.path.join(PROJECT_DIR, "models", "restos.glb")
SEPARACION = 0.28


def abrir(ruta):
    # Se vacia la escena de arranque: si no, el Cube y la luz de fabrica se
    # quedan encima y al mirar no sabes que estas viendo.
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob, do_unlink=True)
    bpy.ops.import_scene.gltf(filepath=ruta)
    piezas = sorted((o for o in bpy.context.scene.objects if o.type == "MESH"),
                    key=lambda o: o.name)
    for i, ob in enumerate(piezas):
        ob.location = (float(i) * SEPARACION, 0.0, 0.10)
    # Encuadrar: sin esto la familia sale en un rincon y hay que buscarla.
    for area in bpy.context.window.screen.areas:
        if area.type != "VIEW_3D":
            continue
        for region in area.regions:
            if region.type != "WINDOW":
                continue
            with bpy.context.temp_override(area=area, region=region):
                bpy.ops.view3d.view_all()
    print("abiertos:", len(piezas), "restos de", ruta)


if __name__ == "__main__":
    argv = sys.argv
    rutas = argv[argv.index("--") + 1:] if "--" in argv else []
    abrir(os.path.abspath(rutas[0]) if rutas else RUTA)
