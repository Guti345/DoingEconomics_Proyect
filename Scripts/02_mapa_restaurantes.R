# =============================================================
# MAPA INTERACTIVO - RESTAURANTES MEDITERRÁNEOS EN BOGOTÁ
# =============================================================
#
#   DoingEconomics_Proyect/         <- PROJECT_ROOT
#   ├── Data/
#   │   ├── Clean/
#   │   └── Raw/                    <- INPUT:  restaurantes_mediterraneos_bogota.csv
#   ├── Documentos/
#   ├── Outputs/
#   │   ├── Graphs/                 <- OUTPUT: mapa HTML + shapefile
#   │   └── Tables/
#   └── Scripts/                    <- este archivo vive aquí
#       ├── venv/
#       ├── .env
#       ├── 01_extraccion restaurantes.py
#       └── 02_mapa_restaurantes.R
#
# Paquetes requeridos:
#   install.packages(c("dplyr","sf","leaflet","leaflet.extras",
#                      "htmlwidgets","geodata","readr","glue"))
# =============================================================

library(dplyr)
library(sf)
library(leaflet)
library(leaflet.extras)
library(htmlwidgets)
library(readr)
library(glue)

# ── 0. RUTAS DEL PROYECTO ────────────────────────────────────────────────────
# Calcula rutas absolutas desde la ubicación de este script,
# sin depender de setwd() ni del usuario que lo ejecute.

SCRIPT_DIR   <- dirname(rstudioapi::getSourceEditorContext()$path)
PROJECT_ROOT <- dirname(SCRIPT_DIR)

# Carpetas del proyecto
DATA_RAW_DIR  <- file.path(PROJECT_ROOT, "Data",    "Raw")
DATA_CLEAN    <- file.path(PROJECT_ROOT, "Data",    "Clean")
GRAPHS_DIR    <- file.path(PROJECT_ROOT, "Outputs", "Graphs")
TABLES_DIR    <- file.path(PROJECT_ROOT, "Outputs", "Tables")
DOCS_DIR      <- file.path(PROJECT_ROOT, "Documentos")

# Crear carpetas si no existen
for (d in c(DATA_RAW_DIR, DATA_CLEAN, GRAPHS_DIR, TABLES_DIR)) {
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
}

# Archivos de input y output
INPUT_CSV  <- file.path(DATA_RAW_DIR, "restaurantes_mediterraneos_bogota.csv")
OUTPUT_MAP <- file.path(GRAPHS_DIR,   "mapa_restaurantes_mediterraneos.html")
OUTPUT_SHP <- file.path(GRAPHS_DIR,   "restaurantes_mediterraneos_bogota.shp")

cat("── Rutas del proyecto ──────────────────────────────────\n")
cat(glue("  Script      : {SCRIPT_DIR}\n"))
cat(glue("  Raíz        : {PROJECT_ROOT}\n"))
cat(glue("  Input CSV   : {INPUT_CSV}\n"))
cat(glue("  Output HTML : {OUTPUT_MAP}\n"))
cat(glue("  Output SHP  : {OUTPUT_SHP}\n"))
cat("────────────────────────────────────────────────────────\n\n")

# ── 1. CARGAR Y PREPARAR DATOS DE RESTAURANTES ───────────────────────────────
df <- read_csv(INPUT_CSV, show_col_types = FALSE) |>
  filter(!is.na(lat), !is.na(lon)) |>
  mutate(
    id           = sprintf("%03d", row_number()),
    rating       = round(as.numeric(rating), 1),
    num_reviews  = as.integer(num_reviews),
    barrio       = ifelse(is.na(barrio) | barrio == "", "Sin datos", barrio),
    # Estrellas visuales para la tarjeta
    estrellas    = sapply(rating, function(r) {
      if (is.na(r)) return("Sin calificación")
      n <- round(r)
      paste0(strrep("★", n), strrep("☆", 5 - n), "  ", r, "/5")
    })
  )

