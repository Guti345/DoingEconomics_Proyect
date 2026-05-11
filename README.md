# 🫒 Digitalización y Posicionamiento en el Mercado de Restaurantes Mediterráneos en Bogotá

> Proyecto de investigación · **Haciendo Economía 2026-1** · Universidad del Rosario

**Autores:** Antonio Gutierrez, Jessica Gil  
**Última actualización:** Mayo 2026

---

## 📋 Descripción General

Este proyecto caracteriza el mercado de restaurantes mediterráneos en Bogotá e investiga la relación entre la adopción de estrategias digitales de posicionamiento y la visibilidad de los establecimientos en plataformas digitales. El estudio combina técnicas de extracción de datos (web scraping y APIs), análisis geoespacial y metodología de campo para generar insights sobre la transformación digital en el sector gastronómico.

### Pregunta de Investigación Principal

**¿Cuál es el estado actual de las estrategias de posicionamiento digital —en plataformas de opinión, redes sociales y delivery— de los restaurantes mediterráneos en Bogotá, y cómo perciben sus propietarios la adopción de inteligencia artificial como palanca de posicionamiento futuro en un nicho de alta competitividad?**

### Objetivos Secundarios

- Identificar y caracterizar la población de restaurantes mediterráneos en Bogotá
- Mapear la presencia digital en plataformas clave (Google Maps, TripAdvisor, redes sociales)
- Generar índices de digitalización y posicionamiento en el mercado (ejes. Redes, Plataformas de Opinión, Delivery)
- Entender la perspectiva hacia la implementación de IA respecto a los tres ejes propuestos. 

---

## 🗂️ Estructura del Repositorio

```
DoingEconomics_Proyect/
│
├── 📊 Data/
│   ├── Raw/                                    # Datos crudos sin procesar
│   │   ├── restaurantes_mediterraneos_bogota.xlsx        # Directorio completo de restaurantes
│   │   ├── restaurantes_mediterraneos_bogota.csv         # Mismo directorio en formato CSV
│   │   ├── restaurantes_mediterraneos_bogota_classified.xlsx  # Con clasificación de cocina
│   │   ├── base_raw.xlsx                      # Base de datos de encuestas en bruto
│   │   └── Barrios_Bogota/                    # Shapefile de barrios para análisis geoespacial
│   │
│   ├── Clean/                                 # Datos procesados y listos para análisis
│   ├── base_restaurantes_enriquecida_tripadvisor.xlsx    # Base enriquecida con datos de TripAdvisor
│   ├── base_final.xlsx                        # Base de datos final consolidada
│   ├── base_final.dta                         # Formato Stata para análisis estadístico
│   ├── result_encuesta.xlsx                   # Resultados de encuestas de campo
│   ├── results_encuesta.dta                   # Resultados en formato Stata
│   ├── SECTOR.* (shapefiles)                  # Capas geoespaciales para mapas
│   └── restaurantes_mediterraneos_bogota.csv  # Base consolidada
│
├── 📁 Documentos/
│   ├── base_datos_proyecto.xlsx               # Diccionario de variables y estructura de datos
│   ├── Consentimiento_Informado.pdf           # Documento de consentimiento ético
│   ├── Plan_de_análisis.pdf                   # Plan metodológico: variables, índices, estrategia estadística
│   ├── Cuestionario - Restaurantes Mediterráneos en Bogotá.pdf  # Instrumento de recolección
│   ├── Motivación-MarcoTeorico-Teoría del Cambio.pdf  # Fundamentación teórica
│   ├── Guion_Audiovisual_Restaurantes_Mediterraneos.docx  # Materiales complementarios
│   └── Reporte_Trabajo de Campo.pdf           # Informe de ejecución del trabajo de campo
│
├── 📈 Outputs/
│   ├── Graphs/                                # Visualizaciones cartográficas
│   │   ├── mapa_restaurantes_mediterraneos.html  # Mapa interactivo de todos los restaurantes
│   │   └── mapa_encuesta_campo_puntos.html      # Mapa de 41 restaurantes a encuestar
│   │
│   ├── Tables/                                # Tablas y estadísticas generadas
│   ├── created_data/                          # Datos intermedios creados durante análisis
│   ├── logs/                                  # Registros de ejecución y errores
│   ├── json/                                  # Datos de restaurantes en formato JSON (n=57)
│   ├── links_candidatos_tripadvisor.xlsx      # Candidatos identificados en TripAdvisor
│   ├── links_seleccionados_tripadvisor.xlsx   # Restaurantes validados en TripAdvisor
│   ├── tripadvisor_api_log.xlsx               # Historial de consultas a TripAdvisor
│   └── [restaurante_*.json]                   # Perfiles detallados por establecimiento
│
└── 🐍 Scripts/
    ├── 01_extraccion_restaurantes.py          # Extracción vía Google Places API
    ├── 02_mapa_restaurantes.py                # Mapa general (Python - Folium)
    ├── 03_completar_barrios.py                # Asignación de barrios por geocodificación inversa
    ├── 04_clasificar_cocina.py                # Clasificación automática de tipos de cocina
    ├── 05_aleatorizacion_encuesta.py          # Muestreo aleatorio para trabajo de campo (n=41)
    ├── 06_mapa_encuesta_campo.py              # Mapa de puntos de encuesta
    ├── 07_tripadvisor_scraper_bogota.ipynb    # Web scraping de TripAdvisor (Jupyter)
    ├── 08_Construccion_Base_Datos.do          # Construcción final en Stata
    ├── .env                                   # Variables de entorno (API keys - no versionar)
    └── api_request_log.json                   # Log de uso de Google Places API
```

