"""Alias de compatibilidad para el generador vigente de la herramienta.

El generador antiguo escribía directamente `models/desbrozadora.glb` con una
jerarquía incompatible con la escena actual. Se conserva este punto de entrada
para scripts antiguos, pero delega en `crear_desbrozadora_mesh.py`, que valida y
genera la máquina y sus cabezales con el contrato activo.
"""

import os
import sys


_TOOLS_DIR = os.path.dirname(os.path.abspath(__file__))
if _TOOLS_DIR not in sys.path:
    sys.path.insert(0, _TOOLS_DIR)

from crear_desbrozadora_mesh import main  # noqa: E402


if __name__ == "__main__":
    sys.exit(main())
