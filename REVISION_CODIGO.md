# Revisión técnica de LootHunter

## Resumen ejecutivo

El addon funciona y tiene una base sólida, pero actualmente tiene **alto acoplamiento**, **archivos muy grandes** y algunos puntos con **inconsistencias de API** que pueden causar bugs sutiles al integrarlo con otros módulos.

## Mejoras recomendadas (prioridad alta)

1. **Dividir archivos monolíticos por dominio**
   - `LootHunter.lua` concentra demasiada lógica (estado, eventos, helpers, integración, stats, UI hooks).
   - `UI.lua` y `Settings.lua` también son extensos y mezclan layout, estado, eventos y reglas.
   - Recomendación: separar en módulos como `core/`, `ui/`, `data/`, `stats/`, `events/`, `api/`.

2. **Corregir contrato de retorno en `LootHunterAPI:IsFavorite`**
   - El comentario declara retorno `(boolean isFavorite, string shortLabel)`, pero en ramas de `BonusRollPreview` se retorna `("", false)` o `(FAVORITE_LABEL, true)`, invirtiendo tipos y orden.
   - Esto puede romper consumidores que asumen contrato estable.
   - Recomendación: definir una firma única y respetarla en todas las ramas.

3. **Reducir trabajo repetido en `IsFavorite`**
   - `CalledFromBonusRollPreview()` se evalúa muchas veces dentro de la misma ejecución de `IsFavorite`.
   - Recomendación: evaluarlo una sola vez al inicio (`local fromPreview = CalledFromBonusRollPreview()`) y reutilizar.

4. **Poner límite al log de debug en memoria**
   - `DebugLog` crece sin límite (`table.insert`) cuando el debug está activo.
   - En sesiones largas puede impactar memoria y rendimiento.
   - Recomendación: ring buffer (por ejemplo, últimos 500 o 1000 eventos).

## Mejoras recomendadas (prioridad media)

5. **Unificar idioma y estilo de comentarios**
   - Hay mezcla de comentarios en inglés/español y algunos problemas de codificación (`pesta?a`).
   - Recomendación: normalizar a UTF-8 y español en comentarios internos.

6. **Estandarizar strings y localización por archivo/idioma**
   - `Localization.lua` mezcla una base grande en inglés y luego bloques en español, lo que dificulta mantenimiento.
   - Recomendación: separar por locale (`enUS.lua`, `esES.lua`) y cargar por `GetLocale()`.

7. **Reducir duplicación de utilidades UI**
   - Helpers como `ForEachChild`, `DrainChildren`, `ForEachRegion` aparecen en más de un archivo.
   - Recomendación: mover utilidades comunes a un módulo compartido.

## Mejoras recomendadas (prioridad baja)

8. **Añadir validaciones automatizadas ligeras**
   - Falta un flujo rápido para chequeos sintácticos/estáticos en CI.
   - Recomendación: incorporar `luac -p`/`luacheck` en workflow (si el entorno de release lo permite).

9. **Documentar contratos públicos del `addonTable`**
   - Muchas funciones se comparten dinámicamente vía `addonTable`.
   - Recomendación: crear documento de interfaces internas para reducir regresiones al refactorizar.

## Evidencia consultada

- `API.lua`
- `LootHunter.lua`
- `UI.lua`
- `Settings.lua`
- `Stats.lua`
- `Localization.lua`
- `Modules/Debug.lua`
