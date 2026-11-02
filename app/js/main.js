// =====================================================================
//  Descripción de cada pantalla, acciones del motor y navegación
// =====================================================================

const EQUIPO_SELECT = { desde: "/equipos", valorDe: "id_equipo", textoDe: (e) => e.nombre };
const fechaCorta = (f) => new Date(f + "T00:00:00").toLocaleDateString("es-CO", { day: "2-digit", month: "short" });

const PANTALLAS = {
  equipos: {
    titulo: "Equipos", singular: "equipo", Singular: "Equipo", ruta: "/equipos", id: "id_equipo",
    descripcion: "Equipos inscritos en el torneo y el barrio que representan.",
    columnas: [
      { titulo: "ID", campo: "id_equipo", clase: "id" },
      { titulo: "Equipo", html: (e) => avatar(e.nombre) },
      { titulo: "Barrio", campo: "barrio" },
    ],
    campos: [
      { nombre: "nombre", etiqueta: "Nombre del equipo", ancho: true },
      { nombre: "barrio", etiqueta: "Barrio", ancho: true },
    ],
    accionesExtra: [
      { id: "plantilla", texto: "Plantilla", ejecutar: verPlantilla },
      { id: "rehabilitar", texto: "Rehabilitar", ejecutar: rehabilitar },
    ],
  },
  jugadores: {
    titulo: "Jugadores", singular: "jugador", Singular: "Jugador", ruta: "/jugadores", id: "id_jugador",
    descripcion: "Plantilla de cada equipo con su número y estado.",
    filtro: { etiqueta: "Equipo", parametro: "id_equipo", ...EQUIPO_SELECT },
    columnas: [
      { titulo: "#", campo: "numero_camiseta", clase: "num" },
      { titulo: "Jugador", html: (j) => avatar(j.nombre) },
      { titulo: "Equipo", campo: "equipo" },
      { titulo: "Estado", html: (j) => insignia(j.estado, TONO_ESTADO[j.estado]) },
      { titulo: "Teléfono", html: (j) => j.telefono ? esc(j.telefono) : `<span class="tenue">—</span>` },
    ],
    campos: [
      { nombre: "nombre", etiqueta: "Nombre completo", ancho: true },
      { nombre: "numero_camiseta", etiqueta: "Número de camiseta", tipo: "number", numero: true },
      { nombre: "estado", etiqueta: "Estado", tipo: "select", opciones: ["activo", "lesionado", "suspendido"], porDefecto: "activo" },
      { nombre: "id_equipo", etiqueta: "Equipo", tipo: "select", numero: true, ...EQUIPO_SELECT },
      { nombre: "telefono", etiqueta: "Teléfono (opcional)", opcional: true },
    ],
  },
  partidos: {
    titulo: "Partidos", singular: "partido", Singular: "Partido", ruta: "/partidos", id: "id_partido",
    descripcion: "Calendario de la llave eliminatoria: cuartos, semifinales y final.",
    columnas: [
      { titulo: "ID", campo: "id_partido", clase: "id" },
      { titulo: "Fase", html: (p) => p.fase ? insignia(p.fase, TONO_FASE[p.fase]) : insignia("Amistoso", "gris") },
      { titulo: "Fecha", clase: "nowrap", html: (p) => `${fechaCorta(p.fecha)} <span class="tenue">· ${String(p.hora).slice(0, 5)}</span>` },
      { titulo: "Encuentro", html: (p) => `<div class="encuentro"><span>${esc(p.local || "Por definir")}</span><span>${esc(p.visitante || "Por definir")}</span></div>` },
      { titulo: "Resultado", html: (p) => p.resultado ? `<b>${esc(p.resultado)}</b>` : insignia("Pendiente", "gris") },
      { titulo: "Sede", campo: "sede" },
      { titulo: "Árbitro", html: (p) => p.arbitro ? esc(p.arbitro) : `<span class="tenue">Sin asignar</span>` },
    ],
    campos: [
      { nombre: "fecha", etiqueta: "Fecha", tipo: "date" },
      { nombre: "hora", etiqueta: "Hora", tipo: "time" },
      { nombre: "id_sede", etiqueta: "Sede", tipo: "select", numero: true, desde: "/sedes", valorDe: "id_sede", textoDe: (s) => s.nombre },
      { nombre: "id_arbitro", etiqueta: "Árbitro", tipo: "select", numero: true, opcional: true, desde: "/arbitros", valorDe: "id_arbitro", textoDe: (a) => a.nombre },
      { nombre: "fase", etiqueta: "Fase", tipo: "select", opcional: true, opciones: ["Cuartos", "Semifinal", "Final"] },
      { nombre: "resultado", etiqueta: "Resultado (opcional)", ayuda: "Ej: 2-1", opcional: true },
      { nombre: "id_partido_siguiente", etiqueta: "Partido siguiente en la llave", tipo: "select", numero: true, opcional: true, ancho: true,
        desde: "/partidos", valorDe: "id_partido", textoDe: (p) => `#${p.id_partido} · ${p.fase || "Amistoso"} · ${p.fecha}` },
    ],
    accionesExtra: [{ id: "asignar", texto: "Equipos", ejecutar: asignarEquipos }],
  },
  sedes: {
    titulo: "Sedes", singular: "sede", Singular: "Sede", ruta: "/sedes", id: "id_sede",
    descripcion: "Canchas y unidades deportivas donde se juegan los partidos.",
    columnas: [{ titulo: "ID", campo: "id_sede", clase: "id" }, { titulo: "Sede", campo: "nombre" }, { titulo: "Dirección", campo: "direccion" }],
    campos: [{ nombre: "nombre", etiqueta: "Nombre", ancho: true }, { nombre: "direccion", etiqueta: "Dirección", ancho: true }],
  },
  arbitros: {
    titulo: "Árbitros", singular: "árbitro", Singular: "Árbitro", ruta: "/arbitros", id: "id_arbitro",
    descripcion: "Árbitros disponibles para dirigir los partidos.",
    columnas: [{ titulo: "ID", campo: "id_arbitro", clase: "id" }, { titulo: "Árbitro", html: (a) => avatar(a.nombre) }, { titulo: "Teléfono", campo: "telefono" }],
    campos: [{ nombre: "nombre", etiqueta: "Nombre completo", ancho: true }, { nombre: "telefono", etiqueta: "Teléfono", ancho: true }],
  },
};

