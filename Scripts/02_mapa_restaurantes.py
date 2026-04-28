"""
=============================================================
MAPA INTERACTIVO - RESTAURANTES MEDITERRÁNEOS EN BOGOTÁ
Python + Folium  (reemplaza 02_mapa_restaurantes.R)
=============================================================

Estructura del proyecto:
  DoingEconomics_Proyect/
  ├── Data/
  │   └── Raw/
  │       ├── restaurantes_mediterraneos_bogota.csv   <- INPUT
  │       └── Barrios_Bogota/                         <- INPUT shapefile
  └── Outputs/
      └── Graphs/
          └── mapa_restaurantes_mediterraneos.html    <- OUTPUT

Columnas del CSV:
  id | place_id | nombre | direccion | lat | lon |
  rating | num_reviews | google_maps_url | tipos | query_origen | barrio

pip install folium geopandas pandas
=============================================================
"""

import pandas as pd
import geopandas as gpd
import folium
from folium.plugins import MarkerCluster
from pathlib import Path
import html

# ─── RUTAS DEL PROYECTO ───────────────────────────────────────────────────────
SCRIPT_DIR   = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parent
DATA_RAW_DIR = PROJECT_ROOT / "Data"    / "Raw"
GRAPHS_DIR   = PROJECT_ROOT / "Outputs" / "Graphs"
BARRIOS_DIR  = DATA_RAW_DIR / "Barrios_Bogota"

GRAPHS_DIR.mkdir(parents=True, exist_ok=True)

INPUT_CSV   = DATA_RAW_DIR / "restaurantes_mediterraneos_bogota.csv"

OUTPUT_HTML = GRAPHS_DIR / f"mapa_restaurantes_mediterraneos.html"

# Nombre del campo de barrio en el shapefile — ajusta si es diferente
CAMPO_BARRIO = "SCANOMBRE"

# ─── CONFIGURACIÓN DE CLUSTERS ────────────────────────────────────────────────
#
#   USE_CLUSTERS = True   →  puntos agrupados en clusters numerados
#                            (útil para ver densidad y navegar rápido)
#
#   USE_CLUSTERS = False  →  todos los puntos visibles simultáneamente
#                            (útil para ver distribución espacial completa)
#
#   El script genera automáticamente un nombre de archivo diferente
#   según la opción, para que puedas tener ambas versiones guardadas.

USE_CLUSTERS = False      # ← cambia aquí: True / False

# ─── PALETA DE COLORES POR COCINA ─────────────────────────────────────────────
COLORES = {
    "Italiana":     "#2A9D8F",
    "Española":     "#E63946",
    "Griega":       "#457B9D",
    "Mediterránea": "#F4A261",
}

def clasificar_cocina(tipos: str, query_origen: str) -> str:
    t = str(tipos).lower()
    q = str(query_origen).lower()
    if "grieg" in t or "greek" in t or "grieg" in q:
        return "Griega"
    if "españ" in t or "spanish" in t or "españ" in q or "tapas" in q:
        return "Española"
    if "italian" in t or "italian" in q or "pizza" in q or "trattoria" in q:
        return "Italiana"
    return "Mediterránea"

# ─── 1. CARGAR CSV ────────────────────────────────────────────────────────────
print("=" * 55)
print("  MAPA INTERACTIVO — RESTAURANTES MEDITERRÁNEOS")
print("=" * 55)

if not INPUT_CSV.exists():
    raise FileNotFoundError(f"CSV no encontrado:\n  {INPUT_CSV}")

df = pd.read_csv(INPUT_CSV, encoding="utf-8-sig")
df = df.dropna(subset=["lat", "lon"]).copy()
df["id"]          = df["id"].apply(lambda i: f"{int(i):03d}")
df["rating"]      = pd.to_numeric(df["rating"],      errors="coerce").round(1)
df["num_reviews"] = pd.to_numeric(df["num_reviews"], errors="coerce").fillna(0).astype(int)
df["barrio"]      = df["barrio"].fillna("Sin datos").replace("", "Sin datos")
df["tipos"]       = df["tipos"].fillna("").astype(str)
df["query_origen"]= df["query_origen"].fillna("").astype(str)
df["cocina"]      = df.apply(
    lambda r: clasificar_cocina(r["tipos"], r["query_origen"]), axis=1
)

print(f"\n✅ Restaurantes cargados : {len(df)}")
print(f"   Distribución por cocina:")
for c, n in df["cocina"].value_counts().items():
    print(f"     {c:<15} : {n}")

# ─── 2. CARGAR SHAPEFILE DE BARRIOS ───────────────────────────────────────────
shp_files = list(BARRIOS_DIR.glob("*.shp"))
if not shp_files:
    raise FileNotFoundError(
        f"No se encontró ningún .shp en:\n  {BARRIOS_DIR}"
    )

barrios = gpd.read_file(shp_files[0]).to_crs(epsg=4326)
print(f"\n✅ Shapefile cargado     : {shp_files[0].name}")
print(f"   Polígonos             : {len(barrios)}")
print(f"   Columnas              : {list(barrios.columns)}")

if CAMPO_BARRIO not in barrios.columns:
    raise KeyError(
        f"\nCampo '{CAMPO_BARRIO}' no existe en el shapefile.\n"
        f"Columnas disponibles: {list(barrios.columns)}\n"
        f"Ajusta CAMPO_BARRIO en la línea 53."
    )

# ─── 3. CONSTRUIR MAPA BASE ───────────────────────────────────────────────────
mapa = folium.Map(
    location=[4.7110, -74.0721],
    zoom_start=11,
    tiles=None                    # tiles se agregan como capas intercambiables
)

# Tiles base
folium.TileLayer(
    tiles="CartoDB positron",
    name="Claro",
    control=True
).add_to(mapa)