sf_rest <- st_as_sf(df, coords = c("lon", "lat"), crs = 4326)

cat(glue("✅ {nrow(df)} restaurantes cargados\n\n"))

# ── 2. SHAPEFILE DE BOGOTÁ (Localidades) ──────────────────────────────────────
# Opción A: descarga automática con geodata (GADM, nivel 3 = municipios/localidades)
# Requiere: install.packages("geodata")
#
# Opción B (manual, más actualizado): descarga desde IDECA/DANE:
#   https://www.ideca.gov.co/recursos/mapas/localidad-bogota-dc
#   Guarda el shapefile en base_dir y usa: bogota_sf <- st_read("Loca.shp")

tryCatch({
  library(geodata)
  # Nivel 2 = departamentos, nivel 3 = municipios dentro de Cundinamarca
  colombia_mun <- gadm("COL", level = 3, path = tempdir()) |> st_as_sf()
  bogota_sf <- colombia_mun |>
    filter(grepl("Bogot", NAME_2, ignore.case = TRUE))

  if (nrow(bogota_sf) == 0) stop("No se encontró Bogotá en GADM nivel 3")
  cat("✅ Shapefile de Bogotá (GADM) cargado con", nrow(bogota_sf), "polígonos\n\n")

}, error = function(e) {
  # Fallback: shapefile simple de Bogotá desde GeoJSON público
  cat("⚠️  geodata no disponible, usando GeoJSON alternativo...\n")
  bogota_sf <<- st_read(
    "https://raw.githubusercontent.com/CodeforBogota/datasets/main/bogota-localidades.geojson",
    quiet = TRUE
  )
  cat("✅ GeoJSON de Bogotá cargado con", nrow(bogota_sf), "localidades\n\n")
})

# ── 3. PALETA DE COLORES POR TIPO DE COCINA ───────────────────────────────────
# Clasificar cada restaurante según su query de origen / tipos
df <- df |>
  mutate(
    cocina = case_when(
      grepl("grieg|greek",    tipos,        ignore.case = TRUE) ~ "Griega",
      grepl("grieg",          query_origen, ignore.case = TRUE) ~ "Griega",
      grepl("españ|spanish",  tipos,        ignore.case = TRUE) ~ "Española",
      grepl("españ|tapas",    query_origen, ignore.case = TRUE) ~ "Española",
      grepl("italian",        tipos,        ignore.case = TRUE) ~ "Italiana",
      grepl("italian|pizza|trattoria", query_origen, ignore.case = TRUE) ~ "Italiana",
      TRUE ~ "Mediterránea"
    )
  )

sf_rest$cocina <- df$cocina

pal_cocina <- colorFactor(
  palette = c("#E63946", "#457B9D", "#2A9D8F", "#F4A261"),
  domain  = c("Griega", "Española", "Italiana", "Mediterránea")
)

