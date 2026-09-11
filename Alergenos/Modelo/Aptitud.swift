import Foundation

/// Estado de un plato frente a los alérgenos que ha marcado la persona.
enum EstadoPlato: Equatable {
    /// No hay ningún alérgeno marcado: la app no sella nada.
    case sinEvaluar
    /// No lleva ninguno de los alérgenos marcados.
    case apto
    /// Lleva al menos uno de los alérgenos marcados.
    case noApto
}

/// Resultado de evaluar un plato.
struct Evaluacion: Equatable {
    let estado: EstadoPlato
    /// Alérgenos del plato que están marcados, en el orden de la carta.
    let lleva: [String]
}

/// Reglas puras de la app: sin vistas, sin estado, fáciles de probar.
///
/// Todo lo que hay aquí está cubierto por AlergenosTests: la aptitud de un
/// plato, la normalización de la búsqueda y el filtro combinado. La interfaz
/// que las usa vive en Vista/ y se comprueba con AlergenosUITests.
enum Aptitud {
    /// Normaliza para buscar: minúsculas y sin acentos.
    ///
    /// Es la misma operación que `normaliza()` en alergenos.html
    /// (`toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "")`),
    /// implementada aquí paso a paso para que se pueda comprobar en un test.
    static func normaliza(_ texto: String) -> String {
        let descompuesto = texto.lowercased().decomposedStringWithCanonicalMapping
        let sinTildes = descompuesto.unicodeScalars.filter { !(0x0300...0x036F).contains($0.value) }
        return String(String.UnicodeScalarView(sinTildes))
    }

    /// Regla de la web: un plato es apto si no lleva NINGUNO de los alérgenos
    /// marcados. La ausencia de un alérgeno en la tabla no es una promesa de
    /// seguridad: de eso avisa el aviso de contaminación cruzada.
    ///
    /// Diferencia deliberada con la web: sin nada marcado, la web sella todos
    /// los platos como «Apto». Aquí no se sella nada (`sinEvaluar`), porque
    /// decir «apto» sin saber qué le pasa a quien lo lee es engañoso.
    static func evalua(plato: Plato, seleccion: Set<String>) -> Evaluacion {
        guard !seleccion.isEmpty else {
            return Evaluacion(estado: .sinEvaluar, lleva: [])
        }
        let lleva = plato.alergenos.filter { seleccion.contains($0) }
        return Evaluacion(estado: lleva.isEmpty ? .apto : .noApto, lleva: lleva)
    }

    /// Un plato entra en la búsqueda si el texto está en su nombre o en el
    /// nombre de su sección, sin acentos y sin distinguir mayúsculas.
    static func coincide(nombre: String, seccion: String, busqueda: String) -> Bool {
        let consulta = normaliza(busqueda).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !consulta.isEmpty else { return true }
        return normaliza(nombre).contains(consulta) || normaliza(seccion).contains(consulta)
    }
}

/// Filtro activo: búsqueda + alérgenos marcados + «solo aptos».
struct Filtro: Equatable {
    var busqueda: String = ""
    var seleccion: Set<String> = []
    var soloAptos: Bool = false

    var haySeleccion: Bool { !seleccion.isEmpty }

    /// ¿Se muestra este plato? Misma regla que `pinta()` en la web:
    /// se oculta si no coincide con la búsqueda o si, pidiendo solo aptos,
    /// lleva alguno de los alérgenos marcados.
    func seMuestra(_ plato: Plato, seccion: Seccion) -> Bool {
        guard Aptitud.coincide(nombre: plato.nombre, seccion: seccion.titulo(idioma: .es), busqueda: busqueda) else {
            return false
        }
        guard soloAptos, haySeleccion else { return true }
        return Aptitud.evalua(plato: plato, seleccion: seleccion).lleva.isEmpty
    }

    /// Candidatos = platos que pasan la búsqueda (sin aplicar «solo aptos»).
    /// Es lo que usa el contador de la web: «N/M platos sin: …».
    func candidatos(_ carta: Carta) -> [PlatoEnCarta] {
        carta.platosEnCarta.filter {
            Aptitud.coincide(nombre: $0.plato.nombre, seccion: $0.seccion.titulo(idioma: .es), busqueda: busqueda)
        }
    }

    func aptos(_ carta: Carta) -> [PlatoEnCarta] {
        candidatos(carta).filter { Aptitud.evalua(plato: $0.plato, seleccion: seleccion).lleva.isEmpty }
    }

    /// Secciones que quedan con al menos un plato visible.
    func seccionesVisibles(_ carta: Carta) -> [Seccion] {
        carta.secciones.filter { seccion in
            seccion.platos.contains { seMuestra($0, seccion: seccion) }
        }
    }
}
