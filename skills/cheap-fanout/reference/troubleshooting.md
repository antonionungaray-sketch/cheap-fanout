# Troubleshooting de cheap-fanout — síntoma → arreglo

> Material de referencia del skill `cheap-fanout`, extraído del `SKILL.md` el 2026-10-01 para no
> cargarlo en cada invocación. Ábrelo cuando un job falle o el helper diga algo que no esperabas.

| Síntoma | Arreglo |
|---|---|
| Solo corre el primer lote de `--parallel` | Falta el `< /dev/null` del helper — usa bin/cheap-fanout tal cual |
| `database is locked` | Carrera de ARRANQUE, no de concurrencia sostenida: opencode instala `busy_timeout` DESPUÉS de convertir la base a WAL, así que solo muerde con la base fría. El helper ya precalienta y reintenta; si llega hasta ti (`.status=75`), corre `opencode db "SELECT 1"` a mano y relanza, o sube `CHEAP_FANOUT_RETRIES` |
| `.status` = 75 / "SQLITE BLOQUEADO" | Agotó los reintentos. Misma receta: precalentar a mano y relanzar. Bajar `--parallel` ayuda poco si la base sigue fría |
| `.status` = 75 pero el `.out` es un informe completo | Falso positivo ya corregido (2026-10-01): el informe *citaba* "database is locked" y el detector lo tomó por el choque. Ahora solo cuenta si el `.out` pesa ≤ 2 KB (`CHEAP_FANOUT_LOCK_OUT_MAX`). Si ves el `.out` bueno con 75, el `.out` es válido: úsalo |
| `Failed query: CREATE TABLE …` | La otra cara de la misma carrera: dos procesos fríos aplicaron la misma migración. Reintentar es seguro (DDL transaccional); el helper ya lo hace |
| `.status` = 66 / "SALIDA VACÍA" | Tercera cara, silenciosa: exit 0 pero el `.out` solo traía cabecera. El helper la reintenta; si persiste, es que el modelo de verdad no dijo nada |
| `.status` = 64 / "PROMPT DEMASIADO LARGO" | El prompt excede el argv del sistema (~28 KB en Windows). El job NO se lanzó: reházlo por referencia (rutas de archivos en un prompt corto) o sube `CHEAP_FANOUT_ARGV_MAX` si sabes lo que haces |
| exit 126 `Argument list too long` (corrido a mano) | El prompt viaja como argumento y Windows topa en ~32 KB. Pásalo por el helper (que lo detecta antes con status 64) o usa prompt por referencia |
| Salida con basura al inicio | Cabecera de opencode (`> build · <model>`) **más códigos ANSI** (`\x1b[0m`): limpia ambos antes de parsear o medir si está vacía |
| Job devolvió null/basura | Rehazlo o reasígnalo a un modelo mejor; no lo integres a ciegas |
| `.status` = 124 o 137 | El job venció su plazo y el helper lo mató. Sube la 4ª columna de ESE job (o `none`) y relánzalo; si vence otra vez, el modelo se está atorando: reasigna |
| `timeout inválido: 'X'` | La 4ª columna solo admite `90`, `30s`, `8m`, `1h` o `none` |
| `.status` = 77 / "SIN CUOTA" | Ese modelo se quedó sin presupuesto y no hay gemelo free seguro (el rescate automático está apagado: esos gemelos entrenan). Corre `go-budget`: cada modelo tiene su propio límite, así que **otro modelo Go siempre tiene presupuesto** salvo que también esté agotado. Decisión de calidad tuya; o un free sin entrenamiento (`longcat-2.5-preview-free`, `space-bunny-free`), `codex` o `kimi-code-plan-cn/k3` |
| `This model collects data used to improve its quality and requires explicit opt in` | Es `muse-spark-1.2/1.3-contributor`, que están **vetados**: no lo actives en la consola. Rutea a `deepseek-v4.1-flash` |
| `MODELO VETADO` (exit 2, no corrió nada) | El helper rechaza el lote **entero en pre-vuelo** si algún job usa un modelo vetado — mejor que gastar cuota en los demás y descubrirlo al final. Cambia el modelo de esa línea (ver *Modelos vetados* en el SKILL.md), no la variable de entorno |
| Un modelo de la doc no aparece en `opencode models` | Esa lista viene desfasada; no es autoridad. Pruébalo con `opencode run -m opencode-go/<id> "Responde exactamente: PONG"` antes de descartarlo |
| Lote DeepSeek gastó el doble de lo esperado | Horas peak (dom-jue 19:00-22:00 y lun-vie 00:00-04:00 CDMX): los cuatro modelos DeepSeek cuestan 2x. Córrelo fuera de esa franja o usa `glm-5.3-flash`, que no tiene peak |
| "cuota Go agotada → servido por opencode/…-free" | Solo puede pasar con `CHEAP_FANOUT_ALLOW_TRAINING_TWINS=1` (gemelos que entrenan). Por default el helper ya no rescata: deja `.status=77` |
| El agente "no puede buscar" | opencode solo tiene `webfetch`: dale una URL de arranque. codex no tiene web search: reasigna a opencode |
| El agente reporta 403 / "bloqueado" / página vacía | No es culpa del modelo: el fetcher está bloqueado. Sube la cascada de 3 escalones (`r.jina.ai` → ZenRows GET) |
| Los precios del skill se ven como `analiza.14` / `las.40` | El cargador sustituyó cada `$N` por el argumento N de `/cheap-fanout …`. Los precios del archivo ya van como "USD" para evitarlo; si pasa, relee el SKILL.md desde disco |
| `r.jina.ai` da 200 pero el `.out` viene vacío | Cloudflare/CAPTCHA — Jina respeta el bloqueo por diseño. Escala a ZenRows con `premium_proxy=true` |
| Job con ZenRows muere en 124 (timeout) | Normal: una request `js_render+premium_proxy` tarda ~75s. Sube la 4ª columna a `8m` o `none` |
| `r.jina.ai` da 403 `AbuseAlleviationError` | El dominio está vetado para acceso anónimo (p.ej. x.com). Con API key de Jina o directo a ZenRows |
| Job codex colgado (corrido a mano) | `codex exec` lee stdin: añade `< /dev/null` (el helper ya lo hace) |
| codex "not logged in" | Corre `codex login` una vez en sesión interactiva (auth ChatGPT) |
| `codex:gpt-6.1-sol` da "not supported when using Codex with a ChatGPT account" | Tu Codex es anterior a 0.159.1 y no conoce el modelo (aquí ya está en 0.159.3) ("Model metadata … not found"). Actualiza: `npm install -g @openai/codex@0.159.3` (global; decisión tuya) |
| Job codex no escribe: `bwrap: loopback: Failed RTM_NEWADDR` | AppArmor niega user namespaces a bwrap (Ubuntu 24.04). **En esta máquina ya está resuelto** con el perfil `bwrap-userns-restrict`; en otra, ver *Sandbox de Linux* en `reference/codex.md` |
| Job codex responde "no pude leer <archivo>" con `bwrap … RTM_NEWADDR` | Misma causa: sin el perfil de AppArmor el sandbox falla incluso en `read-only` y el job **ni lee archivos**. Cárgalo (ver *Sandbox de Linux* en `reference/codex.md`). Mientras tanto: el dato en el prompt, o `danger-full-access` en un directorio aislado |
| `Invalid Authentication` con `moonshotai/*` | Esa llave es de Kimi For Coding, no de api.moonshot.ai: usa la ruta `kimi-code-plan-cn/k3` |
| `kimi-code-plan-cn/k3` (o la vieja `kimi-for-coding/k3`) da `UnknownError` | opencode ≥ 1.18.31 busca la credencial bajo **`kimi-code-plan-cn`** y la tuya sigue bajo `kimi-for-coding`. Exporta `KIMI_API_KEY` con la misma llave `sk-kimi-…`, o copia esa entrada de `~/.local/share/opencode/auth.json` al nombre nuevo. Compruébalo con curl: `GET https://api.kimi.com/coding/v1/models` con `Authorization: Bearer <llave>` debe dar 200 |
| K3 (u otro pre-revisor) devuelve veredicto imparseable | No reintentes al mismo: pasa al siguiente pre-revisor rápido (`deepseek-v4.1-flash`); solo si también falla, revisa TÚ el lote completo |
| K3 429/cuota o >5 min | Mata el job y usa `deepseek-v4.1-flash` como pre-revisor (141s medido); **no caigas a ti** salvo que fallen los dos. Si K3 reincide, sácalo de la sesión |
