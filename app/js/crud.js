const esc = (v) => String(v ?? "").replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]));

const COLORES = ["#0f766e", "#175cd3", "#b54708", "#7a5af8", "#c11574", "#027a48", "#b42318", "#344054"];
function avatar(texto) {
  const t = String(texto || "?");
  const iniciales = t.split(" ").filter(Boolean).slice(0, 2).map((p) => p[0]).join("").toUpperCase();
  const color = COLORES[[...t].reduce((s, c) => s + c.charCodeAt(0), 0) % COLORES.length];
  return `<span class="persona"><span class="avatar" style="background:${color}">${esc(iniciales)}</span>${esc(t)}</span>`;
}
function insignia(texto, tono) { return `<span class="insignia ${tono}">${esc(texto)}</span>`; }
const TONO_ESTADO = { activo: "verde", lesionado: "ambar", suspendido: "rojo" };
const TONO_FASE = { Cuartos: "azul", Semifinal: "ambar", Final: "verde" };

const ICONO_ERROR = `<svg viewBox="0 0 24 24"><path d="M12 2 1 21h22zm1 15h-2v-2h2zm0-4h-2V9h2z"/></svg>`;
const ICONO_VACIO = `<svg viewBox="0 0 24 24"><path d="M4 4h16v4H4zm0 6h16v10H4zm4 3v2h8v-2z"/></svg>`;

function estadoError(e) {
  const sinApi = e.status === 0;
  return `<div class="estado-vacio error"><div class="icono">${ICONO_ERROR}</div>
    <h3>${sinApi ? "No se pudo conectar con la API" : "No se pudo cargar la información"}</h3>
    <p>${sinApi ? "Inicia la API con <code>uvicorn main:app --reload</code> dentro de la carpeta <code>api</code> y recarga la página." : esc(e.message)}</p></div>`;
}
function estadoVacio(texto) {
  return `<div class="estado-vacio"><div class="icono">${ICONO_VACIO}</div><h3>Sin registros</h3><p>${esc(texto)}</p></div>`;
}

async function opcionesDe(campo) {

  if (campo.opciones) return campo.opciones.map((o) => ({ valor: o, texto: o }));
  const filas = await api("GET", campo.desde);
  return filas.map((f) => ({ valor: f[campo.valorDe], texto: campo.textoDe(f) }));
}

async function pantallaCrud(cfg) {
  document.getElementById("acciones-barra").innerHTML = `<button id="btn-nuevo">+ Nuevo ${cfg.singular}</button>`;
  document.getElementById("btn-nuevo").addEventListener("click", () => abrirFormulario(cfg, null));
  const cont = document.getElementById("contenido");
  cont.innerHTML = `
    <section class="tarjeta">
      <div class="tarjeta-cabecera">
        <div><h2>${cfg.titulo}<span class="contador" id="contador">–</span></h2><p>${cfg.descripcion}</p></div>
        ${cfg.filtro ? `<div class="filtros">${cfg.filtro.etiqueta} <select id="filtro"><option value="">Todos</option></select></div>` : ""}
      </div>
      <div id="extra"></div>
      <div id="listado" class="tabla-cont"><p class="cargando">Cargando…</p></div>
    </section>`;

  if (cfg.filtro) {
    try {
      const sel = document.getElementById("filtro");
      (await opcionesDe(cfg.filtro)).forEach((o) => sel.insertAdjacentHTML("beforeend", `<option value="${esc(o.valor)}">${esc(o.texto)}</option>`));
      sel.addEventListener("change", () => cargarListado(cfg));
    } catch {  }
  }
  await cargarListado(cfg);
}

async function cargarListado(cfg) {
  const caja = document.getElementById("listado");
  try {
    let ruta = cfg.ruta;
    const filtro = document.getElementById("filtro");
    if (filtro && filtro.value) ruta += `?${cfg.filtro.parametro}=${encodeURIComponent(filtro.value)}`;
    const filas = await api("GET", ruta);
    document.getElementById("contador").textContent = filas.length;
    if (!filas.length) { caja.innerHTML = estadoVacio(`Todavía no hay ${cfg.titulo.toLowerCase()} registrados.`); return; }
    caja.innerHTML = `
      <table>
        <thead><tr>${cfg.columnas.map((c) => `<th>${c.titulo}</th>`).join("")}<th></th></tr></thead>
        <tbody>${filas.map((f) => `
          <tr>
            ${cfg.columnas.map((c) => `<td class="${c.clase || ""}">${c.html ? c.html(f) : esc(c.valor ? c.valor(f) : f[c.campo])}</td>`).join("")}
            <td class="acciones">
              ${(cfg.accionesExtra || []).map((a) => `<button class="secundario chico" data-extra="${a.id}" data-id="${f[cfg.id]}">${a.texto}</button>`).join("")}
              <button class="secundario chico" data-editar="${f[cfg.id]}">Editar</button>
              <button class="peligro chico" data-borrar="${f[cfg.id]}">Borrar</button>
            </td>
          </tr>`).join("")}
        </tbody>
      </table>`;
    caja.querySelectorAll("[data-editar]").forEach((b) => b.addEventListener("click", () => abrirFormulario(cfg, b.dataset.editar)));
    caja.querySelectorAll("[data-borrar]").forEach((b) => b.addEventListener("click", () => borrar(cfg, b.dataset.borrar)));
    caja.querySelectorAll("[data-extra]").forEach((b) => b.addEventListener("click", () => {
      const accion = cfg.accionesExtra.find((a) => a.id === b.dataset.extra);
      accion.ejecutar(Number(b.dataset.id), filas.find((f) => String(f[cfg.id]) === b.dataset.id));
    }));
  } catch (e) {
    document.getElementById("contador").textContent = "–";
    caja.innerHTML = estadoError(e);
  }
}

