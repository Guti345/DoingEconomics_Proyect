"""
=============================================================
MAPA DE ENCUESTA DE CAMPO — RESTAURANTES A VISITAR
Python + Folium
=============================================================

Muestra ÚNICAMENTE los restaurantes con encuesta == 1,
es decir, los asignados aleatoriamente a la visita de campo.

Estructura del proyecto:
  DoingEconomics_Proyect/
  ├── Data/
  │   └── Raw/
  │       ├── restaurantes_mediterraneos_bogota.xlsx  <- INPUT
  │       └── Barrios_Bogota/                         <- INPUT shapefile
  └── Outputs/
      └── Graphs/
          └── mapa_encuesta_campo_*.html              <- OUTPUT

pip install folium geopandas pandas openpyxl
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

INPUT_XLSX   = DATA_RAW_DIR / "restaurantes_mediterraneos_bogota.xlsx"
CAMPO_BARRIO = "SCANOMBRE"

# ─── CONFIGURACIÓN ────────────────────────────────────────────────────────────
USE_CLUSTERS = False     # False → ver todos los puntos de visita de una vez
                         # True  → agrupar en clusters

_sufijo     = "clusters" if USE_CLUSTERS else "puntos"
OUTPUT_HTML = GRAPHS_DIR / f"mapa_encuesta_campo_{_sufijo}.html"

# ─── PALETA DE COLORES ────────────────────────────────────────────────────────
COLORES = {
    "Italiana":     "#2A9D8F",
    "Española":     "#E63946",
    "Griega":       "#457B9D",
    "Árabe":        "#9B5DE5",
    "Mediterránea": "#F4A261",
}

# ─── 1. CARGAR EXCEL Y FILTRAR encuesta == 1 ──────────────────────────────────
print("=" * 55)
print("  MAPA ENCUESTA DE CAMPO — RESTAURANTES A VISITAR")
print("=" * 55)

if not INPUT_XLSX.exists():
    raise FileNotFoundError(f"Excel no encontrado:\n  {INPUT_XLSX}")

df_total = pd.read_excel(INPUT_XLSX, engine="openpyxl")

if "encuesta" not in df_total.columns:
    raise KeyError(
        "Columna 'encuesta' no encontrada en el Excel.\n"
        "Corre primero el script 05_aleatorizacion_encuesta.py"
    )

# Filtrar solo los asignados a encuesta
df = df_total[df_total["encuesta"] == 1].copy()
df = df.dropna(subset=["lat", "lon"])
df["id"]          = df["id"].apply(lambda i: f"{int(i):03d}")
df["rating"]      = pd.to_numeric(df["rating"],      errors="coerce").round(1)
df["num_reviews"] = pd.to_numeric(df["num_reviews"], errors="coerce").fillna(0).astype(int)
df["barrio"]      = df["barrio"].fillna("Sin datos").replace("", "Sin datos")
df["cocina"]      = df["cocina"].fillna("Mediterránea").astype(str)
df["tipos"]       = df["tipos"].fillna("").astype(str)
df = df.reset_index(drop=True)

print(f"\n📋 Total en el Excel     : {len(df_total)}")
print(f"✅ Asignados a encuesta  : {len(df)}")
print(f"\n   Distribución por cocina:")
for c, n in df["cocina"].value_counts().items():
    print(f"     {c:<15} : {n}")

# ─── 2. CARGAR SHAPEFILE DE BARRIOS ───────────────────────────────────────────
shp_files = list(BARRIOS_DIR.glob("*.shp"))
if not shp_files:
    raise FileNotFoundError(f"No se encontró ningún .shp en:\n  {BARRIOS_DIR}")

barrios = gpd.read_file(shp_files[0]).to_crs(epsg=4326)
print(f"\n✅ Shapefile cargado     : {shp_files[0].name}")

if CAMPO_BARRIO not in barrios.columns:
    raise KeyError(
        f"Campo '{CAMPO_BARRIO}' no existe en el shapefile.\n"
        f"Columnas disponibles: {list(barrios.columns)}"
    )

# ─── 3. MAPA BASE ─────────────────────────────────────────────────────────────
mapa = folium.Map(location=[4.7110, -74.0721], zoom_start=12, tiles=None)

folium.TileLayer(tiles="CartoDB positron", name="Claro",    control=True).add_to(mapa)
folium.TileLayer(tiles="OpenStreetMap",    name="Detallado",control=True).add_to(mapa)

# ─── 4. CAPA DE BARRIOS (solo display, sin interacción) ───────────────────────
barrios_layer = folium.FeatureGroup(name="Barrios", show=True)
folium.GeoJson(
    data=barrios.__geo_interface__,
    style_function=lambda _: {
        "fillColor":  "#f0f0f0",
        "color":      "#999999",
        "weight":      0.8,
        "fillOpacity": 0.2,
    },
    highlight_function=lambda _: {},
    interactive=False,
).add_to(barrios_layer)
barrios_layer.add_to(mapa)

# ─── 5. FUNCIÓN DE POPUP ──────────────────────────────────────────────────────
def hacer_popup(row: pd.Series) -> str:
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

# ─── 6. CAPA DE RESTAURANTES A VISITAR ────────────────────────────────────────
encuesta_layer = folium.FeatureGroup(name="Visitas de campo", show=True)

if USE_CLUSTERS:
    print("\n🔵 Modo: CLUSTERS activado")
    contenedor = MarkerCluster(options={
        "showCoverageOnHover": False,
        "zoomToBoundsOnClick": True,
        "spiderfyOnMaxZoom":   True,
    })
    contenedor.add_to(encuesta_layer)
else:
    print("\n🟢 Modo: PUNTOS INDIVIDUALES activado")
    contenedor = encuesta_layer

for _, row in df.iterrows():
    color = COLORES.get(row["cocina"], "#888888")
    folium.CircleMarker(
        location     = [row["lat"], row["lon"]],
        radius       = 8,           # ligeramente más grande para destacar
        color        = color,
        fill         = True,
        fill_color   = color,
        fill_opacity = 0.9,
        weight       = 2,
        popup        = folium.Popup(hacer_popup(row), max_width=320),
        tooltip      = f"#{row['id']}  {row['nombre']}",
    ).add_to(contenedor)

encuesta_layer.add_to(mapa)

# ─── 7. LEYENDA ───────────────────────────────────────────────────────────────
cocinas_presentes = df["cocina"].unique()
items_leyenda = {k: v for k, v in {
    "Española":     "#E63946",
    "Griega":       "#457B9D",
    "Italiana":     "#2A9D8F",
    "Árabe":        "#9B5DE5",
    "Mediterránea": "#F4A261",
}.items() if k in cocinas_presentes}

filas_leyenda = "\n".join(
    f'  <span style="color:{color};">&#9632;</span> {cocina}<br>'
    for cocina, color in items_leyenda.items()
)

leyenda_html = f"""
<div style="position:fixed; bottom:30px; right:15px; z-index:1000;
            background:white; padding:10px 14px; border-radius:6px;
            border:1px solid #ccc; font-family:Arial,sans-serif;
            font-size:13px; box-shadow:2px 2px 6px rgba(0,0,0,.15);">
  <b style="font-size:13px;">Encuesta de campo</b><br>
  <span style="font-size:11px; color:#555;">{len(df)} restaurantes a visitar</span><br><br>
  <b style="font-size:12px;">Tipo de cocina</b><br>
  {filas_leyenda}
</div>
"""
mapa.get_root().html.add_child(folium.Element(leyenda_html))

# ─── 8. CONTROL DE CAPAS ──────────────────────────────────────────────────────
folium.LayerControl(position="topright", collapsed=False).add_to(mapa)

# ─── 9. GUARDAR HTML ──────────────────────────────────────────────────────────
mapa.save(str(OUTPUT_HTML))

modo = "CLUSTERS" if USE_CLUSTERS else "PUNTOS INDIVIDUALES"
print(f"\n✅ Mapa guardado [{modo}]: {OUTPUT_HTML}")
print(f"\n   Restaurantes a visitar por barrio (top 10):")
print(df["barrio"].value_counts().head(10).to_string())
