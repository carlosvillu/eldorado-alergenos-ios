import SwiftUI
import UIKit

/// De dónde salen los datos: los dos avisos del pie de la web y las dos fotos
/// de la tabla original, que viajan dentro de la app (nada de red).
struct ProcedenciaView: View {
    let datos: DatosApp

    @Environment(EstadoApp.self) private var estado

    var body: some View {
        let paleta = Paleta(tema: datos.tema)
        let idioma = estado.idioma

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(datos.textos.texto(.fotosP, idioma))
                    .font(.footnote)
                    .foregroundStyle(paleta.tinta2)

                ForEach(datos.carta.procedencia) { aviso in
                    TarjetaAviso(paleta: paleta, tono: paleta.lineaFuerte) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(aviso.titulo).font(.footnote.weight(.semibold))
                            Text(aviso.texto).font(.footnote)
                        }
                    }
                }

                if idioma == .en {
                    Text(TextosApp.sinTraduccion.texto(idioma))
                        .font(.caption)
                        .foregroundStyle(paleta.tinta2)
                }

                Text(datos.textos.texto(.fotosSum, idioma))
                    .font(.headline)
                    .foregroundStyle(paleta.tinta)

                ImagenDeRecurso(nombre: "tabla-original-1", paleta: paleta)
                ImagenDeRecurso(nombre: "tabla-original-2", paleta: paleta)

                Text("\(datos.carta.origen.fichero) · \(datos.carta.origen.descripcion)")
                    .font(.caption2)
                    .foregroundStyle(paleta.tinta2)
            }
            .padding(16)
        }
        .background(FondoCuadricula(paleta: paleta))
        .navigationTitle(TextosApp.procedencia.texto(idioma))
    }
}

/// Foto que viaja en el bundle. Toca para ampliarla.
struct ImagenDeRecurso: View {
    let nombre: String
    let paleta: Paleta

    @State private var ampliada = false

    var body: some View {
        Group {
            if let imagen = Self.carga(nombre) {
                Image(uiImage: imagen)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(paleta.lineaFuerte, lineWidth: 1)
                    )
                    .onTapGesture { ampliada = true }
                    .sheet(isPresented: $ampliada) {
                        ScrollView([.horizontal, .vertical]) {
                            Image(uiImage: imagen)
                                .resizable()
                                .scaledToFit()
                                .padding(8)
                        }
                        .background(Color.black.opacity(0.94))
                    }
                    .accessibilityLabel(Text(nombre))
                    .accessibilityIdentifier(nombre)
            } else {
                // Si la foto no estuviera, se dice; no se esconde el hueco.
                Text("\(nombre).webp — no disponible")
                    .font(.footnote)
                    .foregroundStyle(paleta.no)
            }
        }
    }

    static func carga(_ nombre: String) -> UIImage? {
        guard let ruta = Bundle.main.path(forResource: nombre, ofType: "webp") else { return nil }
        return UIImage(contentsOfFile: ruta)
    }
}
