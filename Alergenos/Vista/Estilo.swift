import SwiftUI

// MARK: - Colores de la tabla plastificada

extension Color {
    /// Color a partir del hex del CSS (`#F1E8D2`). Es el mismo valor que usa
    /// la web, así que la app y la página se ven igual.
    init(hex: String, opacidad: Double = 1) {
        let limpio = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")).uppercased()
        var valor: UInt64 = 0
        Scanner(string: limpio).scanHexInt64(&valor)
        let rojo, verde, azul, alfa: Double
        switch limpio.count {
        case 8: // con alfa
            rojo = Double((valor >> 24) & 0xFF) / 255
            verde = Double((valor >> 16) & 0xFF) / 255
            azul = Double((valor >> 8) & 0xFF) / 255
            alfa = Double(valor & 0xFF) / 255
        default: // 6 dígitos
            rojo = Double((valor >> 16) & 0xFF) / 255
            verde = Double((valor >> 8) & 0xFF) / 255
            azul = Double(valor & 0xFF) / 255
            alfa = 1
        }
        self.init(.sRGB, red: rojo, green: verde, blue: azul, opacity: alfa * opacidad)
    }
}

/// Paleta de la app, tomada del JSON (que a su vez la copia del CSS).
struct Paleta {
    let papel: Color
    let carta: Color
    let tinta: Color
    let tinta2: Color
    let linea: Color
    let lineaFuerte: Color
    let ok: Color
    let okSuave: Color
    let no: Color
    let noSuave: Color

    init(tema: Tema) {
        papel = Color(hex: tema.papel)
        carta = Color(hex: tema.carta)
        tinta = Color(hex: tema.tinta)
        tinta2 = Color(hex: tema.tinta2)
        linea = Color(hex: tema.linea)
        lineaFuerte = Color(hex: tema.lineaFuerte)
        ok = Color(hex: tema.ok)
        okSuave = Color(hex: tema.okSuave)
        no = Color(hex: tema.no)
        noSuave = Color(hex: tema.noSuave)
    }
}

extension Color {
    /// Color de un alérgeno. Si el id no estuviera en la carta, tinta neutra.
    static func deAlergeno(_ id: String, en carta: Carta) -> Color {
        guard let hex = carta.alergeno(id)?.color else { return .gray }
        return Color(hex: hex)
    }
}

// MARK: - Piezas repetidas

/// Punto de color + nombre del alérgeno: la unidad mínima de la tabla.
struct ChipAlergeno: View {
    let alergeno: Alergeno
    let idioma: Idioma
    var marcado: Bool = false
    var compacto: Bool = false

    var body: some View {
        HStack(spacing: compacto ? 3 : 6) {
            Circle()
                .fill(Color(hex: alergeno.color))
                .frame(width: compacto ? 8 : 11, height: compacto ? 8 : 11)
            Text(alergeno.nombre(idioma: idioma))
                .font(compacto ? .caption2 : .caption)
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, compacto ? 5 : 9)
        .padding(.vertical, compacto ? 2 : 5)
        .background(
            RoundedRectangle(cornerRadius: compacto ? 5 : 8, style: .continuous)
                .fill(marcado ? Color(hex: alergeno.color).opacity(0.18) : Color.white.opacity(0.55))
        )
        .overlay(
            RoundedRectangle(cornerRadius: compacto ? 5 : 8, style: .continuous)
                .stroke(marcado ? Color(hex: alergeno.color) : Color.black.opacity(0.12), lineWidth: marcado ? 1.5 : 1)
        )
    }
}

/// El sello de la web: ✓ Apto / ✗ No apto / ⚠ Pregunta en barra.
struct Sello: View {
    let estado: EstadoPlato
    let textos: Textos
    let idioma: Idioma
    let paleta: Paleta

    var body: some View {
        switch estado {
        case .sinEvaluar:
            EmptyView()
        case .apto:
            etiqueta(textos.texto(.selloSi, idioma), fondo: paleta.okSuave, tinta: paleta.ok, borde: paleta.ok)
        case .noApto:
            etiqueta(textos.texto(.selloNo, idioma), fondo: paleta.noSuave, tinta: paleta.no, borde: paleta.no)
        }
    }

    private func etiqueta(_ texto: String, fondo: Color, tinta: Color, borde: Color) -> some View {
        Text(texto)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tinta)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(fondo))
            .overlay(Capsule().stroke(borde.opacity(0.4), lineWidth: 1))
            .accessibilityLabel(texto)
    }
}

/// Tarjeta de aviso (contaminación cruzada, notas de sección, procedencia).
struct TarjetaAviso<Contenido: View>: View {
    let paleta: Paleta
    var tono: Color?
    @ViewBuilder var contenido: Contenido

    var body: some View {
        contenido
            .font(.footnote)
            .foregroundStyle(paleta.tinta)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill((tono ?? paleta.linea).opacity(0.22))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke((tono ?? paleta.lineaFuerte).opacity(0.55), lineWidth: 1)
            )
    }
}
