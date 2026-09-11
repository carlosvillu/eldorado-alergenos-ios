import SwiftUI

/// La pantalla principal: la carta frente a los alérgenos que ha marcado quien
/// consulta. Reproduce la estructura de alergenos.html: cabecera con el aviso de
/// contaminación cruzada, buscador, riel de alérgenos, contador y la carta
/// agrupada por secciones.
struct CartaView: View {
    let datos: DatosApp

    @Environment(EstadoApp.self) private var estado
    @State private var destino: Destino?
    @State private var platoAbierto: PlatoEnCarta?

    /// Pantallas que no existen en la web y que la app añade.
    enum Destino: String, Identifiable, Hashable {
        case misAlergenos, leyenda, tabla, procedencia

        var id: String { rawValue }

        func etiqueta(_ idioma: Idioma) -> String {
            switch self {
            case .misAlergenos: return TextosApp.misAlergenos.texto(idioma)
            case .leyenda: return TextosApp.leyenda.texto(idioma)
            case .tabla: return TextosApp.tabla.texto(idioma)
            case .procedencia: return TextosApp.procedencia.texto(idioma)
            }
        }

        var simbolo: String {
            switch self {
            case .misAlergenos: return "checklist"
            case .leyenda: return "circle.grid.2x2"
            case .tabla: return "tablecells"
            case .procedencia: return "photo.on.rectangle"
            }
        }
    }

