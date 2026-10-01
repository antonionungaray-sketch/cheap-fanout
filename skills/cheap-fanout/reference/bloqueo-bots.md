# Páginas que bloquean bots — cascada de 3 escalones (verificado 2026-08-09)

> Material de referencia del skill `cheap-fanout`, extraído del `SKILL.md` el 2026-10-01 para no
> cargarlo en cada invocación. Ábrelo cuando un agente reporte 403, CAPTCHA, página vacía o "bloqueado".

El bloqueo NO es contra el modelo barato: es contra el fetcher. `webfetch` es un GET plano, sin
JS, sin rotación de IP — Cloudflare/DataDome lo tumban. Como el agente barato no tiene shell, la
solución tiene que caber **en una URL**. Escala solo cuando el escalón previo falle:

1. **`webfetch` directo** — el default.
2. **Jina Reader — `https://r.jina.ai/<URL>`.** Gratis, sin key, 20 req/min (500 con key gratis);
   devuelve markdown limpio y **sí renderiza JS**, así que arregla SPAs y bloqueos leves de
   user-agent. **NO es bypass** y no finjas que lo es: *"Reader does not actively circumvent or
   bypass any website defense mechanisms"* (jina.ai/reader). Medido: g2.com devolvió 200 pero
   **cuerpo vacío** con `"This page maybe requiring CAPTCHA"`, y x.com dio 403. Si el `.out` trae
   markdown vacío o esa advertencia, **no es que el modelo falló** — escala al 3.
3. **ZenRows (unlocker con endpoint GET).** Se elige porque autentica por **query param**, o sea
   el agente barato lo llama con su `webfetch` tal cual:

   ```
   https://api.zenrows.com/v1/?apikey=KEY&url=<URL_ENCODED>&js_render=true&premium_proxy=true&response_type=markdown
   ```

   Créditos: base 1 · `js_render` 5 · `premium_proxy` 10 · ambos 25. Plan gratis 5,000 créditos/mes
   ⇒ **200 requests con anti-bot completo al mes, gratis**. Úsalo solo en las unidades que de
   verdad lo necesiten. Docs: `docs.zenrows.com/universal-scraper-api/api-reference`.

   **`response_type=markdown` no es opcional — es lo que hace viable el escalón.** Medido en
   g2.com: HTML crudo **1,227 KB** vs markdown **104 KB** (12x menos) por **el mismo costo de
   créditos**. Sin él, una sola página le revienta la ventana al modelo barato y te cobra los
   tokens de todo el DOM.

   **Tres números medidos el 2026-08-09 que cambian cómo armas el lote:**
   - **Latencia ~75s por request** con `js_render+premium_proxy` (vs 0.4s en modo base). El plazo
     de `2m` de investigación barata NO alcanza: dale **`8m`** a cualquier job que use ZenRows,
     y `none` si hace varias páginas duras.
   - **`Concurrency-Limit: 5`** en el plan gratis. Si N jobs pegan a ZenRows a la vez, baja
     `--parallel` a **4** o reparte: los jobs de sitios abiertos van en paralelo normal, los de
     ZenRows en un lote aparte.
   - Verifica el header **`X-Request-Cost`** cuando dudes de cuánto llevas gastado.

**Manejo de la key (regla dura).** El `webfetch` del agente NO lee variables de entorno: la key
tiene que ir **literal en la URL dentro del prompt file**. Por eso:
- La key vive **fuera del repo**: en tu archivo de credenciales o en `ZENROWS_API_KEY`. Léela al
  vuelo al armar los prompts, p.ej. `K="${ZENROWS_API_KEY:-$(grep -oE '[0-9a-f]{40}' RUTA_A_TUS_CREDENCIALES)}"`.
  Si la guardas en un `.md` propio, ojo con el encabezado exacto que uses al buscarla.
- **TÚ (orquestador) la lees y la inyectas** al generar los prompt files, que son temporales y
  viven en el scratchpad. Nunca la escribas en este SKILL.md, en un `jobs.tsv` versionado, ni en
  ningún archivo dentro de un repo.
- URL-encodea el `url=` destino (los `?` y `&` del target rompen el query si van crudos).

**Lo que NO entra por esta puerta:** ScrapingBee deprecó `api_key` en query y ahora exige header
`Authorization` — inalcanzable desde `webfetch`. Bright Data Web Unlocker es el más potente
(30+ tipos de CAPTCHA, 1.5 USD/1K, 5K gratis/mes) pero su API directa es POST: solo por MCP, no por
un agente barato. Crawl4AI self-host (Apache 2.0, undetected browser) es el escalón 4 si algún día
200 req/mes se quedan cortas — es infra que mantener, no lo montes antes de necesitarlo.
