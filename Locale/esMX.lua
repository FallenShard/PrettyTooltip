-- The Latin American Spanish client: parsing wordings and names from the
-- client's tables (Forever 1.60.1.70450). Loads after English.lua.
-- Addon wording starts from the Spanish draft, with regional terms below;
-- a Latin American Spanish speaker should review it. Unconfirmed formats
-- still need captured tooltips before their wording can be relied on.
local _, ns = ...
local locale = ns.Locale

locale.supported = true
locale.features = { coefficients = true }

local formats = locale.formats
-- Confirmed by the verigans-mx capture: "Velocidad 3.20".
formats.weaponSpeed = "Velocidad %s"
-- ItemSparse's recipe descriptions, after ITEM_SPELL_TRIGGER_ONUSE.
formats.recipeTeaches = "Uso: Te enseña a %s"
-- Unconfirmed until a spell capture checks the complete wording.
formats.baseManaCost = "%d%% del maná base"
-- Unconfirmed on unit lines; these are the client's map legend names.
formats.rare = "Rara"
formats.rareElite = "Raro de élite"

-- SpellItemEnchantment has lists joined by y or e, and slash-separated
-- bonuses, with spaces on either side of a slash or neither side.
locale.listSeparators = { ", y ", " y ", " e ", ", ", " / ", " /", "/ ", "/" }
locale.descriptions.school = { "daño de %s", "daño de las %s", "daño %s", "hechizos de %s", "hechizos de las %s",
    "hechizos %s", "hechizos %ss" }
locale.schoolWords = { Arcane = "Arcano", Fire = "Fuego", Frost = "Escarcha", Holy = "Sagrado",
    Nature = "Naturaleza", Shadow = "Sombras", Holyfire = "Fuego Sagrado", Frostfire = "Pirofrío" }

-- Amounts and durations from the native Spell table (Forever 1.60.1.70450).
local descriptions = locale.descriptions
descriptions.clause = "^[^%d]-"
descriptions.range = { "%d a %d", "%d - %d", "%d-%d" }
descriptions.over = "durante %d s"
descriptions.overBefore = false
descriptions.eachSecond = { "cada segundo durante %d s", "por segundo durante %d s" }
descriptions.every = { "cada %d s", "cada %d segundos" }
descriptions.everyFor = "durante %d s"
descriptions.lasts = "dura %d s"
descriptions.perSecondAfter = { "cada segundo", "por segundo" }
descriptions.units = { "s", "seg", "segundo", "segundos", "min", "minuto", "minutos", "hora", "horas", "m", "metro", "metros", "objetivo", "objetivos", "veces", "cargas", "acumulaciones" }
descriptions.unitBoundaries = true
descriptions.heals = { "sana", "sanar", "sanación", "cura", "restablece", "regenera", "absorbe" }
descriptions.damageSchool = { "daño de %s", "daño de las %s", "daño %s" }

locale.statWordings = {}

local skills = locale.skills
skills.Alchemy = "Alquimia"
skills.Blacksmithing = "Herrería"
skills.Enchanting = "Encantamiento"
skills.Engineering = "Ingeniería"
skills.Leatherworking = "Peletería"
skills.Tailoring = { "Sastrería", "Costura" }
skills.Cooking = "Cocina"
skills["First Aid"] = "Primeros auxilios"
skills.Fishing = "Pesca"
skills.Mining = "Minería"
skills.Herbalism = { "Herboristería", "Botánica" }
skills.Skinning = { "Desuello", "Desollar" }
skills.Lockpicking = "Ganzúa"

local dispels = locale.dispels
dispels.Magic = "Magia"
dispels.Curse = "Maldición"
dispels.Disease = "Enfermedad"
dispels.Poison = "Veneno"
locale.questTags = { ["Élite"] = true, Calabozo = true, Banda = true, Grupo = true, JcJ = true }

local L = ns.L
L["Tooltips"] = "Tooltips"
L["All Tooltips"] = "Todos los tooltips"
L["Title"] = "Título"
L["Body Text"] = "Texto"
L["Appearance"] = "Apariencia"
L["On"] = "Activado"
L["Off"] = "Desactivado"
L["Scale"] = "Escala"
L["1 override"] = "1 ajuste propio"
L["%s overrides"] = "%s ajustes propios"
L["All shared"] = "Todo compartido"
L["Use tooltip text style"] = "Usar el estilo de texto del tooltip"
L["Use All Tooltips setting"] = "Usar el ajuste de Todos los tooltips"
L["Restore addon default"] = "Restaurar el valor del addon"
L["All Tooltips: %s"] = "Todos los tooltips: %s"
L["Tooltip Style: %s"] = "Estilo del tooltip: %s"
L["Defaults for all tooltip types. Individual types can override these settings."] = "Valores para todos los tipos de tooltip. Cada tipo puede personalizar estos ajustes."
L["Addon preferences, modifier keys, and editor appearance."] = "Preferencias del addon, teclas modificadoras y apariencia del editor."
L["Restyle and cursor settings for other tooltip types."] = "Ajustes de rediseño y seguimiento del cursor para otros tipos de tooltip."
L["Preview"] = "Vista previa"
L["Blizzard layout is active. This previews your saved style."] = "El diseño de Blizzard está activo. Esta es una vista previa de tu estilo guardado."
L["Restyle is off for this type. This previews your saved style."] = "El rediseño está desactivado para este tipo. Esta es una vista previa de tu estilo guardado."

-- The panels -------------------------------------------------------------------

-- The spell strip. Spanish spells measure their range in meters.
L["Cast"] = "Lanzamiento"
L["Cooldown"] = "Reutilización"
L["Range"] = "Alcance"
L["Cost"] = "Costo"
L["Free"] = "Gratis"
L["None"] = "Ninguno"
L["Self"] = "Uno mismo"
L["%s yd"] = "%s m"
L["Base Mana"] = "Maná base"
L["Next Rank"] = "Siguiente rango"
L["Rank %s"] = "Rango %s"

