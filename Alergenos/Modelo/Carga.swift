import Foundation

/// Todo lo que la app necesita para pintarse. Si esto existe, no falta nada.
struct DatosApp {
    let carta: Carta
    let textos: Textos
    let tema: Tema
}

enum ErrorDeCarga: LocalizedError {
    case recursoAusente(String)
    case jsonIlegible(String, String)

    var errorDescription: String? {
        switch self {
        case .recursoAusente(let nombre):
            return "No encuentro el recurso «\(nombre)» en la app."
        case .jsonIlegible(let nombre, let detalle):
            return "El fichero «\(nombre)» no se puede leer: \(detalle)"
        }
    }
}

/// Carga de los datos generados por tools/extract.mjs.
///
/// Se lee del bundle en tiempo de ejecución: la app no lleva ningún plato
/// escrito a mano. Si el bundle no trae los JSON, la app lo dice en pantalla
/// en vez de caerse.
enum Carga {
    static func datos(bundle: Bundle = .main) throws -> DatosApp {
        let carta: Carta = try leer("platos", en: bundle)
        let textos: Textos = try leer("i18n", en: bundle)
        return DatosApp(carta: carta, textos: textos, tema: carta.tema)
    }

    static func leer<T: Decodable>(_ nombre: String, en bundle: Bundle) throws -> T {
        guard let url = bundle.url(forResource: nombre, withExtension: "json") else {
            throw ErrorDeCarga.recursoAusente("\(nombre).json")
        }
        do {
            let datos = try Data(contentsOf: url)
            return try JSONDecoder().decode(T.self, from: datos)
        } catch {
            throw ErrorDeCarga.jsonIlegible("\(nombre).json", error.localizedDescription)
        }
    }
}

/// Persistencia entre lanzamientos. Las claves son estables y se pueden
/// comprobar en un test con un UserDefaults de usar y tirar.
///
/// Es una clase, y no una struct, porque es un mango al almacenamiento: se
/// comparte y se muta desde el estado de la app sin copiarse por el camino.
final class Preferencias {
    enum Clave {
        static let idioma = "idioma"
        static let alergenos = "alergenosSeleccionados"
    }

    let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var idioma: Idioma {
        get { Idioma(rawValue: defaults.string(forKey: Clave.idioma) ?? "") ?? .es }
        set { defaults.set(newValue.rawValue, forKey: Clave.idioma) }
    }

    /// Los alérgenos marcados se guardan como lista separada por comas.
    var seleccion: Set<String> {
        get {
            let crudo = defaults.string(forKey: Clave.alergenos) ?? ""
            return Set(crudo.split(separator: ",").map(String.init).filter { !$0.isEmpty })
        }
        set {
            defaults.set(newValue.sorted().joined(separator: ","), forKey: Clave.alergenos)
        }
    }
}
