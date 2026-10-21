# Illustrative client extension stubs

These are provisional examples for the architecture discussion, not a Retail port
or a supported public extension API. `RetailItemExtension.lua` is deliberately
absent from the current TOC and excluded from release packages.

The item pipeline has optional, working call sites. With no descriptor extension,
normal behavior is unchanged and `model.retail` remains absent. The example file
registers no-op readers and a view contributor that only adds content if an
extension supplies `model.retail.upgrade`.
The underscore-prefixed parameters in the example identify intentionally unused
arguments in the no-op callback bodies.

## Where to look

| File / boundary | Illustrative behavior |
| --- | --- |
| `Tooltips/Item.lua`: `newItemModel` | Calls `extension.initModel(model)` for root, crafted-item, and editor sample models |
| `Tooltips/Item.lua`: content classification | Calls `extension.readLine(model, line, context)`; only `true` claims a line and skips ordinary classification |
| `Tooltips/Item.lua`: end of text-line classification | Calls `extension.afterReadLine(model, line, context)` to decorate the resulting model |
| `Tooltips/Item.lua`: end of full reading | Calls `extension.afterRead(model, context)` on a crafted item first, then the root |
| `Tooltips/Item.lua`: completed outer view | Calls `extension.extendView(view, model, context)` before width measurement and drawing |
| `Panel/Layout.lua` | Documents the optional descriptor field; the registry does not dispatch these callbacks automatically |
| `Panel/Render.lua` | Consumes the completed view, including additions, for both measurement and drawing |
| `Integration/Hooks.lua` | Keeps existing read/render failure handling and native presentation ownership |
| `PrettyTooltip.lua` | Documents where client registration must load in TOC order |

## Model ownership

Only the client initializer sets `model.retail = {}`. The core neither creates the
field nor interprets its contents. Fresh models receive fresh extension state.
Shared concepts stay in shared fields; a client-specific row decoration needs an
explicit shared row contract before the renderer can interpret it.

## Reader context and limits

Reader context contains `nativeTooltip`, `data`, `game`, and `rootModel`. During a
text-line callback it also contains `lineNumber` (position in `data.lines`), `text`
(trimmed, core-reworded left text), `originalText`, and `rightText`. The line fields
are cleared before `afterRead`. Do not retain the mutable context as model data.

The callbacks receive the current item model, which can differ from `rootModel`
inside a recipe. The current stubs leave early structural handling (stock changes
and recipe routing), name/level classification, sell-price metadata, and collection
of appended native lines under core control.
`readLine` is placed before the remaining content classification; `afterReadLine`
also observes structural text lines. Neither is called for metadata-only lines
without a native `lineIndex`, or for the separate appended-FontString scan.

The core checks readable text and basic line access first, but does not deeply
sanitize raw metadata. Callbacks must validate optional fields, respect secret
values, and treat native data tables as read-only. Exceptions propagate to the
existing protected read/render call and cause native fallback in live integration;
they are not converted into an unhandled-line result after partial mutation.

## View context and limits

View context contains `panel` and `styles`. Header entries have provisional IDs
`title`, `slot` (when present), and `binding`, so contributors can find semantic
positions rather than assume numeric indices. IDs do not affect drawing.

Contribute rows or sections to the view before rendering; custom sections need
matching measurement and drawing. Do not change native alpha, padding, input,
comparison state, or anchoring from a content callback.
View callbacks should change the view and treat the cached model as read-only.

`extendView` runs for the outer item view and editor previews. The custom embedded
item drawing path does not construct that view, so it does not yet have this hook.
Internal stats/enchants/socket insertion points, native `readDetails`, additional
tooltip types, style/default registration, client API adapters, hot registration,
and extension-version cache invalidation are outside this initial illustration.
Register before models or previews are created; changing callbacks at runtime is
not supported by these stubs.
