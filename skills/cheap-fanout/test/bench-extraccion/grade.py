"""Califica una salida del banco de extracción.
Uso: python3 -I grade.py [--tolerante] <expected.json> <fuente.md> <salida.txt>
--tolerante acepta '<n>|' en lugar de 'FILA|' y líneas sin el '|' final (mide datos, no formato)."""
import json, re, sys
args = sys.argv[1:]
tol = args[:1] == ["--tolerante"]
if tol: args = args[1:]
exp=json.load(open(args[0])); src=open(args[1]).read(); txt=open(args[2]).read()
if tol:
    txt = "\n".join((re.sub(r"^\d+\|", "FILA|", l) + ("" if l.endswith("|") or not re.match(r"^(\d+|FILA)\|", l) else "|")) for l in txt.splitlines())
got={}
for line in txt.splitlines():
    if not line.startswith('FILA|'): continue
    p=line.split('|')
    if len(p)<7: continue
    got[p[1].strip().strip('`')]=p
ok=0; bad=[]
for r in exp:
    p=got.get(r['name'])
    if not p: bad.append(r['name']+':falta'); continue
    try: req=int(re.sub(r'[^0-9]','',p[2])); lim=int(re.sub(r'[^0-9]','',p[3]))
    except ValueError: bad.append(r['name']+':num'); continue
    q1=p[4].strip().strip('"“”'); q2=p[5].strip().strip('"“”')
    if req==r['req'] and lim==r['lim'] and q1 and q1 in src and q2 and q2 in src: ok+=1
    else: bad.append(f"{r['name']}:{req}/{lim}")
fin='===FIN===' in txt
print(f"{ok}/{len(exp)} FIN={'si' if fin else 'NO'} malos={bad[:4]}")
