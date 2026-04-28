# =============================================================
# MAPA INTERACTIVO - RESTAURANTES MEDITERRÁNEOS EN BOGOTÁ
# =============================================================
#
#   DoingEconomics_Proyect/         <- PROJECT_ROOT
#   ├── Data/
#   │   ├── Clean/
#   │   └── Raw/                    <- INPUT: restaurantes_mediterraneos_bogota.csv
#   │       └── Barrios_Bogota/     <- INPUT: shapefile barrios (IDECA)
#   ├── Outputs/
#   │   ├── Graphs/                 <- OUTPUT: mapa HTML + shapefile
#   │   └── Tables/
#   └── Scripts/                    <- este archivo
#
# Columnas del CSV:
#   id | place_id | nombre | direccion | lat | lon |
#   rating | num_reviews | google_maps_url | tipos | query_origen | barrio
#
# Paquetes requeridos:
#   install.packages(c("dplyr","sf","leaflet","leaflet.extras",
#                      "htmlwidgets","readr","glue"))
# =============================================================

library(dplyr)
library(sf)
library(leaflet)
library(leaflet.extras)
library(htmlwidgets)
library(readr)
library(glue)

# ── 0. RUTAS DEL PROYECTO ─────────────────────────────────────────────────────
SCRIPT_DIR   <- dirname(rstudioapi::getSourceEditorContext()$path)
PROJECT_ROOT <- dirname(SCRIPT_DIR)

DATA_RAW_DIR <- file.path(PROJECT_ROOT, "Data",    "Raw")
DATA_CLEAN   <- file.path(PROJECT_ROOT, "Data",    "Clean")
GRAPHS_DIR   <- file.path(PROJECT_ROOT, "Outputs", "Graphs")
TABLES_DIR   <- file.path(PROJECT_ROOT, "Outputs", "Tables")

for (d in c(DATA_RAW_DIR, DATA_CLEAN, GRAPHS_DIR, TABLES_DIR)) {
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
}

INPUT_CSV   <- file.path(DATA_RAW_DIR, "restaurantes_mediterraneos_bogota.csv")
BARRIOS_DIR <- file.path(DATA_RAW_DIR, "Barrios_Bogota")
OUTPUT_MAP  <- file.path(GRAPHS_DIR,   "mapa_restaurantes_mediterraneos.html")
OUTPUT_SHP  <- file.path(GRAPHS_DIR,   "restaurantes_mediterraneos_bogota.shp")

# Nombre del campo de barrio en el shapefile — ajusta si difiere
# Para inspeccionar columnas disponibles: names(st_read(list.files(BARRIOS_DIR, "*.shp", full.names=TRUE)[1]))
CAMPO_BARRIO_LABEL <- "NOMBRE"

cat("── Rutas ───────────────────────────────────────────────\n")
cat(glue("  Input CSV   : {INPUT_CSV}\n"))
cat(glue("  Barrios SHP : {BARRIOS_DIR}\n"))
cat(glue("  Output HTML : {OUTPUT_MAP}\n"))
cat("────────────────────────────────────────────────────────\n\n")

# ── 1. CARGAR Y PREPARAR DATOS DE RESTAURANTES ────────────────────────────────
# Columnas: id, place_id, nombre, direccion, lat, lon,
#           rating, num_reviews, google_maps_url, tipos, query_origen, barrio

df <- read_csv(INPUT_CSV, show_col_types = FALSE) |>
  filter(!is.na(lat), !is.na(lon)) |>
  mutate(
    id           = sprintf("%03d", as.integer(id)),
    rating       = round(as.numeric(rating), 1),
    num_reviews  = as.integer(num_reviews),
    barrio       = ifelse(is.na(barrio) | barrio == "", "Sin datos", barrio),
    tipos        = ifelse(is.na(tipos), "", tipos),
    query_origen = ifelse(is.na(query_origen), "", query_origen),
    # Estrellas visuales
    estrellas = sapply(rating, function(r) {
      if (is.na(r)) return("Sin calificación")
      n <- round(r)
      paste0(strrep("★", n), strrep("☆", 5 - n), "  ", r, " / 5")
    }),
    # Clasificación por tipo de cocina
    cocina = case_when(
      grepl("grieg|greek",             tipos,        ignore.case = TRUE) ~ "Griega",
      grepl("grieg",                   query_origen, ignore.case = TRUE) ~ "Griega",
      grepl("españ|spanish",           tipos,        ignore.case = TRUE) ~ "Española",
      grepl("españ|tapas",             query_origen, ignore.case = TRUE) ~ "Española",
      grepl("italian",                 tipos,        ignore.case = TRUE) ~ "Italiana",
      grepl("italian|pizza|trattoria", query_origen, ignore.case = TRUE) ~ "Italiana",
      TRUE ~ "Mediterránea"
    )
  )

