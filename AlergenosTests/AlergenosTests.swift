import XCTest
@testable import Alergenos

/// Pruebas de la lógica y de los datos. La interfaz no se prueba aquí: se
/// comprueba con capturas reales del simulador.
///
/// Los conteos y los spot-checks de la carta están escritos a mano a propósito:
/// si el extractor o el HTML cambian sin querer, el test falla.
final class AlergenosTests: XCTestCase {

    // MARK: - Apoyo

    private func datos() throws -> DatosApp {
        try Carga.datos(bundle: Bundle(for: AlergenosTests.self))
    }

    private func carta() throws -> Carta {
        try datos().carta
    }

    private func enCarta(_ nombre: String) throws -> PlatoEnCarta {
        let encontrados = try carta().platosEnCarta.filter { $0.plato.nombre == nombre }
        return try XCTUnwrap(encontrados.first, "No existe el plato «\(nombre)»")
    }

    // MARK: - Datos: forma y conteos

    func testConteosDeLaCarta() throws {
        let carta = try carta()
        XCTAssertEqual(carta.alergenos.count, 14, "La tabla del puesto declara 14 alérgenos")
        XCTAssertEqual(carta.secciones.count, 9, "La carta tiene 9 categorías")
        XCTAssertEqual(carta.totalPlatos, 51, "La carta tiene 51 platos")
        XCTAssertEqual(carta.dudas.count, 8, "Hay 8 platos marcados «pregunta en barra»")
        XCTAssertEqual(carta.procedencia.count, 2, "Procedencia y «pendiente de revisión»")
    }

    func testIdsDePlatoUnicosYNombresCompletos() throws {
        let carta = try carta()
        let ids = carta.platosEnCarta.map(\.plato.id)
        XCTAssertEqual(Set(ids).count, ids.count, "Hay ids de plato repetidos")
        for seccion in carta.secciones {
            XCTAssertFalse(seccion.platos.isEmpty, "La sección «\(seccion.titulo)» está vacía")
            for plato in seccion.platos {
                XCTAssertFalse(plato.nombre.isEmpty)
                XCTAssertFalse(plato.alergenos.isEmpty, "«\(plato.nombre)» no declara ningún alérgeno")
            }
        }
    }

    func testTodoAlergenoCitadoExisteEnLaLista() throws {
        let carta = try carta()
        let validos = Set(carta.alergenos.map(\.id))
        for item in carta.platosEnCarta {
            for id in item.plato.alergenos {
                XCTAssertTrue(validos.contains(id), "«\(item.plato.nombre)» cita el alérgeno desconocido «\(id)»")
            }
        }
    }

    func testTodasLasSeccionesTienenTraduccionYNotaTraducida() throws {
        for seccion in try carta().secciones {
            XCTAssertNotNil(seccion.tituloEn, "La sección «\(seccion.titulo)» no tiene título en inglés")
            if seccion.nota != nil {
                XCTAssertNotNil(seccion.notaEn, "La nota de «\(seccion.titulo)» no tiene versión en inglés")
            }
        }
    }

    func testColoresValidosEnTodoElTema() throws {
        let carta = try carta()
        let hex = "^#[0-9A-Fa-f]{6}$"
        for alergeno in carta.alergenos {
            XCTAssertNotNil(alergeno.color.range(of: hex, options: .regularExpression), "Color inválido en «\(alergeno.id)»")
        }
        let tema = carta.tema
        for (nombre, valor) in [
            ("papel", tema.papel), ("carta", tema.carta), ("tinta", tema.tinta), ("tinta2", tema.tinta2),
            ("linea", tema.linea), ("lineaFuerte", tema.lineaFuerte), ("ok", tema.ok),
            ("okSuave", tema.okSuave), ("no", tema.no), ("noSuave", tema.noSuave),
        ] {
            XCTAssertNotNil(valor.range(of: hex, options: .regularExpression), "Color de tema inválido: \(nombre)")
        }
    }