    private var carta: Carta { datos.carta }
    private var textos: Textos { datos.textos }
    private var paleta: Paleta { Paleta(tema: datos.tema) }
    private var idioma: Idioma { estado.idioma }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    cabecera
                    buscador
                    riel
                    filaEstado
                    listado
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .background(FondoCuadricula(paleta: paleta))
            // El titular grande ya está en la cabecera; en la barra basta con
            // el nombre de la app, que además hace de «atrás» en las pantallas
            // de apoyo.
            .navigationTitle(TextosApp.app.texto(idioma))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { barra }
            .navigationDestination(item: $destino) { destino in
                switch destino {
                case .misAlergenos: MisAlergenosView(datos: datos)
                case .leyenda: LeyendaView(datos: datos)
                case .tabla: TablaView(datos: datos)
                case .procedencia: ProcedenciaView(datos: datos)
                }
            }
            .sheet(item: $platoAbierto) { item in
                DetallePlatoView(item: item, datos: datos)
            }
        }
        .tint(paleta.tinta)
    }

    // MARK: - Cabecera

    private var cabecera: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(textos.texto(.ceja, idioma))
                .font(.caption.weight(.semibold))
                .foregroundStyle(paleta.tinta2)
                .textCase(.uppercase)
            Text(textos.texto(.h1, idioma))
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(paleta.tinta)
            Text(textos.texto(.sub, idioma))
                .font(.subheadline)
                .foregroundStyle(paleta.tinta2)

            TarjetaAviso(paleta: paleta, tono: paleta.lineaFuerte) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(textos.texto(.avisoT, idioma))
                        .font(.footnote.weight(.semibold))
                    Text(textos.texto(.avisoTx, idioma))
                        .font(.footnote)
                }
            }
            .padding(.top, 2)
        }
        .padding(.top, 8)
    }

    // MARK: - Buscador

    private var buscador: some View {
        let texto = Binding(get: { estado.busqueda }, set: { estado.busqueda = $0 })
        return HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(paleta.tinta2)
            TextField(textos.texto(.buscarPh, idioma), text: texto)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
                .accessibilityLabel(textos.texto(.buscarAria, idioma))
                .accessibilityIdentifier("buscador")
            if !estado.busqueda.isEmpty {
                Button {
                    estado.busqueda = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(paleta.tinta2)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(TextosApp.cerrar.texto(idioma))
                .accessibilityIdentifier("borrarBusqueda")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous).fill(paleta.carta)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(paleta.lineaFuerte, lineWidth: 1.5)
        )
    }

    // MARK: - Riel de alérgenos

    private var riel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(carta.alergenos) { alergeno in
                    let marcado = estado.seleccion.contains(alergeno.id)
                    Button {
                        estado.alterna(alergeno.id)
                    } label: {
                        ChipAlergeno(alergeno: alergeno, idioma: idioma, marcado: marcado)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(marcado ? [.isSelected] : [])
                    .accessibilityIdentifier("chip-\(alergeno.id)")
                }
            }
            .padding(.vertical, 2)
        }
        .accessibilityLabel(textos.texto(.rielAria, idioma))
    }

    // MARK: - Contador y controles

    private var filaEstado: some View {
        let filtro = estado.filtro
        let candidatos = filtro.candidatos(carta).count
        let aptos = filtro.aptos(carta).count

        return VStack(alignment: .leading, spacing: 8) {
            if estado.seleccion.isEmpty {
                Text(textos.contador(platos: carta.totalPlatos, categorias: carta.secciones.count, idioma))
                    .font(.footnote)
                    .foregroundStyle(paleta.tinta2)
                    .accessibilityIdentifier("contadorBase")
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(aptos)/\(candidatos)")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(paleta.tinta)
                        .accessibilityIdentifier("contador")
                    Text(textos.texto(.contadorSin, idioma))
                        .font(.footnote)
                        .foregroundStyle(paleta.tinta2)
                    Text(nombresMarcados)
                        .font(.footnote)
                        .foregroundStyle(paleta.tinta2)
                        .lineLimit(2)
                }

                HStack(spacing: 14) {
                    Toggle(isOn: Binding(get: { estado.soloAptos }, set: { estado.soloAptos = $0 })) {
                        Text(textos.texto(.solo, idioma)).font(.footnote)
                    }
                    .toggleStyle(.switch)
                    .accessibilityIdentifier("soloAptos")

                    Button(textos.texto(.limpiar, idioma)) {
                        estado.limpiaSeleccion()
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(paleta.tinta)
                    .accessibilityIdentifier("limpiar")

                    Spacer()
                }
            }

            if estado.seleccion.isEmpty {
                Text(TextosApp.ayudaSinSeleccion.texto(idioma))
                    .font(.caption)
                    .foregroundStyle(paleta.tinta2)
            }
        }
    }

    private var nombresMarcados: String {
        carta.alergenos
            .filter { estado.seleccion.contains($0.id) }
            .map { $0.nombre(idioma: idioma) }
            .joined(separator: ", ")
    }

    // MARK: - Carta

    @ViewBuilder
    private var listado: some View {
        let visibles = estado.filtro.seccionesVisibles(carta)
        if visibles.isEmpty {
            Text(estaVacioPorFiltro ? textos.texto(.vacioFiltro, idioma) : textos.texto(.vacioBusqueda, idioma))
                .font(.callout)
                .foregroundStyle(paleta.tinta2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 44)
        } else {
            ForEach(visibles) { seccion in
                seccionVista(seccion)
            }
        }
    }

    private var estaVacioPorFiltro: Bool {
        estado.soloAptos && !estado.seleccion.isEmpty
    }

    private func seccionVista(_ seccion: Seccion) -> some View {
        let filtro = estado.filtro
        let platos = seccion.platos.filter { filtro.seMuestra($0, seccion: seccion) }

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(seccion.titulo(idioma: idioma))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(paleta.tinta)
                Text("\(platos.count)")
                    .font(.caption)
                    .foregroundStyle(paleta.tinta2)
            }

            if let nota = seccion.nota(idioma: idioma) {
                TarjetaAviso(paleta: paleta, tono: paleta.no) {
                    Text(nota).font(.footnote)
                }
            }

            VStack(spacing: 8) {
                ForEach(platos) { plato in
                    FilaPlatoView(
                        item: PlatoEnCarta(seccion: seccion, plato: plato),
                        carta: carta,
                        textos: textos,
                        idioma: idioma,
                        paleta: paleta,
                        seleccion: estado.seleccion,
                        esDuda: carta.esDuda(seccion: seccion, plato: plato)
                    ) {
                        platoAbierto = PlatoEnCarta(seccion: seccion, plato: plato)
                    }
                }
            }
        }
        .padding(.top, 12)
    }

    // MARK: - Barra de navegación

    @ToolbarContentBuilder
    private var barra: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Picker("Idioma", selection: Binding(get: { estado.idioma }, set: { estado.idioma = $0 })) {
                ForEach(Idioma.allCases) { idioma in
                    Text(idioma.etiqueta).tag(idioma)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 112)
            .accessibilityLabel(Text("Idioma"))
            .accessibilityIdentifier("idioma")
        }

        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                ForEach([Destino.misAlergenos, .leyenda, .tabla, .procedencia]) { opcion in
                    Button {
                        destino = opcion
                    } label: {
                        Label(opcion.etiqueta(idioma), systemImage: opcion.simbolo)
                    }
                    .accessibilityIdentifier("destino-\(opcion.rawValue)")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .accessibilityLabel(Text("Más"))
                    .accessibilityIdentifier("menu")
            }
        }
    }
}
