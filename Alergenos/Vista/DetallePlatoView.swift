import SwiftUI

/// Ficha de un plato: sus alérgenos completos, el sello, la nota de su sección
/// y el aviso de contaminación cruzada. Es la pantalla que se abre al tocar una
/// fila de la carta.
struct DetallePlatoView: View {
    let item: PlatoEnCarta
    let datos: DatosApp

    @Environment(EstadoApp.self) private var estado
    @Environment(\.dismiss) private var cerrar

    var body: some View {
        let paleta = Paleta(tema: datos.tema)
        let idioma = estado.idioma
        let evaluacion = Aptitud.evalua(plato: item.plato, seleccion: estado.seleccion)

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(item.seccion.titulo(idioma: idioma))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(paleta.tinta2)
                            .textCase(.uppercase)
                        Spacer()
                        Sello(estado: evaluacion.estado, textos: datos.textos, idioma: idioma, paleta: paleta)
                    }

                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(item.plato.alergenos.count)/\(datos.carta.alergenos.count)")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(paleta.tinta)
                        Text(TextosApp.alergenos.texto(idioma))
                            .font(.footnote)
                            .foregroundStyle(paleta.tinta2)
                    }

                    FlujoAlergenos(
                        ids: item.plato.alergenos,
                        carta: datos.carta,
                        idioma: idioma,
                        marcados: estado.seleccion,
                        compacto: false
                    )

                    if evaluacion.estado == .noApto {
                        TarjetaAviso(paleta: paleta, tono: paleta.no) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(datos.textos.texto(.selloNo, idioma)).font(.footnote.weight(.semibold))
                                Text(nombresQueLleva(idioma: idioma))
                                    .font(.footnote)
                            }
                        }
                    }

                    if datos.carta.esDuda(seccion: item.seccion, plato: item.plato) {
                        TarjetaAviso(paleta: paleta, tono: paleta.lineaFuerte) {
                            Text(datos.textos.texto(.preguntar, idioma)).font(.footnote.weight(.semibold))
                        }
                    }

                    if let nota = item.seccion.nota(idioma: idioma) {
                        TarjetaAviso(paleta: paleta, tono: paleta.no) {
                            Text(nota).font(.footnote)
                        }
                    }

                    TarjetaAviso(paleta: paleta, tono: paleta.lineaFuerte) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(datos.textos.texto(.avisoT, idioma)).font(.footnote.weight(.semibold))
                            Text(datos.textos.texto(.avisoTx, idioma)).font(.footnote)
                        }
                    }

                    if !estado.seleccion.isEmpty && evaluacion.estado == .apto {
                        TarjetaAviso(paleta: paleta, tono: paleta.ok) {
                            Text(datos.textos.texto(.selloSi, idioma)).font(.footnote.weight(.semibold))
                        }
                    }
                }
                .padding(18)
            }
            .background(FondoCuadricula(paleta: paleta))
            .navigationTitle(item.plato.nombre)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(TextosApp.cerrar.texto(idioma)) { cerrar() }
                        .accessibilityIdentifier("cerrar")
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func nombresQueLleva(idioma: Idioma) -> String {
        Aptitud.evalua(plato: item.plato, seleccion: estado.seleccion)
            .lleva
            .compactMap { datos.carta.alergeno($0)?.nombre(idioma: idioma) }
            .joined(separator: ", ")
    }
}