    func testAvisosDeProcedenciaDelPie() throws {
        let avisos = try carta().procedencia
        XCTAssertEqual(avisos.map(\.titulo), ["Procedencia", "Pendiente de revisión"])
        for aviso in avisos {
            XCTAssertFalse(aviso.texto.isEmpty)
        }
    }

    // MARK: - Spot-check contra la tabla fotografiada

    func testSpotCheckDeTresPlatos() throws {
        let fingers = try enCarta("Fingers")
        XCTAssertEqual(fingers.plato.alergenos.count, 10)
        XCTAssertEqual(
            Set(fingers.plato.alergenos),
            ["gluten", "crustaceos", "huevos", "pescado", "soja", "apio", "mostaza", "lacteos", "sulfitos", "moluscos"]
        )

        let cesar = try enCarta("César")
        XCTAssertEqual(cesar.plato.alergenos.count, 11)
        XCTAssertTrue(cesar.plato.alergenos.contains("frutos"))
        XCTAssertEqual(cesar.seccion.titulo, "Ensaladas")

        let empanado = try enCarta("Pollo empanado")
        XCTAssertTrue(empanado.plato.alergenos.contains("cacahuetes"), "Es el único plato con cacahuetes")
        XCTAssertEqual(empanado.seccion.titulo, "Hamburguesas")
    }

    func testPlatosRepetidosEntreSeccionesSiguenDistintos() throws {
        let carta = try carta()
        let normales = carta.platosEnCarta.filter { $0.plato.nombre == "Normal" }
        XCTAssertEqual(normales.count, 2, "«Normal» está en Perritos y en Camperos")
        XCTAssertEqual(Set(normales.map(\.plato.id)).count, 2, "Los dos «Normal» deben tener id distinto")
    }

    func testLasDudasApuntanAPlatosQueExisten() throws {
        let carta = try carta()
        for duda in carta.dudas {
            let partes = duda.split(separator: "|", maxSplits: 1).map(String.init)
            XCTAssertEqual(partes.count, 2, "Clave de duda mal formada: \(duda)")
            let seccion = carta.secciones.first { $0.titulo == partes[0] }
            XCTAssertNotNil(seccion, "La duda «\(duda)» apunta a una sección inexistente")
            XCTAssertTrue(
                seccion?.platos.contains { $0.nombre == partes[1] } ?? false,
                "La duda «\(duda)» apunta a un plato inexistente"
            )
            XCTAssertTrue(carta.esDuda(seccion: seccion!, plato: seccion!.platos.first { $0.nombre == partes[1] }!))
        }
    }

    func testLaNotaDePatatasFritasSigueAhi() throws {
        let seccion = try XCTUnwrap(try carta().secciones.first { $0.titulo == "Patatas fritas" })
        let nota = try XCTUnwrap(seccion.nota)
        XCTAssertTrue(nota.contains("sin gluten"), "La nota original avisa de consultar sin gluten")
        XCTAssertNotNil(seccion.notaEn)
    }

    // MARK: - Búsqueda

    func testNormalizaQuitaAcentosYMayusculas() {
        XCTAssertEqual(Aptitud.normaliza("César"), "cesar")
        XCTAssertEqual(Aptitud.normaliza("CACAHUETES"), "cacahuetes")
        XCTAssertEqual(Aptitud.normaliza("Frutos de cáscara"), "frutos de cascara")
        XCTAssertEqual(Aptitud.normaliza("Sésamo"), "sesamo")
        XCTAssertEqual(Aptitud.normaliza("Tortilla de patatas"), "tortilla de patatas")
    }

    func testBusquedaEncuentraPorNombreYPorSeccion() throws {
        let carta = try carta()
        let porNombre = Filtro(busqueda: "cesar", seleccion: [], soloAptos: false)
        XCTAssertEqual(porNombre.candidatos(carta).map(\.plato.nombre), ["César"])

        // Sin acentos y en mayúsculas también.
        let sinTildes = Filtro(busqueda: "TORTILLA", seleccion: [], soloAptos: false)
        XCTAssertEqual(sinTildes.candidatos(carta).count, 2)

        // La sección también cuenta: «ensalada» aparece en varios nombres.
        let seccion = Filtro(busqueda: "hamburguesas", seleccion: [], soloAptos: false)
        XCTAssertEqual(seccion.candidatos(carta).count, 8, "Los 8 platos de Hamburguesas")

        let nada = Filtro(busqueda: "zzzz", seleccion: [], soloAptos: false)
        XCTAssertTrue(nada.candidatos(carta).isEmpty)
    }