// ---------- Resumen (pantalla de inicio) ----------
async function pantallaResumen() {
  document.getElementById("acciones-barra").innerHTML = "";
  const cont = document.getElementById("contenido");
  cont.innerHTML = `<p class="cargando">Cargando…</p>`;
  try {
    const [resumen, partidos] = await Promise.all([api("GET", "/consultas/resumen-equipos"), api("GET", "/partidos")]);
    const total = resumen.reduce((s, e) => s + Number(e.total_jugadores), 0);
    const activos = resumen.reduce((s, e) => s + Number(e.activos), 0);
    const jugados = partidos.filter((p) => p.resultado).length;
    const proximos = partidos.filter((p) => !p.resultado).slice(0, 5);
    cont.innerHTML = `
      <div class="indicadores">
        <div class="indicador"><span>Equipos</span><b>${resumen.length}</b><small>inscritos</small></div>
        <div class="indicador"><span>Jugadores</span><b>${total}</b><small>${activos} habilitados</small></div>
        <div class="indicador"><span>Partidos</span><b>${partidos.length}</b><small>${jugados} jugados</small></div>
        <div class="indicador"><span>Bajas</span><b>${total - activos}</b><small>lesionados o suspendidos</small></div>
      </div>
      <section class="tarjeta">
        <div class="tarjeta-cabecera"><div><h2>Próximos partidos</h2><p>Partidos sin resultado, en orden de fecha.</p></div></div>
        <div class="tabla-cont">${proximos.length ? `<table><thead><tr><th>Fase</th><th>Fecha</th><th>Encuentro</th><th>Sede</th></tr></thead><tbody>
          ${proximos.map((p) => `<tr><td>${p.fase ? insignia(p.fase, TONO_FASE[p.fase]) : insignia("Amistoso", "gris")}</td>
            <td>${fechaCorta(p.fecha)} <span class="tenue">${String(p.hora).slice(0, 5)}</span></td>
            <td>${esc(p.local || "Por definir")} <span class="tenue">vs</span> ${esc(p.visitante || "Por definir")}</td><td>${esc(p.sede)}</td></tr>`).join("")}
          </tbody></table>` : estadoVacio("No hay partidos pendientes.")}</div>
      </section>
      <section class="tarjeta">
        <div class="tarjeta-cabecera"><div><h2>Estado de las plantillas</h2><p>Desde la vista vista_resumen_equipos.</p></div></div>
        <div class="tabla-cont"><table><thead><tr><th>Equipo</th><th>Barrio</th><th>Jugadores</th><th>Activos</th><th>Lesionados</th><th>Suspendidos</th></tr></thead><tbody>
          ${resumen.map((e) => `<tr><td>${avatar(e.equipo)}</td><td>${esc(e.barrio)}</td><td class="num">${e.total_jugadores}</td>
            <td>${insignia(e.activos, "verde")}</td><td>${insignia(e.lesionados, "ambar")}</td><td>${insignia(e.suspendidos, "rojo")}</td></tr>`).join("")}
        </tbody></table></div>
      </section>`;
  } catch (e) {
    cont.innerHTML = `<section class="tarjeta">${estadoError(e)}</section>`;
  }
}

