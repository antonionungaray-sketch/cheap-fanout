# La carrera de SQLite al arrancar opencode — diagnóstico 2026-09-11

**Síntoma reportado:** dos `opencode run` simultáneos en Windows 11 (opencode 1.18.25) comparten
`%USERPROFILE%\.local\share\opencode\opencode.db`; uno muere al arrancar con `database is locked`
y exit code 1.

**Veredicto:** reproducido y entendido. No es "demasiada concurrencia": es una ventana de carrera
que solo existe mientras la base está **fría** (hay que crearla o migrarla). Con la base ya creada
y migrada, la concurrencia es inofensiva.

> **Dónde se midió y dónde se verificó.** Los experimentos corrieron en **Ubuntu con opencode
> 1.18.29**. Para no extrapolar, se bajó de npm el binario **exacto** del caso reportado
> (`opencode-windows-x64@1.18.25`, 180 MB) y se inspeccionó: el orden de PRAGMAs, el `orDie` y el
> corredor de migraciones son **idénticos**, y tanto el subcomando `opencode db` como la variable
> `OPENCODE_DB` ya existen ahí — o sea, el arreglo aplica tal cual en esa máquina. Lo único que
> sigue sin verificar es la agravante a nivel de sistema operativo (§5).

---

## 1. Causa raíz — dos cabezas, mismo origen

Ambas viven en la inicialización de la base, leída directamente del bundle. Lo de abajo está
**copiado del binario de Windows 1.18.25**, el del caso reportado (idéntico en el 1.18.29 local):

```js
// al abrir la conexión nativa:
let Y = new YG(_.filename, {...});
if (..., _.disableWAL !== true) Y.run("PRAGMA journal_mode = WAL;");

// y enseguida, en la capa de servicio:
PRAGMA journal_mode = WAL
PRAGMA synchronous  = NORMAL
PRAGMA busy_timeout = 5000        // ← TERCERO
PRAGMA cache_size   = -64000
PRAGMA foreign_keys = ON
PRAGMA wal_checkpoint(PASSIVE)
→ migraciones
```

### Cabeza 1 — `busy_timeout` se instala tarde → `database is locked`

`journal_mode = WAL` se ejecuta **dos veces antes** de que exista el busy handler. Si la base ya
está en WAL, es un no-op inocuo. Pero si **no** lo está, convertirla pide un lock **EXCLUSIVO**:
sin busy handler, el proceso que llega tarde recibe `SQLITE_BUSY` al instante.

Toda la capa va envuelta en `.pipe(orDie)` → el proceso **muere con exit 1**.

### Cabeza 2 — el corredor de migraciones hace check-then-act → `Failed query: CREATE TABLE …`

```js
$ = new Set((yield* _.all(`SELECT id FROM migration`)).map(U => U.id))   // se lee UNA vez
for (let A of Y) { if ($.has(A.id)) continue; yield* _.transaction(...) }
```

Dos procesos fríos leen la misma lista vacía, los dos aplican la migración 1, y el perdedor muere
con `Failed query: CREATE TABLE \`workspace\` (…)`. **No es `SQLITE_BUSY`**, así que un detector
que solo busque `database is locked` no lo ve.

### Cabeza 3 — la variante silenciosa

Ya documentada en `hallazgos-2026-08-11.md`: `.status = 0` con un `.out` que trae solo la cabecera
`> build · <model>`. Pasa cualquier check de `.status`.

---

## 2. Por qué `--print-logs --log-level DEBUG` no ayuda

El proceso muere **antes de que el logger exista**. Medido: un arranque fallido produce
**0 líneas** de log en stderr, contra ~470 de uno exitoso. El plan de diagnosticar por logs no
iba a dar señal; hay que mirar el contenido del `.out`.

---

## 3. Evidencia (Ubuntu, opencode 1.18.29, base real de 403 MB)

Banco de pruebas gratis: `opencode db "SELECT 1"` recorre la misma inicialización que
`opencode run` pero no llama a ningún modelo.

| escenario | resultado |
|---|---|
| 16 arranques simultáneos, base ya en WAL y migrada | **16/16 OK** |
| 6 arranques simultáneos sobre base FRÍA, ×5 ensayos | **15/30 murieron** |
| lo mismo, precalentando la base una vez antes | **0/30 murieron** |
| 2 `opencode run` simultáneos, base caliente (el caso reportado) | 2/2 OK |

Réplica aislada del orden de PRAGMAs, sin opencode de por medio (`python3 sqlite3`):

| caso | resultado |
|---|---|
| orden de opencode, base **ya en WAL**, 8 simultáneos | 8/8 OK |
| orden de opencode, base **no-WAL**, 8 simultáneos | **6/8** (2 mueren) |
| `busy_timeout` PRIMERO, base no-WAL, 8 simultáneos | 8/8 OK |

