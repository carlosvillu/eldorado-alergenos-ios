import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// Icono de la app dibujado con el mismo motivo que el favicon de la web:
// cuatro círculos sobre papel manila. Se genera por código para que salga del
// mismo dibujo que la página, sin binarios sueltos de origen desconocido.
//
//   swift tools/make-icon.swift [ruta-de-salida.png]

let lado = 1024
let escala = CGFloat(lado) / 32 // el favicon se dibuja en una caja de 32×32

struct Tinta {
    let rojo: CGFloat
    let verde: CGFloat
    let azul: CGFloat

    init(_ hex: String) {
        let limpio = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        var valor: UInt64 = 0
        Scanner(string: limpio).scanHexInt64(&valor)
        rojo = CGFloat((valor >> 16) & 0xFF) / 255
        verde = CGFloat((valor >> 8) & 0xFF) / 255
        azul = CGFloat(valor & 0xFF) / 255
    }

    var cgColor: CGColor {
        CGColor(srgbRed: rojo, green: verde, blue: azul, alpha: 1)
    }
}

/// Un círculo del dibujo: centro en la caja de 32×32 y su color.
struct Circulo {
    let centroX32: CGFloat
    let centroY32: CGFloat
    let color: String
}

let papel = Tinta("#F1E8D2")
// Mismos cuatro círculos que el favicon: (x, y) en la caja de 32×32 y su color.
let circulos = [
    Circulo(centroX32: 11, centroY32: 11, color: "#C05A2E"),
    Circulo(centroX32: 21, centroY32: 11, color: "#2E9BC4"),
    Circulo(centroX32: 11, centroY32: 21, color: "#E07B39"),
    Circulo(centroX32: 21, centroY32: 21, color: "#2C4E9E"),
]
let radio: CGFloat = 6

guard let contexto = CGContext(
    data: nil,
    width: lado,
    height: lado,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    FileHandle.standardError.write(Data("No se ha podido crear el contexto gráfico\n".utf8))
    exit(1)
}

contexto.setFillColor(papel.cgColor)
contexto.fill(CGRect(x: 0, y: 0, width: lado, height: lado))

for circulo in circulos {
    contexto.setFillColor(Tinta(circulo.color).cgColor)
    // El eje Y del lienzo va al revés que el del SVG: se da la vuelta.
    let centroX = circulo.centroX32 * escala
    let centroY = (32 - circulo.centroY32) * escala
    let ladoCirculo = radio * 2 * escala
    contexto.fillEllipse(
        in: CGRect(
            x: centroX - ladoCirculo / 2,
            y: centroY - ladoCirculo / 2,
            width: ladoCirculo,
            height: ladoCirculo
        )
    )
}

guard let imagen = contexto.makeImage() else {
    FileHandle.standardError.write(Data("No se ha podido rasterizar el icono\n".utf8))
    exit(1)
}

let destino = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "Alergenos/Resources/Assets.xcassets/AppIcon.appiconset/icono-1024.png"
let url = URL(fileURLWithPath: destino)

guard let salida = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
    FileHandle.standardError.write(Data("No se ha podido abrir \(destino) para escribir\n".utf8))
    exit(1)
}
CGImageDestinationAddImage(salida, imagen, nil)

guard CGImageDestinationFinalize(salida) else {
    FileHandle.standardError.write(Data("No se ha podido escribir \(destino)\n".utf8))
    exit(1)
}

FileHandle.standardOutput.write(Data("✓ Icono \(lado)×\(lado) escrito en \(destino)\n".utf8))
