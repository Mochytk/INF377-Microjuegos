"""Genera los efectos de sonido y la música 8-bit de ReMechón!

Todo se sintetiza aquí (ondas cuadradas, triangulares y ruido), así que los sonidos son
originales y no tienen problemas de licencia. Para cambiar uno, edita su función y vuelve a
correr:

    python3 herramientas/generar_sonidos.py

Los .wav quedan en inf-377-microjuegos/Core/assets/sonidos/. Solo necesita numpy.

Algunos sonidos realistas (explosión, golpe, tecla, campanita, viento, paso, tic, mano) se toman del
banco de efectos de earshot (https://github.com/Leonxlnx/earshot, licencia MIT), que también son
sonidos generados por código. Si earshot está instalado (comando `earshot` o variable EARSHOT con su
ruta) se vuelven a renderizar; si no, se mantienen los .wav que ya están en el repositorio. También
se necesita ffmpeg para convertirlos.

Cada sonido se revisó con earshot (`earshot match`) contra una descripción de lo que debe ser.
"""
import os
import shutil
import subprocess
import tempfile
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


def banda(x, lo, hi):
    """filtro pasa banda simple: lo que queda entre lo y hi Hz"""
    return paso_bajo(x, hi) - paso_bajo(x, lo)


def vidrio(dur=0.45, n=40):
    """vidrio que se quiebra: golpe seco y muchos "tin" agudos al azar"""
    out = np.zeros(int(SR * dur))
    for _ in range(n):
        i = int(rng.uniform(0, 0.25) * SR)
        f = rng.uniform(2500, 9000)
        d = rng.uniform(0.03, 0.18)
        s = seno(f, d) * env(int(SR * d), ataque=0.0005, caida=d * 0.7) * rng.uniform(0.2, 1.0)
        out[i:i + len(s)] += s[: len(out) - i]
    golpe = banda(ruido(0.04), 2000, 9000) * env(int(SR * 0.04), ataque=0.0005, caida=0.02) * 2.0
    out[: len(golpe)] += golpe
    return out


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
    # el corazón se quiebra como vidrio: muchos "tin" agudos sobre un golpe seco
    # (earshot: "a glass shattering", plausible z +2.7; antes sonaba a portazo)
    guardar("corazon_roto", vidrio(), 0.7)
    # trombón triste grave: tres notas que bajan, una larga con vibrato y una caída final de tono
    # (earshot: "a sad descending ... fail sound", strong z +5.6; la versión anterior sonaba alegre)
    ultima = cuadrada(freq_de("E3") * (1 + 0.035 * np.sin(2 * np.pi * 6 * t_(0.6))), 0.6) * env(int(SR * 0.6), caida=1.15) * 0.5
    caer = paso_bajo(cuadrada(barrido(165, 60, 0.9), 0.9), 900) * env(int(SR * 0.9), caida=0.85) * 0.5
    guardar("game_over", unir(nota("G3", 0.32, caida=0.3), nota("F#3", 0.32, caida=0.3), nota("F3", 0.32, caida=0.3), ultima, caer), 0.6)
    guardar("record", unir(nota("G5", 0.1, duty=0.25), nota("G5", 0.1, duty=0.25), nota("G5", 0.1, duty=0.25),
                           mezclar(nota("C6", 0.45, duty=0.25, caida=0.4), nota("E5", 0.45, onda=triangular, vol=0.5, caida=0.4))), 0.6)
    guardar("suma", cuadrada(980, 0.02, 0.25) * env(int(SR * 0.02), caida=0.018), 0.3)
    guardar("racha", unir(nota("A5", 0.05, duty=0.125), nota("C#6", 0.05, duty=0.125), nota("E6", 0.05, duty=0.125), nota("A6", 0.12, duty=0.125, caida=0.1)), 0.5)


# ---------- sonidos genéricos para los juegos ----------

def genericos():
    guardar("acierto", unir(nota("B5", 0.06, duty=0.25), nota("E6", 0.16, duty=0.25, caida=0.14)), 0.55)
    # zumbador de concurso: cuadrada grave con trémolo (earshot: "an error buzz", strong z +3.2)
    t = t_(0.45)
    zumbido = cuadrada(92, 0.45) * (0.65 + 0.35 * np.sign(np.sin(2 * np.pi * 18 * t))) * env(len(t), ataque=0.004, sostenido=1.0)
    guardar("error", paso_bajo(zumbido, 2200), 0.6)
    guardar("pop", seno(barrido(700, 260, 0.08), 0.08) * env(int(SR * 0.08), caida=0.07), 0.6)
    w = ruido(0.28)
    guardar("whoosh", paso_bajo(w, barrido(500, 4500, 0.28)) * np.sin(np.linspace(0, np.pi, len(w))), 0.5)


# ---------- sonidos de juegos específicos ----------

