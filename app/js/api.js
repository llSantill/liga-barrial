// =====================================================================
//  Comunicación con la API (la aplicación NUNCA habla directo con la base)
//  y traducción de los errores a palabras del usuario.
// =====================================================================

// Nombres de los campos para los mensajes de error 422
const NOMBRES_CAMPOS = {
  nombre: "Nombre", barrio: "Barrio", numero_camiseta: "Número de camiseta", telefono: "Teléfono",
  estado: "Estado", id_equipo: "Equipo", direccion: "Dirección", fecha: "Fecha", hora: "Hora",
  resultado: "Resultado", id_sede: "Sede", id_arbitro: "Árbitro", fase: "Fase",
  id_partido_siguiente: "Partido siguiente", id_local: "Equipo local", id_visitante: "Equipo visitante",
};

// Explica en español cada error de validación que devuelve FastAPI (422)
function explicarValidacion(error) {
  const campo = NOMBRES_CAMPOS[error.loc[error.loc.length - 1]] || error.loc[error.loc.length - 1];
  const tipos = {
    missing: "es obligatorio",
    string_too_short: "no puede estar vacío",
    string_too_long: "es demasiado largo",
    less_than_equal: "es demasiado grande",
    greater_than_equal: "es demasiado pequeño",
    string_pattern_mismatch: "no tiene el formato correcto (ejemplo: 2-1)",
    int_parsing: "debe ser un número entero",
    int_type: "debe ser un número entero",
    literal_error: "no es una opción válida",
    date_from_datetime_parsing: "no es una fecha válida",
    date_parsing: "no es una fecha válida",
    time_parsing: "no es una hora válida",
  };
  if (error.type === "less_than_equal" || error.type === "greater_than_equal") {
    if (campo === "Número de camiseta") return `El ${campo.toLowerCase()} debe estar entre 1 y 99.`;
  }
  return `El campo «${campo}» ${tipos[error.type] || "no es válido"}.`;
}

// Convierte cualquier respuesta de error en una frase para el usuario
function mensajeDeError(status, cuerpo) {
  const detalle = cuerpo && cuerpo.detail;
  if (status === 422 && Array.isArray(detalle)) {
    return detalle.map(explicarValidacion).join(" ");
  }
  if (detalle && detalle.mensaje) return detalle.mensaje;      // 404 y 409 ya traen el mensaje
  if (status === 404) return "No encontramos ese registro. Puede que ya lo hayan borrado.";
  if (status === 409) return "La base de datos rechazó la operación.";
  return "Ocurrió un error inesperado en el servidor. Intenta de nuevo.";
}

class ErrorApi extends Error {
  constructor(status, mensaje) { super(mensaje); this.status = status; }
}

// Llamada genérica a la API por HTTP
async function api(metodo, ruta, cuerpo) {
  let respuesta;
  try {
    respuesta = await fetch(API_URL + ruta, {
      method: metodo,
      headers: cuerpo ? { "Content-Type": "application/json" } : {},
      body: cuerpo ? JSON.stringify(cuerpo) : undefined,
    });
  } catch {
    throw new ErrorApi(0, "No hay conexión con la API. Revisa que esté corriendo (uvicorn main:app).");
  }
  const datos = await respuesta.json().catch(() => null);
  if (!respuesta.ok) throw new ErrorApi(respuesta.status, mensajeDeError(respuesta.status, datos));
  return datos;
}

// Avisos en pantalla
function avisar(texto, tipo = "ok") {
  const caja = document.getElementById("aviso");
  caja.textContent = texto;
  caja.className = "aviso " + tipo;
  clearTimeout(avisar.t);
  avisar.t = setTimeout(() => caja.classList.add("oculto"), tipo === "error" ? 9000 : 4000);
}
