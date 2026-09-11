import { existsSync } from "node:fs";
import { dirname, isAbsolute, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

/** Raíz del proyecto de la app: el directorio que contiene `Alergenos/` y `tools/`. */
export const REPO = resolve(dirname(fileURLToPath(import.meta.url)), "..");

/**
 * Localiza `alergenos.html`, el HTML de la carta del que salen TODOS los datos
 * de la app.
 *
 * Ese fichero puede no estar en este repositorio: es la web original del
 * restaurante y se mantiene aparte. Se busca, por este orden:
 *
 *   1. la ruta que se pase como argumento,
 *   2. la variable de entorno `ALERGENOS_HTML`,
 *   3. las ubicaciones habituales: `fuente/alergenos.html` dentro del proyecto
 *      o el HTML en un directorio hermano (como estaba al desarrollar esto).
 *
 * Si no aparece, se para con un mensaje que dice exactamente qué hacer: es
 * preferible eso a generar datos a medias.
 */
export function rutaFuente(argumento) {
  /* Si se indica una ruta a propósito, esa ruta o ninguna: nunca se cae a
     otro fichero parecido. Usar una carta distinta de la que se cree haber
     pasado sería el peor fallo posible en una app de alérgenos. */
  const explicitos = [];
  if (argumento) {
    explicitos.push(isAbsolute(argumento) ? argumento : resolve(process.cwd(), argumento));
  }
  if (process.env.ALERGENOS_HTML) explicitos.push(process.env.ALERGENOS_HTML);

  if (explicitos.length > 0) {
    for (const candidato of explicitos) {
      if (existsSync(candidato)) return resolve(candidato);
    }
    throw new Error(
      "La ruta que me has dado no existe:\n" +
        explicitos.map((c) => `  ${c}`).join("\n") +
        "\n  Sin argumento busco alergenos.html en las ubicaciones habituales."
    );
  }

  const candidatos = [
    join(REPO, "fuente", "alergenos.html"),
    join(REPO, "alergenos.html"),
    join(REPO, "..", "alergenos.html"),
    join(REPO, "..", "..", "alergenos.html"),
  ];

  for (const candidato of candidatos) {
    if (existsSync(candidato)) return resolve(candidato);
  }

  throw new Error(
    "No encuentro alergenos.html, la carta original de la que salen los datos.\n" +
      "  Pásale la ruta:   node tools/extract.mjs /ruta/a/alergenos.html\n" +
      "  o define:         ALERGENOS_HTML=/ruta/a/alergenos.html\n" +
      `  buscado en:       ${candidatos.join(", ")}`
  );
}