-- Items.
L["%s Slot"] = "%s casilla"
L["%s Slots"] = "%s casillas"
L["Requires %s %s"] = "Requiere %s %s"
L["Recipe"] = "Receta"
L["Made by %s"] = "Hecho por %s"
L["Expected value"] = "Valor estimado"
L["iLvl %s"] = "Niv %s"
L["Creates"] = "Crea"
L["Reagents"] = "Componentes"
L["Equipped"] = "Equipado"
L["Equipped With"] = "Equipado con"

-- Auras, flight paths, macros, and pet abilities.
L["Buff"] = "Beneficio"
L["Debuff"] = "Perjuicio"
L["%s stacks"] = "%s acumulaciones"
L["No time limit"] = "Sin límite de tiempo"
L["by %s"] = "de %s"
L["You are here"] = "Estás aquí"
L["Macro"] = "Macro"
L["Macro: %s"] = "Macro: %s"
L["Autocast"] = "Auto"
L["Autocast off"] = "Auto desactivado"
L["Active"] = "Activo"

-- World objects.
L["Herb"] = "Hierba"
L["Mining node"] = "Depósito"
L["Fishing pool"] = "Banco de peces"
L["Quest object"] = "Objeto de misión"
L["Auction"] = "Subasta"
L["%s to %s"] = "%s a %s"
L["Your skill %s"] = "Tu habilidad %s"

-- Quests and units.
L["Legendary"] = "Legendaria"
L["Heroic"] = "Heroica"
L["Group"] = "Grupo"
L["Scenario"] = "Gesta"
L["World event"] = "Suceso mundial"
L["Completed"] = "Completada"
L["Ready to turn in"] = "Lista para entregar"
L["In progress"] = "En curso"
L["AFK"] = "AUS"
L["DND"] = "NM"

-- The spell power rows.
L["Healing per Second"] = "Sanación por segundo"
L["Healing per Mana"] = "Sanación por punto de maná"
L["Damage per Mana"] = "Daño por punto de maná"
L["Spell Power Coefficient"] = "Coeficiente de poder con hechizos"
L["Spell Power Coefficient over time"] = "Coeficiente de poder con hechizos en el tiempo"
L["Healing Power Coefficient"] = "Coeficiente de poder de sanación"
L["Healing Power Coefficient over time"] = "Coeficiente de poder de sanación en el tiempo"
L["each"] = "cada uno"
L["Proc"] = "Activación"
L["Judgement"] = "Sentencia"
L["Judgement, stunned target"] = "Sentencia, objetivo aturdido"
L["Per swing, fast weapon"] = "Por golpe, arma rápida"
L["Per swing, slow weapon"] = "Por golpe, arma lenta"
L["Extra to the first targets"] = "Adicional a los primeros objetivos"

-- Stats --------------------------------------------------------------------------

L["All Stats"] = "Todas las estadísticas"
L["Attack Power vs %s"] = "Poder de ataque contra %s"
L["Hit Chance"] = "Probabilidad de golpe"
L["Critical Strike Chance"] = "Probabilidad de golpe crítico"
L["Hit Rating"] = "Índice de golpe"
L["Critical Strike Rating"] = "Índice de golpe crítico"
L["Haste Rating"] = "Índice de celeridad"
L["Expertise Rating"] = "Índice de pericia"
L["Defense Skill"] = "Habilidad de defensa"
L["Defense Rating"] = "Índice de defensa"
L["Dodge Chance"] = "Probabilidad de esquivar"
L["Dodge Rating"] = "Índice de esquivar"
L["Parry Chance"] = "Probabilidad de parada"
L["Parry Rating"] = "Índice de parada"
L["Block Chance"] = "Probabilidad de bloqueo"
L["Block Rating"] = "Índice de bloqueo"
L["Shield Block Value"] = "Valor de bloqueo con escudo"
L["Resilience Rating"] = "Índice de temple"
L["All Resistances"] = "Todas las resistencias"
L["Spell Damage Power"] = "Daño con hechizos"
L["Spell Damage Power vs %s"] = "Daño con hechizos contra %s"
L["Spell Penetration"] = "Penetración de hechizos"
L["Spell Hit Chance"] = "Probabilidad de golpe con hechizos"
L["Spell Critical Strike Chance"] = "Probabilidad de crítico con hechizos"
L["Spell Hit Rating"] = "Índice de golpe con hechizos"
L["Spell Critical Strike Rating"] = "Índice de crítico con hechizos"
L["Spell Haste Rating"] = "Índice de celeridad con hechizos"
-- The school's name follows in brackets: "Poder con hechizos (Fuego)".
L["%s Spell Power"] = "Poder con hechizos (%s)"
L["%s Spell Damage Power"] = "Daño con hechizos (%s)"
L["Healing Power"] = "Poder de sanación"
L["Health per 5 sec"] = "Salud cada 5 s"
L["Mana per 5 sec"] = "Maná cada 5 s"
L["Beasts"] = "bestias"
L["Demons"] = "demonios"
L["Dragonkin"] = "dragonantes"
L["Elementals"] = "elementales"
L["Giants"] = "gigantes"
L["Humanoids"] = "humanoides"
L["Mechanical"] = "mecánicos"
L["Undead"] = "no-muertos"

