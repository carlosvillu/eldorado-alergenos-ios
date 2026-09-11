#!/usr/bin/env node
/**
 * capturas.mjs — Saca las capturas de pantalla del resultado de las pruebas de
 * interfaz y las deja con nombre legible, para poder revisarlas a ojo.
 *
 *   node app-ios/tools/capturas.mjs [ruta.xcresult]
 *
 * Por defecto usa app-ios/build/alergenos.xcresult y escribe en
 * app-ios/Capturas/. Es un paso de verificación, no de build: si el fichero de
 * resultados no existe, lo dice y sale con error.
 */
import {
 copyFileSync,
 existsSync,
 mkdirSync,
 readFileSync,
 readdirSync,
 rmSync,
} from "node:fs";
import { execFileSync } from "node:child_process";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { tmpdir } from "node:os";

const HERE = dirname(fileURLToPath(import.meta.url));
const APP = resolve(HERE, "..");
const RESULTADO = process.argv[2]
 ? resolve(process.argv[2])
 : join(APP, "build", "alergenos.xcresult");
const DESTINO = join(APP, "Capturas");
const TEMPORAL = join(tmpdir(), "capturas-alergenos");

const escribe = (s) => process.stdout.write(`${s}\n`);

if (!existsSync(RESULTADO)) {
 process.stderr.write(
  `✗ No existe el resultado de las pruebas: ${RESULTADO}\n` +
   "  Ejecuta antes: xcodebuild ... -resultBundlePath build/alergenos.xcresult test\n",
 );
 process.exit(1);
}

rmSync(TEMPORAL, { recursive: true, force: true });
mkdirSync(TEMPORAL, { recursive: true });

try {
 execFileSync(
  "xcrun",
  [
   "xcresulttool",
   "export",
   "attachments",
   "--path",
   RESULTADO,
   "--output-path",
   TEMPORAL,
  ],
  {
   stdio: ["ignore", "ignore", "pipe"],
  },
 );
} catch (e) {
 process.stderr.write(`✗ No he podido exportar los adjuntos: ${e.message}\n`);
 process.exit(1);
}

let manifiesto;
try {
 manifiesto = JSON.parse(readFileSync(join(TEMPORAL, "manifest.json"), "utf8"));
} catch (e) {
 process.stderr.write(
  `✗ No he podido leer el manifiesto de adjuntos: ${e.message}\n`,
 );
 process.exit(1);
}

/* El manifiesto es un árbol: se recorre buscando pares
   (fichero exportado, nombre legible que le puso la prueba). */
const pares = new Map();
const recorre = (nodo) => {
 if (!nodo || typeof nodo !== "object") return;
 const fichero = nodo.exportedFileName;
 const nombre = nodo.suggestedHumanReadableName;
 if (typeof fichero === "string" && typeof nombre === "string") {
  pares.set(fichero, nombre.replace(/_\d+_[0-9A-F-]+\.png$/i, ".png"));
 }
 for (const valor of Object.values(nodo)) recorre(valor);
};
recorre(manifiesto);

if (pares.size === 0) {
 process.stderr.write(
  "✗ El resultado no trae capturas. ¿Se ejecutaron las pruebas de interfaz?\n",
 );
 process.exit(1);
}

mkdirSync(DESTINO, { recursive: true });
const ordenadas = [...pares.entries()].sort((a, b) => a[1].localeCompare(b[1]));
for (const [fichero, nombre] of ordenadas) {
 copyFileSync(join(TEMPORAL, fichero), join(DESTINO, nombre));
}

escribe(`✓ ${ordenadas.length} capturas en ${DESTINO}`);
for (const [, nombre] of ordenadas) escribe(`  ${nombre}`);
const sobrantes = readdirSync(TEMPORAL).length - ordenadas.length - 1;
if (sobrantes > 0)
 escribe(`  (${sobrantes} adjunto(s) más en el resultado, no son capturas)`);
