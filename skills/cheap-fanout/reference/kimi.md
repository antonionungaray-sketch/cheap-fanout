# K3 y Kimi — credencial, plan y velocidades (2026-10-01)

> Material de referencia del skill `cheap-fanout`, extraído del `SKILL.md` el 2026-10-01 para no
> cargarlo en cada invocación. Ábrelo cuando `kimi-code-plan-cn/k3` falle o para decidir entre las variantes de Kimi.

> **Cambió el 2026-09/10 y rompió la ruta vieja.** models.dev renombró el proveedor
> `kimi-for-coding` a **`kimi-code-plan-cn`** (endpoint `https://api.kimi.com/coding/v1`, la misma
> suscripción) y a `kimi-code-plan-global` (`api.kimi.ai`). opencode 1.18.31 usa los ids nuevos y
> la credencial seguía guardada bajo el nombre viejo, así que `kimi-for-coding/k3` daba
> `UnknownError` aunque la llave fuera válida (verificado con curl: HTTP 200 directo). El helper
> traduce `kimi-for-coding/*` a `kimi-code-plan-cn/*`, y **en esta máquina la credencial ya está
> copiada bajo el nombre nuevo (2026-10-01)**: `kimi-code-plan-cn/k3` y `kimi-for-coding/k3`
> responden por el helper **sin** `KIMI_API_KEY`.

El proveedor expone cuatro ids: `k3` (1M ctx), `k3-256k`, `kimi-for-coding` (que ahora es **K2.8
Preview**, 1M ctx, desde el 2026-09-11) y `kimi-for-coding-highspeed` (K2.7 Code a ~180-260
tokens/s, consume 3x). En `jobs.tsv` van con la ruta completa: `kimi-code-plan-cn/k3`.

- **Credencial:** el helper no puede arreglarla solo. opencode ≥ 1.18.31 busca `kimi-code-plan-cn`;
  la llave estaba guardada como `kimi-for-coding`. **Cómo se resolvió aquí sin exponerla:** se
  copió esa entrada dentro del mismo `~/.local/share/opencode/auth.json` (escritura atómica:
  archivo temporal 0600 en el mismo directorio y `rename`, sin imprimir la llave, sin copias de
  respaldo con secretos, permisos 600 verificados después; la entrada vieja se dejó intacta). En
  otra máquina haz lo mismo, o exporta `KIMI_API_KEY` solo para la sesión (**no** la pongas en el
  perfil del shell: quedaría en texto plano en más sitios). Smoke:
  `opencode run -m kimi-code-plan-cn/k3 "Responde exactamente: PONG"`. Un `UnknownError` genérico
  = falta la credencial bajo el nombre que opencode busca, no congestión.
- **Tu plan es "antiguo" y conserva sus reglas** (`kimi.com/code/docs/kimi-code/membership.html`):
  los planes nuevos (Plus 15, Pro 31, Max 79, Ultra 159 USD) quitaron la cuota semanal, pero los
  miembros antiguos siguen con cuota que se renueva cada 7 días **más** una ventana móvil de 5
  horas. De Allegretto en adelante tienes **K3 con 1M de contexto** y la **variante highspeed**.
- **Velocidad medida el 2026-10-01** (misma extracción de 6K tokens): K3 por Allegretto **43.5s**,
  K3 por la puerta Go **31.5s**, K2.8 Preview **39.5s**, K2.7 highspeed **23s** (2 corridas c/u;
  los rápidos de Go: 15-17s). **AA mide a K3 en 34 tokens/s.** Moonshot documenta que K3 usa
  esfuerzo `high` por defecto y que K2.8 Preview usa `max`; **bajar a `--variant low` no sirvió**
  en la pre-revisión (349s, peor calidad, 300 KB de trazas). K2.8 Preview no es más rápido que K3
  en mi prueba; lo único claramente más rápido dentro de Kimi es **highspeed (K2.7 Code)**, que es
  un modelo anterior y consume 3x de tu cuota.