# ── 4. CONSTRUIR POPUP HTML PARA CADA RESTAURANTE ─────────────────────────────
make_popup <- function(id, nombre, direccion, barrio, rating,
                       num_reviews, estrellas, cocina, google_maps_url) {
  reviews_txt <- ifelse(is.na(num_reviews), "Sin datos",
                        format(num_reviews, big.mark = "."))
  maps_link   <- ifelse(is.na(google_maps_url) | google_maps_url == "",
                        "",
                        glue('<a href="{google_maps_url}" target="_blank">
                               Ver en Google Maps ↗</a>'))
  glue('
  <div style="
    font-family: Arial, sans-serif;
    min-width: 220px;
    max-width: 280px;
    padding: 4px;">

    <div style="
      background: #1d3557;
      color: white;
      padding: 8px 12px;
      border-radius: 6px 6px 0 0;
      margin: -4px -4px 8px -4px;">
      <span style="font-size:11px; opacity:.8;">#{id}</span>
      <div style="font-size:15px; font-weight:bold; margin-top:2px;">{nombre}</div>
      <span style="
        background: {pal_cocina(cocina)};
        font-size:10px;
        padding: 2px 6px;
        border-radius: 10px;
        margin-top: 4px;
        display: inline-block;">
        {cocina}
      </span>
    </div>

    <table style="width:100%; font-size:12px; border-collapse:collapse;">
      <tr>
        <td style="color:#555; padding:3px 0; width:80px;">📍 Barrio</td>
        <td style="font-weight:500;">{barrio}</td>
      </tr>
      <tr>
        <td style="color:#555; padding:3px 0;">🏠 Dirección</td>
        <td style="font-size:11px;">{direccion}</td>
      </tr>
      <tr>
        <td style="color:#555; padding:3px 0;">⭐ Rating</td>
        <td>{estrellas}</td>
      </tr>
      <tr>
        <td style="color:#555; padding:3px 0;">💬 Reseñas</td>
        <td>{reviews_txt}</td>
      </tr>
    </table>

    <div style="margin-top:8px; font-size:11px; color:#457b9d;">
      {maps_link}
    </div>
  </div>
  ')
}

popups <- mapply(make_popup,
  id             = df$id,
  nombre         = df$nombre,
  direccion      = df$direccion,
  barrio         = df$barrio,
  rating         = df$rating,
  num_reviews    = df$num_reviews,
  estrellas      = df$estrellas,
  cocina         = df$cocina,
  google_maps_url = df$google_maps_url,
  SIMPLIFY       = TRUE
)

# ── 5. CONSTRUIR MAPA LEAFLET ─────────────────────────────────────────────────
mapa <- leaflet() |>

  # Tiles base
  addProviderTiles(providers$CartoDB.Positron, group = "Claro") |>
  addProviderTiles(providers$Esri.WorldStreetMap, group = "Detallado") |>

  # Shapefile de Bogotá (localidades)
  addPolygons(
    data        = bogota_sf,
    fillColor   = "#f0f0f0",
    fillOpacity = 0.25,
    color       = "#888888",
    weight      = 1,
    opacity     = 0.7,
    group       = "Localidades",
    label       = ~if ("NAME_3" %in% names(bogota_sf)) NAME_3
                   else if ("LocNombre" %in% names(bogota_sf)) LocNombre
                   else NULL
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
    label        = ~glue("#{id} {nombre}"),
    labelOptions = labelOptions(
      style     = list("font-weight" = "normal", padding = "3px 6px"),
      textsize  = "13px",
      direction = "auto"
    ),
    group        = "Restaurantes",
    clusterOptions = markerClusterOptions(
      showCoverageOnHover = FALSE,
      zoomToBoundsOnClick = TRUE,
      spiderfyOnMaxZoom   = TRUE
    )
  ) |>

  # Leyenda por tipo de cocina
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
    overlayGroups = c("Localidades", "Restaurantes"),
    options       = layersControlOptions(collapsed = FALSE)
  ) |>

  # Buscador por nombre
  addSearchFeatures(
    targetGroups = "Restaurantes",
    options      = searchFeaturesOptions(
      propertyName = "label",
      zoom         = 16,
      openPopup    = TRUE,
      hideMarkerOnCollapse = TRUE
    )
  ) |>

  # Vista inicial centrada en Bogotá
  setView(lng = -74.0721, lat = 4.7110, zoom = 11)

# ── 6. GUARDAR HTML ───────────────────────────────────────────────────────────
saveWidget(mapa, file = OUTPUT_MAP, selfcontained = TRUE)
cat(glue("\n✅ Mapa guardado: {OUTPUT_MAP}\n"))
cat(glue("   {nrow(df)} restaurantes | {length(unique(df$cocina))} tipos de cocina\n"))

# ── 7. EXPORTAR SHAPEFILE ─────────────────────────────────────────────────────
st_write(sf_rest, OUTPUT_SHP, delete_dsn = TRUE, quiet = TRUE)
cat(glue("✅ Shapefile guardado: {OUTPUT_SHP}\n"))