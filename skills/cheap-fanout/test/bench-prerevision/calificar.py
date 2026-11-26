"""Califica la salida de un pre-revisor contra clave.json del banco sembrado.
Uso: python3 -I calificar.py <clave.json> <salida-del-prerevisor>
Imprime: aciertos=N/8 falsos_ok=K falsas_alarmas=M fin=si|NO
Una unidad sembrada acierta con DUDOSO o FALLO; una limpia, con OK. Sin veredicto = no acierta
(cuenta como falso OK si era sembrada y como falsa alarma si era limpia)."""
import json, re, sys
clave = json.load(open(sys.argv[1], encoding="utf-8"))
txt = re.sub(r"\x1b\[[0-9;]*m", "", open(sys.argv[2], encoding="utf-8", errors="replace").read())
bloque = txt.rsplit("===VEREDICTOS===", 1)[-1] if "===VEREDICTOS===" in txt else ""
ver = {}
for l in bloque.splitlines():
    m = re.match(r"\s*[-*]?\s*\**(U\d+)\**\s*:\s*\**(OK|DUDOSO|FALLO)", l)
    if m and m.group(1) not in ver:
        ver[m.group(1)] = m.group(2)
aciertos = falsos_ok = falsas = 0
for u, esperado in clave.items():
    v = ver.get(u)
    if esperado == "OK":
        if v == "OK": aciertos += 1
        else: falsas += 1
    else:
        if v in ("DUDOSO", "FALLO"): aciertos += 1
        else: falsos_ok += 1
print("aciertos=%d/%d falsos_ok=%d falsas_alarmas=%d fin=%s" % (aciertos, len(clave), falsos_ok, falsas, "si" if "===FIN===" in txt else "NO"))
