"""
Genera el zumbido del motor de la desbrozadora.

Uso:
    python3 tools/crear_motor.py

Se genera en vez de descargarse para que el proyecto no dependa de ficheros de
sonido de fuera y para poder cambiar el sonido tweaking numeros. Es un motor de
dos tiempos: un zumbido grave con muchos armónicos (el pistón) y un siseo
(fresno de la mezcla) por encima. Cuando este funcionando se le cambia el tono
desde el codigo segun las revoluciones.
"""
import math
import os
import struct
import wave

FUERZA = 22050
SEGUNDOS = 2.0
SALIDA = os.path.expanduser("~/Documentos/desarrollos/desbrozadora/audio/motor.wav")

# Un bucle tiene que casar con el final: se usan periodos enteros sobre la
# longitud del bucle, o si no se oye un "clic" en cada vuelta.
def main():
    muestras = int(FUERZA * SEGUNDOS)
    # 25 vueltas de piston por bucle: como el bucle dura 2 s, el motor suena
    # a 750 rpm, que es de donde sale el zumbido grave.
    vueltas = 25.0
    buffer = bytearray(muestras * 2)
    for i in range(muestras):
        t = i / FUERZA
        # Fundamental del piston mas sus armónicos: eso es lo que hace que un
        # motor suene a motor y no a pitido.
        v = (math.sin(2.0 * math.pi * vueltas * t) * 0.55
             + math.sin(2.0 * math.pi * vueltas * 2.0 * t) * 0.28
             + math.sin(2.0 * math.pi * vueltas * 3.0 * t) * 0.12
             + math.sin(2.0 * math.pi * vueltas * 4.0 * t) * 0.06)
        # Siseo de la mezcla, con una modulacion lenta que hace que "viva".
        siseo = math.sin(2.0 * math.pi * 7.0 * t + math.sin(2.0 * math.pi * 1.0 * t) * 2.0)
        v += siseo * 0.18
        v *= 0.55
        v = max(-1.0, min(1.0, v))
        struct.pack_into("<h", buffer, i * 2, int(v * 30000))

    os.makedirs(os.path.dirname(SALIDA), exist_ok=True)
    with wave.open(SALIDA, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(FUERZA)
        w.writeframes(bytes(buffer))
    print("escrito:", SALIDA, "%.2f s" % SEGUNDOS)


if __name__ == "__main__":
    main()
