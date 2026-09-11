// swift-tools-version: 5.9
//
// ⚠️ Este paquete NO forma parte del build de la app. La app se compila con
// Alergenos.xcodeproj (xcodegen + xcodebuild).
//
// Existe por un motivo concreto: el analizador de Swift que usa el agente solo
// enraíza su workspace si encuentra un Package.swift. Sin él, analiza cada
// fichero por su cuenta contra el SDK de macOS y reporta errores falsos del
// estilo «cannot find type 'Plato' in scope» o «no such module 'UIKit'».
//
// Declara únicamente el modelo y las reglas (solo Foundation), que es donde
// está la lógica que merece revisión estática. Las vistas se validan con el
// compilador de verdad: xcodebuild.
import PackageDescription

let package = Package(
    name: "AlergenosModelo",
    platforms: [
        .macOS(.v13),
        .iOS(.v17),
    ],
    targets: [
        .target(
            name: "AlergenosModelo",
            path: "Alergenos",
            exclude: [
                "App",
                "Vista",
                "Info.plist",
                "Resources/Assets.xcassets",
                "Resources/tabla-original-1.webp",
                "Resources/tabla-original-2.webp",
            ],
            sources: ["Modelo"],
            resources: [
                .process("Resources/platos.json"),
                .process("Resources/i18n.json"),
            ]
        )
    ]
)
