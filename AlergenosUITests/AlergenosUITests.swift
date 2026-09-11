import XCTest

/// Pruebas de interfaz: pulsan la app de verdad en el simulador.
///
/// No sustituyen a las pruebas unitarias: comprueban lo que solo se ve
/// pulsando —que marcar un alérgeno selle los platos, que la búsqueda filtre,
/// que el detalle se abra, que se navegue a las pantallas de apoyo— y dejan
/// una captura de cada pantalla como evidencia para revisarla a ojo.
///
/// El orden importa: los métodos van numerados porque comparten el estado
/// guardado de la app (que es justamente lo que se quiere comprobar).
final class AlergenosUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    // MARK: - Apoyo

    /// Guarda una captura en el resultado de la prueba.
    private func captura(_ nombre: String) {
        let adjunto = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        adjunto.name = nombre
        adjunto.lifetime = .keepAlways
        add(adjunto)
    }

    private func ponEspanol() {
        let es = app.buttons["ES"]
        if es.waitForExistence(timeout: 15), !es.isSelected {
            es.tap()
        }
    }

    /// Deja la selección vacía, venga como venga el estado guardado.
    private func limpiaSeleccion() {
        for etiqueta in ["Quitar selección", "Clear selection"] {
            let boton = app.buttons[etiqueta]
            if boton.exists {
                toca(boton)
                return
            }
        }
    }

    /// Toca un elemento. Si el cálculo de punto de toque falla (pasa con
    /// elementos de barra y con los que están a medias fuera de pantalla),
    /// se toca por coordenada, que es lo que haría un dedo.
    private func toca(_ elemento: XCUIElement) {
        XCTAssertTrue(elemento.waitForExistence(timeout: 10), "No existe el elemento \(elemento)")
        if elemento.isHittable {
            elemento.tap()
        } else {
            elemento.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
    }

    private func fila(_ id: String) -> XCUIElement {
        app.buttons["plato-\(id)"]
    }

    private func abreDestino(_ nombre: String) {
        toca(app.buttons["menu"])
        toca(app.buttons["destino-\(nombre)"])
    }

    private func vuelve() {
        toca(app.navigationBars.buttons.element(boundBy: 0))
    }

    // MARK: - 1. La carta y los sellos

    /// Se usan los alérgenos que se ven sin desplazar el riel (Gluten, Huevos):
    /// el desplazamiento del riel tiene su propia prueba, la 7.
    func test01CartaYSellos() {
        ponEspanol()
        limpiaSeleccion()

        XCTAssertTrue(
            app.staticTexts["contadorBase"].waitForExistence(timeout: 10),
            "Sin alérgenos marcados debe verse el recuento de la carta"
        )
        XCTAssertEqual(app.staticTexts["contadorBase"].label, "51 platos · 9 categorías")
        // Sin nada marcado no se sella nada: ni «apto» ni «no apto».
        XCTAssertFalse(fila("entrantes-croquetas").label.contains("No apto"))
        captura("01-carta-sin-marcar")

        toca(app.buttons["chip-gluten"])
        toca(app.buttons["chip-huevos"])

        XCTAssertTrue(app.buttons["chip-gluten"].isSelected, "El alérgeno queda marcado")
        XCTAssertTrue(app.buttons["chip-huevos"].isSelected)
        XCTAssertEqual(app.staticTexts["contador"].label, "4/51", "4 platos sin gluten ni huevos")

        XCTAssertTrue(
            fila("entrantes-croquetas").label.contains("No apto"),
            "Las croquetas llevan gluten y huevos"
        )
        XCTAssertTrue(
            fila("ensaladas-mixta").label.contains("Apto"),
            "La ensalada mixta solo lleva pescado: es apta para gluten y huevos"
        )
        captura("02-carta-con-sellos")
    }

    // MARK: - 2. Búsqueda

    func test02Busqueda() {
        ponEspanol()
        let buscador = app.textFields["buscador"]
        XCTAssertTrue(buscador.waitForExistence(timeout: 10))
        buscador.tap()
        buscador.typeText("cesar")

        XCTAssertTrue(fila("ensaladas-cesar").waitForExistence(timeout: 5), "Debe encontrar el César")
        XCTAssertFalse(fila("entrantes-croquetas").exists, "El resto de la carta se filtra")
        captura("03-busqueda-cesar")

        toca(app.buttons["borrarBusqueda"])
        XCTAssertTrue(fila("entrantes-croquetas").waitForExistence(timeout: 5), "Al borrar vuelve toda la carta")
    }

    // MARK: - 3. Solo aptos

    func test03SoloAptos() {
        ponEspanol()
        let interruptor = app.switches["soloAptos"]
        XCTAssertTrue(interruptor.waitForExistence(timeout: 10))
        toca(interruptor)

        XCTAssertFalse(fila("entrantes-croquetas").exists, "Con «solo aptos» se oculta lo que no lo es")
        XCTAssertTrue(fila("ensaladas-mixta").exists)
        captura("04-solo-aptos")

        toca(interruptor)
    }

    // MARK: - 4. Detalle del plato

    func test04Detalle() {
        ponEspanol()
        toca(fila("entrantes-croquetas"))

        XCTAssertTrue(
            app.navigationBars["Croquetas"].waitForExistence(timeout: 10),
            "Se abre la ficha del plato"
        )
        captura("05-detalle-croquetas")

        toca(app.buttons["cerrar"])
        XCTAssertTrue(fila("entrantes-croquetas").waitForExistence(timeout: 5))
    }

    // MARK: - 5. Pantallas de apoyo

    func test05PantallasDeApoyo() {
        ponEspanol()

        abreDestino("leyenda")
        XCTAssertTrue(app.navigationBars["Leyenda"].waitForExistence(timeout: 10))
        captura("06-leyenda")
        vuelve()

        abreDestino("tabla")
        XCTAssertTrue(app.navigationBars["Tabla completa"].waitForExistence(timeout: 10))
        XCTAssertGreaterThan(
            app.descendants(matching: .any).matching(identifier: "tabla").count, 0,
            "La rejilla de la tabla está en pantalla"
        )
        captura("07-tabla-completa")
        vuelve()

        abreDestino("procedencia")
        XCTAssertTrue(app.navigationBars["Procedencia"].waitForExistence(timeout: 10))
        XCTAssertTrue(
            app.images["tabla-original-1"].waitForExistence(timeout: 5),
            "La foto original 1 se carga desde el bundle"
        )
        XCTAssertTrue(app.images["tabla-original-2"].exists, "La foto original 2 se carga desde el bundle")
        captura("08-procedencia-y-fotos")
        vuelve()

        abreDestino("misAlergenos")
        XCTAssertTrue(app.navigationBars["Mis alérgenos"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.switches["fila-gluten"].exists, "Los 14 alérgenos con su interruptor")
        XCTAssertTrue(app.switches["fila-sesamo"].exists)
        captura("09-mis-alergenos")
        vuelve()
    }

    // MARK: - 6. Inglés y persistencia entre lanzamientos

    func test06InglesYPersistencia() {
        // Deja una selección conocida por si esta prueba se ejecutara sola.
        let gluten = app.buttons["chip-gluten"]
        XCTAssertTrue(gluten.waitForExistence(timeout: 15))
        if !gluten.isSelected {
            toca(gluten)
        }

        toca(app.buttons["EN"])
        XCTAssertTrue(app.buttons["EN"].isSelected, "El conmutador cambia a inglés")
        captura("10-carta-en-ingles")

        // Cerrar y volver a abrir: lo elegido tiene que seguir ahí.
        app.terminate()
        app.launch()

        XCTAssertTrue(app.buttons["EN"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["EN"].isSelected, "El idioma se conserva entre lanzamientos")
        XCTAssertTrue(app.buttons["chip-gluten"].isSelected, "Los alérgenos marcados se conservan")
        captura("11-tras-relanzar")

        // Se deja en español y sin marcar, como estaba al empezar.
        toca(app.buttons["ES"])
        limpiaSeleccion()
    }

    // MARK: - 7. El riel de alérgenos se desplaza

    /// Los 14 alérgenos no caben de ancho en un móvil: el riel se arrastra.
    /// Esta prueba lo arrastra con el dedo y marca un alérgeno que al principio
    /// no se ve (Lácteos), que es el caso real de quien consulta la carta.
    func test07RielDeAlergenos() {
        ponEspanol()
        limpiaSeleccion()

        let lacteos = app.buttons["chip-lacteos"]
        XCTAssertTrue(lacteos.waitForExistence(timeout: 10))

        // Ojo: preguntar «isHittable» por un elemento que está fuera de la
        // pantalla lanza error en vez de devolver false, así que la
        // comprobación se hace con el marco en coordenadas de la ventana.
        let ancho = app.windows.firstMatch.frame.width
        XCTAssertGreaterThan(
            lacteos.frame.minX, ancho,
            "Al principio Lácteos queda fuera de la pantalla"
        )

        // Se desliza el riel con el dedo, como haría cualquiera.
        let riel = app.scrollViews.containing(.button, identifier: "chip-gluten").firstMatch
        XCTAssertTrue(riel.exists, "El riel de alérgenos es un carril que se desliza")

        var intentos = 0
        while lacteos.frame.minX > ancho && intentos < 6 {
            riel.swipeLeft()
            intentos += 1
        }

        XCTAssertLessThan(
            lacteos.frame.minX, ancho,
            "Tras deslizar el riel, Lácteos ya está en pantalla"
        )
        toca(lacteos)
        XCTAssertTrue(lacteos.isSelected)
        XCTAssertTrue(app.staticTexts["contador"].label.hasSuffix("/51"))
        captura("12-riel-desplazado-con-lacteos")

        // Se desmarca y se deja el riel como estaba.
        toca(lacteos)
        var vueltas = 0
        while app.buttons["chip-gluten"].frame.minX < 0 && vueltas < 6 {
            riel.swipeRight()
            vueltas += 1
        }
        XCTAssertFalse(lacteos.isSelected)
    }
}
