import Combine
import Foundation

/// Languages the UI is translated to. Spanish strings are the keys.
enum AppLanguage: String, CaseIterable, Identifiable {
    case system, en, es, ca
    var id: String { rawValue }

    /// Shown in its own language, so anyone can find theirs.
    var nativeName: String {
        switch self {
        case .system: return tr("Sistema")
        case .en: return "English"
        case .es: return "Español"
        case .ca: return "Català"
        }
    }
}

final class Localizer: ObservableObject {
    static let shared = Localizer()

    @Published var choice: AppLanguage {
        didSet { UserDefaults.standard.set(choice.rawValue, forKey: "appLanguage") }
    }

    private init() {
        choice = AppLanguage(rawValue: UserDefaults.standard.string(forKey: "appLanguage") ?? "") ?? .system
    }

    /// The language actually used: the chosen one, or the first supported system language (English otherwise).
    var language: AppLanguage {
        if choice != .system { return choice }
        for preferred in Locale.preferredLanguages {
            let code = String(preferred.prefix(2))
            if let match = AppLanguage(rawValue: code), match != .system { return match }
        }
        return .en
    }

    var locale: Locale { Locale(identifier: language.rawValue) }

    func translate(_ key: String) -> String {
        switch language {
        case .en: return Translations.en[key] ?? key
        case .ca: return Translations.ca[key] ?? key
        default: return key
        }
    }
}

/// Translated UI text. `key` is the Spanish text.
func tr(_ key: String) -> String {
    Localizer.shared.translate(key)
}

/// Translated format string (`%@`, `%d`) with arguments.
func tr(_ key: String, _ args: CVarArg...) -> String {
    String(format: Localizer.shared.translate(key), locale: Localizer.shared.locale, arguments: args)
}