-- Stat categories, schools, and classes, as the style editor names them.
L["Primary attributes"] = "Atributos principales"
L["Attack"] = "Ataque"
L["Defense"] = "Defensa"
L["Magic"] = "Magia"
L["Healing"] = "Sanación"
L["Mana"] = "Maná"
L["Negative values"] = "Valores negativos"
L["Arcane"] = "Arcano"
L["Fire"] = "Fuego"
L["Frost"] = "Escarcha"
L["Holy"] = "Sagrado"
L["Nature"] = "Naturaleza"
L["Shadow"] = "Sombras"
L["Holyfire"] = "Fuego Sagrado"
L["Frostfire"] = "Pirofrío"
L["Warrior"] = "Guerrero"
L["Paladin"] = "Paladín"
L["Hunter"] = "Cazador"
L["Rogue"] = "Pícaro"
L["Priest"] = "Sacerdote"
L["Shaman"] = "Chamán"
L["Mage"] = "Mago"
L["Warlock"] = "Brujo"
L["Druid"] = "Druida"

-- The style editor ---------------------------------------------------------------

L["PrettyTooltip Style Editor"] = "Editor de estilo de PrettyTooltip"
L["Click any part of the sample to restyle it. Tooltips use the new look the next time they open."] =
    "Haz clic en cualquier parte del ejemplo para cambiar su estilo. Las descripciones usan el nuevo aspecto la próxima vez que se abran."
L["Click any part of the sample to edit it."] = "Haz clic en cualquier parte del ejemplo para editarla."
L["%s: click to edit"] = "%s: haz clic para editar"
L["There is no item with ID %s."] = "No hay ningún objeto con el ID %s."
L["Loading item %s..."] = "Cargando el objeto %s..."
L["The sample failed to draw: %s"] = "No se pudo dibujar el ejemplo: %s"
L["Nothing to show for %s ID %s."] = "Nada que mostrar para %s con ID %s."
L["%s (not installed)"] = "%s (no instalado)"
L["Custom"] = "Personalizada"
L["ID, or shift-click a link"] = "ID, o Mayús-clic en un enlace"
L["Clear"] = "Borrar"
L["Click to choose its color; right-click for the default."] =
    "Haz clic para elegir su color; clic derecho para el predeterminado."
L["Selected Part"] = "Parte seleccionada"
L["Font"] = "Fuente"
L["Size"] = "Tamaño"
L["Color"] = "Color"
L["Outline"] = "Contorno"
L["Thick Outline"] = "Contorno grueso"
L["All Caps"] = "Mayúsculas"
L["Capitalization"] = "Uso de mayúsculas"
L["Default"] = "Predeterminado"
L["Reset This Part"] = "Restablecer esta parte"
L["Text Size"] = "Tamaño del texto"
L["Panel Style"] = "Estilo del panel"
L["The frame drawn around each panel.\n\n• Default: DialogueUI's art while DialogueUI is installed, Flat beside EllesmereUI, otherwise Blizzard Border.\n• Blizzard Border: The game's own tooltip border.\n• Flat: A dark, flat panel with a thin edge.\n• DialogueUI: DialogueUI's art, while it is installed."] =
    "El marco que rodea cada panel.\n\n• Predeterminado: El arte de DialogueUI mientras DialogueUI esté instalado, Plano junto a EllesmereUI y, si no, Borde de Blizzard.\n• Borde de Blizzard: El borde de las descripciones del juego.\n• Plano: Un panel oscuro y plano con un borde fino.\n• DialogueUI: El arte de DialogueUI, mientras esté instalado."
L["Blizzard Border"] = "Borde de Blizzard"
L["Flat"] = "Plano"
L["Padding"] = "Margen interior"
L["Minimum Width"] = "Ancho mínimo"
L["Row Spacing"] = "Espacio entre filas"
L["Section Spacing"] = "Espacio entre secciones"
L["General"] = "General"
L["Text"] = "Texto"
L["Layout"] = "Diseño"
L["Behavior"] = "Comportamiento"
L["Other Tooltips"] = "Otras descripciones"
L["Reset Page"] = "Restablecer página"
L["Fonts, spacing, colors, and behavior shared by every tooltip type."] =
    "Fuentes, espaciado, colores y comportamiento que comparten todos los tipos de descripción."
L["Which tooltips are restyled, and the keys that change what they show."] =
    "Qué descripciones se rediseñan y las teclas que cambian lo que muestran."
L["Follow Cursor in Combat"] = "Seguir el cursor en combate"
L["Draw the PrettyTooltip panel for each kind that is restyled."] =
    "Dibuja el panel de PrettyTooltip para cada tipo rediseñado."
L["Every setting, with a live sample: which kinds of tooltip are restyled and follow the cursor, the modifier keys, and the look of each kind, down to the font and color of every part. Also /ptip."] =
    "Todos los ajustes, con una muestra en vivo: qué tipos de descripción se rediseñan y siguen el cursor, las teclas modificadoras y el aspecto de cada tipo, hasta la fuente y el color de cada parte. También /ptip."
L["Icon Placement"] = "Posición del ícono"
L["Left"] = "Izquierda"
L["Right"] = "Derecha"
L["Moves the item or spell icon, and the item level badge under it, to the right of the name."] =
    "Mueve el icono del objeto o hechizo, y la placa de nivel de objeto bajo él, a la derecha del nombre."
L["Panel Tint"] = "Tinte del panel"
L["On: The panel takes a color from what it shows:\n• Items: their quality, from uncommon up, or yellow for quest items\n• Spells and macros: the spell's school, or else the color of the resource it costs\n• Players and NPCs: the class color, gray once tapped, or red, yellow, or green by reaction\n• Buffs and debuffs: the dispel type's color, otherwise blue for buffs and red for debuffs\n• Objects: green for herbs, orange for ore, blue for fishing pools, yellow for locks and quest objects\n• Quests: a pale yellow-brown\n\nOff: Panels keep their plain, untinted color."] =
    "Activado: El panel toma un color de lo que muestra:\n• Objetos: su calidad, de poco común en adelante, o amarillo para los objetos de misión\n• Hechizos y macros: la escuela del hechizo o, si no, el color del recurso que cuesta\n• Jugadores y PNJ: el color de clase, gris si ya está reclamado, o rojo, amarillo o verde según la reacción\n• Beneficios y perjuicios: el color del tipo de disipación o, si no, azul para beneficios y rojo para perjuicios\n• Objetos del mundo: verde para hierbas, naranja para minerales, azul para bancos de peces, amarillo para cerraduras y objetos de misión\n• Misiones: un marrón amarillento pálido\n\nDesactivado: Los paneles conservan su color liso, sin tinte."
