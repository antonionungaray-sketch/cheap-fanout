"""Siembra el banco de pre-revisión: 8 unidades de extracción (2 limpias, 6 con UNA falla cada una)
a partir del fixture de bench-extraccion (fuente.md + expected.json).

Uso: python3 -I sembrar.py <dir-con-fuente.md-y-expected.json> <out-dir>
Escribe en <out-dir>: fuente.md, prompt-Uk.md y Uk.out (k = 1..8), prompt-PREREV.md (plantilla de
pre-revisión de cheap-fanout, por referencia) y clave.json (veredicto esperado por unidad).
Determinista: las fallas están fijas por unidad (semilla nominal 20261121, sin azar).
"""
import json, os, shutil, sys

src, out = sys.argv[1], sys.argv[2]
os.makedirs(out, exist_ok=True)
rows = json.load(open(os.path.join(src, "expected.json"), encoding="utf-8"))
shutil.copyfile(os.path.join(src, "fuente.md"), os.path.join(out, "fuente.md"))

def line(r):
    return 'FILA|%s|%d|%d|"%s"|"%s"|' % (r["name"], r["req"], r["lim"], r["nota"], r["origen"])

# 8 unidades de 4 filas (la última, 3): U1 = filas 1-4 … U8 = filas 29-31
units = [rows[i:i + 4] for i in range(0, len(rows), 4)]
clave = {}
for k, chunk in enumerate(units, start=1):
    a, b = chunk[0]["n"], chunk[-1]["n"]
    with open(os.path.join(out, "prompt-U%d.md" % k), "w", encoding="utf-8") as f:
        f.write("Abre el archivo fuente.md del directorio actual con tu herramienta de lectura de archivos.\n"
                "Devuelve UNA línea por cada fila de la %d a la %d (columna #), en orden, con este formato exacto:\n"
                'FILA|<modelo sin backticks>|<solicitudes por 5h, solo dígitos>|<límite mensual en USD, solo dígitos>|"<cita textual completa de Notas>"|"<cita textual completa de Origen>"|\n'
                "Termina con la línea ===FIN===\n" % (a, b))
    ls = [line(r) for r in chunk]
    falla = "OK"
    if k == 2:    # un número alterado frente a la fuente
        r = dict(chunk[1]); r["req"] += 137; ls[1] = line(r); falla = "FALLO:numero"
    elif k == 3:  # dos filas intercambiadas junto con sus citas (los datos quedan bajo el nombre ajeno)
        r0, r1 = dict(chunk[0]), dict(chunk[1]); r0["name"], r1["name"] = r1["name"], r0["name"]
        ls[0], ls[1] = line(r0), line(r1); falla = "FALLO:intercambio"
    elif k == 4:  # dos filas omitidas, con ===FIN=== presente
        ls = ls[:2]; falla = "FALLO:omision"
    elif k == 5:  # una fila inventada con cita fabricada
        ls.insert(2, 'FILA|quimera-pro-3.1|4321|60|"sin retención; revisión 99"|"consola del 2026-10-31"|'); falla = "FALLO:inventada"
    elif k == 7:  # salida truncada a media fila, sin ===FIN===
        ls = ls[:2] + [ls[2][:len(ls[2]) // 2]]; falla = "FALLO:truncada"
    elif k == 8:  # cita no textual: una palabra cambiada
        r = dict(chunk[0]); r["nota"] = r["nota"].replace("revisión", "versión"); ls[0] = line(r); falla = "FALLO:cita"
    body = "\n".join(ls) + ("\n" if k == 7 else "\n===FIN===\n")
    with open(os.path.join(out, "U%d.out" % k), "w", encoding="utf-8") as f:
        f.write(body)
    clave["U%d" % k] = falla

pares = "\n".join("U%d: prompt-U%d.md → U%d.out" % (k, k, k) for k in range(1, len(units) + 1))
with open(os.path.join(out, "prompt-PREREV.md"), "w", encoding="utf-8") as f:
    f.write("""Eres pre-revisor de un lote. Abajo va la lista de %d unidades como pares de RUTAS de archivo
(prompt original → salida del agente barato). Abre cada archivo con tus herramientas de
lectura desde el directorio actual; no asumas su contenido. La fuente de todas es fuente.md, también
en el directorio actual.
===PARES===
%s
Para cada unidad verifica: (a) ¿CADA número y hecho coincide con fuente.md y trae cita TEXTUAL?;
(b) ¿contradice a otra unidad?; (c) ¿hay filas o citas inventadas?; (d) ¿la unidad omite algo que su
prompt exigía?; (e) ¿la salida está completa o quedó truncada?
Responde EXACTAMENTE en este formato:
===VEREDICTOS===
U1: OK|DUDOSO|FALLO — razón breve con el dato clave
===DISCREPANCIAS===
- unidad A vs B: dato → valor A vs valor B
===ALTO_IMPACTO===
- dato → por qué el orquestador debe verificarlo en primaria
===BORRADOR===
(síntesis solo de unidades OK)
===FIN===
""" % (len(units), pares))
json.dump(clave, open(os.path.join(out, "clave.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