private enum Translations {
    static let en: [String: String] = [
        // Menus
        "Cerrar ventana": "Close Window",
        "Salir de Atajoly": "Quit Atajoly",
        "Edición": "Edit",
        "Deshacer": "Undo",
        "Rehacer": "Redo",
        "Cortar": "Cut",
        "Copiar": "Copy",
        "Pegar": "Paste",
        "Seleccionar todo": "Select All",
        "Abrir Atajoly…": "Open Atajoly…",
        "Pausar atajos": "Pause Shortcuts",
        "Reanudar atajos": "Resume Shortcuts",
        "Abrir al iniciar sesión": "Open at Login",
        "Actualizando…": "Updating…",
        "Buscar actualizaciones…": "Check for Updates…",
        "Invítame a un café…": "Buy Me a Coffee…",
        "Sistema": "System",

        // Sidebar
        "Teclado": "Keyboard",
        "Comportamiento": "Behaviour",
        "Ajustes": "Settings",
        "En pausa": "Paused",
        "Activo": "Active",
        "Los atajos no hacen nada hasta que los reanudes.": "Shortcuts do nothing until you resume them.",
        "Mantén %@ y pulsa la inicial de una app.": "Hold %@ and press an app's first letter.",
        "Versión %@": "Version %@",

        // Keyboard
        "%@ + letra abre la app; si ya está delante, hace su acción.": "%@ + letter opens the app; if it's already in front, does its action.",
        "Asignada a mano": "Assigned by hand",
        "Apps abiertas": "Open apps",
        "Desactivada": "Disabled",
        "Asignadas a mano": "Assigned by hand",
        "%@ + %@ + letra asigna la app activa": "%@ + %@ + letter assigns the active app",
        "Ninguna todavía. Elige una tecla en el teclado y asígnale una app, aunque no esté abierta.": "None yet. Pick a key on the keyboard and give it an app, even one that isn't open.",
        "Quitar": "Remove",
        "Apps sin letra automática": "Apps without an automatic letter",
        "Volver a incluir": "Include again",
        "Elige una tecla": "Pick a key",
        "Tecla %@": "Key %@",
        "Desactivar esta tecla": "Disable this key",
        "%@ + %@ vuelve a funcionar como siempre": "%@ + %@ works as usual again",
        "App asignada": "Assigned app",
        "Abierta": "Open",
        "Se abrirá al pulsar": "Opens when pressed",
        "Si ya está delante": "If it's already in front",
        "Ninguna: la tecla va a las apps abiertas que empiezan por %@.": "None: the key goes to open apps starting with %@.",
        "Asignar app…": "Assign App…",
        "Cambiar app…": "Change App…",
        "Apps abiertas con la %@": "Open apps with %@",
        "Ninguna abierta ahora.": "None open right now.",
        "Asignar a la %@": "Assign to %@",
        "No darle letra automática": "Don't give it an automatic letter",
        "Al pulsar la tecla otra vez se pasa a la siguiente.": "Pressing the key again moves to the next one.",
        "Abiertas": "Open",
        "Instaladas": "Installed",
        "Otra app…": "Other App…",

        // Behaviour
        "Tecla de activación": "Trigger key",
        "Solo la tecla derecha: la izquierda sigue haciendo los atajos de siempre.": "Only the right-hand key: the left one keeps doing the usual shortcuts.",
        "Si la app ya está delante": "If the app is already in front",
        "Para las letras automáticas. Las asignadas a mano tienen su propia opción en Teclado.": "For automatic letters. Keys assigned by hand have their own option in Keyboard.",
        "Traer todas las ventanas de la app": "Bring all of the app's windows forward",
        "No solo la última que usaste": "Not just the last one you used",
        "Al pasar de app, saltar la asignada a mano": "When cycling apps, skip the one assigned by hand",
        "Recorre solo las apps abiertas con esa letra": "Only goes through open apps with that letter",
        "Teclas añadidas": "Extra keys",
        "%@ + ⇧ izquierdo + letra: ocultar las demás": "%@ + left ⇧ + letter: hide the others",
        "Abre la app y oculta todas las otras": "Opens the app and hides all the others",
        "Ocultar siempre las demás apps": "Always hide the other apps",
        "Sin tener que añadir ⇧ izquierdo": "Without having to add left ⇧",
        "%@ + ⇧ derecho + letra: siguiente app": "%@ + right ⇧ + letter: next app",
        "Pasa a la siguiente app con la misma letra": "Moves to the next app with the same letter",
        "%@ + %@ + letra: asignar": "%@ + %@ + letter: assign",
        "Da la letra a la app activa; otra vez la libera": "Gives the letter to the active app; again frees it",
        "Mostrar el mapa de teclas": "Show the key map",
        "Al mantener la tecla de activación": "While holding the trigger key",
        "Esperar": "Wait",
        "Tecla para ocultar": "Hide key",
        "Ninguna": "None",
        "Sin tecla para ocultar.": "No hide key.",
        "%@ + %@ oculta la app activa; con ⇧, todas las demás.": "%@ + %@ hides the active app; with ⇧, all the others.",
        "Ventanas": "Windows",
        "Permiso concedido": "Permission granted",
        "Sin permiso": "No permission",
        "«Pasar a la siguiente ventana» necesita permiso de Accesibilidad. Lo demás funciona sin él.": "“Go to the next window” needs Accessibility permission. Everything else works without it.",
        "Pedir permiso": "Ask for Permission",
        "Abrir Ajustes del Sistema": "Open System Settings",

        // Settings
        "Idioma": "Language",
        "General": "General",
        "Ocultar el icono de la barra de menú": "Hide the menu bar icon",
        "Para volver aquí, abre Atajoly otra vez desde Aplicaciones": "To come back here, open Atajoly again from Applications",
        "Actualizaciones": "Updates",
        "Buscar actualizaciones automáticamente": "Check for updates automatically",
        "Al arrancar y una vez al día": "At launch and once a day",
        "Buscar ahora": "Check Now",
        "Cómo se usa": "How to use it",
        "Abre la app que empieza por A, o la asignada a la A": "Opens the app starting with A, or the one assigned to A",
        "Otra vez: su acción (ocultar, siguiente app…)": "Again: its action (hide, next app…)",
        "⇧ izquierdo: abre y oculta las demás · ⇧ derecho: siguiente app": "Left ⇧: open and hide the others · Right ⇧: next app",
        "Asigna la A a la app activa": "Assigns A to the active app",
        "Oculta la app activa": "Hides the active app",

        // Options
        "⌘ derecho": "Right ⌘",
        "⌥ derecho": "Right ⌥",
        "Ocultar la app": "Hide the app",
        "Mostrar sus ventanas (Exposé)": "Show its windows (Exposé)",
        "Pasar a la siguiente app con la misma letra": "Go to the next app with the same letter",
        "Pasar a la siguiente ventana": "Go to the next window",
        "Compacto": "Compact",
        "Amplio": "Comfortable",
        "Tecla liberada": "Key freed",
        "Asignada a %@": "Assigned to %@",

        // Updater
        "Atajoly está actualizado": "Atajoly is up to date",
        "Tienes la última versión (%@).": "You have the latest version (%@).",
        "No se pudo buscar actualizaciones": "Couldn't check for updates",
        "Atajoly %@ está disponible": "Atajoly %@ is available",
        "Tienes la versión %@.": "You have version %@.",
        "Actualizar ahora": "Update Now",
        "Más tarde": "Later",
        "Omitir esta versión": "Skip This Version",
        "No se puede actualizar desde aquí": "Can't update from here",
        "Mueve Atajoly a la carpeta Aplicaciones, ábrela de nuevo y vuelve a intentarlo.": "Move Atajoly to the Applications folder, open it again and try once more.",
        "No se puede actualizar": "Can't update",
        "No hay permiso para escribir en %@.\nUsa el instalador:\n\n%@": "No permission to write to %@.\nUse the installer:\n\n%@",
        "La versión %@ no incluye los archivos de actualización.": "Version %@ doesn't include the update files.",
        "La actualización falló": "The update failed",
        "GitHub no respondió correctamente. Inténtalo más tarde.": "GitHub didn't respond properly. Try again later.",
        "El archivo descargado no coincide con su huella SHA-256. No se ha instalado nada.": "The downloaded file doesn't match its SHA-256 fingerprint. Nothing was installed.",
        "No se pudo descomprimir la actualización.": "Couldn't unzip the update.",
        "La descarga no contiene una versión válida de Atajoly.": "The download doesn't contain a valid version of Atajoly.",
    ]

