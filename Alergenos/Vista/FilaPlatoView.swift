import SwiftUI

/// Una fila de la carta: el plato, su sello y los alérgenos que declara.
/// Los alérgenos marcados por quien consulta se destacan sobre el resto.
struct FilaPlatoView: View {
    let item: PlatoEnCarta
    let carta: Carta
    let textos: Textos
    let idioma: Idioma
    let paleta: Paleta
    let seleccion: Set<String>
    let esDuda: Bool
    let alTocar: () -> Void

    private var evaluacion: Evaluacion {
        Aptitud.evalua(plato: item.plato, seleccion: seleccion)
    }

    var body: some View {
        Button(action: alTocar) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(item.plato.nombre)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(paleta.tinta)
                        .multilineTextAlignment(.leading)
                    Sello(estado: evaluacion.estado, textos: textos, idioma: idioma, paleta: paleta)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(paleta.tinta2)
                }

                if esDuda {
                    Text(textos.texto(.preguntar, idioma))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(paleta.tinta)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(paleta.linea.opacity(0.6)))
                        .overlay(Capsule().stroke(paleta.lineaFuerte, lineWidth: 1))
                }

                FlujoAlergenos(
                    ids: item.plato.alergenos,
                    carta: carta,
                    idioma: idioma,
                    marcados: seleccion
                )
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(fondo)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(borde, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("plato-\(item.plato.id)")
        .accessibilityHint(Text(TextosApp.plato.texto(idioma)))
    }

    /// El fondo y el borde cuentan lo mismo que el sello: verde si es apto,
    /// rojo si no, papel si todavía no se ha marcado nada.
    private var fondo: Color {
        switch evaluacion.estado {
        case .sinEvaluar: return paleta.carta
        case .apto: return paleta.okSuave
        case .noApto: return paleta.noSuave
        }
    }

    private var borde: Color {
        switch evaluacion.estado {
        case .sinEvaluar: return paleta.linea
        case .apto: return paleta.ok.opacity(0.55)
        case .noApto: return paleta.no.opacity(0.55)
        }
    }
}

/// Lista de alérgenos que se reparte en varias líneas, como la web.
struct FlujoAlergenos: View {
    let ids: [String]
    let carta: Carta
    let idioma: Idioma
    var marcados: Set<String> = []
    var compacto: Bool = true

    var body: some View {
        // Un «flow» sencillo: se agrupan en filas de dos o tres según el ancho
        // disponible. No hace falta un layout a medida para 14 etiquetas.
        let filas = reparto(ids.count)
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(filas.enumerated()), id: \.offset) { _, rango in
                HStack(spacing: 6) {
                    ForEach(rango, id: \.self) { indice in
                        if let alergeno = carta.alergeno(ids[indice]) {
                            ChipAlergeno(
                                alergeno: alergeno,
                                idioma: idioma,
                                marcado: marcados.contains(alergeno.id),
                                compacto: compacto
                            )
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    /// Reparte los índices en filas de tres.
    private func reparto(_ total: Int) -> [[Int]] {
        stride(from: 0, to: total, by: 3).map { inicio in
            Array(inicio..<min(inicio + 3, total))
        }
    }
}
