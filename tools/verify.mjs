#!/usr/bin/env node
/**
 * verify.mjs — Comprueba INDEPENDIENTEMENTE que el JSON de la app coincide
 * con alergenos.html.
 *
 *   node app-ios/tools/verify.mjs
 *
 * Deliberadamente NO reutiliza tools/jsliteral.mjs: si el parser tuviera un
 * fallo, los dos lados del diff compartirían el error. Aquí los datos se
 * re-derivan del HTML con expresiones regulares sobre el texto crudo, que es
 * un método distinto, y se comparan contra el JSON ya escrito.
 *
 * Sale con código ≠ 0 si hay cualquier diferencia.
 */
import { readFileSync } from "node:fs";
import { createHash } from "node:crypto";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { rutaFuente } from "./fuente.mjs";

const HERE = dirname(fileURLToPath(import.meta.url));
const RES = resolve(HERE, "..", "Alergenos", "Resources");
const HTML_PATH = rutaFuente(process.argv[2]);

/** Lee y parsea un JSON dando un error legible si el fichero falta o está mal formado. */
function leeJson(ruta) {
  let crudo;
  try {
    crudo = readFileSync(ruta, "utf8");
  } catch (e) {
    throw new Error(`No puedo leer ${ruta}: ${e.message}`);
  }
  try {
    return JSON.parse(crudo);
  } catch (e) {
    throw new Error(`JSON inválido en ${ruta}: ${e.message}`);
  }
}

const html = readFileSync(HTML_PATH, "utf8");
const platos = leeJson(join(RES, "platos.json"));
const i18n = leeJson(join(RES, "i18n.json"));

const diferencias = [];
const dif = (msg) => diferencias.push(msg);
const escribe = (s) => process.stdout.write(`${s}\n`);
const escapa = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");

/** Recorta el fuente JS desde `const <desde> =` hasta el siguiente `const <hasta> =`. */
function bloque(desde, hasta) {
  const a = html.indexOf(`const ${desde} =`);
  if (a < 0) throw new Error(`No encuentro "const ${desde} =" en el HTML`);
  const b = html.indexOf(`const ${hasta} =`, a);
  if (b < 0)
    throw new Error(
      `No encuentro "const ${hasta} =" después de "const ${desde} ="`,
    );
  return html.slice(a, b);
}

/** HTML → texto plano, recalculado aquí de forma independiente. */
function textoPlano(s) {
  return s
    .replace(/<br\s*\/?>/gi, "\n")
    .replace(/<[^>]+>/g, "")
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&nbsp;/g, " ");
}

