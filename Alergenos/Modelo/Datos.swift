import Foundation

// MARK: - Modelo de la carta
//
// Las estructuras reflejan tal cual el JSON que genera tools/extract.mjs a
// partir de alergenos.html. Ningún dato se escribe en el código: si algo no
// viene del JSON, no existe.

/// Un alérgeno de declaración obligatoria (los 14 de la UE).
struct Alergeno: Codable, Identifiable, Hashable {
    let id: String
    let nombre: String
    let nombreEn: String?
    let color: String

    func nombre(idioma: Idioma) -> String {
        switch idioma {
        case .es: return nombre
        case .en: return nombreEn ?? nombre
        }
    }
}

/// Un plato de la carta con los alérgenos que declara la tabla del puesto.
struct Plato: Codable, Identifiable, Hashable {
    let id: String
    let nombre: String
    let alergenos: [String]
}

/// Una sección de la carta (Entrantes, Ensaladas, …).
struct Seccion: Codable, Identifiable, Hashable {
    let id: String
    let titulo: String
    let tituloEn: String?
    let nota: String?
    let notaEn: String?
    let platos: [Plato]

    func titulo(idioma: Idioma) -> String {
        switch idioma {
        case .es: return titulo
        case .en: return tituloEn ?? titulo
        }
    }

    /// Nota de la sección: en «Patatas fritas» avisa de que la tabla original
    /// dice «consultar sin gluten».
    func nota(idioma: Idioma) -> String? {
        switch idioma {
        case .es: return nota
        case .en: return notaEn ?? nota
        }
    }
}

/// Un aviso del pie de la página original (procedencia y revisión pendiente).
struct Aviso: Codable, Hashable, Identifiable {
    let titulo: String
    let texto: String
    var id: String { titulo }
}

/// De dónde salen los datos que muestra la app.
struct Origen: Codable, Hashable {
    let fichero: String
    let descripcion: String
    let generadoPor: String
}

/// Colores de la tabla plastificada, tal cual están en el CSS de la web.
struct Tema: Codable, Hashable {
    let papel: String
    let carta: String
    let tinta: String
    let tinta2: String
    let linea: String
    let lineaFuerte: String
    let ok: String
    let okSuave: String
    let no: String
    let noSuave: String
}

/// La carta completa.
struct Carta: Codable, Hashable {
    let origen: Origen
    let alergenos: [Alergeno]
    let secciones: [Seccion]
    let dudas: [String]
    let procedencia: [Aviso]
    let tema: Tema

    /// Nº de platos de la carta completa.
    var totalPlatos: Int { secciones.reduce(0) { $0 + $1.platos.count } }

    /// Alérgeno por id, para pintar su color y su nombre.
    func alergeno(_ id: String) -> Alergeno? {
        alergenos.first { $0.id == id }
    }

    /// La web marca con «⚠ Pregunta en barra» los platos cuya fritura o plancha
    /// es compartida. La clave es exactamente "Sección|Plato".
    func esDuda(seccion: Seccion, plato: Plato) -> Bool {
        dudas.contains("\(seccion.titulo)|\(plato.nombre)")
    }
}

// MARK: - Identificadores estables para la vista

/// Clave única de un plato dentro de la carta: el id del plato ya es único
/// (sección + nombre), pero la vista necesita además saber a qué sección
/// pertenece para el filtro y las dudas.
struct PlatoEnCarta: Identifiable, Hashable {
    let seccion: Seccion
    let plato: Plato
    var id: String { plato.id }
}

extension Carta {
    /// Todos los platos con su sección, en el orden de la carta.
    var platosEnCarta: [PlatoEnCarta] {
        secciones.flatMap { seccion in
            seccion.platos.map { PlatoEnCarta(seccion: seccion, plato: $0) }
        }
    }
}