sf_rest <- st_as_sf(df, coords = c("lon", "lat"), crs = 4326)

cat(glue("✅ {nrow(df)} restaurantes cargados\n"))
cat(glue("   Cocinas: {paste(names(table(df$cocina)), collapse=' | ')}\n\n"))

# ── 2. SHAPEFILE DE BARRIOS DE BOGOTÁ (IDECA — local) ─────────────────────────
shp_files <- list.files(BARRIOS_DIR, pattern = "\\.shp$", full.names = TRUE)

if (length(shp_files) == 0) {
  stop(glue(
    "No se encontró ningún .shp en:\n  {BARRIOS_DIR}\n",
    "Verifica que la carpeta Barrios_Bogota contiene el shapefile de IDECA."
  ))
}

bogota_sf <- st_read(shp_files[1], quiet = TRUE) |>
  st_transform(crs = 4326)

# Diagnóstico rápido
cat(glue("✅ Shapefile barrios cargado: {basename(shp_files[1])}\n"))
cat(glue("   Polígonos : {nrow(bogota_sf)}\n"))
cat(glue("   Columnas  : {paste(names(bogota_sf), collapse=', ')}\n\n"))

if (!CAMPO_BARRIO_LABEL %in% names(bogota_sf)) {
  stop(glue(
    "El campo '{CAMPO_BARRIO_LABEL}' no existe en el shapefile.\n",
    "Columnas disponibles: {paste(names(bogota_sf), collapse=', ')}\n",
    "Ajusta CAMPO_BARRIO_LABEL en la línea 48."
  ))
}

# ── 3. PALETA DE COLORES ──────────────────────────────────────────────────────
pal_cocina <- colorFactor(
  palette = c("#E63946", "#457B9D", "#2A9D8F", "#F4A261"),
  domain  = c("Griega", "Española", "Italiana", "Mediterránea")
)

# ── 4. POPUP HTML ─────────────────────────────────────────────────────────────
# Muestra todas las columnas relevantes del CSV:
# id | nombre | cocina | barrio | direccion | rating | num_reviews |
# tipos | query_origen | google_maps_url

