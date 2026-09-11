import SwiftUI

/// «Mis alérgenos»: la misma selección que el riel de la pantalla principal,
/// pero en lista, con sitio para explicar qué hace cada marca. Se guarda entre
/// lanzamientos.
struct MisAlergenosView: View {
    let datos: DatosApp

    @Environment(EstadoApp.self) private var estado

    var body: some View {
        let paleta = Paleta(tema: datos.tema)
        let idioma = estado.idioma

        List {
            Section {
                Text(TextosApp.ayudaSinSeleccion.texto(idioma))
                    .font(.footnote)
                    .foregroundStyle(paleta.tinta2)
            }

            Section {
                ForEach(datos.carta.alergenos) { alergeno in
                    HStack(spacing: 10) {
                        Toggle(
                            isOn: Binding(
                                get: { estado.seleccion.contains(alergeno.id) },
                                set: { nuevo in
                                    if nuevo != estado.seleccion.contains(alergeno.id) {
                                        estado.alterna(alergeno.id)
                                    }
                                }
                            )
                        ) {
                            ChipAlergeno(
                                alergeno: alergeno,
                                idioma: idioma,
                                marcado: estado.seleccion.contains(alergeno.id),
                                compacto: false
                            )
                        }
                        Spacer(minLength: 0)
                    }
                    .listRowBackground(paleta.carta)
                    .accessibilityIdentifier("fila-\(alergeno.id)")
                }
            }

            Section {
                Toggle(
                    isOn: Binding(get: { estado.soloAptos }, set: { estado.soloAptos = $0 }),
                    label: { Text(datos.textos.texto(.solo, idioma)) }
                )
                .listRowBackground(paleta.carta)

                Button(role: .destructive) {
                    estado.limpiaSeleccion()
                } label: {
                    Text(datos.textos.texto(.limpiar, idioma))
                }
                .disabled(estado.seleccion.isEmpty)
                .listRowBackground(paleta.carta)
            }
        }
                    .scrollContentBackground(.hidden)
                    .background(FondoCuadricula(paleta: paleta))
                    .navigationTitle(TextosApp.misAlergenos.texto(idioma))
    }
}
