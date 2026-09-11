import SwiftUI

/// Fondo de papel con cuadrícula, calcado del CSS original (líneas cada 34 px,
/// con las mismas opacidades que la web). Es lo que hace que la app se parezca
/// a la tabla plastificada del puesto y no a una app cualquiera.
struct FondoCuadricula: View {
    let paleta: Paleta
    private let paso: CGFloat = 34

    var body: some View {
        Canvas { contexto, tamano in
            contexto.fill(Path(CGRect(origin: .zero, size: tamano)), with: .color(paleta.papel))

            var horizontales = Path()
            var lineaY: CGFloat = 0
            while lineaY <= tamano.height {
                horizontales.move(to: CGPoint(x: 0, y: lineaY))
                horizontales.addLine(to: CGPoint(x: tamano.width, y: lineaY))
                lineaY += paso
            }
            contexto.stroke(horizontales, with: .color(paleta.tinta.opacity(0.045)), lineWidth: 1)

            var verticales = Path()
            var lineaX: CGFloat = 0
            while lineaX <= tamano.width {
                verticales.move(to: CGPoint(x: lineaX, y: 0))
                verticales.addLine(to: CGPoint(x: lineaX, y: tamano.height))
                lineaX += paso
            }
            contexto.stroke(verticales, with: .color(paleta.tinta.opacity(0.03)), lineWidth: 1)
        }
        .background(paleta.papel)
        .ignoresSafeArea()
    }
}
