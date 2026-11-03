const CONSULTAS = [
  {
    ruta: "/consultas/jugadores-activos-por-equipo",
    titulo: "Jugadores habilitados por equipo",
    pregunta: "¿Cuántos jugadores puede alinear cada equipo en el próximo partido?",
    tecnica: "JOIN + WHERE + GROUP BY",
    columnas: [["Equipo", "equipo"], ["Barrio", "barrio"], ["Jugadores activos", "total_jugadores_activos"]],
  },
  {
    ruta: "/consultas/partidos-por-arbitro",
    titulo: "Partidos dirigidos por árbitro",
    pregunta: "¿Cuántos partidos ya jugados ha dirigido cada árbitro? Sirve para repartir y pagar.",
    tecnica: "JOIN + WHERE + GROUP BY",
    columnas: [["Árbitro", "arbitro"], ["Teléfono", "telefono"], ["Partidos dirigidos", "partidos_dirigidos"]],
  },
  {
    ruta: "/consultas/partidos-por-sede",
    titulo: "Partidos por sede",
    pregunta: "¿Cuántos partidos se juegan en cada sede desde una fecha?",
    tecnica: "JOIN + WHERE + GROUP BY",
    parametro: { nombre: "desde", tipo: "date", valor: "2026-12-01", etiqueta: "Desde" },
    columnas: [["Sede", "sede"], ["Dirección", "direccion"], ["Partidos", "total_partidos"]],
  },
  {
    ruta: "/consultas/llave",
    titulo: "Camino en la llave eliminatoria",
    pregunta: "¿A qué semifinal y a qué final lleva cada partido de cuartos?",
    tecnica: "Self-join sobre la relación recursiva",
    columnas: [["Cuartos", "partido_cuartos"], ["Fecha", "fecha_cuartos"], ["Semifinal", "pasa_a_semifinal"],
               ["Fecha semifinal", "fecha_semifinal"], ["Final", "pasa_a_final"], ["Sede de la final", "sede_final"]],
  },
  {
    ruta: "/consultas/resumen-equipos",
    titulo: "Resumen de equipos",
    pregunta: "¿Cuántos jugadores activos, lesionados y suspendidos tiene cada equipo?",
    tecnica: "Vista vista_resumen_equipos",
    columnas: [["Equipo", "equipo"], ["Jugadores", "total_jugadores"], ["Activos", "activos"], ["Lesionados", "lesionados"],
               ["Suspendidos", "suspendidos"], ["Partidos", "partidos_asignados"]],
  },
];

function pantallaConsultas() {
  document.getElementById("acciones-barra").innerHTML = "";
  const cont = document.getElementById("contenido");
  cont.innerHTML = CONSULTAS.map((c, i) => `
    <section class="tarjeta">
      <div class="tarjeta-cabecera">
        <div><h2>${c.titulo} <span class="insignia gris">${c.tecnica}</span></h2><p>${c.pregunta}</p></div>
        <div class="filtros">
          ${c.parametro ? `${c.parametro.etiqueta} <input id="param-${i}" type="${c.parametro.tipo}" value="${c.parametro.valor}">` : ""}
          <button data-consulta="${i}">Consultar</button>
        </div>
      </div>
      <div id="resultado-${i}" class="tabla-cont"></div>
    </section>`).join("");
  cont.querySelectorAll("[data-consulta]").forEach((b) => b.addEventListener("click", () => ejecutarConsulta(Number(b.dataset.consulta))));
}

async function ejecutarConsulta(i) {
  const c = CONSULTAS[i];
  const caja = document.getElementById(`resultado-${i}`);
  caja.innerHTML = `<p class="cargando">Consultando…</p>`;
  try {
    let ruta = c.ruta;
    if (c.parametro) ruta += `?${c.parametro.nombre}=${encodeURIComponent(document.getElementById(`param-${i}`).value)}`;
    const filas = await api("GET", ruta);
    caja.innerHTML = filas.length
      ? `<table><thead><tr>${c.columnas.map(([t]) => `<th>${t}</th>`).join("")}</tr></thead>
         <tbody>${filas.map((f) => `<tr>${c.columnas.map(([, k]) => `<td>${esc(f[k])}</td>`).join("")}</tr>`).join("")}</tbody></table>`
      : estadoVacio("La consulta no devolvió resultados.");
  } catch (e) {
    caja.innerHTML = estadoError(e);
  }
}