L["Washes the panel in the item's quality color, or the spell's school or resource. Off, every panel is neutral; the name keeps its quality color."] =
    "Tiñe el panel del color de calidad del objeto, o de la escuela o el recurso del hechizo. Desactivado, todos los paneles son neutros; el nombre conserva su color de calidad."
L["Separators"] = "Separadores"
L["The gold dividers between sections and the thin rules above other addons' rows. Off, they are hidden along with the space around them."] =
    "Los divisores dorados entre secciones y las líneas finas sobre las filas de otros addons. Desactivado, se ocultan junto con el espacio que los rodea."
L["School Colors"] = "Colores de escuela"
L["Enable Tooltip Fading"] = "Activar el desvanecimiento de las descripciones"
L["On: Panels for units and world objects fade out with the timings below; both at zero hides them at once.\n\nOff: They hide as soon as the cursor leaves them."] =
    "Activado: Las descripciones de unidades y objetos del mundo se desvanecen con los tiempos de abajo; ambos en cero las ocultan al instante.\n\nDesactivado: Se ocultan en cuanto el cursor sale de ellas."
L["Fade Delay"] = "Retraso del desvanecimiento"
L["Fade Duration"] = "Duración del desvanecimiento"
L[" sec"] = " s"
L["Show Icon"] = "Mostrar icono"
L["The icon or portrait in the header, for the kind of tooltip shown."] =
    "El icono o retrato del encabezado, para el tipo de descripción mostrado."
L["Header Opacity (Upper Edge)"] = "Opacidad del encabezado (borde superior)"
L["Header Opacity (Lower Edge)"] = "Opacidad del encabezado (borde inferior)"
L["Backdrop Opacity"] = "Opacidad del fondo"
L["Glow Strength"] = "Intensidad del brillo"
L["Footer"] = "Pie"
L["Item Details"] = "Detalles de objetos"
L["Spell Details"] = "Detalles de hechizos"
L["Unit Details"] = "Detalles de unidades"
L["Object Details"] = "Detalles de objetos del mundo"
L["Quest Details"] = "Detalles de misiones"
L["Quest Parchment"] = "Pergamino de misión"
L["DialogueUI's brown parchment for quest tooltips, Quest Items, and items that begin a quest, with darker ink for readability. Requires DialogueUI to be installed."] =
    "El pergamino marrón de DialogueUI para las descripciones de misiones, los objetos de misión y los objetos que inician una misión, con tinta más oscura para leer mejor. Requiere DialogueUI."
L["Level Badge"] = "Placa de nivel"
L["The item level on a plate under the icon, for equipment."] =
    "El nivel de objeto en una placa bajo el icono, para el equipo."
L["On: The level on a plate under the portrait.\n\nOff: The level stays in the info line."] =
    "Activado: El nivel en una placa bajo el retrato.\n\nDesactivado: El nivel queda en la línea de información."
L["Stat Markers"] = "Marcadores de estadísticas"
L["The small diamond before each stat; enchants use a green one."] =
    "El pequeño rombo delante de cada estadística; los encantamientos usan uno verde."
L["Stat Colors"] = "Colores de estadísticas"
L["On: Each kind of stat in its color, and the school colors.\n\nOff: Every stat is off-white."] =
    "Activado: Cada tipo de estadística en su color, y los colores de escuela.\n\nDesactivado: Todas las estadísticas son de un blanco amarillento."
L["Armor Colors"] = "Colores de armadura"
L["On: Cloth, leather, mail, and plate under the item's name, each in its color. A type you cannot wear stays red.\n\nOff: They take the quality color."] =
    "Activado: Tela, cuero, malla y placas bajo el nombre del objeto, cada uno en su color. Un tipo que no puedes usar sigue en rojo.\n\nDesactivado: Toman el color de calidad."
L["Abbreviated Equip Effects"] = "Efectos de Equipar abreviados"
L["Where the game's own item tooltip shows, in the Blizzard layout or with items not restyled, its Equip effects are shortened, as +1% Critical Strike Chance, and the game's colors kept, but for spell power and chance on hit effects in their stat colors. Hold the default tooltip modifier for the full wording."] =
    "Donde se muestra la descripción de objeto del juego, en el diseño Blizzard o con los objetos sin rediseñar, sus efectos de Equipar se abrevian, como +1% Probabilidad de golpe crítico, y se conservan los colores del juego, salvo el poder con hechizos y los efectos de probabilidad al golpear, en sus colores de atributo. Mantén presionada la tecla para la descripción del juego para ver el texto completo."
L["Disenchant"] = "Desencantar"
L["Green, blue, and purple armor and weapons list what they disenchant into, with each result's chance and the Enchanting it needs; with Auctionator, the expected value."] =
    "Las armaduras y armas verdes, azules y moradas indican en qué se desencantan, con la probabilidad de cada resultado y el Encantamiento que requieren; con Auctionator, el valor estimado."
L["Sell Price"] = "Precio de venta"
L["The vendor price in the footer; for a stack, the price of one and of the whole stack."] =
    "El precio del vendedor en el pie; para un montón, el precio de una unidad y del montón entero."
L["Weapon Damage First"] = "Daño del arma primero"
L["A weapon's damage on the large line, with its speed and damage per second on the small one under it."] =
    "El daño de un arma en la línea grande, con su velocidad y su daño por segundo en la pequeña debajo."
