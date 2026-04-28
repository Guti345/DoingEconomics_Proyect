"""
=============================================================
EXTRACCIÓN DE RESTAURANTES MEDITERRÁNEOS EN BOGOTÁ
Google Places API (New) - Text Search
=============================================================
Cuisines cubiertas: griega, española, italiana, mediterránea
Output: restaurantes_mediterraneos_bogota.csv

REQUISITOS:
    pip install requests pandas

PASOS PREVIOS:
    1. Crear proyecto en https://console.cloud.google.com
    2. Habilitar "Places API (New)"
    3. Crear API Key en APIs & Services > Credentials
    4. Reemplazar YOUR_API_KEY abajo

─── CÓMO FUNCIONA EL COBRO (Google Places API New, desde marzo 2025) ─────────

  Google cobra por SKU (tipo de datos pedidos), NO por API en general.
  El nivel depende de los campos que pidas con FieldMask:

  ┌─────────────────────────────────────────────────────────────────┐
  │ CAMPOS QUE USAMOS       │ SKU ACTIVADO   │ CUOTA GRATIS/MES    │
  ├─────────────────────────────────────────────────────────────────┤
  │ id, location, address,  │  Essentials    │ 10.000 requests/mes │
  │ displayName, types,     │                │                     │
  │ googleMapsUri           │                │                     │
  ├─────────────────────────────────────────────────────────────────┤
  │ + rating, userRating    │  Pro           │  5.000 requests/mes │
  │   Count (reseñas)       │  (más alto)    │  ← ESTE ES EL TUYO  │
  └─────────────────────────────────────────────────────────────────┘

  REGLA CLAVE: si pides UN SOLO campo Pro, TODO el request se cobra a Pro.
  → Por eso nuestro límite seguro es 5.000 requests/mes.

  Para ~150 restaurantes usas aprox. 100-120 requests → muy por debajo del límite.
  El riesgo es re-ejecutar el script muchas veces en el mismo mes.

  PRECIO FUERA DEL FREE TIER: ~$17 USD por cada 1.000 requests adicionales.

  CONTADOR INTEGRADO ABAJO:
  - FREE_TIER_LIMIT  = 5.000  (bloqueo absoluto antes de cobrar)
  - SAFE_LIMIT       = 4.500  (advertencia cuando llegas al 90%)
  - El contador se guarda en api_request_log.json para acumularse
    entre ejecuciones del mismo mes.
=============================================================
"""

import requests
import pandas as pd
import time
import json
import os
from datetime import datetime
from pathlib import Path
from dotenv import load_dotenv

# ─── RUTAS DEL PROYECTO ───────────────────────────────────────────────────────
#
#   DoingEconomics_Proyect/         <- PROJECT_ROOT
#   ├── Data/
#   │   ├── Clean/                  <- DATA_CLEAN_DIR  (datos procesados)
#   │   └── Raw/                    <- DATA_RAW_DIR    (output de este script)
#   ├── Documentos/                 <- DOCS_DIR
#   ├── Outputs/
#   │   ├── Graphs/                 <- GRAPHS_DIR
#   │   └── Tables/                 <- TABLES_DIR
#   └── Scripts/                    <- SCRIPT_DIR (este archivo)
#       ├── venv/
#       ├── .env
#       └── 01_extraccion restaurantes.py

SCRIPT_DIR     = Path(__file__).resolve().parent       # .../Scripts
PROJECT_ROOT   = SCRIPT_DIR.parent                     # .../DoingEconomics_Proyect

DATA_RAW_DIR   = PROJECT_ROOT / "Data"    / "Raw"
DATA_CLEAN_DIR = PROJECT_ROOT / "Data"    / "Clean"
GRAPHS_DIR     = PROJECT_ROOT / "Outputs" / "Graphs"
TABLES_DIR     = PROJECT_ROOT / "Outputs" / "Tables"
DOCS_DIR       = PROJECT_ROOT / "Documentos"

