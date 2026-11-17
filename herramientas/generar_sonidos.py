"""Genera los efectos de sonido y la música 8-bit de ReMechón!

Todo se sintetiza aquí (ondas cuadradas, triangulares y ruido), así que los sonidos son
originales y no tienen problemas de licencia. Para cambiar uno, edita su función y vuelve a
correr:

    python3 herramientas/generar_sonidos.py

Los .wav quedan en inf-377-microjuegos/Core/assets/sonidos/. Solo necesita numpy.
"""
import os
import wave

import numpy as np

SR = 22050
DESTINO = os.path.join(os.path.dirname(__file__), "..", "inf-377-microjuegos", "Core", "assets", "sonidos")
rng = np.random.default_rng(377)


# ---------- osciladores y utilidades ----------

def t_(dur):
    return np.arange(int(SR * dur)) / SR


def freq_de(nota):
    """'A4', 'C#5', 'Eb3' -> Hz"""
    nombres = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
    n = nombres[nota[0]]
    resto = nota[1:]
    if resto.startswith("#"):
        n += 1
        resto = resto[1:]
    elif resto.startswith("b"):
        n -= 1
        resto = resto[1:]
    midi = 12 * (int(resto) + 1) + n
    return 440.0 * 2 ** ((midi - 69) / 12)


def fase(freq, dur):
    """fase acumulada; freq puede ser número o arreglo (barridos)"""
    f = np.broadcast_to(np.asarray(freq, dtype=float), (int(SR * dur),))
    return np.cumsum(f) / SR


def cuadrada(freq, dur, duty=0.5):
    return np.where((fase(freq, dur) % 1.0) < duty, 1.0, -1.0)


def triangular(freq, dur):
    p = fase(freq, dur) % 1.0
    return 4.0 * np.abs(p - 0.5) - 1.0


def seno(freq, dur):
    return np.sin(2 * np.pi * fase(freq, dur))


def ruido(dur):
    return rng.uniform(-1, 1, int(SR * dur))


def paso_bajo(x, corte):
    """filtro de un polo; corte en Hz (número o arreglo)"""
    corte = np.broadcast_to(np.asarray(corte, dtype=float), x.shape)
    a = 1.0 - np.exp(-2 * np.pi * corte / SR)
    y = np.zeros_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc += a[i] * (x[i] - acc)
        y[i] = acc
    return y


def env(n, ataque=0.005, caida=None, sostenido=1.0):
    """envolvente: ataque lineal y caída exponencial (caida = segundos hasta ~5 %)"""
    e = np.ones(n) * sostenido
    a = max(1, int(SR * ataque))
    e[:a] = np.linspace(0, 1, a)
    if caida:
        k = np.arange(n - a) / SR
        e[a:] = np.exp(-3.0 * k / caida)
    return e


def barrido(f0, f1, dur, curva="exp"):
    n = int(SR * dur)
    if curva == "exp":
        return f0 * (f1 / f0) ** np.linspace(0, 1, n)
    return np.linspace(f0, f1, n)


def silencio(dur):
    return np.zeros(int(SR * dur))


def unir(*partes):
    return np.concatenate(partes)


def mezclar(*pistas):
    largo = max(len(p) for p in pistas)
    out = np.zeros(largo)
    for p in pistas:
        out[: len(p)] += p
    return out


def nota(n, dur, onda=cuadrada, vol=0.5, caida=None, duty=0.5):
    f = freq_de(n)
    x = onda(f, dur, duty) if onda is cuadrada else onda(f, dur)
    return x * env(len(x), caida=caida or dur * 0.9) * vol


