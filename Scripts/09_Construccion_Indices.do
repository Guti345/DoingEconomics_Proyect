/* =============================================================================
   PROYECTO: Digitalización y posicionamiento - Restaurantes Mediterráneos Bogotá
   SCRIPT:   indices_digitalizacion_v3.do
   --------------------------------------------------------------------------
   Construye IRS (0–14), IDL (0–10) e IPO (0–18) desde base_final.dta
   INPUT:  ${clean}\base_final.dta
   OUTPUT: ${clean}\base_indices.dta  |  ${tables}\tabla_indices.xlsx
   ============================================================================= */

clear all
set more off

* ── Descomentar solo si se corre de forma independiente ──
cd "C:\Users\anton\OneDrive\Documentos\GitHub\DoingEconomics_Proyect\Scripts"
global main   "C:\Users\anton\OneDrive\Documentos\GitHub\DoingEconomics_Proyect"
global graphs "${main}\Outputs\Graphs"
global tables "${main}\Outputs\Tables"
global raw    "${main}\Data\Raw"
global clean  "${main}\Data\Clean"


/* =============================================================================
   SECCION 0 - CARGA Y FILTRO
   ============================================================================= */

use "${clean}\base_final.dta", clear

keep if encuesta_si == 1

count
di "N con encuesta: `r(N)' (esperado: 35)"


/* =============================================================================
   SECCION 1 - CONVERSION DE STRINGS A NUMERICO
   Todas las variables de encuesta llegan como texto desde Google Forms.
   ============================================================================= */

* p0a: tipo de cocina
gen     p0a_n = 1 if p0a == "Española"
replace p0a_n = 2 if p0a == "Griega"
replace p0a_n = 3 if p0a == "Italiana"
replace p0a_n = 4 if strpos(p0a, "Mediterránea") > 0
replace p0a_n = 5 if p0a_n == . & p0a != ""

label define cocina_lbl 1 "Española" 2 "Griega" 3 "Italiana" 4 "Mediterránea" 5 "Otra"
label values  p0a_n cocina_lbl
label variable p0a_n "p0a - Tipo de cocina"

* p3: pertenece a cadena — viene con tilde "Sí"
gen p3_n = (p3 == "Sí")

label define sino_lbl 0 "No" 1 "Si"
label values  p3_n sino_lbl
label variable p3_n "p3 - Pertenece a cadena"

* p3b: competitividad percibida — llega como string "2","3","4","5"
gen p3b_n = p3b
label variable p3b_n "p3b - Competitividad percibida (1-5)"

* p4: inversion en marketing digital
gen p4_n = (p4 == "Sí")
label values  p4_n sino_lbl
label variable p4_n "p4 - Realiza inversion en marketing digital"

* p6: frecuencia de pauta (ordinal 0-3)
gen p6_n = .
replace p6_n = 0 if p6 == "Nunca"
replace p6_n = 1 if strpos(p6, "sola vez")    > 0
replace p6_n = 2 if strpos(p6, "casionalmen") > 0
replace p6_n = 3 if strpos(p6, "continua")    > 0

label define frec_lbl 0 "Nunca" 1 "Una vez" 2 "Ocasional" 3 "Continua"
label values  p6_n frec_lbl
label variable p6_n "p6 - Frecuencia de pauta (0-3)"

* p7: porcentaje de ingresos en marketing (ordinal 0-4)
gen p7_n = .
replace p7_n = 0 if strpos(p7, "No lo sé")    > 0
replace p7_n = 1 if strpos(p7, "Menos del 1") > 0
replace p7_n = 2 if strpos(p7, "1% y el 3")   > 0
replace p7_n = 3 if strpos(p7, "3% y el 5")   > 0
replace p7_n = 4 if strpos(p7, "Más del 5")   > 0

label define porc_lbl 0 "No lo sé" 1 "<1%" 2 "1-3%" 3 "3-5%" 4 ">5%"
label values  p7_n porc_lbl
label variable p7_n "p7 - % ingresos en marketing (0-4)"