function abrirModal(titulo, html) {
  document.getElementById("modal-titulo").textContent = titulo;
  const form = document.getElementById("formulario");
  form.innerHTML = html;
  document.getElementById("modal").classList.remove("oculto");
  return form;
}
function cerrarModal() { document.getElementById("modal").classList.add("oculto"); }
document.getElementById("modal-cerrar").addEventListener("click", cerrarModal);
document.getElementById("modal").addEventListener("click", (ev) => { if (ev.target.id === "modal") cerrarModal(); });
document.addEventListener("keydown", (ev) => { if (ev.key === "Escape") cerrarModal(); });

function mostrarErrorForm(form, texto) {
  let caja = form.querySelector(".error-form");
  if (!caja) { caja = document.createElement("p"); caja.className = "error-form"; form.querySelector(".botones").before(caja); }
  caja.textContent = texto;
}

async function abrirFormulario(cfg, id) {
  try {
    const actual = id ? await api("GET", `${cfg.ruta}/${id}`) : {};
    const campos = await Promise.all(cfg.campos.map(async (c) => {
      const valor = actual[c.nombre] ?? c.porDefecto ?? "";
      const clase = c.ancho ? ' class="ancho"' : "";
      if (c.tipo === "select") {
        const ops = await opcionesDe(c);
        return `<label${clase}>${c.etiqueta}
          <select name="${c.nombre}">
            ${c.opcional ? `<option value="">— Ninguno —</option>` : `<option value="" disabled ${valor === "" ? "selected" : ""}>Selecciona…</option>`}
            ${ops.map((o) => `<option value="${esc(o.valor)}" ${String(o.valor) === String(valor) ? "selected" : ""}>${esc(o.texto)}</option>`).join("")}
          </select></label>`;
      }
      const v = c.tipo === "time" ? String(valor).slice(0, 5) : valor;
      return `<label${clase}>${c.etiqueta}<input name="${c.nombre}" type="${c.tipo || "text"}" value="${esc(v)}" placeholder="${esc(c.ayuda || "")}"></label>`;
    }));
    const form = abrirModal(id ? `Editar ${cfg.singular}` : `Nuevo ${cfg.singular}`, `
      <div class="campos">${campos.join("")}</div>
      <div class="botones">
        <button type="button" class="secundario" id="btn-cancelar">Cancelar</button>
        <button type="submit">${id ? "Guardar cambios" : `Crear ${cfg.singular}`}</button>
      </div>`);
    document.getElementById("btn-cancelar").addEventListener("click", cerrarModal);
    form.onsubmit = (ev) => { ev.preventDefault(); guardar(cfg, id, form); };
    form.querySelector("input, select")?.focus();
  } catch (e) {
    avisar(e.message, "error");
  }
}

function leerFormulario(cfg, form) {
  const datos = {};
  for (const c of cfg.campos) {
    const crudo = (form.elements[c.nombre].value || "").trim();
    if (crudo === "") { datos[c.nombre] = c.opcional ? null : ""; continue; }
    datos[c.nombre] = c.numero ? Number(crudo) : crudo;
  }
  return datos;
}

async function guardar(cfg, id, form) {
  try {
    const datos = leerFormulario(cfg, form);
    if (id) await api("PUT", `${cfg.ruta}/${id}`, datos);
    else await api("POST", cfg.ruta, datos);
    cerrarModal();
    avisar(id ? `${cfg.Singular} actualizado correctamente.` : `${cfg.Singular} creado correctamente.`);
    await cargarListado(cfg);
  } catch (e) {
    mostrarErrorForm(form, e.message);
  }
}

async function borrar(cfg, id) {
  if (!confirm(`¿Seguro que quieres borrar este ${cfg.singular}? Esta acción no se puede deshacer.`)) return;
  try {
    await api("DELETE", `${cfg.ruta}/${id}`);
    avisar(`${cfg.Singular} borrado correctamente.`);
    await cargarListado(cfg);
  } catch (e) {
    avisar(e.message, "error");
  }
}