---

## 📊 Descripción de Datos

### Directorio de Restaurantes (`restaurantes_mediterraneos_bogota.xlsx`)

**Universo:** ~100 restaurantes identificados en Bogotá con ofertas de cocina griega, española, italiana o mediterránea genérica.

**Campos principales:**
- `id` — Identificador único
- `nombre` — Nombre del establecimiento
- `direccion` — Dirección física en Bogotá
- `barrio` — Barrio de ubicación
- `coordenadas_lat`, `coordenadas_lon` — Geolocalización
- `rating` — Calificación en Google (0-5)
- `num_resenas` — Número de reseñas en Google
- `link_google_maps` — URL de Google Maps
- `tipo_cocina` — Clasificación: griega, española, italiana, mediterránea, mixta
- `pertenencia_muestra` — Binaria (1: incluida en muestra encuesta, 0: excluida)
- `encuesta` — Binaria (1: seleccionada para trabajo de campo, 0: no seleccionada)

### Base de Encuestas (`result_encuesta.xlsx`)

**Muestra:** 41 restaurantes seleccionados aleatoriamente (reproducibilidad: seed=42)

**Información recolectada:**
- Características del negocio (antigüedad, tamaño, propiedad)
- Adopción de tecnologías digitales
- Presencia en plataformas (Google, redes sociales, delivery)
- Estrategias de marketing digital
- Inversión en digitalización
- Percepciones sobre impacto en visibilidad

### Base Enriquecida con TripAdvisor (`base_restaurantes_enriquecida_tripadvisor.xlsx`)

**57 restaurantes** con datos adicionales:
- Reseñas y ratings en TripAdvisor
- Fotos disponibles
- Clasificaciones de viajeros
- URLs de perfiles

### Base Final (`base_final.xlsx` / `base_final.dta`)

**Muestra final:** 35 restaurantes con datos completos y validados

**Descripción:**
La base final consolida toda la información recolectada a través de múltiples fuentes (Google Places API, TripAdvisor, encuestas de campo) en una única base de datos integrada lista para análisis. De los 41 restaurantes encuestados inicialmente, 35 completaron el proceso de validación de datos y enriquecimiento con información de plataformas digitales.

**Composición:**
- 35 restaurantes con información completa de encuestas
- Variables de caracterización (ubicación, tipo de cocina, tamaño, antigüedad)
- Índices construidos:
  - **IRS** (Índice de Redes Sociales) — Presencia y actividad en redes (Facebook, Instagram, TikTok)
  - **IDL** (Índice de Digitalización) — Adopción general de tecnologías digitales
  - **IPO** (Índice de Posicionamiento Online) — Visibilidad en plataformas de opinión (Google, TripAdvisor)
  - **IA_Future** (Percepción de IA) — Disposición hacia implementación de inteligencia artificial

**Formatos disponibles:**
- `base_final.xlsx` — Formato Excel para visualización y exploración
- `base_final.dta` — Formato Stata para análisis estadístico avanzado

**Procesos de construcción:**
- Merge de encuestas campo + datos Google + datos TripAdvisor
- Validación y limpieza de datos inconsistentes
- Creación de índices compuestos (ver `Scripts/08_Construccion_Base_Datos.do`)
- Pruebas de confiabilidad y consistencia

---

## 🔧 Descripción de Scripts

### 1. `01_extraccion_restaurantes.py`
**Propósito:** Extrae restaurantes mediterráneos desde Google Places API (New).

**Entrada:** Búsquedas textuales por tipo de cocina (griega, española, italiana, mediterránea)  
**Salida:** `restaurantes_mediterraneos_bogota.csv` y `restaurantes_mediterraneos_bogota.xlsx`  
**Requisitos:**
- Google Cloud proyecto con Places API (New) habilitada
- API Key válida
- `pip install requests pandas`