Un detalle que importa para el arreglo: si otro proceso ya tiene un lock de escritura sostenido,
poner `busy_timeout` primero **tampoco basta** — SQLite no invoca el busy handler al subir a
EXCLUSIVO (evita deadlock). Por eso el arreglo correcto no es "subir el timeout", sino
**reintentar reabriendo la conexión**.

---

## 4. Cuándo se abre la ventana en la vida real

La base está fría, y por lo tanto el bug muerde, cuando:

- es la **primera corrida** tras instalar;
- cambió el **canal** de release → opencode usa otro archivo (`opencode-<canal>.db`);
- se usa un **`OPENCODE_DB`** nuevo;
- **hay migraciones pendientes tras un upgrade** ← el más traicionero: la base existe desde hace
  meses y aun así el primer lote después de actualizar entra en la ventana.

Ese último explica por qué el bug aparece "de repente" en una máquina que llevaba semanas bien.

---

## 5. La agravante de Windows (hipótesis NO verificada)

En Windows el síntoma es crónico y en Linux esporádico. Mi hipótesis, que **no pude probar desde
Ubuntu**: cuando la última conexión a una base WAL se cierra, SQLite hace checkpoint y **borra los
archivos `-wal` y `-shm`**, lo que pide lock exclusivo. En Linux borrar un archivo con handles
abiertos es normal; en Windows falla con sharing violation, y Defender sosteniendo handles
transitorios lo empeora. Como los `opencode run` de un lote abren y cierran constantemente, la
carrera cierre-contra-apertura se repite todo el tiempo.

**Si alguien valida esto en Windows**, la prueba es: lote con la base ya caliente y migrada; si aun
así hay fallos, la agravante es real y el precalentado no basta ahí (el reintento sí lo cubre).

Ojo con leer de más en el reporte original: los síntomas de Windows del 2026-08-11 ocurrieron
**con la base vieja y caliente**, no recién instalada — lo que apunta a que allá hay algo más que
la ventana fría, o a que ese día había migraciones pendientes de un upgrade reciente. No se puede
decidir entre esas dos desde Ubuntu.

---

## 6. Qué se cambió en cheap-fanout

Dos capas, porque ninguna sola alcanza:

1. **Pre-vuelo: precalentar** (`warm_opencode_db`). Una sola llamada en serie a
   `opencode db "SELECT 1"` deja la base creada, en WAL y migrada antes de soltar el lote. Cuesta
   ~1s y cero tokens. Toma un **`flock` global** si el sistema lo tiene, para que dos lotes
   simultáneos no se peleen — ésta es la "serialización global de las escrituras de inicialización".
   Nunca es fatal: si no se puede precalentar, avisa y el lote sigue.
2. **Reintento con backoff exponencial + jitter** por job, para las tres cabezas. Sale barato: el
   choque ocurre **antes** de llamar al modelo, así que un reintento no gasta tokens. El jitter no
   es adorno — sin él, los N jobs que chocaron en el mismo instante reintentan en el mismo instante.

Reintentar la colisión de migraciones es **seguro**: cada migración corre en una transacción que
crea las tablas E inserta su fila en `migration`, y SQLite tiene DDL transaccional — el perdedor
revierte entera y al reintentar ve la migración ya aplicada.

Nuevos: `.status = 75` (siguió bloqueado tras los reintentos), marcador `.out.retried` con el
número de intentos, y las perillas `CHEAP_FANOUT_RETRIES` (3), `CHEAP_FANOUT_RETRY_BASE` (2s),
`CHEAP_FANOUT_NO_WARMUP=1`.

**Test de regresión:** `skills/cheap-fanout/test/sqlite-race.sh` — lanza N jobs contra una base
fría propia (nunca toca la tuya) con un modelo `-free`, y exige 0 fallos. Costo: cero.

---

## 7. Lo que NO se hizo, y por qué

- **Aislar la base por job** (`OPENCODE_DB` distinto para cada uno) elimina la contención de raíz,
  y la palanca existe: `OPENCODE_DB` acepta ruta absoluta o `:memory:`. **Se descartó como default
  porque rompería `go-budget`**, que calcula el gasto del plan Go leyendo las sesiones de la base
  compartida: los jobs de fanout —que son justamente el grueso del gasto— dejarían de contarse.
- **Parchar opencode.** El arreglo de raíz es suyo y es de una línea: mover
  `PRAGMA busy_timeout` ANTES del primer `journal_mode = WAL`, y envolver el corredor de
  migraciones en una transacción con `BEGIN IMMEDIATE` (o revalidar la lista de aplicadas dentro de
  la transacción). Vale la pena reportarlo aguas arriba; este documento tiene la evidencia lista.