# Crear carpetas si no existen
for _folder in [DATA_RAW_DIR, DATA_CLEAN_DIR, GRAPHS_DIR, TABLES_DIR]:
    _folder.mkdir(parents=True, exist_ok=True)

# Archivos de output de este script
OUTPUT_CSV = DATA_RAW_DIR / "restaurantes_mediterraneos_bogota.csv"
LOG_FILE   = str(SCRIPT_DIR / "api_request_log.json")  # log queda en Scripts/

# ─── CONFIGURACIÓN ────────────────────────────────────────────────────────────
load_dotenv(SCRIPT_DIR / ".env")   # carga el .env que está en Scripts/

API_KEY = os.getenv("GOOGLE_PLACES_API_KEY")

if not API_KEY:
    raise EnvironmentError(
        "No se encontró GOOGLE_PLACES_API_KEY.\n"
        f"Verifica que existe el archivo: {SCRIPT_DIR / '.env'}\n"
        "Y que contiene la línea: GOOGLE_PLACES_API_KEY=tu_clave_aqui"
    )

# Límites de seguridad (basados en free tier Pro SKU = 5.000/mes)
FREE_TIER_LIMIT = 5_000    # bloqueo duro: NUNCA superar esto
SAFE_LIMIT      = 4_500    # advertencia al 90% del free tier

# Queries separados por tipo de cocina para maximizar cobertura
QUERIES = [
    "restaurante mediterráneo Bogotá",
    "restaurante griego Bogotá",
    "restaurante español Bogotá Colombia",
    "restaurante italiano Bogotá",
    "cocina griega Bogotá",
    "cocina italiana Bogotá",
    "comida española Bogotá",
    "tapas bar Bogotá",
    "pizzeria italiana Bogotá",
    "trattoria Bogotá",
]

# Coordenadas centro de Bogotá + radio de búsqueda (25 km cubre toda la ciudad)
LOCATION_BIAS = {
    "circle": {
        "center": {"latitude": 4.7110, "longitude": -74.0721},
        "radius": 25000
    }
}

# ── NOTA SOBRE FIELD MASK Y COBRO ─────────────────────────────────────────────
# rating y userRatingCount activan el SKU "Pro" → 5.000 free/mes
# Si quisieras SOLO Essentials (10.000 free/mes), elimina esas dos líneas
# y ajusta FREE_TIER_LIMIT a 10_000
FIELD_MASK = (
    "places.displayName,"
    "places.formattedAddress,"
    "places.location,"
    "places.rating,"          # activa SKU Pro (relevante para tu investigación)
    "places.userRatingCount," # activa SKU Pro
    "places.googleMapsUri,"
    "places.types,"
    "places.id"
)

URL = "https://places.googleapis.com/v1/places:searchText"


# ─── SISTEMA DE CONTADOR PERSISTENTE ─────────────────────────────────────────

def load_request_log() -> dict:
    """
    Carga el log de requests del mes actual.
    Si no existe o es de un mes anterior, lo reinicia.
    """
    current_month = datetime.now().strftime("%Y-%m")

    if os.path.exists(LOG_FILE):
        with open(LOG_FILE, "r") as f:
            log = json.load(f)
        if log.get("month") != current_month:
            print(f"📅 Nuevo mes detectado ({current_month}). Reiniciando contador.")
            log = {"month": current_month, "total_requests": 0, "sessions": []}
    else:
        log = {"month": current_month, "total_requests": 0, "sessions": []}

    return log


def save_request_log(log: dict):
    """Guarda el log actualizado en disco."""
    with open(LOG_FILE, "w") as f:
        json.dump(log, f, indent=2)