**Consideraciones:**
- Google cobra por **SKU** (no por API general)
- Nuestro nivel: **Pro** (5.000 requests/mes gratuitos)
- Cada request incluye: id, location, address, rating, userRatingCount, googleMapsUri
- Script incluye contador de límite de cuota para evitar sobrecargos

---

### 2. `02_mapa_restaurantes.py` / `.R`
**Propósito:** Genera visualización interactiva de todos los restaurantes identificados.

**Entrada:** `restaurantes_mediterraneos_bogota.xlsx`  
**Salida:** `mapa_restaurantes_mediterraneos.html`  
**Tecnologías:** Python (Folium) o R (ggmap/leaflet)  
**Características:**
- Mapa base OSM
- Marcadores con popups informativos
- Agrupación por barrio
- Código de colores por tipo de cocina

---

### 3. `03_completar_barrios.py`
**Propósito:** Asigna barrio a cada restaurante basándose en coordenadas (geocodificación inversa).

**Entrada:** `restaurantes_mediterraneos_bogota.xlsx` (sin barrio)  
**Salida:** Mismo archivo con columna `barrio` completa  
**Método:** Shapefiles de Bogotá + spatial join

---

### 4. `04_clasificar_cocina.py`
**Propósito:** Clasifica automáticamente establecimientos en: griega, española, italiana, mediterránea, mixta.

**Entrada:** `restaurantes_mediterraneos_bogota.xlsx` (columna `tipo_cocina`)  
**Salida:** `restaurantes_mediterraneos_bogota_classified.xlsx`  
**Lógica:** Reglas léxicas sobre nombres y tipos Google

---

### 5. `05_aleatorizacion_encuesta.py`
**Propósito:** Selecciona muestra aleatoria para trabajo de campo.

**Configuración:**
- Proporción mínima por tipo de cocina: **50%** (redondeo hacia arriba)
- Seed: **42** (para reproducibilidad)
- Tamaño final esperado: ~41 restaurantes

**Entrada:** `restaurantes_mediterraneos_bogota.xlsx`  
**Salida:** Misma ruta, columna `encuesta` añadida

---

### 6. `06_mapa_encuesta_campo.py`
**Propósito:** Genera mapa de puntos de encuesta para logística de trabajo de campo.

**Entrada:** Base con `encuesta == 1`  
**Salida:** `mapa_encuesta_campo_puntos.html`

---

### 7. `07_tripadvisor_scraper_bogota.ipynb`
**Propósito:** Web scraping de TripAdvisor para enriquecer datos de restaurantes.

**Tecnología:** Jupyter Notebook + BeautifulSoup / Selenium  
**Extrae:**
- Reseñas y ratings
- Fotos de establecimientos
- Clasificaciones de viajeros
- URLs de perfiles

**Salida:** `base_restaurantes_enriquecida_tripadvisor.xlsx`, archivos JSON individuales

---

### 8. `08_Construccion_Base_Datos.do`
**Propósito:** Construcción y consolidación final de la base de datos en Stata.

**Incluye:**
- Merge de todas las fuentes
- Creación de índices: IRS (Índice de Resencias en Redes Sociales), IDL (Índice de Digitalización), IPO (Índice de Posicionamiento)
- Validación y limpieza final
- Exportación a `base_final.dta` y `base_final.xlsx`

---

## 📈 Estado del Proyecto

| Fase | Tarea | Estado | Notas |
|------|-------|--------|-------|
| **Identificación** | Extracción y clasificación de directorio | ✅ Completada | ~100 restaurantes identificados |
| **Muestreo** | Aleatorización de muestra de encuesta | ✅ Completada | n=41 (seed=42 para reproducibilidad) |
| **Diseño** | Cuestionario y consentimiento informado | ✅ Completada | Aprobado por ética |
| **Diseño** | Plan de análisis | ✅ Completada | Variables, índices, estrategia estadística |
| **Recolección** | Trabajo de campo (encuestas) | ✅ Completada | 41 restaurantes encuestados |
| **Enriquecimiento** | Extracción TripAdvisor | ✅ Completada | 57 restaurantes con datos adicionales |
| **Procesamiento** | Construcción de índices (IRS, IDL, IPO, IA_Future) | ✅ Completada | Stata — Base final: 35 restaurantes |
| **Validación** | Limpieza y consolidación final | ✅ Completada | `base_final.xlsx` / `base_final.dta` |
| **Análisis** | Análisis estadístico exploratorio | 🔄 En progreso | Descriptivas, correlaciones, visualización |
| **Análisis** | Modelos de regresión | 🔄 En progreso | Relación digitalización ↔ visibilidad y IA |
| **Documentación** | Informe final | ⏳ Pendiente | Síntesis de hallazgos y recomendaciones |