    // MARK: - Aptitud

    func testSinAlergenosMarcadosNoSeSellaNada() throws {
        let croquetas = try enCarta("Croquetas")
        let evaluacion = Aptitud.evalua(plato: croquetas.plato, seleccion: [])
        XCTAssertEqual(evaluacion.estado, .sinEvaluar)
        XCTAssertTrue(evaluacion.lleva.isEmpty)
    }

    func testAptoYNoApto() throws {
        let croquetas = try enCarta("Croquetas")
        XCTAssertEqual(croquetas.plato.alergenos, ["gluten", "huevos", "lacteos"])

        XCTAssertEqual(Aptitud.evalua(plato: croquetas.plato, seleccion: ["soja"]).estado, .apto)

        let conGluten = Aptitud.evalua(plato: croquetas.plato, seleccion: ["gluten"])
        XCTAssertEqual(conGluten.estado, .noApto)
        XCTAssertEqual(conGluten.lleva, ["gluten"])

        let dos = Aptitud.evalua(plato: croquetas.plato, seleccion: ["lacteos", "huevos"])
        XCTAssertEqual(dos.estado, .noApto)
        XCTAssertEqual(dos.lleva, ["huevos", "lacteos"], "El orden es el de la ficha del plato")

        let otro = Aptitud.evalua(plato: croquetas.plato, seleccion: ["cacahuetes"])
        XCTAssertEqual(otro.estado, .apto)
        XCTAssertTrue(otro.lleva.isEmpty)
    }

    func testSoloAptosOcultaLoQueLlevaAlergeno() throws {
        let carta = try carta()
        let seccion = try XCTUnwrap(carta.secciones.first { $0.titulo == "Entrantes" })
        let croquetas = try XCTUnwrap(seccion.platos.first { $0.nombre == "Croquetas" })

        let conGluten = Filtro(busqueda: "", seleccion: ["gluten"], soloAptos: false)
        XCTAssertTrue(conGluten.seMuestra(croquetas, seccion: seccion))

        let soloAptos = Filtro(busqueda: "", seleccion: ["gluten"], soloAptos: true)
        XCTAssertFalse(soloAptos.seMuestra(croquetas, seccion: seccion))

        // Pidiendo solo aptos pero sin nada marcado, no se oculta nada.
        let sinSeleccion = Filtro(busqueda: "", seleccion: [], soloAptos: true)
        XCTAssertTrue(sinSeleccion.seMuestra(croquetas, seccion: seccion))
    }

    func testContadorDeAptos() throws {
        let carta = try carta()
        let celiaco = Filtro(busqueda: "", seleccion: ["gluten"], soloAptos: false)
        let candidatos = celiaco.candidatos(carta)
        XCTAssertEqual(candidatos.count, 51, "Sin búsqueda, todos los platos son candidatos")

        let aptos = celiaco.aptos(carta).map(\.plato.nombre)
        XCTAssertEqual(aptos.count, candidatos.count - candidatos.filter { $0.plato.alergenos.contains("gluten") }.count)
        XCTAssertTrue(aptos.contains("Dorado"), "«Dorado» (frutos, lácteos) sí es apto para celíaco")
        XCTAssertTrue(aptos.contains("Tropical"))
        XCTAssertFalse(
            aptos.contains("César"),
            "«César» lleva gluten: el nombre engaña, la tabla manda"
        )
        XCTAssertFalse(aptos.contains("Croquetas"))
    }

