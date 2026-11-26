"""Genera el fixture del banco de extracción: <dir>/fuente.md (31 filas) y <dir>/expected.json.
Determinista (semilla 20261121); sha256 de fuente.md: 2116c44e21f831f7dbb1135543e9621f521354853921c305558e17c50ff71a9e.
Uso: python3 -I gen.py <dir>"""
import random, json, sys, os
out = sys.argv[1] if len(sys.argv) > 1 else "."
random.seed(20261121)
pref=['nimbo','cuarzo','lince','ámbar','sauce','delta','órbita','tundra','cobalto','brisa','faro','jade','marea','nogal','pampa','quetzal','roble','sílice','tejón','umbral','vértice','yunque','zafiro','alba','bruma','cénit','duna','eco','fresno','granito','helio']
rows=[]
for i,p in enumerate(pref):
    name=f"{p}-{random.choice(['flash','pro','max','mini','lite'])}-{random.randint(2,9)}.{random.randint(0,9)}"
    req=random.randint(80,48000); lim=random.choice([15,20,30,60,100,500])
    nota=random.choice(['sin retención','retiene 30 días','entrena con datos','solo texto','texto e imagen','alojado en EE. UU.','alojado en Europa','lento en hora pico'])+f"; revisión {random.randint(1,40)}"
    origen=random.choice(['consola','endpoint','doc pública','changelog'])+f" del 2026-{random.randint(8,11):02d}-{random.randint(1,28):02d}"
    rows.append(dict(n=i+1,name=name,req=req,lim=lim,nota=nota,origen=origen))
with open(os.path.join(out, 'fuente.md'),'w') as f:
    f.write('# Tabla de límites (fixture de benchmark)\n\n| # | Modelo | Solicitudes por 5h | Límite mensual (USD) | Notas | Origen |\n|---|---|---|---|---|---|\n')
    for r in rows: f.write(f"| {r['n']} | `{r['name']}` | {r['req']:,} | {r['lim']} | {r['nota']} | {r['origen']} |\n")
json.dump(rows,open(os.path.join(out, 'expected.json'),'w'),ensure_ascii=False)
