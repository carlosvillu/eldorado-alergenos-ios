#!/usr/bin/env node
/**
 * extract.mjs — Genera los datos de la app iOS a partir de alergenos.html
 *
 * REGLA: este script es la ÚNICA vía por la que los datos entran en la app.
 * Nada se teclea a mano: se leen los literales del HTML con un parser propio
 * (tools/jsliteral.mjs, sin eval ni Function) y se escriben como JSON.
 * Si la carta cambia en el HTML, se vuelve a ejecutar este script.
 *
 *   node app-ios/tools/extract.mjs
 *
 * Salidas (todas derivadas del HTML):
 *   app-ios/Alergenos/Resources/platos.json
 *   app-ios/Alergenos/Resources/i18n.json
 *   app-ios/Alergenos/Resources/tabla-original-1.webp
 *   app-ios/Alergenos/Resources/tabla-original-2.webp
 *
 * Sale con código ≠ 0 si los conteos no cuadran con los esperados.
 */
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { extraeConst } from "./jsliteral.mjs";
import { rutaFuente } from "./fuente.mjs";

const HERE = dirname(fileURLToPath(import.meta.url));
const OUT_DIR = resolve(HERE, "..", "Alergenos", "Resources");

/* Conteos esperados: se comprueban al final para que un cambio silencioso
   en la carta no pase inadvertido a la app.

   NOTA: el set DUDAS de alergenos.html tiene 8 entradas, no 9. El contrato del
   objetivo decía 9 por un recuento mío a ojo; manda el HTML y aquí queda
   corregido y comprobado en cada ejecución. */
const ESPERADO = { alergenos: 14, secciones: 9, platos: 51, dudas: 8 };

const errores = [];
const fail = (msg) => errores.push(msg);
const escribe = (s) => process.stdout.write(`${s}\n`);

/* ── 1. Leer el HTML de la carta ─────────────────────────────────────── */
const HTML_PATH = rutaFuente(process.argv[2]);
const html = readFileSync(HTML_PATH, "utf8");

const scriptStart = html.indexOf("<script>", html.indexOf('id="carta"'));
const scriptEnd = html.indexOf("</script>", scriptStart);
if (scriptStart < 0 || scriptEnd < 0)
  throw new Error("No encuentro el bloque <script> de datos");
let js = html.slice(scriptStart + "<script>".length, scriptEnd);

/* Los datos puros llegan hasta justo antes del primer acceso al DOM.
   A partir de ahí el script es UI y no nos interesa. */
const corte = js.indexOf("const $ = id =>");
if (corte < 0)
  throw new Error("No encuentro el corte 'const $ = id =>' en el script");
js = js.slice(0, corte);

const ALERGENOS = extraeConst(js, "ALERGENOS");
const CARTA = extraeConst(js, "CARTA");
const NOMBRES_EN = extraeConst(js, "NOMBRES_EN");
const TITULOS_EN = extraeConst(js, "TITULOS_EN");
const NOTA_EN = extraeConst(js, "NOTA_EN");
const DUDAS = extraeConst(js, "DUDAS");
const IDIOMAS = extraeConst(js, "IDIOMAS");

/* ── 2. Variables CSS (colores de alérgenos y tema) ──────────────────── */
const styleStart = html.indexOf("<style>");
const styleEnd = html.indexOf("</style>", styleStart);
const css = html.slice(styleStart, styleEnd);

const cssVar = (name) => {
  const m = css.match(new RegExp(`--${name}\\s*:\\s*([^;]+);`));
  return m ? m[1].trim() : null;
};

