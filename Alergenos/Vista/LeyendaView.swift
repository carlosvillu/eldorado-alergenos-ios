import SwiftUI

/// La leyenda: qué es cada color y cómo se lee un sello. Es la pantalla que
/// explica la tabla a quien la coge por primera vez.
struct LeyendaView: View {
    let datos: DatosApp

    @Environment(EstadoApp.self) private var estado

    private let columnas = [GridItem(.adaptive(minimum: 150), spacing: 10)]

    var body: some View {
        let paleta = Paleta(tema: datos.tema)
        let idioma = estado.idioma

        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                LazyVGrid(columns: columnas, alignment: .leading, spacing: 10) {
                    ForEach(datos.carta.alergenos) { alergeno in
                        ChipAlergeno(
                            alergeno: alergeno,
                            idioma: idioma,
                            marcado: estado.seleccion.contains(alergeno.id)
                        )
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text(TextosApp.comoSeLee.texto(idioma))
                        .font(.headline)
                        .foregroundStyle(paleta.tinta)

                    fila {
                        Sello(estado: .apto, textos: datos.textos, idioma: idioma, paleta: paleta)
                    } descripcion: {
                        Text(datos.textos.texto(.avisoT, idioma).replacingOccurrences(of: "⚠️ ", with: ""))
                            .font(.footnote)
                            .foregroundStyle(paleta.tinta2)
                    }

                    fila {
                        Sello(estado: .sinEvaluar, textos: datos.textos, idioma: idioma, paleta: paleta)
                    } descripcion: {
                        Text(TextosApp.sinMarcar.texto(idioma))
                            .font(.footnote)
                            .foregroundStyle(paleta.tinta2)
                    }

                    fila {
                        Text(datos.textos.texto(.preguntar, idioma))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(paleta.tinta)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(paleta.linea.opacity(0.6)))
                            .overlay(Capsule().stroke(paleta.lineaFuerte, lineWidth: 1))
                    } descripcion: {
                        Text(datos.textos.texto(.avisoTx, idioma))
                            .font(.footnote)
                            .foregroundStyle(paleta.tinta2)
                    }
                }

                TarjetaAviso(paleta: paleta, tono: paleta.lineaFuerte) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(datos.textos.texto(.avisoT, idioma)).font(.footnote.weight(.semibold))
                        Text(datos.textos.texto(.avisoTx, idioma)).font(.footnote)
                    }
                }
            }
            .padding(16)
        }
        .background(FondoCuadricula(paleta: paleta))
        .navigationTitle(TextosApp.leyenda.texto(idioma))
    }

    private func fila<Sello: View, Texto: View>(
        @ViewBuilder sello: () -> Sello,
        @ViewBuilder descripcion: () -> Texto
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            sello().frame(width: 96, alignment: .leading)
            descripcion()
            Spacer(minLength: 0)
        }
    }
}
