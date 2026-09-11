import SwiftUI

/// Punto de entrada. La app es una sola pantalla con navegación a las vistas
/// de apoyo; todo el estado vive en `EstadoApp`.
///
/// Si los JSON no se pueden leer, `RaizView` enseña una pantalla de problema
/// en vez de caerse: la app nunca se cierra sola.
@main
struct AlergenosApp: App {
    @State private var estado = EstadoApp()

    var body: some Scene {
        WindowGroup {
            RaizView()
                .environment(estado)
                // La web de la que sale esta app es de papel claro: se respeta
                // ese aspecto en lugar de inventar un modo oscuro.
                .preferredColorScheme(.light)
        }
    }
}

/// Decide entre la carta y la pantalla de problema (si faltaran los datos).
struct RaizView: View {
    @Environment(EstadoApp.self) private var estado

    var body: some View {
        if let datos = estado.datos {
            CartaView(datos: datos)
        } else {
            PantallaProblema(mensaje: estado.problema ?? "Error desconocido")
        }
    }
}

/// Si los JSON no están, se dice claramente en pantalla. Nunca se cae.
struct PantallaProblema: View {
    @Environment(EstadoApp.self) private var estado
    let mensaje: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
            Text("No se han podido cargar los datos")
                .font(.headline)
            Text(mensaje)
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Reintentar") { estado.reintenta() }
                .buttonStyle(.borderedProminent)
        }
        .padding(28)
    }
}