/* ── 3. Las dos fotos originales (WebP embebidos en el propio HTML) ──── */
const fotos = [
  ...html.matchAll(/data:image\/webp;base64,([A-Za-z0-9+/=]+)"/g),
].map((m) => m[1]);

/* ── 3b. Aviso de procedencia y de revisión pendiente (pie del HTML) ─── */
const pie = /<footer>([\s\S]*?)<\/footer>/.exec(html);
const procedencia = pie
  ? [...pie[1].matchAll(/<p>\s*<b>([^<]+)<\/b>\s*([\s\S]*?)<\/p>/g)].map(
      (m) => ({
        titulo: m[1].replace(/\.\s*$/, ""),
        texto: m[2].replace(/\s+/g, " ").trim(),
      }),
    )
  : [];
if (procedencia.length !== 2)
  fail(
    `Esperaba 2 avisos en el pie del HTML, he encontrado ${procedencia.length}`,
  );

/* ── 4. Utilidades ───────────────────────────────────────────────────── */
const ENTIDADES = {
  "&amp;": "&",
  "&lt;": "<",
  "&gt;": ">",
  "&quot;": '"',
  "&#39;": "'",
  "&nbsp;": " ",
};

/** HTML → texto plano: <br> pasa a salto de línea y el resto de etiquetas
 *  se quitan, conservando el texto literal (sin resumir ni reescribir). */
function aTextoPlano(s) {
  if (typeof s !== "string") return s;
  return s
    .replace(/<br\s*\/?>/gi, "\n")
    .replace(/<[^>]+>/g, "")
    .replace(/&[a-z#0-9]+;/gi, (e) => ENTIDADES[e.toLowerCase()] ?? e);
}

function slug(s) {
  return s
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-|-$/g, "");
}

/** ids estables y únicos: si un nombre se repite en la misma sección,
 *  el segundo pasa a ser "-2". Determinista entre ejecuciones. */
function idsUnicos(nombres) {
  const vistos = new Map();
  return nombres.map((n) => {
    const base = slug(n);
    const veces = (vistos.get(base) ?? 0) + 1;
    vistos.set(base, veces);
    return veces === 1 ? base : `${base}-${veces}`;
  });
}

/* ── 5. Montar platos.json ───────────────────────────────────────────── */
const alergenoIds = ALERGENOS.map((a) => a.id);

for (const a of ALERGENOS) {
  if (!NOMBRES_EN[a.id]) fail(`Falta traducción EN del alérgeno "${a.id}"`);
  if (!cssVar(`al-${a.id}`)) fail(`Falta el color --al-${a.id} en el CSS`);
}

let totalPlatos = 0;
const secciones = CARTA.map((sec) => {
  const tituloEn = TITULOS_EN[sec.titulo];
  if (!tituloEn) fail(`Falta TITULOS_EN para la sección "${sec.titulo}"`);

  const ids = idsUnicos(sec.platos.map(([nombre]) => nombre));
  const platos = sec.platos.map(([nombre, als], i) => {
    totalPlatos++;
    for (const id of als) {
      if (!alergenoIds.includes(id))
        fail(`Plato "${nombre}": alérgeno desconocido "${id}"`);
    }
    const dup = als.filter((id, j) => als.indexOf(id) !== j);
    if (dup.length)
      fail(`Plato "${nombre}": alérgenos duplicados ${dup.join(", ")}`);
    if (als.length === 0) fail(`Plato "${nombre}": sin alérgenos (¿seguro?)`);
    return { id: `${slug(sec.titulo)}-${ids[i]}`, nombre, alergenos: als };
  });

  return {
    id: slug(sec.titulo),
    titulo: sec.titulo,
    tituloEn: tituloEn ?? null,
    nota: sec.nota ? aTextoPlano(sec.nota) : null,
    notaEn: NOTA_EN[sec.titulo] ? aTextoPlano(NOTA_EN[sec.titulo]) : null,
    platos,
  };
});

if (secciones.some((s) => s.nota && !s.notaEn)) {
  fail("Hay una nota de sección sin traducción EN en NOTA_EN");
}

const platosJson = {
  origen: {
    fichero: "alergenos.html",
    descripcion:
      "Transcripción de las dos tablas de alérgenos fotografiadas en el puesto del Restaurante El Dorado.",
    generadoPor: "app-ios/tools/extract.mjs — no editar a mano",
  },
  alergenos: ALERGENOS.map((a) => ({
    id: a.id,
    nombre: a.nombre,
    nombreEn: NOMBRES_EN[a.id] ?? null,
    color: cssVar(`al-${a.id}`),
  })),
  secciones,
  dudas: DUDAS,
  procedencia,
  tema: {
    papel: cssVar("papel"),
    carta: cssVar("carta"),
    tinta: cssVar("tinta"),
    tinta2: cssVar("tinta-2"),
    linea: cssVar("linea"),
    lineaFuerte: cssVar("linea-fuerte"),
    ok: cssVar("ok"),
    okSuave: cssVar("ok-suave"),
    no: cssVar("no"),
    noSuave: cssVar("no-suave"),
  },
};

/* ── 6. Montar i18n.json ─────────────────────────────────────────────── */
const i18n = {};
for (const idioma of ["es", "en"]) {
  const claves = Object.keys(IDIOMAS[idioma]);
  i18n[idioma] = Object.fromEntries(
    claves.map((k) => [k, aTextoPlano(IDIOMAS[idioma][k])]),
  );
}

/* Paridad de claves: si ES tiene una clave que EN no tiene, la app
   mostraría texto en español dentro del modo inglés. */
const faltanEn = Object.keys(i18n.es).filter((k) => !(k in i18n.en));
const sobranEn = Object.keys(i18n.en).filter((k) => !(k in i18n.es));
if (faltanEn.length) fail(`Claves sin traducción EN: ${faltanEn.join(", ")}`);
if (sobranEn.length)
  fail(`Claves EN que no existen en ES: ${sobranEn.join(", ")}`);

/* ── 7. Comprobación de conteos ──────────────────────────────────────── */
const real = {
  alergenos: platosJson.alergenos.length,
  secciones: platosJson.secciones.length,
  platos: totalPlatos,
  dudas: platosJson.dudas.length,
};
for (const [k, v] of Object.entries(ESPERADO)) {
  if (real[k] !== v)
    fail(`Conteo de ${k}: esperaba ${v}, he encontrado ${real[k]}`);
}
if (fotos.length !== 2)
  fail(`Esperaba 2 fotos embebidas, he encontrado ${fotos.length}`);
for (const d of platosJson.dudas) {
  const [sec, plato] = d.split("|");
  const s = secciones.find((x) => x.titulo === sec);
  if (!s) fail(`Duda "${d}": sección inexistente`);
  else if (!s.platos.some((p) => p.nombre === plato))
    fail(`Duda "${d}": plato inexistente`);
}

if (errores.length) {
  process.stderr.write(
    "✗ Extracción abortada:\n  - " + errores.join("\n  - ") + "\n",
  );
  process.exit(1);
}

/* ── 8. Escribir ─────────────────────────────────────────────────────── */
mkdirSync(OUT_DIR, { recursive: true });
writeFileSync(
  join(OUT_DIR, "platos.json"),
  JSON.stringify(platosJson, null, 2) + "\n",
);
writeFileSync(join(OUT_DIR, "i18n.json"), JSON.stringify(i18n, null, 2) + "\n");
fotos.forEach((b64, i) =>
  writeFileSync(
    join(OUT_DIR, `tabla-original-${i + 1}.webp`),
    Buffer.from(b64, "base64"),
  ),
);

escribe("✓ Datos extraídos de la carta original");
escribe(`  origen: ${HTML_PATH}`);
escribe(
  `  alergenos: ${real.alergenos}   secciones: ${real.secciones}   platos: ${real.platos}   dudas: ${real.dudas}`,
);
escribe(
  `  fotos originales: ${fotos.length}   avisos de procedencia: ${procedencia.length}`,
);
escribe(`  → ${join(OUT_DIR, "platos.json")}`);
escribe(`  → ${join(OUT_DIR, "i18n.json")}`);
escribe(
  `  claves i18n: ES ${Object.keys(i18n.es).length} / EN ${Object.keys(i18n.en).length}`,
);
