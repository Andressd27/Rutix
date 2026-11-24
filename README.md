# Rutix

Aplicación móvil en **Flutter + Firebase** para el seguimiento del transporte empresarial. El conductor comparte la ubicación del vehículo en tiempo real, el trabajador ve en el mapa cuánto falta para que llegue a su parada y recibe un aviso cuando está a 1 km o menos, y el administrador gestiona rutas, usuarios y asignaciones.

## Roles

Cada rol tiene **su propia interfaz, navegación y color**, y una insignia visible en la barra superior para que nunca haya duda de con qué cuenta se está trabajando:

| Rol | Color | Qué ve y qué hace |
|---|---|---|
| 🟢 **Trabajador** | Verde `#007A55` | Inicio con el tiempo estimado de llegada · Mapa con el vehículo y su parada · **Mi QR** de abordaje y su ruta · Avisos · Perfil |
| 🔵 **Conductor** | Azul `#1D4ED8` | Mi recorrido (iniciar con GPS, simular o finalizar) · **Abordaje** (escanear QR y conteo del día) · Mi ruta · Perfil |
| 🟣 **Administrador** | Morado `#6D28D9` | Rutas con su recorrido en vivo · **Abordajes** ("X de Y" por ruta y fecha) · Usuarios (asignar rol, ruta y parada) · Perfil |

- Toda cuenta nueva se registra como **trabajador**. Solo un administrador puede convertirla en conductor o administrador; las reglas de Firestore lo impiden desde cualquier otro lugar.
- Cada trabajador y cada conductor solo pueden leer **su propia ruta** y su recorrido.

## Tecnologías