    static let ca: [String: String] = [
        // Menus
        "Cerrar ventana": "Tanca la finestra",
        "Salir de Atajoly": "Surt d'Atajoly",
        "Edición": "Edició",
        "Deshacer": "Desfés",
        "Rehacer": "Refés",
        "Cortar": "Retalla",
        "Copiar": "Copia",
        "Pegar": "Enganxa",
        "Seleccionar todo": "Selecciona-ho tot",
        "Abrir Atajoly…": "Obre Atajoly…",
        "Pausar atajos": "Pausa les dreceres",
        "Reanudar atajos": "Reprèn les dreceres",
        "Abrir al iniciar sesión": "Obre en iniciar la sessió",
        "Actualizando…": "S'està actualitzant…",
        "Buscar actualizaciones…": "Cerca actualitzacions…",
        "Invítame a un café…": "Convida'm a un cafè…",
        "Sistema": "Sistema",

        // Sidebar
        "Teclado": "Teclat",
        "Comportamiento": "Comportament",
        "Ajustes": "Configuració",
        "En pausa": "En pausa",
        "Activo": "Actiu",
        "Los atajos no hacen nada hasta que los reanudes.": "Les dreceres no fan res fins que les reprenguis.",
        "Mantén %@ y pulsa la inicial de una app.": "Mantén %@ i prem la inicial d'una app.",
        "Versión %@": "Versió %@",

        // Keyboard
        "%@ + letra abre la app; si ya está delante, hace su acción.": "%@ + lletra obre l'app; si ja és al davant, fa la seva acció.",
        "Asignada a mano": "Assignada a mà",
        "Apps abiertas": "Apps obertes",
        "Desactivada": "Desactivada",
        "Asignadas a mano": "Assignades a mà",
        "%@ + %@ + letra asigna la app activa": "%@ + %@ + lletra assigna l'app activa",
        "Ninguna todavía. Elige una tecla en el teclado y asígnale una app, aunque no esté abierta.": "Encara cap. Tria una tecla al teclat i assigna-li una app, encara que no estigui oberta.",
        "Quitar": "Treu",
        "Apps sin letra automática": "Apps sense lletra automàtica",
        "Volver a incluir": "Torna a incloure",
        "Elige una tecla": "Tria una tecla",
        "Tecla %@": "Tecla %@",
        "Desactivar esta tecla": "Desactiva aquesta tecla",
        "%@ + %@ vuelve a funcionar como siempre": "%@ + %@ torna a funcionar com sempre",
        "App asignada": "App assignada",
        "Abierta": "Oberta",
        "Se abrirá al pulsar": "S'obrirà en prémer",
        "Si ya está delante": "Si ja és al davant",
        "Ninguna: la tecla va a las apps abiertas que empiezan por %@.": "Cap: la tecla va a les apps obertes que comencen per %@.",
        "Asignar app…": "Assigna una app…",
        "Cambiar app…": "Canvia l'app…",
        "Apps abiertas con la %@": "Apps obertes amb la %@",
        "Ninguna abierta ahora.": "Cap d'oberta ara.",
        "Asignar a la %@": "Assigna a la %@",
        "No darle letra automática": "No li donis lletra automàtica",
        "Al pulsar la tecla otra vez se pasa a la siguiente.": "Si tornes a prémer la tecla, passa a la següent.",
        "Abiertas": "Obertes",
        "Instaladas": "Instal·lades",
        "Otra app…": "Una altra app…",

        // Behaviour
        "Tecla de activación": "Tecla d'activació",
        "Solo la tecla derecha: la izquierda sigue haciendo los atajos de siempre.": "Només la tecla dreta: l'esquerra continua fent les dreceres de sempre.",
        "Si la app ya está delante": "Si l'app ja és al davant",
        "Para las letras automáticas. Las asignadas a mano tienen su propia opción en Teclado.": "Per a les lletres automàtiques. Les assignades a mà tenen la seva pròpia opció a Teclat.",
        "Traer todas las ventanas de la app": "Porta totes les finestres de l'app",
        "No solo la última que usaste": "No només l'última que vas fer servir",
        "Al pasar de app, saltar la asignada a mano": "En passar d'app, salta l'assignada a mà",
        "Recorre solo las apps abiertas con esa letra": "Recorre només les apps obertes amb aquesta lletra",
        "Teclas añadidas": "Tecles afegides",
        "%@ + ⇧ izquierdo + letra: ocultar las demás": "%@ + ⇧ esquerre + lletra: amaga les altres",
        "Abre la app y oculta todas las otras": "Obre l'app i amaga totes les altres",
        "Ocultar siempre las demás apps": "Amaga sempre les altres apps",
        "Sin tener que añadir ⇧ izquierdo": "Sense haver d'afegir ⇧ esquerre",
        "%@ + ⇧ derecho + letra: siguiente app": "%@ + ⇧ dret + lletra: app següent",
        "Pasa a la siguiente app con la misma letra": "Passa a la següent app amb la mateixa lletra",
        "%@ + %@ + letra: asignar": "%@ + %@ + lletra: assigna",
        "Da la letra a la app activa; otra vez la libera": "Dona la lletra a l'app activa; un altre cop l'allibera",
        "Mostrar el mapa de teclas": "Mostra el mapa de tecles",
        "Al mantener la tecla de activación": "En mantenir la tecla d'activació",
        "Esperar": "Espera",
        "Tecla para ocultar": "Tecla per amagar",
        "Ninguna": "Cap",
        "Sin tecla para ocultar.": "Sense tecla per amagar.",
        "%@ + %@ oculta la app activa; con ⇧, todas las demás.": "%@ + %@ amaga l'app activa; amb ⇧, totes les altres.",
        "Ventanas": "Finestres",
        "Permiso concedido": "Permís concedit",
        "Sin permiso": "Sense permís",
        "«Pasar a la siguiente ventana» necesita permiso de Accesibilidad. Lo demás funciona sin él.": "«Passa a la finestra següent» necessita permís d'Accessibilitat. La resta funciona sense.",
        "Pedir permiso": "Demana permís",
        "Abrir Ajustes del Sistema": "Obre la Configuració del Sistema",

        // Settings
        "Idioma": "Idioma",
        "General": "General",
        "Ocultar el icono de la barra de menú": "Amaga la icona de la barra de menús",
        "Para volver aquí, abre Atajoly otra vez desde Aplicaciones": "Per tornar aquí, obre Atajoly un altre cop des d'Aplicacions",
        "Actualizaciones": "Actualitzacions",
        "Buscar actualizaciones automáticamente": "Cerca actualitzacions automàticament",
        "Al arrancar y una vez al día": "En obrir-se i un cop al dia",
        "Buscar ahora": "Cerca ara",
        "Cómo se usa": "Com es fa servir",
        "Abre la app que empieza por A, o la asignada a la A": "Obre l'app que comença per A, o l'assignada a la A",
        "Otra vez: su acción (ocultar, siguiente app…)": "Un altre cop: la seva acció (amagar, app següent…)",
        "⇧ izquierdo: abre y oculta las demás · ⇧ derecho: siguiente app": "⇧ esquerre: obre i amaga les altres · ⇧ dret: app següent",
        "Asigna la A a la app activa": "Assigna la A a l'app activa",
        "Oculta la app activa": "Amaga l'app activa",

        // Options
        "⌘ derecho": "⌘ dret",
        "⌥ derecho": "⌥ dret",
        "Ocultar la app": "Amaga l'app",
        "Mostrar sus ventanas (Exposé)": "Mostra les seves finestres (Exposé)",
        "Pasar a la siguiente app con la misma letra": "Passa a la següent app amb la mateixa lletra",
        "Pasar a la siguiente ventana": "Passa a la finestra següent",
        "Compacto": "Compacte",
        "Amplio": "Ampli",
        "Tecla liberada": "Tecla alliberada",
        "Asignada a %@": "Assignada a %@",

        // Updater
        "Atajoly está actualizado": "Atajoly està actualitzat",
        "Tienes la última versión (%@).": "Tens l'última versió (%@).",
        "No se pudo buscar actualizaciones": "No s'han pogut cercar actualitzacions",
        "Atajoly %@ está disponible": "Atajoly %@ està disponible",
        "Tienes la versión %@.": "Tens la versió %@.",
        "Actualizar ahora": "Actualitza ara",
        "Más tarde": "Més tard",
        "Omitir esta versión": "Omet aquesta versió",
        "No se puede actualizar desde aquí": "No es pot actualitzar des d'aquí",
        "Mueve Atajoly a la carpeta Aplicaciones, ábrela de nuevo y vuelve a intentarlo.": "Mou Atajoly a la carpeta Aplicacions, torna-la a obrir i torna-ho a provar.",
        "No se puede actualizar": "No es pot actualitzar",
        "No hay permiso para escribir en %@.\nUsa el instalador:\n\n%@": "No hi ha permís per escriure a %@.\nFes servir l'instal·lador:\n\n%@",
        "La versión %@ no incluye los archivos de actualización.": "La versió %@ no inclou els fitxers d'actualització.",
        "La actualización falló": "L'actualització ha fallat",
        "GitHub no respondió correctamente. Inténtalo más tarde.": "GitHub no ha respost correctament. Torna-ho a provar més tard.",
        "El archivo descargado no coincide con su huella SHA-256. No se ha instalado nada.": "El fitxer baixat no coincideix amb la seva empremta SHA-256. No s'ha instal·lat res.",
        "No se pudo descomprimir la actualización.": "No s'ha pogut descomprimir l'actualització.",
        "La descarga no contiene una versión válida de Atajoly.": "La baixada no conté una versió vàlida d'Atajoly.",
    ]
}
