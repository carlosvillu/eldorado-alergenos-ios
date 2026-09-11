import Foundation

/// Textos de las pantallas que NO existen en alergenos.html: «Mis alérgenos»,
/// leyenda, tabla y procedencia.
///
/// Son los ÚNICOS textos escritos a mano en la app. Todo lo demás (títulos,
/// avisos, sellos, notas, nombres de plato y de alérgeno) sale del JSON que
/// genera el extractor desde la web, para que no haya dos versiones de lo mismo.
enum TextosApp: String {
    case misAlergenos
    case leyenda
    case tabla
    case procedencia
    case app
    case plato
    case alergenos
    case cerrar
    case noLoLleva
    case loLleva
    case comoSeLee
    case sinMarcar
    case ayudaSinSeleccion
    case sinTraduccion

    struct Par {
        let es: String
        let en: String
    }

    var par: Par {
        switch self {
        case .misAlergenos:
            return Par(es: "Mis alérgenos", en: "My allergens")
        case .leyenda:
            return Par(es: "Leyenda", en: "Legend")
        case .tabla:
            return Par(es: "Tabla completa", en: "Full chart")
        case .procedencia:
            return Par(es: "Procedencia", en: "Source")
        case .app:
            return Par(es: "Alérgenos", en: "Allergens")
        case .plato:
            return Par(es: "Plato", en: "Dish")
        case .alergenos:
            return Par(es: "alérgenos", en: "allergens")
        case .cerrar:
            return Par(es: "Cerrar", en: "Close")
        case .noLoLleva:
            return Par(es: "no lo lleva", en: "does not contain it")
        case .loLleva:
            return Par(es: "lo lleva", en: "contains it")
        case .comoSeLee:
            return Par(es: "Cómo se lee la tabla", en: "How to read the chart")
        case .sinMarcar:
            return Par(es: "Sin marcar: no se sella nada", en: "Nothing ticked: nothing is stamped")
        case .ayudaSinSeleccion:
            return Par(
                es: "Marca tus alérgenos arriba y cada plato queda sellado como apto o no apto.",
                en: "Tick your allergens above and every dish gets stamped as safe or unsafe."
            )
        case .sinTraduccion:
            return Par(
                es: "Texto original de la página, sin traducir.",
                en: "Original text from the page, not translated."
            )
        }
    }

    func texto(_ idioma: Idioma) -> String {
        switch idioma {
        case .es: return par.es
        case .en: return par.en
        }
    }
}