L["Spell Power (Experimental)"] = "Poder con hechizos (experimental)"
L["Under the description, each amount's spell power coefficient and its split into base and spell power. No game API has coefficients: they come from Forever's client data, and ones marked ~ are estimates."] =
    "Bajo la descripción, el coeficiente de poder con hechizos de cada cantidad y su reparto entre la base y el poder con hechizos. Ninguna API del juego da coeficientes: vienen de los datos del cliente de Forever, y los marcados con ~ son estimaciones."
L["Experimental: not all values are correct yet."] = "Experimental: aún no todos los valores son correctos."
L["Rates"] = "Tasas"
L["Under the spell power breakdown, the average a cast deals or heals per second and per mana. Per second, what lands at once counts over the cast time (instants as the 1.5 sec global cooldown) and what comes over time over its duration. Crits and talents do not count."] =
    "Bajo el reparto de poder con hechizos, la media que un lanzamiento inflige o sana por segundo y por punto de maná. Por segundo, lo que llega de golpe cuenta sobre el tiempo de lanzamiento (los instantáneos como el tiempo de reutilización global de 1,5 s) y lo que llega con el tiempo, sobre su duración. Los críticos y los talentos no cuentan."
L["Health Bar"] = "Barra de salud"
L["The game's own health bar at the bottom of player and NPC panels. The game fills it, so it stays live without the addon reading health, which WoW Forever keeps from addons."] =
    "La barra de salud del juego en la parte inferior de los paneles de jugadores y PNJ. La rellena el juego, así que se mantiene al día sin que el addon lea la salud, que WoW Forever oculta a los addons."
L["Gathering"] = "Recolección"
L["What a herb or ore node holds: its yield over all the times it can be gathered, then the stone, gems, and other herbs it may give and the chance each time. On a dead creature that can be skinned, the Skinning it needs and the leather, hides, and scales it may give. From Classic's loot tables."] =
    "Lo que contiene una hierba o un depósito: su rendimiento en todas las veces que se puede recolectar, luego la piedra, las gemas y otras hierbas que puede dar y la probabilidad cada vez. En una criatura muerta que se puede desollar, el Desuello que requiere y el cuero, las pieles y las escamas que puede dar. Según las tablas de botín de Classic."
L["Class Colors"] = "Colores de clase"
L["Reset All Fonts and Colors"] = "Restablecer todas las fuentes y colores"
L["Reset"] = "Restablecer"
L["Every font, text size, outline, capitalization, and color goes back to its default, and so do the panel opacities: on All Tooltips, every tooltip type, and every part. Other settings stay as they are."] =
    "Todas las fuentes, tamaños de texto, contornos, usos de mayúsculas y colores vuelven a sus valores predeterminados, igual que la opacidad de los paneles: en Todos los tooltips, en cada tipo de tooltip y en cada parte. Los demás ajustes no cambian."
L["Show IDs"] = "Mostrar ID"
L["The item's, spell's, aura's, or NPC's ID at the bottom of its panel, under other addons' rows."] =
    "El ID del objeto, hechizo, aura o PNJ al pie de su panel, bajo las filas de otros addons."
L["Item ID: %s"] = "ID de objeto: %s"
L["NPC ID: %s"] = "ID de PNJ: %s"

-- The kinds of tooltip, their samples' tabs, and the lookup by ID.
L["Items"] = "Objetos"
L["Spells"] = "Hechizos"
L["Objects"] = "Objetos del mundo"
L["Units"] = "Unidades"
L["Buffs"] = "Auras"
L["Quests"] = "Misiones"
L["Macros"] = "Macros"
L["Item ID"] = "ID de objeto"
L["Spell ID"] = "ID de hechizo"
L["Object ID"] = "ID de objeto del mundo"
L["Unit ID"] = "ID de unidad"
L["Buff ID"] = "ID de aura"
L["Quest ID"] = "ID de misión"
L["Macro ID"] = "ID de macro"
L["Weapon"] = "Arma"
L["Set piece"] = "Pieza de conjunto"
L["Potion"] = "Poción"
L["Quest item"] = "Objeto de misión"
L["Fireball"] = "Bola de Fuego"
L["Ability"] = "Habilidad"
L["Heal"] = "Sanación"
L["Ore"] = "Mineral"
L["Chest"] = "Cofre"
L["Quest"] = "Misión"
L["Player"] = "Jugador"
L["Enemy"] = "Enemigo"
L["Vendor"] = "Vendedor"
L["Rare"] = "Raro"
L["Rare elite"] = "Élite raro"
L["Boss"] = "Jefe"
L["Curse"] = "Maldición"
L["Poison"] = "Veneno"
L["Ready"] = "Lista"
L["New"] = "Nueva"
L["Targeting"] = "Selección de objetivo"

-- The style parts, and what each says about its color.
L["Item Name"] = "Nombre del objeto"
L["Quality color unless set."] = "Color de calidad, salvo que se elija otro."
L["Type and Slot"] = "Tipo y casilla"
L["Half the quality color, red for a type you cannot use."] =
    "Media tinta del color de calidad, rojo para un tipo que no puedes usar."
L["Binding and Level"] = "Ligado y nivel"
L["The required level is red while you are below it."] = "El nivel requerido es rojo mientras no lo alcances."
L["Damage per Second"] = "Daño por segundo"
L["Damage and Speed"] = "Daño y velocidad"
L["Armor"] = "Armadura"
L["Stats"] = "Estadísticas"
L["Colored by category unless set."] = "Coloreadas por categoría, salvo que se elija otro."
L["Equip Effects"] = "Efectos de Equipar"
L["On-hit numbers use the spell tooltip's school colors unless set."] =
    "Los números de los efectos al acertar usan los colores de escuela de la descripción de hechizo, salvo que se elija otro."