folium.TileLayer(
    tiles="OpenStreetMap",
    name="Detallado",
    control=True
).add_to(mapa)

# ─── 4. CAPA DE BARRIOS ───────────────────────────────────────────────────────
barrios_layer = folium.FeatureGroup(name="Barrios", show=True)

folium.GeoJson(
    data=barrios.__geo_interface__,
    style_function=lambda _: {
        "fillColor":   "#f0f0f0",
        "color":       "#999999",
        "weight":       0.8,
        "fillOpacity":  0.2,
    },
    highlight_function=lambda _: {},   # sin resaltado al hover
    interactive=False,                  # bloquea clic y tooltip
).add_to(barrios_layer)

barrios_layer.add_to(mapa)

# ─── 5. FUNCIÓN DE POPUP ──────────────────────────────────────────────────────
def hacer_popup(row: pd.Series) -> str:
    """
    Genera el HTML del popup para cada restaurante.
    html.escape() protege contra caracteres especiales en los datos
    que podrían romper el HTML (&, <, >, comillas).
    """
    def esc(v):
        return html.escape(str(v)) if pd.notna(v) else "-"

    nombre    = esc(row["nombre"])
    rid       = esc(row["id"])
    cocina    = esc(row["cocina"])
    barrio    = esc(row["barrio"])
    direccion = esc(row["direccion"])
    rating    = f"{row['rating']} / 5" if pd.notna(row["rating"]) else "Sin datos"
    reviews   = f"{row['num_reviews']:,}".replace(",", ".") if row["num_reviews"] > 0 else "Sin datos"
    tipos     = esc(row["tipos"]).replace("_", " ") if row["tipos"] else "Sin datos"

    maps_link = (
        f'<a href="{html.escape(row["google_maps_url"])}" target="_blank">'
        f'Ver en Google Maps</a>'
        if pd.notna(row.get("google_maps_url")) and row["google_maps_url"] != ""
        else ""
    )

    return f"""
    <div style="font-family:Arial,sans-serif; font-size:13px;
                line-height:1.8; min-width:210px;">
        <b style="font-size:14px;">{nombre}</b><br>
        ID: {rid}<br>
        Cocina: {cocina}<br>
        Barrio: {barrio}<br>
        Dirección: {direccion}<br>
        Rating: {rating}<br>
        Reseñas: {reviews}<br>
        Tipo: {tipos}<br>
        {maps_link}
    </div>
    """

# ─── 6. CAPA DE RESTAURANTES — CLUSTER O PUNTOS INDIVIDUALES ─────────────────
restaurantes_layer = folium.FeatureGroup(name="Restaurantes", show=True)

if USE_CLUSTERS:
    # ── Modo cluster: agrupa puntos cercanos en burbujas numeradas ────────────
    print("\n🔵 Modo: CLUSTERS activado")
    contenedor = MarkerCluster(
        options={
            "showCoverageOnHover": False,
            "zoomToBoundsOnClick": True,
            "spiderfyOnMaxZoom":   True,
        }
    )
    contenedor.add_to(restaurantes_layer)

else:
    # ── Modo puntos: todos los puntos visibles al mismo tiempo ────────────────
    print("\n🟢 Modo: PUNTOS INDIVIDUALES activado")
    contenedor = restaurantes_layer   # los markers van directo a la capa

for _, row in df.iterrows():
    color  = COLORES.get(row["cocina"], "#888888")
    popup  = folium.Popup(hacer_popup(row), max_width=320)
    label  = f"#{row['id']}  {row['nombre']}"

    folium.CircleMarker(
        location     = [row["lat"], row["lon"]],
        radius       = 7,
        color        = color,
        fill         = True,
        fill_color   = color,
        fill_opacity = 0.85,
        weight       = 1.5,
        popup        = popup,
        tooltip      = label,
    ).add_to(contenedor)

restaurantes_layer.add_to(mapa)

# ─── 7. LEYENDA MANUAL ────────────────────────────────────────────────────────
leyenda_html = """
<div style="
    position: fixed;
    bottom: 30px;
    right: 15px;
    z-index: 1000;
    background: white;
    padding: 10px 14px;
    border-radius: 6px;
    border: 1px solid #ccc;
    font-family: Arial, sans-serif;
    font-size: 13px;
    box-shadow: 2px 2px 6px rgba(0,0,0,.15);">
  <b style="font-size:13px;">Tipo de cocina</b><br>
  <span style="color:#E63946;">&#9632;</span> Española<br>
  <span style="color:#457B9D;">&#9632;</span> Griega<br>
  <span style="color:#2A9D8F;">&#9632;</span> Italiana<br>
  <span style="color:#F4A261;">&#9632;</span> Mediterránea
</div>
"""
mapa.get_root().html.add_child(folium.Element(leyenda_html))

# ─── 8. CONTROL DE CAPAS ──────────────────────────────────────────────────────
folium.LayerControl(position="topright", collapsed=False).add_to(mapa)

# ─── 9. GUARDAR HTML ──────────────────────────────────────────────────────────
mapa.save(str(OUTPUT_HTML))

modo = "CLUSTERS" if USE_CLUSTERS else "PUNTOS INDIVIDUALES"
print(f"\n✅ Mapa guardado [{modo}]: {OUTPUT_HTML}")
print(f"   {len(df)} restaurantes | {df['cocina'].nunique()} tipos de cocina")
print(f"\n   Para cambiar entre modos, edita la línea:")
print(f"   USE_CLUSTERS = {USE_CLUSTERS}  →  cambia a {not USE_CLUSTERS}")
print(f"\n   Distribución final por barrio (top 10):")
print(df["barrio"].value_counts().head(10).to_string())