def check_and_increment(log: dict, n: int = 1) -> dict:
    """
    Verifica si el próximo request supera los límites.
    Lanza SystemExit si alcanza FREE_TIER_LIMIT.
    Imprime advertencia si supera SAFE_LIMIT.
    """
    current   = log["total_requests"]
    projected = current + n

    # BLOQUEO DURO
    if projected > FREE_TIER_LIMIT:
        print("\n" + "=" * 60)
        print("  🚨  BLOQUEO DE SEGURIDAD ACTIVADO")
        print("=" * 60)
        print(f"  Requests realizados este mes : {current:,}")
        print(f"  Límite free tier (Pro SKU)   : {FREE_TIER_LIMIT:,} / mes")
        print(f"  El siguiente request generaría COBRO (~$0.017 USD)")
        print(f"  Script detenido. No se realizará ninguna llamada más.")
        print("=" * 60 + "\n")
        raise SystemExit("Límite de free tier alcanzado. Script detenido sin cobro.")

    # ADVERTENCIA AL 90%
    if projected >= SAFE_LIMIT and current < SAFE_LIMIT:
        print(f"\n{'⚠️ ' * 10}")
        print(f"  ADVERTENCIA: llevas {projected:,} de {FREE_TIER_LIMIT:,} requests.")
        print(f"  Solo quedan {FREE_TIER_LIMIT - projected:,} requests gratuitos.")
        print(f"  Considera detener si ya tienes suficientes resultados.")
        print(f"{'⚠️ ' * 10}\n")

    log["total_requests"] = projected
    return log


def print_cost_status(log: dict):
    """Imprime el estado actual del contador con barra de progreso."""
    total   = log["total_requests"]
    pct     = (total / FREE_TIER_LIMIT) * 100
    bar_len = 40
    filled  = int(bar_len * total / FREE_TIER_LIMIT)
    bar     = "█" * filled + "░" * (bar_len - filled)
    icon    = "✅" if pct < 70 else ("⚠️ " if pct < 90 else "🚨")

    print(f"\n{icon} Contador de requests — mes {log['month']}")
    print(f"   [{bar}] {total:,} / {FREE_TIER_LIMIT:,} ({pct:.1f}%)")
    if total < FREE_TIER_LIMIT:
        remaining = FREE_TIER_LIMIT - total
        print(f"   Requests libres restantes : {remaining:,}")
        print(f"   Costo estimado hasta ahora: $0.00 USD\n")


# ─── FUNCIÓN DE BÚSQUEDA ──────────────────────────────────────────────────────

def search_places(query: str, log: dict, next_page_token: str = None):
    """
    Llama a Places API Text Search.
    Incrementa el contador ANTES de hacer la llamada.
    Retorna (respuesta_json, log_actualizado).
    """
    log = check_and_increment(log, n=1)
    save_request_log(log)   # persiste inmediatamente por si hay crash

    headers = {
        "Content-Type": "application/json",
        "X-Goog-Api-Key": API_KEY,
        "X-Goog-FieldMask": FIELD_MASK,
    }
    body = {
        "textQuery": query,
        "languageCode": "es",
        "maxResultCount": 20,
        "locationBias": LOCATION_BIAS,
    }
    if next_page_token:
        body["pageToken"] = next_page_token

    response = requests.post(URL, headers=headers, json=body)
    response.raise_for_status()
    return response.json(), log


def extract_restaurants(queries: list, log: dict):
    """Itera sobre todos los queries y acumula resultados únicos."""
    all_places = {}

    for query in queries:
        print(f"\n🔍 Query: '{query}'")
        page = 0

        while True:
            page += 1
            try:
                data, log = search_places(query, log)
            except requests.HTTPError as e:
                print(f"   ⚠️  Error HTTP: {e}")
                break

            places    = data.get("places", [])
            new_count = 0
            for p in places:
                pid = p.get("id", "")
                if pid and pid not in all_places:
                    all_places[pid] = {
                        "place_id":        pid,
                        "nombre":          p.get("displayName", {}).get("text", ""),
                        "direccion":       p.get("formattedAddress", ""),
                        "lat":             p.get("location", {}).get("latitude", None),
                        "lon":             p.get("location", {}).get("longitude", None),
                        "rating":          p.get("rating", None),
                        "num_reviews":     p.get("userRatingCount", None),
                        "google_maps_url": p.get("googleMapsUri", ""),
                        "tipos":           ", ".join(p.get("types", [])),
                        "query_origen":    query,
                    }
                    new_count += 1

            print(f"   Pág {page}: {len(places)} resultados "
                  f"| {new_count} nuevos | Acumulado: {len(all_places)} "
                  f"| Requests usados: {log['total_requests']:,}")

            next_token = data.get("nextPageToken")
            if not next_token:
                break
            time.sleep(2)

        time.sleep(1)

    return pd.DataFrame(list(all_places.values())), log