L["Enchants"] = "Encantamientos"
L["Use and Other Effects"] = "Uso y otros efectos"
L["Flavor Text"] = "Texto de ambientación"
L["Set Name and Count"] = "Nombre y recuento del conjunto"
L["Set Pieces"] = "Piezas de conjunto"
L["Owned pieces bright, missing ones grey, unless set."] =
    "Piezas que tienes claras, las que faltan grises, salvo que se elija otro."
L["Set Bonuses"] = "Bonificaciones de conjunto"
L["Active bonuses green, inactive ones grey, unless set."] =
    "Bonificaciones activas verdes, inactivas grises, salvo que se elija otro."
L["Other Addons' Rows"] = "Filas de otros addons"
L["Durability, crafter, requirements, and sell price."] = "Durabilidad, artesano, requisitos y precio de venta."
L["Item Level Badge"] = "Placa de nivel de objeto"
L["Crafted Item's Name"] = "Nombre del objeto fabricado"
L["On recipes; quality color unless set."] = "En recetas; color de calidad, salvo que se elija otro."
L["On recipes; the count you carry red while short, unless set."] =
    "En recetas; la cantidad que llevas en rojo si falta, salvo que se elija otro."
L["Section Captions"] = "Títulos de sección"
L["Creates and Reagents on recipes."] = "Crea y Componentes en las recetas."
L["Disenchant Results"] = "Resultados de desencantar"
L["The Enchanting needed red while yours is too low, grey without Enchanting, unless set."] =
    "El Encantamiento requerido en rojo mientras el tuyo sea demasiado bajo, gris sin Encantamiento, salvo que se elija otro."
L["Spell Name"] = "Nombre del hechizo"
L["School and Rank Badges"] = "Placas de escuela y rango"
L["Colored by school unless set."] = "Coloreadas por escuela, salvo que se elija otro."
L["Cost, Cast, Cooldown, Range"] = "Costo, lanzamiento, reutilización, alcance"
L["The cost takes its resource color unless set."] = "El costo toma el color de su recurso, salvo que se elija otro."
L["Strip Captions"] = "Leyendas de la franja"
L["Requirements and Details"] = "Requisitos y detalles"
L["Unmet requirements red, time remaining orange, unless set."] =
    "Requisitos no cumplidos en rojo, tiempo restante en naranja, salvo que se elija otro."
L["Description"] = "Descripción"
L["Numbers in the school color unless set."] = "Números en el color de la escuela, salvo que se elija otro."
L["Object Name"] = "Nombre del objeto del mundo"
L["Kind of Object"] = "Tipo de objeto del mundo"
L["Tinted by the skill it needs, unless set."] = "Teñido según la habilidad que requiere, salvo que se elija otro."
L["Skill and Requirements"] = "Habilidad y requisitos"
L["The skill in its skill-up color, unmet requirements red, unless set."] =
    "La habilidad en su color de progreso, requisitos no cumplidos en rojo, salvo que se elija otro."
L["Quest Lines"] = "Líneas de misión"
L["Quest names yellow, finished objectives green, unless set."] =
    "Nombres de misión en amarillo, objetivos cumplidos en verde, salvo que se elija otro."
L["Contents"] = "Contenido"
L["A herb or ore node's yield over its taps, then what else it may hold and the chance each tap. Turned off by Gathering contents in the options."] =
    "El rendimiento de una hierba o un depósito en todas sus recolecciones, luego qué más puede contener y la probabilidad en cada una. Se desactiva con Recolección en las opciones."
L["Prices"] = "Precios"
L["The yielded item's sell price, and its auction price with Auctionator."] =
    "El precio de venta del objeto obtenido, y su precio de subasta con Auctionator."
L["Name"] = "Nombre"
L["Class color for players, reaction color for NPCs, unless set."] =
    "Color de clase para los jugadores, color de reacción para los PNJ, salvo que se elija otro."
L["Guild or Role"] = "Hermandad o función"
L["Level, Race, and Class"] = "Nivel, raza y clase"
L["The level in its difficulty color, unless set."] = "El nivel en su color de dificultad, salvo que se elija otro."
L["Badges"] = "Placas"
L["Elite, rare, faction, PvP, AFK, dead, and Skinnable in its skill-up color."] = "Élite, raro, facción, JcJ, AUS, muerto y Desollable en su color de progreso."
L["Skinning"] = "Desuello"
L["On a dead creature that can be skinned: the Skinning it needs, in its skill-up color, and what it may give. Turned off by Gathering contents in the options."] =
    "En una criatura muerta que se puede desollar: el Desuello que requiere, en su color de progreso, y lo que puede dar. Se desactiva con Recolección en las opciones."
L["Target and Owner"] = "Objetivo y dueño"
L["Buff or debuff, dispel type in the game's colors, and stacks."] =
    "Beneficio o perjuicio, tipo de disipación en los colores del juego, y acumulaciones."
L["Numbers in the aura's color unless set."] = "Números en el color del aura, salvo que se elija otro."
L["Time and Caster"] = "Duración y lanzador"
L["Quest Name"] = "Nombre de la misión"
L["Dungeon"] = "Calabozo"
L["The level in its difficulty color, tags, and where the quest stands."] =
    "El nivel en su color de dificultad, las etiquetas y el estado de la misión."
L["Section Caption"] = "Título de sección"
L["Objectives"] = "Objetivos"
L["Finished objectives green unless set."] = "Objetivos cumplidos en verde, salvo que se elija otro."
L["Macro Lines"] = "Líneas de macro"
L["Commands yellow, conditions grey, unless set."] = "Comandos en amarillo, condiciones grises, salvo que se elija otro."

-- The options page ---------------------------------------------------------------

L["A full reskin of tooltips. Changes apply the next time a tooltip opens."] =
    "Un rediseño completo de las descripciones emergentes. Los cambios se aplican la próxima vez que se abra una."