make_popup <- function(id, nombre, cocina, barrio, direccion,
                       rating, num_reviews, estrellas,
                       tipos, query_origen, google_maps_url) {

  reviews_txt  <- ifelse(is.na(num_reviews), "—", format(num_reviews, big.mark = "."))
  tipos_txt    <- ifelse(tipos == "", "—", gsub(",", " ·", tipos))
  maps_link    <- ifelse(
    is.na(google_maps_url) | google_maps_url == "",
    "",
    glue('<a href="{google_maps_url}" target="_blank" ',
         'style="color:#457b9d; text-decoration:none;">',
         '🔗 Ver en Google Maps</a>')
  )

  glue('
  <div style="font-family:Arial,sans-serif; min-width:240px; max-width:300px; padding:4px;">

    <!-- ENCABEZADO -->
    <div style="background:#1d3557; color:white; padding:10px 12px;
                border-radius:8px 8px 0 0; margin:-4px -4px 10px -4px;">
      <div style="font-size:10px; opacity:.7; margin-bottom:2px;">#{id}</div>
      <div style="font-size:15px; font-weight:bold; line-height:1.3;">{nombre}</div>
      <span style="background:{pal_cocina(cocina)}; font-size:10px;
                   padding:2px 8px; border-radius:10px; margin-top:5px;
                   display:inline-block;">
        {cocina}
      </span>
    </div>

    <!-- DATOS -->
    <table style="width:100%; font-size:12px; border-collapse:collapse; line-height:1.6;">
      <tr>
        <td style="color:#777; width:90px; padding:2px 0;">📍 Barrio</td>
        <td style="font-weight:600;">{barrio}</td>
      </tr>
      <tr>
        <td style="color:#777; padding:2px 0;">🏠 Dirección</td>
        <td style="font-size:11px;">{direccion}</td>
      </tr>
      <tr>
        <td style="color:#777; padding:2px 0;">⭐ Rating</td>
        <td>{estrellas}</td>
      </tr>
      <tr>
        <td style="color:#777; padding:2px 0;">💬 Reseñas</td>
        <td>{reviews_txt}</td>
      </tr>
      <tr>
        <td style="color:#777; padding:2px 0;">🍽️ Tipo</td>
        <td style="font-size:11px;">{tipos_txt}</td>
      </tr>
      <tr>
        <td style="color:#777; padding:2px 0;">🔎 Query</td>
        <td style="font-size:11px; color:#555;">{query_origen}</td>
      </tr>
    </table>

    <!-- LINK -->
    <div style="margin-top:10px; padding-top:8px;
                border-top:1px solid #eee; font-size:12px;">
      {maps_link}
    </div>
  </div>
  ')
}

popups <- mapply(
  make_popup,
  id             = df$id,
  nombre         = df$nombre,
  cocina         = df$cocina,
  barrio         = df$barrio,
  direccion      = df$direccion,
  rating         = df$rating,
  num_reviews    = df$num_reviews,
  estrellas      = df$estrellas,
  tipos          = df$tipos,
  query_origen   = df$query_origen,
  google_maps_url = df$google_maps_url,
  SIMPLIFY       = TRUE
)

# ── 5. CONSTRUIR MAPA LEAFLET ─────────────────────────────────────────────────
mapa <- leaflet() |>

  # Tiles base
  addProviderTiles(providers$CartoDB.Positron,    group = "Claro") |>
  addProviderTiles(providers$Esri.WorldStreetMap, group = "Detallado") |>

  # Shapefile de barrios de Bogotá
  addPolygons(
    data        = bogota_sf,
    fillColor   = "#f0f0f0",
    fillOpacity = 0.2,
    color       = "#999999",
    weight      = 0.8,
    opacity     = 0.8,
    group       = "Barrios",
    label       = ~get(CAMPO_BARRIO_LABEL),
    labelOptions = labelOptions(
      style    = list("font-size" = "11px", "padding" = "2px 5px"),
      direction = "auto"
    )
  ) |>

  # Puntos de restaurantes
  addCircleMarkers(
    data         = sf_rest,
    radius       = 7,
    color        = ~pal_cocina(cocina),
    fillColor    = ~pal_cocina(cocina),
    fillOpacity  = 0.85,
    weight       = 1.5,
    stroke       = TRUE,
    popup        = popups,
    label        = ~glue("#{id}  {nombre}"),
    labelOptions = labelOptions(
      style     = list("font-weight" = "500", "padding" = "3px 7px"),
      textsize  = "12px",
      direction = "auto"
    ),
    group = "Restaurantes",
    clusterOptions = markerClusterOptions(
      showCoverageOnHover = FALSE,
      zoomToBoundsOnClick = TRUE,
      spiderfyOnMaxZoom   = TRUE
    )
  ) |>

  # Leyenda
  addLegend(
    position = "bottomright",
    pal      = pal_cocina,
    values   = df$cocina,
    title    = "Tipo de cocina",
    opacity  = 0.9
  ) |>

  # Control de capas
  addLayersControl(
    baseGroups    = c("Claro", "Detallado"),
    overlayGroups = c("Barrios", "Restaurantes"),
    options       = layersControlOptions(collapsed = FALSE)
  ) |>

  # Buscador por nombre
  addSearchFeatures(
    targetGroups = "Restaurantes",
    options      = searchFeaturesOptions(
      propertyName        = "label",
      zoom                = 16,
      openPopup           = TRUE,
      hideMarkerOnCollapse = TRUE
    )
  ) |>

  setView(lng = -74.0721, lat = 4.7110, zoom = 11)

# ── 6. GUARDAR HTML ───────────────────────────────────────────────────────────
saveWidget(mapa, file = OUTPUT_MAP, selfcontained = TRUE)
cat(glue("\n✅ Mapa HTML guardado : {OUTPUT_MAP}\n"))
cat(glue("   {nrow(df)} restaurantes | {length(unique(df$cocina))} tipos de cocina\n"))

# ── 7. EXPORTAR SHAPEFILE ─────────────────────────────────────────────────────
st_write(sf_rest, OUTPUT_SHP, delete_dsn = TRUE, quiet = TRUE)
cat(glue("✅ Shapefile guardado  : {OUTPUT_SHP}\n"))