def especificos():
    # celular vibrando: zumbido grave a pulsos
    t = t_(0.6)
    vib = cuadrada(145, 0.6, 0.5) * (0.6 + 0.4 * (np.sin(2 * np.pi * 9 * t) > 0))
    guardar("vibracion", paso_bajo(vib, 700) * env(len(t), ataque=0.01, sostenido=1.0), 0.5)
    guardar("alarma", unir(*[nota(n, 0.12, duty=0.5, vol=0.5, caida=0.5) for n in ("A5", "E5") * 3]), 0.5)
    # splat: golpe blando + burbujeo húmedo (earshot: "a wet splat", plausible z +3.0; antes "a slap")
    imp = paso_bajo(ruido(0.12), barrido(2500, 400, 0.12)) * env(int(SR * 0.12), ataque=0.001, caida=0.07)
    sp = np.zeros(int(SR * 0.35))
    sp[: len(imp)] += imp
    for _ in range(14):
        i = int(rng.uniform(0.01, 0.22) * SR)
        d = rng.uniform(0.015, 0.04)
        b = seno(barrido(rng.uniform(250, 600), rng.uniform(700, 1500), d), d) * env(int(SR * d), caida=d) * rng.uniform(0.15, 0.5)
        sp[i:i + len(b)] += b
    guardar("splat", sp, 0.6)
    # papel arrugándose: muchos crujidos muy cortos (earshot: "paper crumpling", strong z +3.2)
    papel = np.zeros(int(SR * 0.45))
    for _ in range(55):
        i = int(rng.uniform(0, 0.43) * SR)
        d = rng.uniform(0.002, 0.012)
        papel[i:i + int(SR * d)] += banda(ruido(d), 1500, 9000) * rng.uniform(0.2, 1.0)
    guardar("papel", papel * np.sin(np.linspace(0, np.pi, len(papel))) ** 0.5, 0.5)
    guardar("borrador", paso_bajo(ruido(0.09), 2200) * env(int(SR * 0.09), ataque=0.02, caida=0.06), 0.35)
    guardar("enceste", unir(seno(barrido(500, 220, 0.09), 0.09) * env(int(SR * 0.09), caida=0.08), nota("C6", 0.06, duty=0.25), nota("G6", 0.14, duty=0.25, caida=0.12)), 0.55)
    guardar("bocina", mezclar(cuadrada(392, 0.4, 0.5), cuadrada(494, 0.4, 0.5) * 0.7) * env(int(SR * 0.4), ataque=0.01, sostenido=1.0) * 0.5, 0.45)


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


# ---------- sonidos tomados del banco de earshot ----------

# nombre: (id en el banco, duración en s (None = la del banco), volumen); al lado, lo que dijo earshot match
DEL_BANCO = {
    "explosion": ("impact/blast", 1.6, 0.85),      # "an explosion": strong (antes sonaba a tambor)
    "golpe": ("impact/punch", 0.4, 0.8),           # golpe a la máquina: strong
    "tecla": ("fit/key/medium", None, 0.45),       # "a single keyboard key press": strong
    "campanita": ("fit/bell/small_bell", None, 0.55),  # campanita del microondas: plausible
    "viento": ("whoosh_big/gust", None, 0.5),      # >99 % "a gust of wind" frente a "ocean waves"
    "paso": ("knock/wood", None, 0.45),            # "a footstep on a wooden floor": strong
    "tic": ("hover_tick/mid", None, 0.35),         # tic del carrusel: 96 % "tick de ruleta" (otros clics sonaban a zumbido)
    "mano": ("whoosh_fast/tight", None, 0.4),      # mano que se levanta: "a quick swoosh", strong
}


def banco_earshot():
    exe = os.environ.get("EARSHOT") or shutil.which("earshot")
    if not exe or not shutil.which("ffmpeg"):
        print("earshot o ffmpeg no están instalados: se mantienen los .wav del banco que ya existen")
        return
    for nombre, (sid, dur, vol) in DEL_BANCO.items():
        with tempfile.TemporaryDirectory() as tmp:
            crudo = os.path.join(tmp, "crudo.wav")
            mono = os.path.join(tmp, "mono.wav")
            extra = ["--dur", str(dur)] if dur else []
            subprocess.run([exe, "sfx", "render", sid, "-o", crudo, "--seed", "1", *extra], check=True, capture_output=True)
            subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", crudo, "-ac", "1", "-ar", str(SR),
                            "-sample_fmt", "s16", mono], check=True)
            with wave.open(mono) as w:
                x = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16) / 32768.0
        guardar(nombre, x.copy(), vol)


if __name__ == "__main__":
    os.makedirs(DESTINO, exist_ok=True)
    core()
    genericos()
    especificos()
    banco_earshot()
    musica()
    print("Sonidos generados en", os.path.abspath(DESTINO))