L["Open the Style Editor"] = "Abrir el editor de estilo"
L["Style Editor"] = "Editor de estilo"
L["Restyle"] = "Rediseñar"
L["Follow Cursor"] = "Seguir el cursor"
L["On: Tooltips keep following the cursor in combat.\n\nOff: In combat, tooltips take their default position, and follow the cursor again afterward."] =
    "Activado: Las descripciones siguen al cursor también en combate.\n\nDesactivado: En combate, las descripciones usan su posición predeterminada y vuelven a seguir el cursor al terminar."
L["On: Draws the PrettyTooltip panel.\n\nOff: This kind keeps the game's own tooltip, with the details modifier's rows added to it."] =
    "Activado: Dibuja el panel de PrettyTooltip.\n\nDesactivado: Este tipo conserva la descripción del juego, con las filas de la tecla para los detalles agregadas."
L["Not restyled yet; this kind keeps the game's own tooltip."] =
    "Aún sin rediseñar; este tipo conserva la descripción del juego."
L["On: Shows this kind's tooltip at the cursor when the game would put it in its default corner; bags and other panels keep theirs.\n\nOff: Its position is left to the game and other addons."] =
    "Activado: Muestra la descripción de este tipo junto al cursor cuando el juego la pondría en su esquina predeterminada; las bolsas y otros paneles conservan la suya.\n\nDesactivado: Su posición queda en manos del juego y de otros addons."
L["Restyle items"] = "Rediseñar objetos"
L["Restyle spells"] = "Rediseñar hechizos"
L["Restyle players and npcs"] = "Rediseñar jugadores y PNJ"
L["Restyle buffs and debuffs"] = "Rediseñar beneficios y perjuicios"
L["Restyle weapon imbues"] = "Rediseñar imbuiciones de arma"
L["Restyle herbs, ore, chests, and other objects"] = "Rediseñar hierbas, minerales, cofres y otros objetos"
L["Restyle flight paths"] = "Rediseñar rutas de vuelo"
L["Restyle quests"] = "Rediseñar misiones"
L["Restyle macros"] = "Rediseñar macros"
L["Restyle mail"] = "Rediseñar el correo"
L["Restyle currencies"] = "Rediseñar monedas"
L["Restyle dungeon and raid lockouts"] = "Rediseñar bloqueos de calabozo y banda"
L["Restyle pet abilities"] = "Rediseñar habilidades de mascota"
L["Restyle minimap"] = "Rediseñar el minimapa"
L["Restyle mounts, toys, and pets"] = "Rediseñar monturas, juguetes y mascotas"
L["Restyle achievements"] = "Rediseñar logros"
L["Restyle totems"] = "Rediseñar tótems"
L["Restyle flyout buttons"] = "Rediseñar botones desplegables"
L["Players and NPCs"] = "Jugadores y PNJ"
L["Buffs and Debuffs"] = "Beneficios y perjuicios"
L["Weapon Imbues"] = "Imbuiciones de arma"
L["Herbs, Ore, Chests, and Other Objects"] = "Hierbas, minerales, cofres y otros objetos"
L["Flight Paths"] = "Rutas de vuelo"
L["Currencies"] = "Monedas"
L["Dungeon and Raid Lockouts"] = "Bloqueos de calabozo y banda"
L["Pet Abilities"] = "Habilidades de mascota"
L["Minimap"] = "Minimapa"
L["Mounts, Toys, and Pets"] = "Monturas, juguetes y mascotas"
L["Achievements"] = "Logros"
L["Totems"] = "Tótems"
L["Flyout Buttons"] = "Botones desplegables"
L["Layout Style"] = "Estilo de diseño"
L["PrettyTooltip"] = "PrettyTooltip"
L["Keep the game's own tooltips. Item Equip effects are shortened, and the details modifier adds disenchant results, the spell power breakdown and rates, gathering contents, and IDs."] =
    "Conserva las descripciones del juego. Los efectos de Equipar de los objetos se abrevian, y la tecla para los detalles agrega los resultados de desencantar, el reparto de poder con hechizos y las tasas, el contenido de la recolección y los ID."
L["Default Tooltip Modifier"] = "Tecla para la descripción del juego"
L["Ctrl"] = "Ctrl"
L["Alt"] = "Alt"
L["Never"] = "Nunca"
L["Hold Ctrl to see the game's own tooltip instead of the panel."] =
    "Mantén presionado Ctrl para ver la descripción del juego en lugar del panel."
L["Hold Alt to see the game's own tooltip instead of the panel."] =
    "Mantén presionado Alt para ver la descripción del juego en lugar del panel."
L["Never show the game's own tooltip in place of the panel."] =
    "No mostrar nunca la descripción del juego en lugar del panel."
L["Tooltip Details Modifier"] = "Tecla para los detalles"
L["Shift"] = "Mayús"
L["Always Show"] = "Mostrar siempre"
L["Hold Shift to see disenchant results, the spell power breakdown and rates, gathering contents, and IDs. Each can still be turned off in the style editor."] =
    "Mantén presionado Mayús para ver los resultados de desencantar, el reparto de poder con hechizos y las tasas, el contenido de la recolección y los ID. Cada uno se puede desactivar en el editor de estilo."
L["Always show disenchant results, the spell power breakdown and rates, gathering contents, and IDs, as each one's setting in the style editor allows."] =
    "Muestra siempre los resultados de desencantar, el reparto de poder con hechizos y las tasas, el contenido de la recolección y los ID, según lo permita el ajuste de cada uno en el editor de estilo."
L["Style Editor Appearance"] = "Aspecto del editor de estilo"
L["Blizzard"] = "Blizzard"
L["Use the game's settings frame borders and controls."] =
    "Usar los bordes y controles de la ventana de opciones del juego."
L["Dark, flat panels with thin edges and plain controls."] = "Paneles oscuros y planos con bordes finos y controles sencillos."