/* ── A. Alérgenos ────────────────────────────────────────────────────── */
const bloqueAlergenos = bloque("ALERGENOS", "CARTA");
const alergenosHtml = [
  ...bloqueAlergenos.matchAll(/\{\s*id:\s*"([^"]+)",\s*nombre:\s*"([^"]+)"/g),
].map((m) => ({
  id: m[1],
  nombre: m[2],
}));

if (alergenosHtml.length !== platos.alergenos.length) {
  dif(
    `Nº de alérgenos: HTML ${alergenosHtml.length} vs JSON ${platos.alergenos.length}`,
  );
}
alergenosHtml.forEach((a, i) => {
  const j = platos.alergenos[i];
  if (!j) return dif(`Alérgeno ${i}: falta en el JSON (${a.id})`);
  if (a.id !== j.id || a.nombre !== j.nombre) {
    dif(
      `Alérgeno ${i}: HTML {${a.id}, ${a.nombre}} vs JSON {${j.id}, ${j.nombre}}`,
    );
  }
  if (!j.nombreEn) dif(`Alérgeno ${a.id}: sin nombreEn`);
  if (!/^#[0-9A-Fa-f]{6}$/.test(j.color ?? ""))
    dif(`Alérgeno ${a.id}: color inválido (${j.color})`);
});

/* ── B. Secciones y platos (regex sobre el texto crudo de CARTA) ─────── */
const bloqueCarta = bloque("CARTA", "NOMBRE");
const cortes = [...bloqueCarta.matchAll(/\{\s*titulo:\s*"([^"]+)"/g)];
const seccionesHtml = cortes.map((m, i) => {
  const inicio = m.index;
  const fin = i + 1 < cortes.length ? cortes[i + 1].index : bloqueCarta.length;
  const trozo = bloqueCarta.slice(inicio, fin);

  const notaM = /nota:\s*"([^"]*)"/.exec(trozo);
  const platosTrozo = trozo.slice(trozo.indexOf("platos:"));
  const platosSec = [
    ...platosTrozo.matchAll(/\[\s*"([^"]+)"\s*,\s*\[([^\]]*)\]\s*\]/g),
  ].map((p) => ({
    nombre: p[1],
    alergenos: [...p[2].matchAll(/"([^"]+)"/g)].map((x) => x[1]),
  }));

  return { titulo: m[1], nota: notaM ? notaM[1] : null, platos: platosSec };
});

if (seccionesHtml.length !== platos.secciones.length) {
  dif(
    `Nº de secciones: HTML ${seccionesHtml.length} vs JSON ${platos.secciones.length}`,
  );
}

let platosHtml = 0;
seccionesHtml.forEach((s, i) => {
  const j = platos.secciones[i];
  if (!j) return dif(`Sección ${i} "${s.titulo}": falta en el JSON`);
  if (s.titulo !== j.titulo)
    dif(`Sección ${i}: HTML "${s.titulo}" vs JSON "${j.titulo}"`);
  if ((s.nota ?? null) !== (j.nota ?? null)) {
    dif(
      `Sección "${s.titulo}": nota distinta.\n    HTML: ${s.nota}\n    JSON: ${j.nota}`,
    );
  }
  if (s.nota && !j.notaEn) dif(`Sección "${s.titulo}": nota sin traducción EN`);

  platosHtml += s.platos.length;
  if (s.platos.length !== j.platos.length) {
    dif(
      `Sección "${s.titulo}": HTML ${s.platos.length} platos vs JSON ${j.platos.length}`,
    );
  }

  s.platos.forEach((p, k) => {
    const jp = j.platos[k];
    if (!jp)
      return dif(`Sección "${s.titulo}": falta el plato ${k} (${p.nombre})`);
    if (p.nombre !== jp.nombre)
      dif(`Plato ${k} de "${s.titulo}": "${p.nombre}" vs "${jp.nombre}"`);
    const a = [...p.alergenos].sort().join(",");
    const b = [...jp.alergenos].sort().join(",");
    if (a !== b)
      dif(
        `Plato "${p.nombre}" (${s.titulo}): alérgenos\n    HTML: ${a}\n    JSON: ${b}`,
      );
    if (!jp.id) dif(`Plato "${p.nombre}": sin id`);
  });
});

const ids = platos.secciones.flatMap((s) => s.platos.map((p) => p.id));
if (new Set(ids).size !== ids.length) {
  const repetidos = ids.filter((id, i) => ids.indexOf(id) !== i);
  dif(`ids de plato repetidos: ${[...new Set(repetidos)].join(", ")}`);
}

/* ── C. DUDAS ("⚠ Pregunta en barra") ────────────────────────────────── */
const bloqueDudas = bloque("DUDAS", "IDIOMAS");
const dudasHtml = [...bloqueDudas.matchAll(/"([^"]+)"/g)].map((m) => m[1]);
if (dudasHtml.join("|") !== platos.dudas.join("|")) {
  dif(
    `DUDAS distintas.\n    HTML: ${dudasHtml.join(", ")}\n    JSON: ${platos.dudas.join(", ")}`,
  );
}
for (const d of platos.dudas) {
  const [sec, plato] = d.split("|");
  if (
    !platos.secciones
      .find((s) => s.titulo === sec)
      ?.platos.some((p) => p.nombre === plato)
  ) {
    dif(`Duda "${d}": apunta a un plato que no existe en el JSON`);
  }
}

/* ── D. i18n: ES y EN por separado ───────────────────────────────────── */
const bloqueIdiomas = bloque("IDIOMAS", "T");
const posEs = bloqueIdiomas.indexOf("es: {");
const posEn = bloqueIdiomas.indexOf("en: {");
if (posEs < 0 || posEn < 0 || posEn < posEs) {
  throw new Error("No puedo separar los bloques es/en dentro de IDIOMAS");
}
const trozos = {
  es: bloqueIdiomas.slice(posEs, posEn),
  en: bloqueIdiomas.slice(posEn),
};
const clavesDe = (t) =>
  [...t.matchAll(/^ {4}([A-Za-z]\w*):/gm)].map((m) => m[1]);
const claves = { es: clavesDe(trozos.es), en: clavesDe(trozos.en) };

for (const k of claves.es)
  if (!claves.en.includes(k))
    dif(`i18n: la clave "${k}" existe en ES pero no en EN`);
for (const k of claves.en)
  if (!claves.es.includes(k))
    dif(`i18n: la clave "${k}" existe en EN pero no en ES`);

for (const idioma of ["es", "en"]) {
  for (const k of claves[idioma]) {
    if (!(k in i18n[idioma]))
      dif(`i18n ${idioma}: falta la clave "${k}" en el JSON`);
  }
  for (const [k, v] of Object.entries(i18n[idioma])) {
    const m = new RegExp(`^ {4}${k}: (["'])([\\s\\S]*?)\\1,?$`, "m").exec(
      trozos[idioma],
    );
    if (!m) {
      dif(`i18n ${idioma}: no encuentro el literal de "${k}" en el HTML`);
      continue;
    }
    const esperado = textoPlano(m[2]);
    if (esperado !== v) {
      dif(
        `i18n ${idioma}.${k}:\n    HTML: ${JSON.stringify(esperado)}\n    JSON: ${JSON.stringify(v)}`,
      );
    }
  }
}

/* ── E. Traducciones de alérgeno / sección / nota (valor a valor) ────── */
const bloqueNombresEn = bloque("NOMBRES_EN", "nombreDe");
for (const a of platos.alergenos) {
  const m = new RegExp(`\\b${a.id}:\\s*"([^"]+)"`).exec(bloqueNombresEn);
  if (!m) dif(`NOMBRES_EN no cubre el alérgeno "${a.id}"`);
  else if (m[1] !== a.nombreEn)
    dif(`nombreEn de "${a.id}": HTML "${m[1]}" vs JSON "${a.nombreEn}"`);
}

const bloqueTitulosEn = bloque("TITULOS_EN", "NOTA_EN");
for (const s of platos.secciones) {
  const m = new RegExp(`"${escapa(s.titulo)}":\\s*"([^"]+)"`).exec(
    bloqueTitulosEn,
  );
  if (!m) dif(`TITULOS_EN no cubre la sección "${s.titulo}"`);
  else if (m[1] !== s.tituloEn)
    dif(`tituloEn de "${s.titulo}": HTML "${m[1]}" vs JSON "${s.tituloEn}"`);
}

const bloqueNotaEn = bloque("NOTA_EN", "DUDAS");
for (const s of platos.secciones.filter((x) => x.nota)) {
  const m = new RegExp(`"${escapa(s.titulo)}":\\s*"([^"]+)"`).exec(
    bloqueNotaEn,
  );
  if (!m) dif(`NOTA_EN no cubre la sección con nota "${s.titulo}"`);
  else if (textoPlano(m[1]) !== s.notaEn) {
    dif(
      `notaEn de "${s.titulo}":\n    HTML: ${JSON.stringify(textoPlano(m[1]))}\n    JSON: ${JSON.stringify(s.notaEn)}`,
    );
  }
}

/* ── F. Las dos fotos originales: byte a byte contra el HTML ─────────── */
const fotosHtml = [
  ...html.matchAll(/data:image\/webp;base64,([A-Za-z0-9+/=]+)"/g),
].map((m) => m[1]);
if (fotosHtml.length !== 2)
  dif(`Esperaba 2 fotos embebidas en el HTML, hay ${fotosHtml.length}`);
const sha = (b) => createHash("sha256").update(b).digest("hex").slice(0, 12);
fotosHtml.forEach((b64, i) => {
  const esperado = Buffer.from(b64, "base64");
  let real;
  try {
    real = readFileSync(join(RES, `tabla-original-${i + 1}.webp`));
  } catch (e) {
    return dif(`Falta tabla-original-${i + 1}.webp: ${e.message}`);
  }
  if (sha(esperado) !== sha(real) || esperado.length !== real.length) {
    dif(
      `tabla-original-${i + 1}.webp no coincide con el HTML (${real.length} vs ${esperado.length} bytes)`,
    );
  }
});

/* ── G. Avisos de procedencia (pie del HTML) ─────────────────────────── */
const pieHtml = /<footer>([\s\S]*?)<\/footer>/.exec(html);
const procedenciaHtml = pieHtml
  ? [...pieHtml[1].matchAll(/<p>\s*<b>([^<]+)<\/b>\s*([\s\S]*?)<\/p>/g)].map(
      (m) => ({
        titulo: m[1].replace(/\.\s*$/, ""),
        texto: m[2].replace(/\s+/g, " ").trim(),
      }),
    )
  : [];
if (procedenciaHtml.length !== 2)
  dif(
    `Esperaba 2 avisos de procedencia en el HTML, hay ${procedenciaHtml.length}`,
  );
if (procedenciaHtml.length !== platos.procedencia.length) {
  dif(
    `Avisos de procedencia: HTML ${procedenciaHtml.length} vs JSON ${platos.procedencia.length}`,
  );
}
procedenciaHtml.forEach((p, i) => {
  const j = platos.procedencia[i];
  if (!j) return dif(`Aviso de procedencia ${i}: falta en el JSON`);
  if (p.titulo !== j.titulo)
    dif(`Aviso ${i}: título "${p.titulo}" vs "${j.titulo}"`);
  if (p.texto !== j.texto) {
    dif(
      `Aviso "${p.titulo}": texto distinto.\n    HTML: ${JSON.stringify(p.texto)}\n    JSON: ${JSON.stringify(j.texto)}`,
    );
  }
});

/* ── H. Spot-check literal contra el HTML ────────────────────────────── */
const spot = ["Fingers", "César", "Pollo empanado"];
const lineas = [];
for (const nombre of spot) {
  const m = new RegExp(`\\["${escapa(nombre)}",\\s*\\[([^\\]]*)\\]\\]`).exec(
    bloqueCarta,
  );
  const j = platos.secciones
    .flatMap((s) => s.platos)
    .filter((p) => p.nombre === nombre);
  if (!m) dif(`Spot-check: "${nombre}" no aparece en el texto del HTML`);
  if (j.length !== 1)
    dif(`Spot-check: "${nombre}" aparece ${j.length} veces en el JSON`);
  if (m && j.length === 1) {
    const htmlSet = [...m[1].matchAll(/"([^"]+)"/g)]
      .map((x) => x[1])
      .sort()
      .join(",");
    const jsonSet = [...j[0].alergenos].sort().join(",");
    if (htmlSet !== jsonSet)
      dif(`Spot-check "${nombre}": ${htmlSet} vs ${jsonSet}`);
    lineas.push(
      `    ${nombre.padEnd(16)} ${j[0].alergenos.length} alérgenos: ${jsonSet}`,
    );
  }
}

/* ── Informe ─────────────────────────────────────────────────────────── */
escribe("Verificación JSON ↔ alergenos.html");
escribe(
  `  alérgenos:   HTML ${alergenosHtml.length} / JSON ${platos.alergenos.length}`,
);
escribe(
  `  secciones:   HTML ${seccionesHtml.length} / JSON ${platos.secciones.length}`,
);
escribe(`  platos:      HTML ${platosHtml} / JSON ${ids.length}`);
escribe(
  `  dudas:       HTML ${dudasHtml.length} / JSON ${platos.dudas.length}`,
);
escribe(`  claves i18n: ES ${claves.es.length} / EN ${claves.en.length}`);
escribe(`  fotos:       ${fotosHtml.length} WebP verificados byte a byte`);
escribe(
  `  avisos pie:  HTML ${procedenciaHtml.length} / JSON ${platos.procedencia.length}`,
);
escribe("  spot-check:");
lineas.forEach(escribe);
escribe(
  `  matriz:      ${platosHtml} platos × ${platos.alergenos.length} alérgenos = ` +
    `${platosHtml * platos.alergenos.length} celdas comparadas (lo que lleva y lo que no)`,
);

if (diferencias.length) {
  process.stderr.write(
    `\n✗ ${diferencias.length} diferencia(s):\n  - ${diferencias.join("\n  - ")}\n`,
  );
  process.exit(1);
}
escribe("\n✓ 0 diferencias entre el HTML y los datos que usa la app");
