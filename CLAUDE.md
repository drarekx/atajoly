# Atajoly

App de macOS (barra de menú) para cambiar de app con ⌘ derecho + letra. Swift + AppKit/SwiftUI, sin dependencias externas. Misma estructura y estilo que Wallpy (`../wallpapers`). Repo: https://github.com/drarekx/atajoly (público).

Nació como réplica limpia (clean-room) de `rcmd.app` 2.7.1 (`com.lowtechguys.rcmd`) analizada con REA; no se copia nada de su binario ni de sus recursos. Lo observado en rcmd: hot keys de Carbon (`RegisterEventHotKey`) que solo existen mientras ⌘ derecho está pulsado, detección del lado de la tecla con `NSEvent` global/local de `flagsChanged`, distribución de teclado con TIS/`UCKeyTranslate`, activación `activate(options:)` + `activate(from: .current, options:)` + `unhide()`, y modelo `{key, app, whenAlreadyFocusedAction: hide|expose|cycleApps|cycleWindows}`. Las ventanas en rcmd van por Hammerspoon; aquí, por Accesibilidad (`AXUIElement`).

## Compilar y ejecutar

```sh
swift build                      # debug, comprobación rápida
./build-app.sh                   # release universal (arm64 + x86_64) → build/Atajoly.app + build/Atajoly.zip
VERSION=1.1.0 ./build-app.sh     # versión en Info.plist (por defecto 1.0.0)
open build/Atajoly.app
```

- Requisitos: macOS 14+, Xcode 16+. `Package.swift` usa tools 5.10 (modo Swift 5).
- No hay tests. Verificar compilando (`swift build -c release --arch arm64 --arch x86_64`) y lanzando la app.
- **No abrir dos copias ni tener rcmd abierto**: el primero que registra ⌘ + letra se la queda (`RegisterEventHotKey` falla en el otro).

## GitHub

Igual que Wallpy: `main` protegida, PR con squash y comprobación `build` (`.github/workflows/build.yml`: compila arm64 + x86_64 y verifica que `en` y `ca` tienen las mismas claves y que todo `tr()` está traducido). Versión: `git tag vX.Y.Z && git push origin vX.Y.Z` → `release.yml` publica `Atajoly.zip` + `.sha256`; `Updater.swift` actualiza las copias instaladas.

## Estructura (`Sources/Atajoly/`)

| Archivo | Qué hace |
|---|---|
| `main.swift`, `AppDelegate.swift` | Arranque, app accesoria (`LSUIElement`), menú de barra, menú principal oculto (Edición), ventana principal |
| `Switcher.swift` | Vigila el modificador derecho (bits de dispositivo de `modifierFlags`), registra/quita hot keys y ejecuta las acciones (abrir, ciclar, ocultar, asignar) |
| `HotkeyCenter.swift` | Envoltorio de las hot keys de Carbon |
| `KeyboardLayout.swift` | Carácter ↔ código de tecla según la distribución actual; filas físicas para el teclado visual |
| `AppCatalog.swift` | `AppRef`, `StaticAssignment`, apps abiertas, uso (orden de las que comparten letra), apps instaladas, iconos |
| `Windows.swift` | Accesibilidad (ciclar ventanas), Exposé (`CoreDockSendNotification` por `dlsym`), ventanas visibles por PID |
| `SwitcherPanel.swift` | Panel flotante: mapa de teclas al mantener el modificador y aviso al asignar |
| `MainView.swift` | Ventana: barra lateral, Teclado (mapa + inspector), Comportamiento, Ajustes |
| `Settings.swift` | `UserDefaults` (`com.egluu.atajoly`) y login item (`SMAppService`) |
| `Theme.swift` | Colores y controles (copia del de Wallpy con prefijo `Atajoly`) |
| `Updater.swift` | Autoactualización desde GitHub Releases con SHA-256 |
| `Localization.swift` | Idiomas (en, es, ca): `tr()`, `Localizer`, tablas |

## Convenciones

- Código, comentarios y commits en inglés. Interfaz en castellano, inglés y catalán.
- **Todo texto visible pasa por `tr("…")`**; la clave es el castellano y va en las tablas `en` y `ca` con los mismos `%@`/`%d`. Nunca interpolar dentro de un texto traducible.
- Estilo: usar `Theme` y sus componentes (`AtajolyButtonStyle`, `SegmentedControl`, `SwitchRow`, `atajolyCard`…), nunca colores sueltos.
- Tipos `@MainActor` para estado de UI. Los callbacks de Carbon y `NSEvent` llegan en el hilo principal: `MainActor.assumeIsolated`.
- Mantener el README al día cuando cambian funciones visibles.

## Cosas que ya costaron (no repetir)

- **Activar otra app en macOS 14+**: `activate(options:)` solo no basta (activación cooperativa). Hay que llamar también a `activate(from: .current, options:)`, como rcmd.
- Si la app no tiene ventanas visibles en el Space actual, se usa `NSWorkspace.openApplication` (equivale a pulsar en el Dock: desminimiza o abre ventana).
- **Lado de la tecla**: ⌘ derecho = bit `0x10` de `modifierFlags.rawValue`, izquierdo `0x08`; ⇧ izq. `0x02`, der. `0x04`; ⌥ izq. `0x20`, der. `0x40`. Carbon no distingue lados: se mira `deviceFlags` al disparar.
- En AZERTY los números no salen sin ⇧: `KeyboardLayout.keyCode(for:)` cae a la fila numérica ANSI.
- Cada build ad-hoc cambia la firma: el permiso de Accesibilidad hay que volver a darlo tras recompilar.

## Pruebas manuales

- Se puede simular la pulsación con `CGEvent` (`flagsChanged` en la tecla 54 con flags `maskCommand | 0x10`, luego la letra con los mismos flags). La terminal necesita permiso de Accesibilidad.
- Para saber qué app está delante, usar `lsappinfo info -only name $(lsappinfo front)`: `NSWorkspace.frontmostApplication` en un script sin run loop devuelve un valor viejo.
- Las asignaciones reales del usuario están en `defaults read com.egluu.atajoly`: si una prueba las toca, `defaults export com.egluu.atajoly` antes y restaurar después.
