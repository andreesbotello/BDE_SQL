# Diccionarios de datos geográficos para el proyecto de automatización

# Mapeo de códigos de provincia a nombres oficiales para las descargas de transporte del CNIG
PROVINCIAS_MAP = {
    "01": "ALAVA", "02": "ALBACETE", "03": "ALICANTE", "04": "ALMERIA", "05": "AVILA",
    "06": "BADAJOZ", "07": "BALEARES", "08": "BARCELONA", "09": "BURGOS", "10": "CACERES",
    "11": "CADIZ", "12": "CASTELLON", "13": "CIUDAD_REAL", "14": "CORDOBA", "15": "CORUNA",
    "16": "CUENCA", "17": "GIRONA", "18": "GRANADA", "19": "GUADALAJARA", "20": "GIPUZKOA",
    "21": "HUELVA", "22": "HUESCA", "23": "JAEN", "24": "LEON", "25": "LLEIDA",
    "26": "LA_RIOJA", "27": "LUGO", "28": "MADRID", "29": "MALAGA", "30": "MURCIA",
    "31": "NAVARRA", "32": "OURENSE", "33": "ASTURIAS", "34": "PALENCIA", "35": "LAS_PALMAS",
    "36": "PONTEVEDRA", "37": "SALAMANCA", "38": "SANTA_CRUZ_DE_TENERIFE", "39": "CANTABRIA", "40": "SEGOVIA",
    "41": "SEVILLA", "42": "SORIA", "43": "TARRAGONA", "44": "TERUEL", "45": "TOLEDO",
    "46": "VALENCIA", "47": "VALLADOLID", "48": "BIZKAIA", "49": "ZAMORA", "50": "ZARAGOZA",
    "51": "CEUTA", "52": "MELILLA"
}

# Mapeo de códigos oficiales de demarcaciones hidrográficas (cuencas) a sus archivos ZIP en el CNIG
CUENCAS_ZIP_MAP = {
    "ES010": "DH_V0_ES010_Minio_Sil.ZIP",
    "ES014": "DH_V0_ES014_Galicia_Costa.ZIP",
    "ES017": "DH_V0_ES017_Cantabrico_Oriental.ZIP",
    "ES018": "DH_V0_ES018_Cantabrico_Occidental.ZIP",
    "ES020": "DH_V0_ES020_Duero.ZIP",
    "ES030": "DH_V0_ES030_Tajo.ZIP",
    "ES040": "DH_V0_ES040_Guadiana.ZIP",
    "ES050": "DH_V0_ES050_Guadalquivir.ZIP",
    "ES060": "DH_V0_ES060_Cuencas_Mediterraneas_Andaluzas.ZIP",
    "ES063": "DH_V0_ES063_Guadalete_Barbate.ZIP",
    "ES064": "DH_V0_ES064_Tinto_Odiel_Piedras.ZIP",
    "ES070": "DH_V0_ES070_Segura.ZIP",
    "ES080": "DH_V0_ES080_Jucar.ZIP",
    "ES091": "DH_V0_ES091_Ebro.ZIP",
    "ES100": "DH_V0_ES100_Cuencas_Internas_Cataluna.ZIP",
    "ES110": "DH_V0_ES110_Baleares.ZIP",
    "ES120": "DH_V0_ES120_Gran_Canaria.ZIP",
    "ES122": "DH_V0_ES122_Fuerteventura.ZIP",
    "ES123": "DH_V0_ES123_Lanzarote.ZIP",
    "ES124": "DH_V0_ES124_Tenerife.ZIP",
    "ES125": "DH_V0_ES125_La_Palma.ZIP",
    "ES126": "DH_V0_ES126_La_Gomera.ZIP",
    "ES127": "DH_V0_ES127_El_Hierro.ZIP",
    "ES150": "DH_V0_ES150_Ceuta.ZIP",
    "ES160": "DH_V0_ES160_Melilla.ZIP"
}

# Mapeo de códigos de provincia (2 dígitos) a comunidades autónomas de SIOSE en el CNIG
PROVINCIA_A_SIOSE_MAP = {
    "01": "Pais_Vasco", "20": "Pais_Vasco", "48": "Pais_Vasco",
    "02": "Castilla_La_Mancha", "13": "Castilla_La_Mancha", "16": "Castilla_La_Mancha", "19": "Castilla_La_Mancha", "45": "Castilla_La_Mancha",
    "03": "Comunidad_Valenciana", "12": "Comunidad_Valenciana", "46": "Comunidad_Valenciana",
    "04": "Andalucia", "11": "Andalucia", "14": "Andalucia", "18": "Andalucia", "21": "Andalucia", "23": "Andalucia", "29": "Andalucia", "41": "Andalucia",
    "05": "Castilla_y_Leon", "09": "Castilla_y_Leon", "24": "Castilla_y_Leon", "34": "Castilla_y_Leon", "37": "Castilla_y_Leon", "40": "Castilla_y_Leon", "42": "Castilla_y_Leon", "47": "Castilla_y_Leon", "49": "Castilla_y_Leon",
    "06": "Extremadura", "10": "Extremadura",
    "07": "Illes_Balears",
    "08": "Cataluna", "17": "Cataluna", "25": "Cataluna", "43": "Cataluna",
    "15": "Galicia", "27": "Galicia", "32": "Galicia", "36": "Galicia",
    "22": "Aragon", "44": "Aragon", "50": "Aragon",
    "26": "La_Rioja",
    "28": "Madrid",
    "30": "Murcia",
    "31": "Navarra",
    "33": "Asturias",
    "35": "Canarias", "38": "Canarias",
    "39": "Cantabria",
    "51": "Ceuta",
    "52": "Melilla"
}