---

## 🚀 Requisitos y Configuración

### Dependencias Python

```bash
pip install requests pandas openpyxl folium geopandas shapely
# Para TripAdvisor scraper:
pip install selenium beautifulsoup4 lxml
# Para notebooks:
pip install jupyter ipython
```

### Configuración de Secretos

Crear archivo `.env` en la raíz de `Scripts/`:

```
GOOGLE_PLACES_API_KEY=your_api_key_here
TRIPADVISOR_API_KEY=your_api_key_here  # Si aplica
```

**⚠️ NO versionar `.env` — ya está en `.gitignore`**

### Requisitos Adicionales

- **Python:** 3.9+
- **R:** 4.0+ (si se usan scripts en R)
- **Stata:** 15+ (para `08_Construccion_Base_Datos.do`)
- **Datos geoespaciales:** Shapefile de barrios de Bogotá (incluido en `Data/Raw/Barrios_Bogota/`)

---

## 📖 Cómo Usar Este Proyecto

### Ejecutar el flujo de trabajo completo

```bash
cd Scripts/

# 1. Extraer restaurantes (requiere Google Places API Key)
python 01_extraccion_restaurantes.py

# 2. Asignar barrios por coordenadas
python 03_completar_barrios.py

# 3. Clasificar tipos de cocina
python 04_clasificar_cocina.py

# 4. Generar mapas
python 02_mapa_restaurantes.py
python 06_mapa_encuesta_campo.py

# 5. Scraping TripAdvisor (usar Jupyter)
jupyter notebook 07_tripadvisor_scraper_bogota.ipynb

# 6. Construcción final en Stata (requiere Stata instalado)
stata < 08_Construccion_Base_Datos.do
```

### Reproducibilidad

Todos los scripts están diseñados para ser **reproducibles**:
- **Seed fijo (42)** en aleatorización para garantizar misma muestra
- **Logs** de API en `api_request_log.json` para auditoría
- **Versionamiento** de datos en carpetas `Raw/` y `Clean/`

---

## 📁 Archivos Clave para Referencia

| Archivo | Propósito | Audiencia |
|---------|-----------|-----------|
| `Documentos/base_datos_proyecto.xlsx` | Diccionario de variables | Analistas, investigadores |
| `Documentos/Plan_de_análisis.pdf` | Metodología estadística | Investigadores, supervisores |
| `Documentos/Consentimiento_Informado.pdf` | Marco ético | Comité ética, encuestadores |
| `Documentos/Reporte_Trabajo de Campo.pdf` | Ejecución de encuestas | Equipo, supervisores |
| `Outputs/Graphs/` | Mapas interactivos | Presentaciones, reportes |
| `Data/base_final.dta` | Base consolidada | Análisis estadístico (Stata/R) |

---

## 🔍 Características Destacadas

✨ **Reproducibilidad:** Todos los scripts usan seeds fijos y versionamiento de datos  
🗺️ **Análisis geoespacial:** Mapas interactivos en HTML para exploración  
🔗 **Integración multi-fuente:** Google Maps + TripAdvisor + encuestas de campo  
📊 **Índices creados:** IRS, IDL, IPO para cuantificar digitalización  
🎯 **Muestreo estratificado:** Aleatorización respetando proporciones de tipos de cocina  
---

## 👥 Contacto y Colaboración

**Autores:**
- Antonio Gutierrez
- Jessica Gil

**Institución:** Universidad del Rosario — Haciendo Economía 2026-1  
**Supervisor:** Paul Rodriguez

**¿Preguntas sobre los datos o metodología?**  
Revisa primero:
1. `Documentos/base_datos_proyecto.xlsx` (diccionario de variables)
2. `Documentos/Plan_de_análisis.pdf` (estrategia estadística)
3. Comentarios en los scripts de Python

---

## 📝 Notas Importantes

- Los datos de encuestas están protegidos por consentimiento informado (confidencialidad de restaurantes)
- No incluyen información de clientes finales (solo datos de establecimientos)
- Scripts requieren autenticación (API keys, credenciales Stata)
- Mapas interactivos en `Outputs/Graphs/` se visualizan mejor en navegador web

---

## 📚 Referencias y Marco Teórico

Ver: `Documentos/Motivación-MarcoTeorico-Teoría del Cambio.pdf`

Temas principales:
- Transformación digital en gastronomía
- Estrategias de posicionamiento en línea
- Plataformas digitales de visibilidad (Google Maps, redes sociales, TripAdvisor)
- Teoría del cambio aplicada a digitalización

---

**Última actualización:** Mayo 2026  
**Estado:** Proyecto activo — fase de análisis e informe