// ---------- Acciones que usan la lógica del motor (funciones y triggers) ----------
async function verPlantilla(idEquipo, equipo) {
  try {
    const r = await api("GET", `/equipos/${idEquipo}/plantilla`);
    const pct = r.p_total_jugadores ? Math.round((r.p_activos / r.p_total_jugadores) * 100) : 0;
    document.getElementById("extra").innerHTML = `
      <div class="panel-motor">
        <div><b>${esc(equipo.nombre)}</b><br><small>Función obtener_estado_plantilla</small></div>
        <div class="barra-progreso"><i style="width:${pct}%"></i></div>
        <div><b>${r.p_activos}/${r.p_total_jugadores}</b> activos<br>${esc(r.p_disponibilidad)}</div>
      </div>`;
  } catch (e) { avisar(e.message, "error"); }
}

async function rehabilitar(idEquipo, equipo) {
  try {
    const r = await api("POST", `/equipos/${idEquipo}/rehabilitar`);
    avisar(r.p_total_rehabilitados
      ? `Se rehabilitaron ${r.p_total_rehabilitados} jugadores suspendidos de ${equipo.nombre}.`
      : `${equipo.nombre} no tenía jugadores suspendidos.`);
    verPlantilla(idEquipo, equipo);
  } catch (e) { avisar(e.message, "error"); }
}

async function asignarEquipos(idPartido) {
  try {
    const equipos = await api("GET", "/equipos");
    const ops = `<option value="" disabled selected>Selecciona…</option>` + equipos.map((e) => `<option value="${e.id_equipo}">${esc(e.nombre)}</option>`).join("");
    const form = abrirModal(`Asignar equipos al partido #${idPartido}`, `
      <div class="campos">
        <label>Equipo local<select name="id_local">${ops}</select></label>
        <label>Equipo visitante<select name="id_visitante">${ops}</select></label>
      </div>
      <p class="nota">Usa la función asignar_equipos_partido. El trigger trg_validar_max_equipos_partido impide un tercer equipo.</p>
      <div class="botones"><button type="button" class="secundario" id="btn-cancelar">Cancelar</button><button type="submit">Asignar</button></div>`);
    document.getElementById("btn-cancelar").addEventListener("click", cerrarModal);
    form.onsubmit = async (ev) => {
      ev.preventDefault();
      try {
        const r = await api("POST", `/partidos/${idPartido}/equipos`,
          { id_local: Number(form.id_local.value), id_visitante: Number(form.id_visitante.value) });
        cerrarModal();
        avisar(r.mensaje);
        cargarListado(PANTALLAS.partidos);
      } catch (e) { mostrarErrorForm(form, e.message); }
    };
  } catch (e) { avisar(e.message, "error"); }
}

// ---------- Navegación ----------
const TITULOS = { resumen: "Resumen", consultas: "Consultas de negocio" };

function mostrar(vista) {
  document.querySelectorAll("#menu button").forEach((b) => b.classList.toggle("activo", b.dataset.vista === vista));
  const titulo = TITULOS[vista] || PANTALLAS[vista].titulo;
  document.getElementById("titulo-vista").textContent = titulo;
  document.getElementById("miga").textContent = titulo;
  document.getElementById("aviso").classList.add("oculto");
  if (vista === "resumen") pantallaResumen();
  else if (vista === "consultas") pantallaConsultas();
  else pantallaCrud(PANTALLAS[vista]);
}

document.querySelectorAll("#menu button").forEach((b) => b.addEventListener("click", () => mostrar(b.dataset.vista)));

// Indicador de conexión con la API
function revisarApi() {
  const el = document.getElementById("estado-api");
  api("GET", "/")
    .then(() => { el.className = "estado on"; el.innerHTML = "<i></i>API conectada"; })
    .catch(() => { el.className = "estado off"; el.innerHTML = "<i></i>API sin conexión"; });
}
revisarApi();
setInterval(revisarApi, 10000);

mostrar("resumen");