    func testBusquedaConjuntaConAlergenos() throws {
        let carta = try carta()
        let filtro = Filtro(busqueda: "ensalada", seleccion: ["gluten"], soloAptos: true)
        let visibles = filtro.candidatos(carta).filter { filtro.seMuestra($0.plato, seccion: $0.seccion) }
        XCTAssertTrue(visibles.allSatisfy { !$0.plato.alergenos.contains("gluten") })
        XCTAssertTrue(visibles.contains { $0.plato.nombre == "Pollo con ensalada" })
    }

    func testSeccionesVisiblesCasanConSusPlatos() throws {
        let carta = try carta()
        let filtro = Filtro(busqueda: "croquetas", seleccion: [], soloAptos: false)
        let visibles = filtro.seccionesVisibles(carta)
        XCTAssertEqual(visibles.map(\.titulo), ["Entrantes"])
    }

    // MARK: - Textos

    func testTodasLasClavesQueUsaLaAppExistenEnLosDosIdiomas() throws {
        let textos = try datos().textos
        for idioma in Idioma.allCases {
            let diccionario = textos.diccionario(idioma)
            for clave in ClaveTexto.allCases {
                let valor = diccionario[clave.rawValue]
                XCTAssertNotNil(valor, "Falta la clave «\(clave.rawValue)» en \(idioma.rawValue)")
                XCTAssertFalse(valor?.isEmpty ?? true, "La clave «\(clave.rawValue)» está vacía en \(idioma.rawValue)")
            }
        }
    }

    func testLosDosIdiomasTienenLasMismasClaves() throws {
        let textos = try datos().textos
        XCTAssertEqual(Set(textos.es.keys), Set(textos.en.keys), "ES y EN deben cubrir lo mismo")
        XCTAssertFalse(textos.es.isEmpty)
    }

    func testContadorSustituyeLosHuecos() throws {
        let textos = try datos().textos
        let es = textos.contador(platos: 51, categorias: 9, .es)
        XCTAssertFalse(es.contains("{p}"))
        XCTAssertFalse(es.contains("{c}"))
        XCTAssertTrue(es.contains("51"))
        XCTAssertTrue(es.contains("9"))

        let en = textos.contador(platos: 51, categorias: 9, .en)
        XCTAssertNotEqual(es, en, "El contador debe estar traducido")
    }

    func testLasClavesDelJsonSonExactamenteLasQueSeEsperan() throws {
        let textos = try datos().textos
        XCTAssertEqual(Set(textos.es.keys), Set(ClaveTexto.allCases.map(\.rawValue)))
    }

    func testIdiomaPorDefectoEsEspanolYLasEtiquetasSonEsYEn() {
        XCTAssertEqual(Idioma.allCases.map(\.etiqueta), ["ES", "EN"])
        XCTAssertEqual(Idioma.allCases.first, .es)
    }

    func testAvisoDeContaminacionCruzadaEstaPresente() throws {
        let textos = try datos().textos
        let aviso = textos.texto(.avisoTx, .es).lowercased()
        XCTAssertTrue(aviso.contains("freidora"), "El aviso de fritura compartida debe estar")
        XCTAssertTrue(aviso.contains("trazas"))
    }

    // MARK: - Persistencia

    func testPreferenciasGuardanIdiomaYSeleccion() throws {
        let nombre = "pruebas.alergenos.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: nombre))
        defer { defaults.removePersistentDomain(forName: nombre) }

        let prefs = Preferencias(defaults: defaults)
        XCTAssertEqual(prefs.idioma, .es, "Por defecto, español")
        XCTAssertTrue(prefs.seleccion.isEmpty)

        prefs.idioma = .en
        prefs.seleccion = ["gluten", "lacteos"]
        XCTAssertEqual(prefs.idioma, .en)
        XCTAssertEqual(prefs.seleccion, ["gluten", "lacteos"])

        // Un segundo lector (otro lanzamiento) ve lo mismo.
        let otra = Preferencias(defaults: defaults)
        XCTAssertEqual(otra.idioma, .en)
        XCTAssertEqual(otra.seleccion, ["gluten", "lacteos"])
    }

