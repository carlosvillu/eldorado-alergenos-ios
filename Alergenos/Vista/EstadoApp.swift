import Foundation
import Observation

/// Estado único de la app: los datos cargados y lo que ha elegido quien la usa.
///
/// Lo que se guarda entre lanzamientos: los alérgenos marcados y el idioma.
/// «Solo aptos» y la búsqueda son de un vistazo, no se persisten.
@Observable
final class EstadoApp {
    private(set) var datos: DatosApp?
    private(set) var problema: String?

    var idioma: Idioma {
        didSet { prefs.idioma = idioma }
    }

    var seleccion: Set<String> {
        didSet { prefs.seleccion = seleccion }
    }

    var soloAptos = false
    var busqueda = ""

    private let prefs: Preferencias
    private let bundle: Bundle

    init(prefs: Preferencias = Preferencias(), bundle: Bundle = .main) {
        self.prefs = prefs
        self.bundle = bundle
        self.idioma = prefs.idioma
        self.seleccion = prefs.seleccion
        carga()
    }

    /// Lee los JSON del bundle. Si algo falla, se guarda el motivo y la app
    /// muestra una pantalla de problema en lugar de caerse.
    func carga() {
        do {
            let cargados = try Carga.datos(bundle: bundle)
            datos = cargados
            problema = nil
            // Si una versión anterior guardó un alérgeno que ya no existe en la
            // carta, no se arrastra: la selección se recorta a lo que hay.
            let validos = Set(cargados.carta.alergenos.map(\.id))
            seleccion = seleccion.intersection(validos)
        } catch {
            datos = nil
            problema = error.localizedDescription
        }
    }

    func reintenta() {
        carga()
    }

    /// Marca o desmarca un alérgeno.
    func alterna(_ id: String) {
        if seleccion.contains(id) {
            seleccion.remove(id)
        } else {
            seleccion.insert(id)
        }
        if seleccion.isEmpty {
            soloAptos = false
        }
    }

    func limpiaSeleccion() {
        seleccion = []
        soloAptos = false
    }

    /// El filtro que ven las vistas, montado con lo que hay ahora mismo.
    var filtro: Filtro {
        Filtro(busqueda: busqueda, seleccion: seleccion, soloAptos: soloAptos)
    }

    /// Atajo para textos de interfaz.
    func texto(_ clave: ClaveTexto) -> String {
        datos?.textos.texto(clave, idioma) ?? clave.rawValue
    }

    var paleta: Paleta {
        Paleta(tema: datos?.tema ?? Tema.vacio)
    }
}

extension Tema {
    /// Tema de emergencia: solo se usa si los datos no han cargado, para poder
    /// pintar la pantalla de problema sin inventar colores.
    static let vacio = Tema(
        papel: "#F1E8D2",
        carta: "#FBF6E9",
        tinta: "#262219",
        tinta2: "#6B6350",
        linea: "#D9CDAE",
        lineaFuerte: "#B7A87F",
        ok: "#1E6E3F",
        okSuave: "#E4EFE0",
        no: "#B3261E",
        noSuave: "#F7E4E0"
    )
}