| Paquete | Uso |
|---|---|
| `firebase_core`, `firebase_auth` | Inicio de sesión y registro. Las contraseñas las guarda Firebase cifradas. |
| `cloud_firestore` | Base de datos en la nube en tiempo real: usuarios, rutas y recorridos |
| `flutter_local_notifications` | Aviso de proximidad generado en el propio teléfono, **sin costo** (no usa Cloud Functions) |
| `connectivity_plus` | Aviso de "Sin conexión" |
| `geolocator` | GPS del conductor y ubicación del usuario |
| `flutter_map` + `latlong2` | Mapa con teselas de OpenStreetMap (sin API key) |
| `http` + [OSRM](https://project-osrm.org) | Trazado por calles de cada ruta y velocidad media para el tiempo estimado (servidor público, gratis y sin clave) |
| `material_ui` | Widgets Material (reemplaza a `package:flutter/material.dart`, obsoleto desde Flutter 3.47) |

Todo funciona con el **plan gratuito (Spark)** de Firebase.

## Requisitos

- **Flutter 3.47 o superior** (probado con Flutter 3.50.1 / Dart 3.14.0).
- **Node.js** (para la CLI de Firebase).
- **Android:** Android Studio con Android SDK y un emulador o un teléfono con *Depuración USB*. En **Android Studio → Settings → Languages & Frameworks → Android SDK** deben estar instalados:
  - Pestaña *SDK Platforms*: **Android 37** (el proyecto compila con `compileSdk = 37`, que exigen las notificaciones).
  - Pestaña *SDK Tools*: **NDK (Side by side) 30.0.16248370** (marca *Show Package Details* para elegir la versión).
  - El proyecto usa Android Gradle Plugin 9.1.1 y Gradle 9.5.0; se descargan solos la primera vez.
- **Web:** Google Chrome o Edge.
- **Windows:** activar el **Modo de desarrollador** (Configuración → Sistema → Para programadores). Flutter lo necesita para los plugins; sin él, las compilaciones para Android fallan.

```powershell
flutter doctor
```

## Instalación

```powershell
git clone https://github.com/Andressd27/Rutix.git
cd Rutix
flutter pub get
```

## Configurar Firebase (una sola vez)

Mientras Firebase no esté configurado, la app abre una pantalla de error que dice *"No se pudo conectar con Firebase"*.

### 1. Instalar las herramientas

```powershell
npm install -g firebase-tools
```

```powershell
dart pub global activate flutterfire_cli
```

### 2. Crear el proyecto en Firebase

1. Entra a [console.firebase.google.com](https://console.firebase.google.com) y crea un proyecto (por ejemplo `rutix-uts`). Google Analytics no es necesario.
2. **Authentication → Comenzar → Método de acceso →** habilita **Correo electrónico/contraseña**.
3. **Firestore Database → Crear base de datos →** modo **producción**, ubicación cercana (por ejemplo `southamerica-east1`).

### 3. Conectar la app al proyecto

```powershell
firebase login
```

```powershell
dart pub global run flutterfire_cli:flutterfire configure --platforms=android,web
```

Elige el proyecto que creaste. El comando genera `lib/firebase_options.dart` y `android/app/google-services.json`, y registra la app Android con el identificador `co.edu.uts.rutix`.

### 4. Publicar las reglas de seguridad

```powershell
firebase use --add
```

```powershell
firebase deploy --only firestore:rules
```

También puedes copiar el contenido de [`firestore.rules`](firestore.rules) en **Firestore → Reglas → Publicar**.

### 5. Crear el primer administrador

1. Ejecuta la app y pulsa **"¿Eres trabajador nuevo? Crea tu cuenta"**.
2. En la consola de Firebase, abre **Firestore → `usuarios` →** el documento de esa cuenta y cambia el campo `rol` de `trabajador` a `admin`.
3. La app cambia sola a la interfaz morada de administrador. En **Rutas**, pulsa **"Cargar rutas de ejemplo"**.

### 6. Crear conductores y trabajadores

1. Registra más cuentas desde la app (todas empiezan como trabajador).
2. Como administrador, en **Usuarios** toca cada cuenta y asígnale:
   - **Conductor** + la ruta que conduce, o
   - **Trabajador** + su ruta + su parada de recogida.

## Ejecutar

```powershell
flutter run -d chrome
```

```powershell
flutter run
```

### Demostración con dos dispositivos

1. **Teléfono o emulador:** inicia sesión como **conductor** → *Mi recorrido* → **Iniciar recorrido (GPS)** o **Simular recorrido (demo)**.
2. **Navegador (`flutter run -d chrome`) u otro teléfono:** inicia sesión como **trabajador** de la misma ruta. El vehículo se mueve en el mapa, el tiempo estimado baja y, al quedar a 1 km o menos de la parada, llega **una** notificación.
3. El conductor ve en su panel la línea *"Servidor: ubicación compartida (…)"* con lo que realmente quedó guardado en Firestore. Al finalizar, cambia a *"recorrido inactivo · ubicación no compartida"*.

> **Sobre las notificaciones:** se generan en el teléfono del trabajador mientras la app está abierta o en segundo plano reciente. Así no hace falta servidor ni el plan de pago *Blaze*. Si el sistema cierra la app, el aviso no llega hasta que se vuelva a abrir.

### Prueba del QR de abordaje (RF-05 y RF-06)

1. **Trabajador:** pestaña **Mi QR**. Muestra su código único y el estado *"Hoy todavía no registras abordaje"*.
2. **Conductor:** pestaña **Abordaje** → **Escanear QR del trabajador** y apunta la cámara al código. En el computador, sin cámara, usa **Ingresar código manualmente** y pega el texto del QR (`rutix:v1:…`).
3. Resultado esperado:
   - QR válido → **"Abordaje registrado"** y el trabajador ve *"Abordaste hoy a las HH:MM"*.
   - El mismo QR otra vez → **"Este trabajador ya abordó hoy"**.
   - Un QR inventado o de una asignación anterior → **"Código QR no válido"**.
   - Un trabajador de otra ruta → **"Este trabajador no está asignado a tu ruta"**.
4. **Administrador:** pestaña **Abordajes** → cada ruta muestra **"Abordaron X de Y"**, quién subió y a qué hora y quién falta. Se puede cambiar la fecha.

> El código QR se genera cuando el administrador asigna la ruta a un trabajador. A los trabajadores asignados antes de que existiera el QR se les genera **automáticamente** la próxima vez que un administrador abra la app (aparece el aviso *"Se generó el código QR de N trabajadores"*).

## Trazado por calles (OSRM)

El recorrido no se dibuja en línea recta entre paradas: se usa el camino real por calles que calcula [OSRM](https://project-osrm.org), con los mismos datos de OpenStreetMap que el mapa.

- **Se calcula una sola vez por ruta** y se guarda en Firestore (`caminoPolilinea`). Lo hace la app del administrador al cargar las rutas o al abrirse, si a alguna ruta le falta. Las demás pantallas no consultan OSRM, así se respeta el límite del servidor público (1 consulta por segundo).
- En **Rutas**, cada ruta muestra su distancia y duración por calles, y un botón para **recalcular** el trazado.
- **Tiempo estimado (RF-03):** se usa la distancia que falta **por la vía** hasta la parada y la velocidad media de la ruta según OSRM.
- La app **sigue al vehículo hacia adelante** sobre el camino, así no se confunde cuando la ruta pasa dos veces por la misma vía. Cuando el vehículo deja atrás la parada, el trabajador ve *"El vehículo ya pasó por tu parada"*.
- La simulación del conductor recorre el camino por calles.
- Si OSRM no responde, la ruta sigue funcionando con líneas rectas.

> OSRM calcula por dónde se puede ir, no por dónde va realmente el conductor, y no considera el tráfico en vivo. Con el GPS real, el marcador del vehículo siempre muestra la posición verdadera.

## Modelo de datos (Firestore)

```
usuarios/{uid}          nombre, correo, rol (trabajador|conductor|admin), rutaId, paradaIdx, codigoQr
rutas/{rutaId}          nombre, turno, placa, conductorUid, conductorNombre, paradas[{nombre, lat, lng, hora}],
                        caminoPolilinea, distanciaMetros, duracionSegundos   (trazado por calles de OSRM)
  ├─ pasajeros/{uid}     nombre, paradaIdx, token            (asignados; base del QR y de "X de Y")
  └─ abordajes/{fecha}_{uid}  uid, nombre, token, fecha, hora, conductorUid, conductorNombre
recorridos/{rutaId}     activo, conductorUid, conductorNombre, ubicacion (GeoPoint), inicio, actualizado, fin, simulado
```

## Despliegue

### Android (APK)

```powershell
flutter build apk --release
```

El archivo queda en `build/app/outputs/flutter-apk/app-release.apk`. Para instalarlo en un teléfono conectado:

```powershell
flutter install
```

> Antes de publicar en Play Store, configura una firma propia: ahora el build `release` se firma con la clave de depuración. Ver [Firmar la app](https://docs.flutter.dev/deployment/android#sign-the-app).

### Web

```powershell
flutter build web --release
```

El resultado queda en `build/web/`. Se puede publicar gratis en Firebase Hosting (`firebase init hosting` y luego `firebase deploy --only hosting`). La geolocalización y las notificaciones del navegador solo funcionan sobre **HTTPS** (o `localhost`).

## Pruebas y análisis

```powershell
flutter test
```

```powershell
flutter analyze
```

Las pruebas de `test/` están ligadas a los requisitos: roles y colores (RF-01), cálculo del tiempo estimado (RF-03), aviso único a ≤ 1 km (RF-04), login sin credenciales visibles (RNF-03), estado del recorrido (RNF-04), validación del QR (RF-05), resumen "3 de 5" (RF-06) y contraste ≥ 4.5:1 y texto ≥ 14 sp (RNF-05).

## Estructura

```
lib/
├── main.dart                  # Arranque: Firebase y elección de interfaz según el rol
├── firebase_options.dart      # Lo genera `flutterfire configure`
├── core/                      # Roles, tema por rol y cálculos geográficos
├── models/                    # Usuario, Ruta, Recorrido
├── data/datos_ejemplo.dart    # Rutas de ejemplo para cargar desde el admin
├── services/                  # Auth, sesión, Firestore, GPS del conductor,
│                              # seguimiento del trabajador, notificaciones, conectividad
├── screens/
│   ├── login_page.dart, registro_page.dart
│   ├── trabajador/            # Interfaz verde
│   ├── conductor/             # Interfaz azul
│   └── admin/                 # Interfaz morada
└── widgets/                   # Mapa compartido, barra e insignia de rol, aviso de conexión
firestore.rules                # Reglas de seguridad por rol y por ruta
```