    func testEstadoArrancaConLoGuardadoYDescartaAlergenosQueYaNoExisten() throws {
        let nombre = "pruebas.alergenos.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: nombre))
        defer { defaults.removePersistentDomain(forName: nombre) }

        let prefs = Preferencias(defaults: defaults)
        prefs.idioma = .en
        prefs.seleccion = ["gluten", "inventado"]

        let estado = EstadoApp(prefs: prefs, bundle: Bundle(for: AlergenosTests.self))
        XCTAssertNotNil(estado.datos, "Los datos deben cargar en las pruebas")
        XCTAssertEqual(estado.idioma, .en)
        XCTAssertEqual(estado.seleccion, ["gluten"], "Un alérgeno que ya no está en la carta no se arrastra")
        XCTAssertNil(estado.problema)
    }

    func testAlMarcarYDesmarcarSeGuarda() throws {
        let nombre = "pruebas.alergenos.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: nombre))
        defer { defaults.removePersistentDomain(forName: nombre) }

        let estado = EstadoApp(prefs: Preferencias(defaults: defaults), bundle: Bundle(for: AlergenosTests.self))
        estado.alterna("gluten")
        estado.soloAptos = true
        XCTAssertEqual(Preferencias(defaults: defaults).seleccion, ["gluten"])

        estado.alterna("gluten")
        XCTAssertTrue(Preferencias(defaults: defaults).seleccion.isEmpty)
        XCTAssertFalse(estado.soloAptos, "Sin alérgenos marcados, «solo aptos» no tiene sentido y se apaga")
    }

    // MARK: - Filtro combinado con datos reales

    func testCeliacoEnLaCartaCompleta() throws {
        let carta = try carta()
        let celiaco = Filtro(busqueda: "", seleccion: ["gluten"], soloAptos: true)
        let puedeComer = celiaco.aptos(carta).map(\.plato.nombre)

        XCTAssertFalse(puedeComer.contains("Croquetas"))
        XCTAssertFalse(puedeComer.contains("Serranito pollo o cerdo"), "El pan lleva gluten")
        XCTAssertFalse(puedeComer.contains("César"), "La tabla le pone gluten aunque el nombre no lo diga")
        XCTAssertTrue(puedeComer.contains("Pollo con ensalada"), "Solo lleva pescado")
        XCTAssertTrue(puedeComer.contains("Dorado"))
        XCTAssertEqual(puedeComer.count, 10, "La tabla declara 41 platos con gluten de 51")
        XCTAssertEqual(carta.totalPlatos - puedeComer.count, 41)
    }

    /// Comprobación sobre los datos del puesto: hay un alérgeno de la lista
    /// (el sésamo) que no aparece marcado en ningún plato. No es un fallo de la
    /// app: es lo que dice la tabla transcrita, y conviene que se vea.
    func testRecuentosPorAlergenoEnLaTabla() throws {
        let carta = try carta()
        let platos = carta.platosEnCarta.map(\.plato)
        let recuento = Dictionary(uniqueKeysWithValues: carta.alergenos.map { alergeno in
            (alergeno.id, platos.filter { $0.alergenos.contains(alergeno.id) }.count)
        })

        XCTAssertEqual(recuento["gluten"], 41)
        XCTAssertEqual(recuento["soja"], 42)
        XCTAssertEqual(recuento["cacahuetes"], 1, "Solo el pollo empanado")
        XCTAssertEqual(recuento["altramuces"], 1)
        XCTAssertEqual(recuento["moluscos"], 2)
        XCTAssertEqual(recuento["sesamo"], 0, "La tabla no marca sésamo en ningún plato")
    }

    func testAlergicoATodosLosAlergenosNoPuedeComerNada() throws {
        let carta = try carta()
        let todo = Set(carta.alergenos.map(\.id))
        let filtro = Filtro(busqueda: "", seleccion: todo, soloAptos: true)
        XCTAssertTrue(filtro.aptos(carta).isEmpty)
        XCTAssertTrue(filtro.seccionesVisibles(carta).isEmpty)
    }
}