* p12: canal mas rentable (dummy delivery)
gen p12_delivery = (p12 == "Delivery por plataformas")
label values  p12_delivery sino_lbl
label variable p12_delivery "p12 - Canal mas rentable = delivery (dummy)"

* p12b: acceso y uso de datos de plataformas de delivery (0-2)
gen p12b_n = .
replace p12b_n = 2 if strpos(p12b, "regularmente")  > 0
replace p12b_n = 1 if strpos(p12b, "disponibles")   > 0
replace p12b_n = 0 if strpos(p12b, "no ofrece")     > 0
replace p12b_n = 0 if strpos(p12b, "No sé")         > 0
label variable p12b_n "p12b - Uso datos delivery (0=No/NS, 1=Disponible, 2=Consulta activa)"

* p12c: uso de datos para decisiones estrategicas
* Reemplaza "Rappi Ads" (ausente en p5) como señal de uso activo de delivery
* Si, con frecuencia o Si, ocasionalmente = 2 pts | resto = 0
gen p12c_n = 0
replace p12c_n = 2 if strpos(p12c, "frecuencia")    > 0
replace p12c_n = 2 if strpos(p12c, "casionalmente") > 0
label variable p12c_n "p12c - Usa datos delivery para decisiones (0 o 2)"

* p13b: IA en gestion de resenas (ordinal 0-3)
gen p13b_n = .
replace p13b_n = 3 if p13b == "Sí (ej. respuestas generadas por IA)"
replace p13b_n = 2 if strpos(p13b, "interesaría") > 0
replace p13b_n = 1 if strpos(p13b, "manual")      > 0
replace p13b_n = 0 if strpos(p13b, "No sé")       > 0
label variable p13b_n "p13b - IA en gestion de resenas (0-3)"

