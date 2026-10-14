# Atajoly

Cambia de app con el pulgar. Mantén **⌘ derecho** y pulsa la inicial de una app: se pone delante. Si ya lo estaba, se oculta o pasa a la siguiente app con la misma letra. Vive en la barra de menú.

## Instalar

Abre Terminal y pega:

```sh
curl -fsSL https://raw.githubusercontent.com/drarekx/atajoly/main/install.sh | bash
```

El instalador descarga la última versión, la copia en `/Applications` y la abre. Atajoly se actualiza sola (al arrancar y una vez al día, o desde el menú → **Buscar actualizaciones…**) y comprueba cada descarga con su SHA-256.

**Instalación manual:** descarga `Atajoly.zip` de [Releases](https://github.com/drarekx/atajoly/releases/latest), descomprímelo y mueve `Atajoly.app` a Aplicaciones. No está notarizada por Apple: la primera vez, clic derecho → **Abrir**.

Requisitos: macOS 14 (Sonoma) o posterior. Apple Silicon o Intel. Si usas rcmd, ciérralo: los dos usan ⌘ derecho.

## Qué hace

| Atajo | Acción |
|---|---|
| ⌘ derecho + letra | Abre la app que empieza por esa letra (o la que le hayas asignado) |
| Otra vez | Su acción: ocultarla, pasar a la siguiente app con la misma letra, Exposé o siguiente ventana |
| ⌘ derecho + ⇧ izquierdo + letra | Abre la app y oculta todas las demás |
| ⌘ derecho + ⇧ derecho + letra | Siempre a la siguiente app con esa letra |
| ⌘ derecho + ⌥ + letra | Asigna la letra a la app activa (otra vez la libera) |
| ⌘ derecho + − | Oculta la app activa; con ⇧, todas las demás |

- **Letras automáticas**: cada app abierta tiene la letra de su nombre («Google Chrome» va a la C). Si varias comparten letra, la más usada va primero.
- **Asignaciones a mano**: una tecla para una app concreta, aunque no esté abierta (se abre al pulsar). Cada una con su acción para cuando ya está delante.
- **Teclado visual** con el icono de cada tecla, adaptado a tu distribución (QWERTY, AZERTY…). Desde ahí se asigna, se desactiva una tecla (para que ⌘ derecho + C siga copiando, por ejemplo) o se quita una app de las letras automáticas.
- **Mapa de teclas** en pantalla al mantener ⌘ derecho, compacto o amplio.
- Se puede usar **⌥ derecho** en lugar de ⌘ derecho.
- **Sin permisos** para cambiar de app. Solo «pasar a la siguiente ventana» pide Accesibilidad.
- **Idiomas**: castellano, inglés y catalán.

## Dónde guarda las cosas

- Ajustes y asignaciones: `defaults read com.egluu.atajoly`

## Desinstalar

```sh
osascript -e 'quit app "Atajoly"'
rm -rf /Applications/Atajoly.app
defaults delete com.egluu.atajoly
```

## Compilar desde el código

Necesitas Xcode 16 o posterior.

```sh
git clone https://github.com/drarekx/atajoly.git
cd atajoly
./build-app.sh          # deja build/Atajoly.app y build/Atajoly.zip
open build/Atajoly.app
```

Para publicar una versión nueva, crea y sube una etiqueta; GitHub Actions compila la app y crea el release con el zip:

```sh
git tag v1.0.1 && git push origin v1.0.1
```