# ─── LIMPIEZA Y FILTRADO ──────────────────────────────────────────────────────

def clean_and_filter(df: pd.DataFrame) -> pd.DataFrame:
    """Filtra restaurantes dentro de Bogotá y agrega ID correlativo."""
    df = df.dropna(subset=["lat", "lon"]).copy()

    df = df[
        (df["lat"] >= 4.45) & (df["lat"] <= 4.85) &
        (df["lon"] >= -74.25) & (df["lon"] <= -73.95)
    ]

    EXCLUIR = ["mcdonald", "domino", "pizza hut", "telepizza", "subway",
               "burger", "kentucky", "kfc"]
    mask = ~df["nombre"].str.lower().str.contains("|".join(EXCLUIR), na=False)
    df   = df[mask]

    df = df.sort_values("num_reviews", ascending=False).reset_index(drop=True)
    df.insert(0, "id", df.index.map(lambda i: f"{i+1:03d}"))
    df["barrio"] = df["direccion"].str.extract(
        r",\s*([^,]+),\s*Bogotá", expand=False
    ).str.strip()

    return df


# ─── MAIN ─────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    print("=" * 60)
    print("  EXTRACCIÓN RESTAURANTES MEDITERRÁNEOS - BOGOTÁ")
    print("=" * 60)

    log = load_request_log()
    print_cost_status(log)

    # Estimación previa de requests
    est_requests = len(QUERIES) * 2
    print(f"📊 Estimación para esta ejecución: ~{est_requests} requests")
    print(f"   ({len(QUERIES)} queries × ~2 páginas promedio)")

    if log["total_requests"] + est_requests > SAFE_LIMIT:
        print(f"\n⚠️  Esta ejecución podría acercarte al límite de cobro.")
        resp = input("   ¿Deseas continuar? (s/n): ").strip().lower()
        if resp != "s":
            print("Ejecución cancelada por el usuario.")
            raise SystemExit(0)

    # Registrar inicio de sesión
    session_info = {
        "inicio":              datetime.now().isoformat(),
        "requests_al_inicio":  log["total_requests"]
    }

    # Extracción
    raw_df, log = extract_restaurants(QUERIES, log)

    # Registrar fin
    session_info["fin"]                  = datetime.now().isoformat()
    session_info["requests_en_sesion"]   = (
        log["total_requests"] - session_info["requests_al_inicio"]
    )
    log["sessions"].append(session_info)
    save_request_log(log)

    print(f"\n✅ Total sin depurar: {len(raw_df)} registros únicos")
    print_cost_status(log)

    clean_df = clean_and_filter(raw_df)
    print(f"✅ Tras limpieza y filtrado: {len(clean_df)} restaurantes en Bogotá")

    output_csv = OUTPUT_CSV
    clean_df.to_csv(output_csv, index=False, encoding="utf-8-sig")
    print(f"\n💾 CSV guardado    : {output_csv}")
    print(f"📋 Log de requests : {LOG_FILE}")

    print("\nPrimeras filas:")
    print(clean_df[["id", "nombre", "barrio", "lat", "lon",
                     "rating", "num_reviews"]].head(10).to_string(index=False))

    print(f"\n📊 Top 10 barrios con restaurantes mediterráneos:")
    print(clean_df["barrio"].value_counts().head(10).to_string())