* Verificacion: detectar missing no esperados
foreach v of varlist p0a_n p3_n p4_n p6_n p7_n p12_delivery p12b_n p12c_n p13b_n {
    quietly count if missing(`v')
    if r(N) > 0 di "ADVERTENCIA: `v' tiene `r(N)' missing — revisar texto fuente"
}


/* =============================================================================
   SECCION 2 - DESAGREGACION DE P5 Y P8 (SELECCION MULTIPLE)
   ============================================================================= */

* P5: plataformas con pauta paga
gen p5_lower = lower(p5)

gen p5_fbig   = (strpos(p5_lower, "facebook") > 0 | strpos(p5_lower, "instagram") > 0)
gen p5_tiktok = (strpos(p5_lower, "tiktok")   > 0)
gen p5_google = (strpos(p5_lower, "google ads") > 0)

foreach v of varlist p5_fbig p5_tiktok p5_google {
    replace `v' = 0 if p4_n == 0
    label values `v' sino_lbl
}

label variable p5_fbig   "p5 - FB/IG Ads (dummy)"
label variable p5_tiktok "p5 - TikTok Ads (dummy)"
label variable p5_google "p5 - Google Ads (dummy)"
drop p5_lower

* P8: canal principal de descubrimiento
gen p8_lower = lower(p8)

gen p8_google   = (strpos(p8_lower, "google")   > 0 | strpos(p8_lower, "maps")      > 0)
gen p8_redes    = (strpos(p8_lower, "redes")     > 0 | strpos(p8_lower, "instagram") > 0 | ///
                   strpos(p8_lower, "tiktok")    > 0)
gen p8_delivery = (strpos(p8_lower, "delivery")  > 0 | strpos(p8_lower, "rappi")     > 0 | ///
                   strpos(p8_lower, "didi")       > 0)

foreach v of varlist p8_google p8_redes p8_delivery {
    label values `v' sino_lbl
}

label variable p8_google   "p8 - Descubrimiento via Google/Maps (dummy)"
label variable p8_redes    "p8 - Descubrimiento via redes sociales (dummy)"
label variable p8_delivery "p8 - Descubrimiento via delivery (dummy)"
drop p8_lower


/* =============================================================================
   SECCION 3 - NORMALIZACION DE P9 / P10 / P11 A BASE 10
   Si la suma real no es 10, se redistribuye proporcionalmente.
   ============================================================================= */

destring p9 p10 p11, replace force

gen _suma = p9 + p10 + p11

gen p9_n  = round((p9  / _suma) * 10, 0.1) if _suma > 0
gen p10_n = round((p10 / _suma) * 10, 0.1) if _suma > 0
gen p11_n = round((p11 / _suma) * 10, 0.1) if _suma > 0

replace p9_n  = . if _suma == 0
replace p10_n = . if _suma == 0
replace p11_n = . if _suma == 0

label variable p9_n  "p9 - Clientes presenciales normalizados (de cada 10)"
label variable p10_n "p10 - Clientes delivery normalizados (de cada 10)"
label variable p11_n "p11 - Clientes domicilio propio normalizados (de cada 10)"

quietly gen _check = round(p9_n + p10_n + p11_n, 0.1)
list nombre p9 p10 p11 _suma p9_n p10_n p11_n if abs(_check - 10) > 0.5 & !missing(_check)
drop _suma _check


/* =============================================================================
   SECCION 4 - P7b: USOS DE IA EN REDES (SELECCION MULTIPLE)
   Cada uso activo de IA suma 1 punto al IRS (max 3).
   "No utilizo" y "No se si incluye IA" = 0 puntos.
   ============================================================================= */

gen p7b_lower = lower(p7b)

gen p7b_contenido = (strpos(p7b_lower, "generación de contenido")      > 0)
gen p7b_programac = (strpos(p7b_lower, "programación y automatización") > 0)
gen p7b_algoritm  = (strpos(p7b_lower, "publicidad algorítmica")        > 0)

gen p7b_score = p7b_contenido + p7b_programac + p7b_algoritm
label variable p7b_score "p7b - Usos de IA en redes (0-3 pts para IRS)"

drop p7b_lower


/* =============================================================================
   SECCION 5 - INDICE DE REDES SOCIALES (IRS)   Maximo: 14 puntos
   ─────────────────────────────────────────────────────────────────────────────
   C1  P4       Inversion digital          0-1
   C2  P5       FB/IG Ads + TikTok Ads     0-2
   C3  P6       Frecuencia de pauta        0-3
   C4  P7       % ingresos en marketing    0-4
   C5  P8       Descubrimiento via redes   0-1
   C6  P7b      Usos de IA en redes        0-3
   ─────────────────────────────────────────────────────────────────────────────
   Niveles: Bajo 0-4 | Medio 5-9 | Alto 10-14
   ============================================================================= */

gen irs_c1 = p4_n
gen irs_c2 = p5_fbig + p5_tiktok
gen irs_c3 = p6_n
gen irs_c4 = p7_n
gen irs_c5 = p8_redes
gen irs_c6 = p7b_score

label variable irs_c1 "IRS C1: inversion digital (0-1)"
label variable irs_c2 "IRS C2: FB/IG + TikTok Ads (0-2)"
label variable irs_c3 "IRS C3: frecuencia de pauta (0-3)"
label variable irs_c4 "IRS C4: % ingresos marketing (0-4)"
label variable irs_c5 "IRS C5: descubrimiento via redes (0-1)"
label variable irs_c6 "IRS C6: usos de IA en redes (0-3)"

egen IRS = rowtotal(irs_c1 irs_c2 irs_c3 irs_c4 irs_c5 irs_c6), missing
label variable IRS "Indice de Redes Sociales (0-14)"

gen IRS_nivel = .
replace IRS_nivel = 1 if IRS >=  0 & IRS <=  4
replace IRS_nivel = 2 if IRS >=  5 & IRS <=  9
replace IRS_nivel = 3 if IRS >= 10 & IRS <= 14

label define irs_niv 1 "Bajo (0-4)" 2 "Medio (5-9)" 3 "Alto (10-14)"
label values IRS_nivel irs_niv
label variable IRS_nivel "Nivel IRS"

di _newline "── Distribución IRS ──"
tab IRS_nivel, miss
sum IRS, detail


/* =============================================================================
   SECCION 6 - INDICE DE DELIVERY (IDL)   Maximo: 10 puntos
   ─────────────────────────────────────────────────────────────────────────────
   C1  P12c     Usa datos delivery para decisiones     0-2
                (reemplaza Rappi Ads ausente en P5)
   C2  P8       Descubrimiento via delivery             0-2
   C3  P10_n    % ventas delivery (base 10)             0-3
   C4  P12      Canal mas rentable = delivery           0-1
   C5  P12b     Acceso y uso de datos de delivery       0-2
   ─────────────────────────────────────────────────────────────────────────────
   Niveles: Bajo 0-3 | Medio 4-6 | Alto 7-10
   ============================================================================= */

gen idl_c1 = p12c_n
gen idl_c2 = p8_delivery * 2

* C3: umbrales sobre p10_n (escala 0-10)
*     0 clientes = 0%  |  <= 1.4 = <14%  |  1.5-3 = 15-30%  |  > 3 = >30%
gen idl_c3 = .
replace idl_c3 = 0 if p10_n == 0
replace idl_c3 = 1 if p10_n >   0 & p10_n <= 1.4
replace idl_c3 = 2 if p10_n >= 1.5 & p10_n <= 3
replace idl_c3 = 3 if p10_n >   3 & !missing(p10_n)

gen idl_c4 = p12_delivery
gen idl_c5 = p12b_n

label variable idl_c1 "IDL C1: uso datos delivery para decisiones (0-2)"
label variable idl_c2 "IDL C2: descubrimiento via delivery (0-2)"
label variable idl_c3 "IDL C3: % ventas delivery recodificado (0-3)"
label variable idl_c4 "IDL C4: delivery como canal mas rentable (0-1)"
label variable idl_c5 "IDL C5: acceso y uso de datos plataformas (0-2)"

egen IDL = rowtotal(idl_c1 idl_c2 idl_c3 idl_c4 idl_c5), missing
label variable IDL "Indice de Delivery (0-10)"

gen IDL_nivel = .
replace IDL_nivel = 1 if IDL >= 0 & IDL <= 3
replace IDL_nivel = 2 if IDL >= 4 & IDL <= 6
replace IDL_nivel = 3 if IDL >= 7 & IDL <= 10

label define idl_niv 1 "Bajo (0-3)" 2 "Medio (4-6)" 3 "Alto (7-10)"
label values IDL_nivel idl_niv
label variable IDL_nivel "Nivel IDL"

di _newline "── Distribución IDL ──"
tab IDL_nivel, miss
sum IDL, detail


/* =============================================================================
   SECCION 7 - INDICE DE PLATAFORMAS DE OPINION (IPO)   Maximo: 18 puntos
   ─────────────────────────────────────────────────────────────────────────────
   C1  P5         Google Ads                      0-2
   C2  P8         Descubrimiento via Google/Maps   0-2
   C3  obs1       Numero resenas Google Maps       0-3
   C4  obs2       Calificacion Google Maps         0-2
   C5  obs3       Presencia en TripAdvisor         0-1
   C6  obs4       Numero resenas TripAdvisor       0-3
   C7  obs5       Calificacion TripAdvisor         0-2
   C8  P13b       IA en gestion de resenas         0-3
   ─────────────────────────────────────────────────────────────────────────────
   Niveles: Bajo 0-5 | Medio 6-11 | Alto 12-18
   ============================================================================= */

gen ipo_c1 = p5_google * 2
gen ipo_c2 = p8_google * 2

* C3: resenas Google Maps
gen ipo_c3 = .
replace ipo_c3 = 0 if obs1 <   50 & !missing(obs1)
replace ipo_c3 = 1 if obs1 >=  50 & obs1 <=  99
replace ipo_c3 = 2 if obs1 >= 100 & obs1 <= 200
replace ipo_c3 = 3 if obs1 >  200 & !missing(obs1)

* C4: calificacion Google Maps
gen ipo_c4 = .
replace ipo_c4 = 0 if obs2 <  4.0 & !missing(obs2)
replace ipo_c4 = 1 if obs2 >= 4.0 & obs2 < 4.5
replace ipo_c4 = 2 if obs2 >= 4.5 & !missing(obs2)

* C5: presencia TripAdvisor
gen ipo_c5 = obs3

* C6: resenas TripAdvisor (obs4 llega como string)
destring obs4, replace force

gen ipo_c6 = .
replace ipo_c6 = 0 if obs3 == 0
replace ipo_c6 = 0 if obs4 <  10  & !missing(obs4) & obs3 == 1
replace ipo_c6 = 1 if obs4 >= 10  & obs4 <=  49    & obs3 == 1
replace ipo_c6 = 2 if obs4 >= 50  & obs4 <= 100    & obs3 == 1
replace ipo_c6 = 3 if obs4 >  100 & !missing(obs4) & obs3 == 1

* C7: calificacion TripAdvisor
gen ipo_c7 = .
replace ipo_c7 = 0 if obs3 == 0
replace ipo_c7 = 0 if missing(obs5)              & obs3 == 1
replace ipo_c7 = 0 if obs5 <  4.0               & !missing(obs5) & obs3 == 1
replace ipo_c7 = 1 if obs5 >= 4.0 & obs5 < 4.5  & !missing(obs5) & obs3 == 1
replace ipo_c7 = 2 if obs5 >= 4.5               & !missing(obs5) & obs3 == 1

* C8: IA en gestion de resenas
gen ipo_c8 = p13b_n

label variable ipo_c1 "IPO C1: Google Ads (0-2)"
label variable ipo_c2 "IPO C2: descubrimiento via Google/Maps (0-2)"
label variable ipo_c3 "IPO C3: resenas Google Maps (0-3)"
label variable ipo_c4 "IPO C4: calificacion Google Maps (0-2)"
label variable ipo_c5 "IPO C5: presencia TripAdvisor (0-1)"
label variable ipo_c6 "IPO C6: resenas TripAdvisor (0-3)"
label variable ipo_c7 "IPO C7: calificacion TripAdvisor (0-2)"
label variable ipo_c8 "IPO C8: IA en gestion de resenas (0-3)"

egen IPO = rowtotal(ipo_c1 ipo_c2 ipo_c3 ipo_c4 ipo_c5 ipo_c6 ipo_c7 ipo_c8), missing
label variable IPO "Indice de Plataformas de Opinion (0-18)"

gen IPO_nivel = .
replace IPO_nivel = 1 if IPO >=  0 & IPO <=  5
replace IPO_nivel = 2 if IPO >=  6 & IPO <= 11
replace IPO_nivel = 3 if IPO >= 12 & IPO <= 18

label define ipo_niv 1 "Bajo (0-5)" 2 "Medio (6-11)" 3 "Alto (12-18)"
label values IPO_nivel ipo_niv
label variable IPO_nivel "Nivel IPO"

di _newline "── Distribución IPO ──"
tab IPO_nivel, miss
sum IPO, detail


/* =============================================================================
   SECCION 8 - INDICADOR TRANSVERSAL DE MADUREZ EN IA
   ============================================================================= */

gen p7c_lower = lower(p7c)

gen ia_chatgpt  = (strpos(p7c_lower, "chatgpt")    > 0)
gen ia_claude   = (strpos(p7c_lower, "claude")     > 0)
gen ia_gemini   = (strpos(p7c_lower, "gemini")     > 0)
gen ia_deepseek = (strpos(p7c_lower, "deepseek")   > 0)
gen ia_copilot  = (strpos(p7c_lower, "copilot")    > 0)
gen ia_integrad = (strpos(p7c_lower, "canva")      > 0 | ///
                   strpos(p7c_lower, "meta ai")    > 0 | ///
                   strpos(p7c_lower, "integradas") > 0)

gen ia_negocio = ia_chatgpt + ia_claude + ia_gemini + ia_deepseek + ia_copilot + ia_integrad
label variable ia_negocio "IA en administracion del negocio (numero herramientas, p7c)"
drop p7c_lower

* Dummy global: adopta algun tipo de IA en cualquier eje
gen ia_adopta = (p7b_score > 0 | ia_negocio > 0 | p13b_n >= 2)
replace ia_adopta = . if missing(p7b_score) & missing(ia_negocio) & missing(p13b_n)

label values  ia_adopta sino_lbl
label variable ia_adopta "Adopta alguna herramienta de IA (dummy)"

tab ia_adopta


/* =============================================================================
   SECCION 9 - ESTADISTICA DESCRIPTIVA POR TIPO DE COCINA
   ============================================================================= */

di _newline(2) "════════ MEDIAS DE INDICES POR TIPO DE COCINA ════════"

table p0a_n, statistic(mean IRS IDL IPO) ///
             statistic(sd   IRS IDL IPO) ///
             nformat(%5.2f)

foreach idx in IRS IDL IPO {
    di _newline "── `idx' nivel por tipo de cocina ──"
    tab p0a_n `idx'_nivel, row nofreq
}

di _newline "── Adopcion de IA por tipo de cocina ──"
tab p0a_n ia_adopta, row nofreq

di _newline "── P18 (IA deseada) x P3b (competitividad percibida) ──"
tab p3b_n p18, row


/* =============================================================================
   SECCION 10 - ORDER, GUARDAR Y EXPORTAR
   ============================================================================= */

order encuesta_si id nombre barrio p0a_n p3_n p3b_n                         ///
      p4_n p5 p5_fbig p5_tiktok p5_google                                   ///
      p6_n p7_n p7b p7b_score p7c ia_negocio                                ///
      p8 p8_google p8_redes p8_delivery                                      ///
      p9_n p10_n p11_n p12_delivery p12b_n p12c_n                           ///
      p13 p13b p13b_n p14 p16 p18                                           ///
      obs1 obs2 obs3 obs4 obs5 tripadvisor_ranking                           ///
      IRS  irs_c1 irs_c2 irs_c3 irs_c4 irs_c5 irs_c6  IRS_nivel            ///
      IDL  idl_c1 idl_c2 idl_c3 idl_c4 idl_c5         IDL_nivel            ///
      IPO  ipo_c1 ipo_c2 ipo_c3 ipo_c4 ipo_c5 ipo_c6 ipo_c7 ipo_c8        ///
           IPO_nivel                                                         ///
      ia_adopta ia_chatgpt ia_claude ia_gemini ia_deepseek ia_copilot       ///
      lat lon direccion

label data "Restaurantes mediterraneos Bogota – indices IRS/IDL/IPO v3"
save "${clean}\base_indices.dta", replace

export excel using "${clean}\tabla_indices.xlsx", ///
    firstrow(varlabels) sheet("Indices") replace

di _newline "✓ base_indices.dta guardada en: ${clean}"
di          "✓ tabla_indices.xlsx exportada en: ${tables}"

/* =============================================================================
   REFERENCIA RAPIDA DE MAXIMOS Y NIVELES DE CORTE
   ─────────────────────────────────────────────────────────────────────────────
   IRS  max 14:  Bajo 0-4   |  Medio 5-9   |  Alto 10-14
   IDL  max 10:  Bajo 0-3   |  Medio 4-6   |  Alto 7-10
   IPO  max 18:  Bajo 0-5   |  Medio 6-11  |  Alto 12-18
   ============================================================================= */
