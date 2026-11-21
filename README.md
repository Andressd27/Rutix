# Rutix

Aplicación móvil en **Flutter** para seguir rutas de transporte en un mapa: inicio de sesión con usuarios de demostración, mapa con la ubicación del usuario (OpenStreetMap) y seguimiento de rutas.

## Tecnologías

| Paquete | Versión | Uso |
|---|---|---|
| [material_ui](https://pub.dev/packages/material_ui) | ^1.11.1 | Widgets Material (reemplaza a `package:flutter/material.dart`, obsoleto desde Flutter 3.47) |
| [flutter_map](https://pub.dev/packages/flutter_map) | 7.0.2 | Mapa con teselas de OpenStreetMap |
| [latlong2](https://pub.dev/packages/latlong2) | 0.9.1 | Coordenadas y cálculo de distancias |
| [geolocator](https://pub.dev/packages/geolocator) | 13.0.2 | Ubicación GPS del dispositivo |

No requiere API keys: los mapas se cargan desde `tile.openstreetmap.org`, así que el dispositivo necesita conexión a internet.

## Requisitos

- **Flutter SDK** compatible con Dart `^3.13.3` (probado con Flutter 3.50.1 / Dart 3.14.0). Los widgets Material se importan desde `package:material_ui/material_ui.dart`, no desde `package:flutter/material.dart`.
- **Android:** Android Studio con Android SDK y un emulador o un teléfono con *Depuración USB* activada.
- **iOS** (solo en macOS): Xcode y CocoaPods.
- **Web:** Google Chrome o Edge.
- **Windows:** activar el **Modo de desarrollador** (Configuración → Sistema → Para programadores). Flutter lo necesita para crear los enlaces simbólicos de los plugins (`geolocator`); sin él, las compilaciones para Android y escritorio fallan.

Comprueba el entorno con:

```powershell
flutter doctor
```

## Instalación

```powershell
git clone <url-del-repositorio>
cd Rutix
flutter pub get
```

## Ejecutar en desarrollo

Lista los dispositivos disponibles y ejecuta la app en uno de ellos:

```powershell
flutter devices
```

```powershell
flutter run
```

Para elegir un dispositivo concreto: `flutter run -d chrome`, `flutter run -d emulator-5554`, etc.

### Usuarios de demostración

| Rol | Correo | Contraseña |
|---|---|---|
| Trabajador | `trabajador@rutix.com` | `1234` |
| Conductor | `conductor@rutix.com` | `1234` |

### Permisos de ubicación

La app pide permiso de ubicación al abrir el mapa. Ya están declarados en `android/app/src/main/AndroidManifest.xml` (`ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `INTERNET`) y en `ios/Runner/Info.plist`. En el emulador de Android puedes simular la posición desde *Extended controls → Location*.

## Despliegue

### Android (APK)

```powershell
flutter build apk --release
```

El archivo queda en `build/app/outputs/flutter-apk/app-release.apk`. Para instalarlo en un teléfono conectado:

```powershell
flutter install
```

Para publicar en Google Play, genera un App Bundle:

```powershell
flutter build appbundle --release
```

> Antes de publicar en Play Store:
> 1. Cambia el `applicationId` (`com.example.rutix`) en `android/app/build.gradle.kts`.
> 2. Configura una firma propia: ahora el build `release` se firma con la clave de depuración. Ver [Firmar la app](https://docs.flutter.dev/deployment/android#sign-the-app).

### Web

```powershell
flutter build web --release
```

El resultado queda en `build/web/` y se puede subir a cualquier hosting estático (Firebase Hosting, Netlify, GitHub Pages, etc.). Para servirlo en una subruta, usa `--base-href /ruta/`. La geolocalización en el navegador solo funciona sobre **HTTPS** (o `localhost`).

### iOS (solo macOS)

```bash
flutter build ipa --release
```

Requiere una cuenta de Apple Developer y configurar el *Bundle Identifier* y el equipo de firma en Xcode (`ios/Runner.xcworkspace`).

## Pruebas y análisis

```powershell
flutter test
```

```powershell
flutter analyze
```

## Estructura

```
lib/
├── main.dart              # Punto de entrada (RutixApp)
├── login_page.dart        # Inicio de sesión con usuarios demo
├── home_shell.dart        # Navegación principal
├── inicio_page.dart       # Pantalla de inicio
├── mapa_page.dart         # Mapa y seguimiento en vivo
├── mis_rutas_page.dart    # Rutas del usuario
├── config_page.dart       # Configuración / cerrar sesión
├── models.dart            # Modelos y datos de demostración
├── tracking_service.dart  # Seguimiento de la ruta
└── ubicacion_service.dart # Acceso al GPS (geolocator)
```
