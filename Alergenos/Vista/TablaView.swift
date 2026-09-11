import SwiftUI

/// La tabla completa: la carta frente a los 14 alérgenos, plato por plato.
/// Es el equivalente en pantalla de la tabla plastificada del puesto: se lee
/// en horizontal y cabe arrastrando con el dedo.
struct TablaView: View {
    let datos: DatosApp

    @Environment(EstadoApp.self) private var estado

    private let anchoPlato: CGFloat = 168
    private let anchoAlergeno: CGFloat = 30
    private let altoCabecera: CGFloat = 108
    private let altoFila: CGFloat = 30

    var body: some View {
        let paleta = Paleta(tema: datos.tema)
        let idioma = estado.idioma

        VStack(alignment: .leading, spacing: 10) {
            Text(datos.textos.texto(.tablaNota, idioma))
                .font(.footnote)
                .foregroundStyle(paleta.tinta2)
                .padding(.horizontal, 16)
                .padding(.top, 12)

            HStack(spacing: 14) {
                clave(texto: "✓ \(TextosApp.noLoLleva.texto(idioma))", color: paleta.ok, paleta: paleta)
                clave(texto: "✕ \(TextosApp.loLleva.texto(idioma))", color: paleta.no, paleta: paleta)
            }
            .padding(.horizontal, 16)

            ScrollView([.horizontal, .vertical], showsIndicators: true) {
                VStack(alignment: .leading, spacing: 0) {
                    filaCabecera(paleta: paleta, idioma: idioma)
                    ForEach(datos.carta.secciones) { seccion in
                        filaTitulo(seccion, paleta: paleta, idioma: idioma)
                        ForEach(seccion.platos) { plato in
                            filaPlato(plato, seccion: seccion, paleta: paleta, idioma: idioma)
                        }
                    }
                }
                .accessibilityIdentifier("tabla")
                .background(paleta.carta)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(paleta.lineaFuerte, lineWidth: 1)
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
        }
        .background(FondoCuadricula(paleta: paleta))
        .navigationTitle(TextosApp.tabla.texto(idioma))
    }

    private func clave(texto: String, color: Color, paleta: Paleta) -> some View {
        Text(texto)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
    }

    private func filaCabecera(paleta: Paleta, idioma: Idioma) -> some View {
        HStack(alignment: .bottom, spacing: 0) {
            Text(TextosApp.plato.texto(idioma))
                .font(.caption.weight(.bold))
                .foregroundStyle(paleta.tinta)
                .frame(width: anchoPlato, height: altoFila, alignment: .leading)
                .padding(.leading, 8)
            ForEach(datos.carta.alergenos) { alergeno in
                VStack(spacing: 2) {
                    Circle()
                        .fill(Color(hex: alergeno.color))
                        .frame(width: 8, height: 8)
                    Text(alergeno.nombre(idioma: idioma))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color(hex: alergeno.color))
                        .fixedSize()
                        .rotationEffect(.degrees(-90))
                        .frame(width: anchoAlergeno, height: altoCabecera - 22)
                }
                .frame(width: anchoAlergeno, height: altoCabecera)
            }
        }
        .background(paleta.papel)
    }

    private func filaTitulo(_ seccion: Seccion, paleta: Paleta, idioma: Idioma) -> some View {
        HStack(spacing: 0) {
            Text(seccion.titulo(idioma: idioma))
                .font(.caption.weight(.bold))
                .foregroundStyle(paleta.tinta)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
        }
        .background(paleta.linea.opacity(0.55))
    }

    private func filaPlato(_ plato: Plato, seccion: Seccion, paleta: Paleta, idioma: Idioma) -> some View {
        HStack(spacing: 0) {
            Text(plato.nombre)
                .font(.caption)
                .foregroundStyle(paleta.tinta)
                .lineLimit(1)
                .frame(width: anchoPlato, height: altoFila, alignment: .leading)
                .padding(.leading, 8)
            ForEach(datos.carta.alergenos) { alergeno in
                let lleva = plato.alergenos.contains(alergeno.id)
                Text(lleva ? "✕" : "✓")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(lleva ? paleta.no : paleta.ok)
                    .frame(width: anchoAlergeno, height: altoFila)
                    .background(lleva ? paleta.noSuave.opacity(0.5) : Color.clear)
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(paleta.linea.opacity(0.6))
                .frame(height: 0.5)
        }
    }
}