-- Commands and the report window.
L["PrettyTooltip: hover something first; there is no tooltip to dump."] =
    "PrettyTooltip: pasa el cursor por encima de algo primero; no hay ninguna descripción que volcar."
L["PrettyTooltip: this tooltip cannot be read right now (%s)."] =
    "PrettyTooltip: esta descripción no se puede leer ahora mismo (%s)."
L["PrettyTooltip: the options cannot open during combat. Try again once it ends."] =
    "PrettyTooltip: las opciones no se pueden abrir en combate. Vuelve a intentarlo cuando termine."
L["Press Ctrl+C to copy the selected text, and paste it into your bug report."] =
    "Presiona Ctrl+C para copiar el texto seleccionado y pégalo en tu informe de error."
L["Select all"] = "Seleccionar todo"

-- The samples ---------------------------------------------------------------------
-- The names of quests, people, and places are drafts for the Latin American client;
-- a reviewer should check them against the client.

L["Axe"] = "Hacha"
L["Plate"] = "Placas"
L["Polearm"] = "Arma de asta"
L["Mail"] = "Malla"
L["Cloth"] = "Tela"
L["Leather"] = "Cuero"
L["Consumable"] = "Consumible"
L["Plans"] = "Diseño"
L["Shields"] = "Escudos"
L["Human"] = "Humano"
L["Humanoid"] = "Humanoide"
L["Beast"] = "Bestia"
L["Innkeeper"] = "Tabernero"
L["Your attacks have a chance to cleave a nearby enemy."] =
    "Tus ataques tienen probabilidad de alcanzar también a un enemigo cercano."
L["Wounds the target for 40 to 60 damage."] = "Hiere al objetivo e inflige de 40 a 60 p. de daño."
L["Sample flavor text sits here, in gold."] = "Aquí va un texto de ambientación de ejemplo, en dorado."
L["Redemption Armor"] = "Armadura de Redención"
L["Increases the amount healed by your Judgement of Light by 20."] =
    "Aumenta 20 p. la sanación de tu Sentencia de Luz."
L["Reduces cooldown on your Lay on Hands by 12 min."] =
    "Reduce 12 min el tiempo de reutilización de tu Imposición de manos."
L["Dropped by: %s"] = "Lo suelta: %s"
L["Argent Dawn"] = "El Alba Argenta"
L["Restores 1050 to 1750 health."] = "Restaura entre 1050 y 1750 p. de salud."
L["A schedule of gold pickups."] = "Un calendario de recogidas de oro."
L["Hurls a fiery ball that causes 16 to 25 Fire damage and an additional 2 Fire damage over 4 sec."] =
    "Lanza una bola ígnea que inflige de 16 a 25 p. de daño de Fuego y 2 p. de daño de Fuego adicional durante 4 s."
L["Bashes the target with your shield for 8 damage. It also interrupts spellcasting and prevents any spell in that school from being cast for 6 sec."] =
    "Golpea al objetivo con tu escudo e inflige 8 p. de daño. También interrumpe el lanzamiento de hechizos e impide lanzar hechizos de esa escuela durante 6 s."
L["Heals a friendly target for 42 to 51."] = "Sana a un objetivo amistoso entre 42 y 51 p."
L["Spell ID: %s"] = "ID de hechizo: %s"
L["Gathered here %s times"] = "Recolectado aquí %s veces"
L["Bruiseweed"] = "Hierba cardenal"
L["Mithril Deposit"] = "Depósito de mitril"
L["Battered Chest"] = "Cofre abollado"
L["Sealed Supply Crate"] = "Caja de suministros sellada"
L["Heavy Supplies"] = "Suministros pesados"
L["Supply Crate: 2/5"] = "Caja de suministros: 2/5"
L["Report to the quartermaster"] = "Informa al intendente"
L["Defias Pillager"] = "Saqueador Defias"
L["The Defias Brotherhood"] = "La Hermandad Defias"
L["Defias Pillager slain: 4/10"] = "Saqueador Defias muerto: 4/10"
L["Innkeeper Farley"] = "Tabernero Farley"
L["Mother Fang"] = "Madre Colmillo"
L["Foe Reaper 4000"] = "Siegaenemigos 4000"
L["Increases Stamina by 26."] = "Aumenta 26 p. el aguante."
L["Causes 84 Shadow damage over 24 sec. This damage is dealt slowly at first, and builds up as the Curse reaches its full duration."] =
    "Inflige 84 p. de daño de las Sombras durante 24 s. Este daño es lento al principio y aumenta a medida que la Maldición llega a su duración total."
L["Inflicts 9 Nature damage every 3 sec."] = "Inflige 9 p. de daño de Naturaleza cada 3 s."
L["The Fury Runs Deep"] = "La furia mora en las profundidades"
L["Arugal Must Die"] = "Arugal debe morir"
L["The Stockade"] = "Las Calabozos"
L["Shadowfang Keep"] = "Castillo de Colmillo Oscuro"
L["Silverpine Forest"] = "Bosque de Argénteos"
L["Wolves Across the Border"] = "Lobos en la frontera"
L["Dalar Dawnweaver"] = "Dalar Tejealba"
L["Motley Garmason wants Kam Deepfury's head brought to him at Dun Modr."] =
    "Motley Garmason quiere que le lleves la cabeza de Kam Furiahonda a Dun Modr."
L["Eliminate the wolves to the east of Northshire and bring their paws to Eagan Peltskinner."] =
    "Elimina a los lobos al este de Villanorte y llévale sus zarpas a Eagan Pelapieles."
L["Dalar Dawnweaver wants Arugal dead and his head brought to him."] =
    "Dalar Tejealba quiere a Arugal muerto y que le lleves su cabeza."
L["Ended by"] = "Se entrega a"
L["Started by"] = "La inicia"
L["Found in"] = "Se encuentra en"
L["Rares"] = "Raros"