def guardar(nombre, x, vol=0.8):
    x = np.asarray(x, dtype=float)
    pico = np.max(np.abs(x)) or 1.0
    x = x / pico * vol
    # fundido corto para que no haga "clic" al terminar
    f = min(len(x), int(SR * 0.006))
    x[-f:] *= np.linspace(1, 0, f)
    datos = (x * 32767).astype(np.int16)
    with wave.open(os.path.join(DESTINO, nombre + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(datos.tobytes())


# ---------- sonidos del Core ----------

def core():
    guardar("clic", cuadrada(1250, 0.035, 0.25) * env(int(SR * 0.035), caida=0.03), 0.5)
    guardar("tic", cuadrada(1900, 0.018, 0.5) * env(int(SR * 0.018), caida=0.015), 0.35)
    guardar("ruleta_fin", mezclar(nota("E6", 0.35, vol=0.5, caida=0.3), unir(silencio(0.06), nota("B6", 0.4, vol=0.4, caida=0.35))), 0.6)
    guardar("preparate", unir(nota("C5", 0.08, duty=0.25), nota("E5", 0.08, duty=0.25), nota("G5", 0.08, duty=0.25), nota("C6", 0.3, duty=0.25, caida=0.28)), 0.6)
    guardar("victoria", unir(*[nota(n, 0.07, duty=0.25) for n in ("C5", "E5", "G5", "C6", "E6")],
                             mezclar(nota("G6", 0.35, duty=0.25, caida=0.33), nota("C6", 0.35, onda=triangular, vol=0.6, caida=0.33))), 0.6)
    brillos = unir(*[nota(n, 0.05, duty=0.125, vol=0.35) for n in ("E7", "C7", "G7", "E7", "C8")])
    guardar("perfecto", unir(*[nota(n, 0.055, duty=0.25) for n in ("C5", "G5", "C6", "E6", "G6")],
                             mezclar(nota("C7", 0.4, duty=0.25, caida=0.38), unir(silencio(0.05), brillos))), 0.6)
    # "wa wa waaa" descendente con vibrato al final
    ultima = cuadrada(freq_de("E4") * (1 + 0.03 * np.sin(2 * np.pi * 7 * t_(0.6))), 0.6, 0.5) * env(int(SR * 0.6), caida=0.55) * 0.5
    guardar("derrota", unir(nota("G4", 0.18, caida=0.17), nota("F#4", 0.18, caida=0.17), nota("F4", 0.18, caida=0.17), ultima), 0.55)
    crack = paso_bajo(ruido(0.07), 6000) * env(int(SR * 0.07), caida=0.05)
    golpe = seno(barrido(180, 60, 0.25), 0.25) * env(int(SR * 0.25), caida=0.2)
    guardar("corazon_roto", unir(crack, mezclar(golpe, crack * 0.5)), 0.7)
    guardar("game_over", unir(*[nota(n, 0.28, onda=triangular, vol=0.6, caida=0.26) for n in ("A4", "F4", "D4")],
                              nota("A3", 0.8, onda=triangular, vol=0.6, caida=0.75)), 0.7)
    guardar("record", unir(nota("G5", 0.1, duty=0.25), nota("G5", 0.1, duty=0.25), nota("G5", 0.1, duty=0.25),
                           mezclar(nota("C6", 0.45, duty=0.25, caida=0.4), nota("E5", 0.45, onda=triangular, vol=0.5, caida=0.4))), 0.6)
    guardar("suma", cuadrada(980, 0.02, 0.25) * env(int(SR * 0.02), caida=0.018), 0.3)
    guardar("racha", unir(nota("A5", 0.05, duty=0.125), nota("C#6", 0.05, duty=0.125), nota("E6", 0.05, duty=0.125), nota("A6", 0.12, duty=0.125, caida=0.1)), 0.5)


# ---------- sonidos genéricos para los juegos ----------

def genericos():
    guardar("acierto", unir(nota("B5", 0.06, duty=0.25), nota("E6", 0.16, duty=0.25, caida=0.14)), 0.55)
    zumbido = cuadrada(barrido(150, 95, 0.28), 0.28, 0.5) * env(int(SR * 0.28), caida=0.26)
    guardar("error", paso_bajo(zumbido, 1800), 0.6)
    guardar("pop", seno(barrido(700, 260, 0.08), 0.08) * env(int(SR * 0.08), caida=0.07), 0.6)
    w = ruido(0.28)
    guardar("whoosh", paso_bajo(w, barrido(500, 4500, 0.28)) * np.sin(np.linspace(0, np.pi, len(w))), 0.5)
    guardar("tecla", paso_bajo(ruido(0.02), 5000) * env(int(SR * 0.02), caida=0.015), 0.4)


# ---------- sonidos de juegos específicos ----------

def especificos():
    # explosión: ruido grave que se apaga + retumbe
    n = ruido(0.9)
    exp = paso_bajo(n, barrido(3000, 150, 0.9)) * env(len(n), ataque=0.002, caida=0.75)
    retumbe = seno(barrido(90, 35, 0.9), 0.9) * env(int(SR * 0.9), caida=0.7) * 0.7
    guardar("explosion", mezclar(exp, retumbe), 0.85)
    # celular vibrando: zumbido grave a pulsos
    t = t_(0.6)
    vib = cuadrada(145, 0.6, 0.5) * (0.6 + 0.4 * (np.sin(2 * np.pi * 9 * t) > 0))
    guardar("vibracion", paso_bajo(vib, 700) * env(len(t), ataque=0.01, sostenido=1.0), 0.5)
    # golpe seco (máquina de snacks)
    golpe = mezclar(seno(barrido(110, 45, 0.18), 0.18) * env(int(SR * 0.18), caida=0.15),
                    paso_bajo(ruido(0.04), 2500) * env(int(SR * 0.04), caida=0.03) * 0.6)
    guardar("golpe", golpe, 0.8)
    guardar("alarma", unir(*[nota(n, 0.12, duty=0.5, vol=0.5, caida=0.5) for n in ("A5", "E5") * 3]), 0.5)
    sp = ruido(0.2)
    guardar("splat", paso_bajo(sp, barrido(2500, 200, 0.2)) * env(len(sp), caida=0.15), 0.6)
    papel = paso_bajo(ruido(0.22), 7000) - paso_bajo(ruido(0.22), 1200)
    guardar("papel", papel * env(int(SR * 0.22), caida=0.18) * (0.6 + 0.4 * np.sin(2 * np.pi * 30 * t_(0.22))), 0.45)
    vi = ruido(1.4)
    guardar("viento", paso_bajo(vi, 600 + 400 * np.sin(np.linspace(0, 3 * np.pi, len(vi)))) * np.sin(np.linspace(0, np.pi, len(vi))), 0.5)
    guardar("campanita", mezclar(seno(freq_de("G6"), 0.7) * env(int(SR * 0.7), caida=0.6),
                                 seno(freq_de("D7"), 0.7) * env(int(SR * 0.7), caida=0.4) * 0.4), 0.55)
    guardar("borrador", paso_bajo(ruido(0.09), 2200) * env(int(SR * 0.09), ataque=0.02, caida=0.06), 0.35)
    guardar("enceste", unir(seno(barrido(500, 220, 0.09), 0.09) * env(int(SR * 0.09), caida=0.08), nota("C6", 0.06, duty=0.25), nota("G6", 0.14, duty=0.25, caida=0.12)), 0.55)
    guardar("bocina", mezclar(cuadrada(392, 0.4, 0.5), cuadrada(494, 0.4, 0.5) * 0.7) * env(int(SR * 0.4), ataque=0.01, sostenido=1.0) * 0.5, 0.45)
    guardar("paso", paso_bajo(ruido(0.05), 900) * env(int(SR * 0.05), caida=0.04), 0.4)
    guardar("mano", unir(seno(barrido(300, 600, 0.06), 0.06) * env(int(SR * 0.06), caida=0.05)), 0.4)


# ---------- música (loops cortos) ----------

def secuencia(notas, pulso, onda, vol, caida=0.8, duty=0.5):
    """notas: lista de (nota o None, duración en pulsos)"""
    partes = []
    for n, d in notas:
        dur = d * pulso
        if n is None:
            partes.append(silencio(dur))
        else:
            partes.append(nota(n, dur, onda=onda, vol=vol, caida=dur * caida, duty=duty))
    return unir(*partes)


def bateria(compases, pulso):
    """bombo en 1 y 3, caja en 2 y 4, platillo en corcheas"""
    out = []
    for _ in range(compases * 4):
        golpe = silencio(pulso)
        hat = paso_bajo(ruido(0.03), 8000) * env(int(SR * 0.03), caida=0.02) * 0.12
        golpe[: len(hat)] += hat
        mitad = int(SR * pulso / 2)
        golpe[mitad: mitad + len(hat)] += hat
        out.append(golpe)
    pista = unir(*out)
    for c in range(compases * 4):
        i = int(SR * pulso * c)
        if c % 2 == 0:
            k = seno(barrido(120, 50, 0.12), 0.12) * env(int(SR * 0.12), caida=0.1) * 0.45
        else:
            k = paso_bajo(ruido(0.1), 3000) * env(int(SR * 0.1), caida=0.08) * 0.22
        pista[i: i + len(k)] += k[: len(pista) - i]
    return pista


def musica():
    # Menú: tranquila, en Do mayor (130 bpm, 8 compases)
    p = 60 / 130
    mel = [("E5", 1), ("G5", 1), ("C6", 1), ("G5", 1), ("A5", 1.5), ("G5", 0.5), ("E5", 2),
           ("F5", 1), ("A5", 1), ("C6", 1), ("A5", 1), ("G5", 3), (None, 1),
           ("E5", 1), ("G5", 1), ("C6", 1), ("E6", 1), ("D6", 1.5), ("C6", 0.5), ("A5", 2),
           ("F5", 1), ("G5", 1), ("B5", 1), ("D6", 1), ("C6", 3), (None, 1)]
    bajo_notas = ["C3", "C3", "A2", "A2", "F2", "F2", "G2", "G2"] * 1
    bajo = []
    for raiz in bajo_notas:
        quinta = {"C3": "G3", "A2": "E3", "F2": "C3", "G2": "D3"}[raiz]
        bajo += [(raiz, 1), (quinta, 1), (raiz, 1), (quinta, 1)]
    menu = mezclar(secuencia(mel, p, cuadrada, 0.22, duty=0.25),
                   secuencia(bajo, p, triangular, 0.35, caida=0.7),
                   bateria(8, p) * 0.5)
    guardar("musica_menu", menu, 0.55)
    # Ruleta: corta y movida (150 bpm, 4 compases) mientras gira el carrusel
    p = 60 / 150
    mel = [("A5", 0.5), ("C6", 0.5), ("E6", 0.5), ("C6", 0.5), ("A5", 0.5), ("C6", 0.5), ("E6", 1),
           ("G5", 0.5), ("B5", 0.5), ("D6", 0.5), ("B5", 0.5), ("G5", 0.5), ("B5", 0.5), ("D6", 1),
           ("F5", 0.5), ("A5", 0.5), ("C6", 0.5), ("A5", 0.5), ("F5", 0.5), ("A5", 0.5), ("C6", 1),
           ("E5", 0.5), ("G#5", 0.5), ("B5", 0.5), ("E6", 0.5), ("D6", 1), ("B5", 1)]
    bajo = []
    for raiz in ["A2", "G2", "F2", "E2"]:
        bajo += [(raiz, 0.5), (raiz, 0.5), (None, 0.5), (raiz, 0.5)] * 2
    ruleta = mezclar(secuencia(mel, p, cuadrada, 0.2, duty=0.125),
                     secuencia(bajo, p, triangular, 0.4, caida=0.6),
                     bateria(4, p))
    guardar("musica_ruleta", ruleta, 0.55)


if __name__ == "__main__":
    os.makedirs(DESTINO, exist_ok=True)
    core()
    genericos()
    especificos()
    musica()
    print("Sonidos generados en", os.path.abspath(DESTINO))
