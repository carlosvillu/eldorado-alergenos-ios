/**
 * jsliteral.mjs — Parser mínimo de literales JavaScript.
 *
 * Lee el subconjunto que aparece en los datos de alergenos.html:
 *   - arrays            [ "a", "b" ]
 *   - objetos           { id: "gluten", nombre: "Gluten" }
 *   - cadenas           "..." y '...' con escapes
 *   - números, true, false, null
 *   - new Set([ ... ])  → se devuelve como array
 *   - comentarios       /* ... *\/  y  // ...
 *
 * NO ejecuta código: no hay eval ni Function. Un literal que no encaje en la
 * gramática lanza error en vez de ser interpretado a ciegas.
 */

/** @typedef {{ value: unknown, end: number }} Parseo */

const ES_ESPACIO = /\s/;

export class ErrorDeLiteral extends Error {}

/** Parsea el literal que empieza en `pos`. Devuelve valor y posición final. */
export function parseLiteral(src, pos = 0) {
  const i = saltaEspacio(src, pos);
  const c = src[i];

  if (c === undefined) throw new ErrorDeLiteral("Fin inesperado del literal");
  if (c === "[") return parseArray(src, i);
  if (c === "{") return parseObjeto(src, i);
  if (c === '"' || c === "'") return parseCadena(src, i);

  // new Set([...])  /  Set([...])
  const set = /^(?:new\s+)?Set\s*\(/.exec(src.slice(i, i + 12));
  if (set) {
    const abre = src.indexOf("[", i + set[0].length - 1);
    if (abre < 0) throw new ErrorDeLiteral("Set sin corchete de apertura");
    const arr = parseArray(src, abre);
    const cierra = src.indexOf(")", arr.end);
    if (cierra < 0) throw new ErrorDeLiteral("Set sin paréntesis de cierre");
    return { value: arr.value, end: cierra + 1 };
  }

  const resto = src.slice(i);
  const mNum = /^-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?/.exec(resto);
  if (mNum) return { value: Number(mNum[0]), end: i + mNum[0].length };

  for (const [palabra, valor] of [
    ["true", true],
    ["false", false],
    ["null", null],
    ["undefined", null],
  ]) {
    if (
      resto.startsWith(palabra) &&
      !/[\w$]/.test(resto[palabra.length] ?? "")
    ) {
      return { value: valor, end: i + palabra.length };
    }
  }

  throw new ErrorDeLiteral(
    `Literal no reconocido en la posición ${i}: ${JSON.stringify(resto.slice(0, 30))}`,
  );
}

function parseArray(src, i) {
  const out = [];
  i++; // [
  for (;;) {
    i = saltaEspacio(src, i);
    if (src[i] === "]") return { value: out, end: i + 1 };
    if (src[i] === ",") {
      i++;
      continue;
    }
    const item = parseLiteral(src, i);
    out.push(item.value);
    i = saltaEspacio(src, item.end);
    if (src[i] === ",") i++;
    else if (src[i] === "]") return { value: out, end: i + 1 };
    else if (src[i] === undefined) throw new ErrorDeLiteral("Array sin cerrar");
    else throw new ErrorDeLiteral(`Se esperaba "," o "]" en la posición ${i}`);
  }
}

function parseObjeto(src, i) {
  /** @type {Record<string, unknown>} */
  const out = {};
  i++; // {
  for (;;) {
    i = saltaEspacio(src, i);
    if (src[i] === "}") return { value: out, end: i + 1 };
    if (src[i] === ",") {
      i++;
      continue;
    }

    let clave;
    if (src[i] === '"' || src[i] === "'") {
      const k = parseCadena(src, i);
      clave = String(k.value);
      i = k.end;
    } else {
      const m = /^[A-Za-z_$][\w$]*/.exec(src.slice(i));
      if (!m) throw new ErrorDeLiteral(`Clave no válida en la posición ${i}`);
      clave = m[0];
      i += m[0].length;
    }

    i = saltaEspacio(src, i);
    if (src[i] !== ":")
      throw new ErrorDeLiteral(`Se esperaba ":" tras la clave "${clave}"`);
    const valor = parseLiteral(src, i + 1);
    out[clave] = valor.value;
    i = saltaEspacio(src, valor.end);
    if (src[i] === ",") i++;
    else if (src[i] === "}") return { value: out, end: i + 1 };
    else if (src[i] === undefined)
      throw new ErrorDeLiteral(`Objeto sin cerrar (clave "${clave}")`);
    else throw new ErrorDeLiteral(`Se esperaba "," o "}" en la posición ${i}`);
  }
}

function parseCadena(src, i) {
  const comilla = src[i];
  let out = "";
  i++;
  while (i < src.length) {
    const c = src[i];
    if (c === "\\") {
      const esc = src[i + 1];
      const mapa = {
        n: "\n",
        t: "\t",
        r: "\r",
        b: "\b",
        f: "\f",
        v: "\v",
        0: "\0",
      };
      if (esc === "u") {
        const code = src.slice(i + 2, i + 6);
        if (/^[0-9a-fA-F]{4}$/.test(code)) {
          out += String.fromCharCode(parseInt(code, 16));
          i += 6;
          continue;
        }
        throw new ErrorDeLiteral(`Escape \\u no válido en la posición ${i}`);
      }
      if (esc === "x") {
        const code = src.slice(i + 2, i + 4);
        if (/^[0-9a-fA-F]{2}$/.test(code)) {
          out += String.fromCharCode(parseInt(code, 16));
          i += 4;
          continue;
        }
        throw new ErrorDeLiteral(`Escape \\x no válido en la posición ${i}`);
      }
      out += mapa[esc] ?? esc;
      i += 2;
      continue;
    }
    if (c === comilla) return { value: out, end: i + 1 };
    /* El \n literal dentro de una cadena solo es válido en plantillas,
       pero el HTML genera cadenas de una línea: si aparece, se respeta. */
    out += c;
    i++;
  }
  throw new ErrorDeLiteral("Cadena sin cerrar");
}

function saltaEspacio(src, i) {
  for (;;) {
    while (i < src.length && ES_ESPACIO.test(src[i])) i++;
    if (src[i] === "/" && src[i + 1] === "*") {
      const fin = src.indexOf("*/", i + 2);
      if (fin < 0) throw new ErrorDeLiteral("Comentario /* sin cerrar");
      i = fin + 2;
      continue;
    }
    if (src[i] === "/" && src[i + 1] === "/") {
      const fin = src.indexOf("\n", i + 2);
      i = fin < 0 ? src.length : fin + 1;
      continue;
    }
    return i;
  }
}

/**
 * Extrae el valor de `const <nombre> = <literal>;` de un fuente JS.
 * Lanza si la declaración no existe.
 */
export function extraeConst(src, nombre) {
  const m = new RegExp(`(?:^|[\\s;])const\\s+${nombre}\\s*=`).exec(src);
  if (!m) throw new ErrorDeLiteral(`No encuentro "const ${nombre} ="`);
  return parseLiteral(src, m.index + m[0].length).value;
}
