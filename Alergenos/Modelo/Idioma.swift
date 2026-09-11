import Foundation

/// Los dos idiomas que trae la web. El idioma se guarda entre lanzamientos.
enum Idioma: String, CaseIterable, Codable, Identifiable {
    case es
    case en

    var id: String { rawValue }

    /// Etiqueta del conmutador, igual que en la web: ES / EN.
    var etiqueta: String { rawValue.uppercased() }
}

/// Textos de interfaz. Las claves son EXACTAMENTE las de `IDIOMAS` en
/// alergenos.html, para que el verificador pueda compararlas una a una.
struct Textos: Codable, Hashable {
    let es: [String: String]
    let en: [String: String]

    func diccionario(_ idioma: Idioma) -> [String: String] {
        switch idioma {
        case .es: return es
        case .en: return en
        }
    }

    /// Texto de una clave. Si faltara en el idioma pedido cae al español y,
    /// en último término, a la propia clave: la app nunca muestra un hueco.
    func texto(_ clave: ClaveTexto, _ idioma: Idioma) -> String {
        let elegido = diccionario(idioma)[clave.rawValue]
        let respaldo = es[clave.rawValue]
        return elegido ?? respaldo ?? clave.rawValue
    }

    /// Sustituye los huecos `{p}` y `{c}` del contador, igual que la web.
    func contador(platos: Int, categorias: Int, _ idioma: Idioma) -> String {
        texto(.contadorBase, idioma)
            .replacingOccurrences(of: "{p}", with: String(platos))
            .replacingOccurrences(of: "{c}", with: String(categorias))
    }
}

/// Claves de texto que usa la app. Si esta lista y el JSON se separan, el test
/// `TextosTests` falla: no se puede publicar una clave que no exista.
enum ClaveTexto: String, CaseIterable {
    case h1
    case ceja
    case sub
    case avisoT
    case avisoTx
    case buscarPh
    case buscarAria
    case rielAria
    case solo
    case limpiar
    case vacioBusqueda
    case vacioFiltro
    case selloSi
    case selloNo
    case preguntar
    case contadorSin
    case contadorBase
    case imprimir
    case tablaNota
    case fotosSum
    case fotosP
}
