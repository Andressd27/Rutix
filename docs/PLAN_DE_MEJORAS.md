# Rutix — Plan de mejoras

Base: *Especificación de requisitos* (19/11/2026), *Documento final* (objetivo, funcionamiento, Gantt) y revisión del código actual (`lib/`, 21/11/2026).

## 1. Diagnóstico: requisitos frente a la implementación actual

| Req. | Qué pide | Estado actual | Cumple |
|---|---|---|---|
| RF-01 | Login con 3 roles (trabajador, conductor, administrador), color distinto por rol, error con clave incorrecta | Solo 2 roles, usuarios fijos en `models.dart`, un único color (`#16C08A`). El error sí se muestra. | ⚠️ Parcial |
| RF-02 | Conductor inicia/finaliza recorrido y envía GPS **al servidor** | Inicia/finaliza y lee el GPS, pero la posición vive en memoria (`TrackingService`). No hay servidor: el trabajador solo la ve si usa **el mismo teléfono**. | ❌ |
| RF-03 | Trabajador ve el vehículo en el mapa y el tiempo estimado de llegada (ETA) | Marcador y ETA existen, pero solo en el mismo dispositivo. ETA = línea recta ÷ 25 km/h. | ⚠️ Parcial |
| RF-04 | **Notificación push** a ≤ 1 km, una sola vez | Solo un banner dentro de la app, con umbral de **300 m**. Sin push. | ❌ |
| RF-05 | QR único por trabajador; el conductor lo escanea; se rechazan duplicados e inválidos | No existe. | ❌ |
| RF-06 | Administrador ve por ruta y fecha "abordaron X de Y" | No existe (no hay rol administrador). | ❌ |
| RNF-01 | Ver el vehículo en ≤ 3 toques desde inicio | 1 toque (pestaña *Mapa* o botón *Ver en el mapa*). | ✅ |
| RNF-02 | Aviso sin internet y reconexión automática | No se detecta la conexión. | ❌ |
| RNF-03 | Contraseñas cifradas, HTTPS, cada rol solo accede a lo suyo | Contraseñas en texto plano en el código **y mostradas en la pantalla de login**. Sin control por rol. | ❌ |
| RNF-04 | Ubicación solo con recorrido activo; trabajador solo ve **su** ruta | La primera parte se cumple. *Mis rutas* muestra **todas** las rutas a cualquier usuario. | ⚠️ Parcial |
| RNF-05 | Contraste ≥ 4.5:1 y texto ≥ 14 sp | Texto blanco sobre `#16C08A` = **2.35:1**; gris `Colors.grey` sobre blanco = **2.68:1**; textos de 12–13 sp en el mapa. | ❌ |

**Resultado: 1 de 11 requisitos cumplidos, 3 parciales y 7 sin cumplir.** El mayor bloqueo es que **no hay backend**: RF-02, RF-03, RF-04, RF-06, RNF-03 y RNF-04 dependen de él.

También faltan cosas que el *Documento final* promete:
- registro del trabajador ("el trabajador crea su cuenta");
- panel administrativo (usuarios, vehículos, rutas, paradas y asignaciones);
- API de rutas para el ETA;
- base de datos en la nube;
- modo oscuro y pantalla de *Alertas* del prototipo Figma.

## 2. Decisión técnica clave: backend

**Recomendación: Firebase.** Cubre casi todo lo pendiente con poco código de servidor:

| Necesidad | Servicio Firebase | Requisito que resuelve |
|---|---|---|
| Login y contraseñas cifradas | Firebase Auth (guarda las claves con hash; nunca en texto plano) | RF-01, RNF-03 |
| Rol del usuario | Documento `usuarios/{uid}.rol` en Firestore | RF-01 |
| Ubicación en tiempo real | Firestore `recorridos/{id}` con *snapshots* | RF-02, RF-03 |
| Caché sin conexión y reconexión | Persistencia offline de Firestore + `connectivity_plus` | RNF-02 |
| Acceso por rol y por ruta | *Security Rules* de Firestore | RNF-03, RNF-04 |
| Push a ≤ 1 km | Firebase Cloud Messaging + Cloud Function al escribir la ubicación | RF-04 |
| HTTPS | Todo el tráfico de Firebase va por TLS | RNF-03 |

> ⚠️ Las Cloud Functions requieren el plan *Blaze* (pide tarjeta, pero tiene cuota gratuita amplia). Sin él, hay una alternativa: el teléfono del trabajador escucha la ubicación y lanza una **notificación local** (`flutter_local_notifications`) al cruzar 1 km. Es más simple, pero solo funciona con la app abierta o en segundo plano reciente. Decidir esto con el docente.

La alternativa sería Supabase (Postgres, *Row Level Security*, Realtime). Es igual de válida, pero las notificaciones push son más laboriosas.

### Modelo de datos propuesto (Firestore)

```
usuarios/{uid}        nombre, correo, rol, rutaId, paradaIdx, activo
vehiculos/{placa}     placa, capacidad, conductorUid
rutas/{rutaId}        nombre, turno, conductorUid, placa, paradas[{nombre, lat, lng, hora}]
asignaciones/{rutaId_fecha}  trabajadores[uid]          // base de "X de Y"
recorridos/{id}       rutaId, conductorUid, estado(activo|finalizado), inicio, fin,
                      ubicacion{lat,lng,ts}, notificados[uid]
abordajes/{rutaId_fecha_uid}  uid, rutaId, fecha, hora, recorridoId   // id compuesto = sin duplicados
```

## 3. Plan por fases

Cada tarea dice qué requisito cierra y **cómo se mide**. Una fase está terminada cuando sus pruebas pasan y su evidencia (captura o video) está guardada en `docs/evidencias/`.

### Fase 0 — Calidad base y corrección de lo existente (rápido, sin backend)

| # | Tarea | Requisito | Métrica / evidencia |
|---|---|---|---|
| 0.1 | Paleta accesible: primario `#007A55` (5.36:1 con blanco); quitar `Colors.grey` y `black54` del texto | RNF-05 | Contraste ≥ 4.5:1 medido en WebAIM Contrast Checker (captura) |
| 0.2 | Texto mínimo de 14 sp (hoy hay 12–13 sp en el globo del mapa) | RNF-05 | `grep "fontSize: 1[0-3]"` → 0 resultados |
| 0.3 | *Mis rutas*: el trabajador solo ve su ruta asignada | RNF-04 | Prueba de widget: el trabajador de R03 no ve R04 ni R05 |
| 0.4 | Quitar las credenciales visibles en el login | RNF-03 | Captura del login sin claves |
| 0.5 | Umbral de proximidad configurable y en **1000 m** | RF-04 | Pruebas unitarias: 2 km → sin alerta; 900 m → 1 alerta; seguir acercándose → sigue 1 |
| 0.6 | Separar la lógica en capas: `models/`, `services/`, `screens/`, `widgets/`, con repositorios intercambiables (demo ↔ Firebase) | Mantenibilidad | `flutter analyze` sin avisos |
| 0.7 | Tema por rol (3 colores) y modo oscuro como en Figma | RF-01 | 3 capturas con color principal distinto |

### Fase 1 — Backend y autenticación real

| # | Tarea | Requisito | Métrica / evidencia |
|---|---|---|---|
| 1.1 | Proyecto Firebase y `flutterfire configure` (Android + web) | — | La app conecta (captura de la consola) |
| 1.2 | Login con Firebase Auth y rol leído de Firestore; tres usuarios semilla | RF-01 | Prueba manual con los 3 roles + clave errónea |
| 1.3 | Registro del trabajador (pantalla nueva) | Doc. final | Usuario nuevo visible en Firebase Auth |
| 1.4 | Navegación protegida por rol (guardas en rutas) | RNF-03 | Un trabajador que intenta abrir la vista de administrador es redirigido (prueba de widget) |
| 1.5 | *Security Rules* por rol y ruta, con pruebas en el emulador | RNF-03, RNF-04 | Pruebas de reglas: un trabajador de R04 **no puede leer** el recorrido de R03 |
| 1.6 | Sesión persistente (no pedir login en cada apertura) | Usabilidad | Cerrar y abrir la app conserva la sesión |

### Fase 2 — Seguimiento en tiempo real entre dispositivos

| # | Tarea | Requisito | Métrica / evidencia |
|---|---|---|---|
| 2.1 | El conductor escribe la ubicación en `recorridos/{id}` cada ≤ 5 s o cada 10 m | RF-02 | Captura de Firestore con la ubicación cambiando |
| 2.2 | Al finalizar: `estado = finalizado` y no se escribe más | RF-02, RNF-04 | Prueba: después de finalizar, la marca de tiempo deja de cambiar |
| 2.3 | El trabajador escucha el recorrido activo de su ruta (otro teléfono) | RF-03 | Video con dos teléfonos: el marcador se mueve |
| 2.4 | ETA por carretera con OSRM u OpenRouteService; si falla, línea recta | RF-03, Doc. final | Prueba: el ETA disminuye monótonamente en la simulación |
| 2.5 | La simulación también escribe en Firestore (demo con dos equipos) | RF-03 | Video |
| 2.6 | Ubicación en segundo plano para el conductor (servicio en primer plano en Android) | RF-02 | Con la pantalla apagada 2 min, la ubicación sigue actualizándose |

### Fase 3 — Notificaciones y conectividad

| # | Tarea | Requisito | Métrica / evidencia |
|---|---|---|---|
| 3.1 | FCM: guardar el token del trabajador y pedir permiso de notificaciones (Android 13+) | RF-04 | Token guardado en `usuarios/{uid}` |
| 3.2 | Cloud Function (o notificación local, ver §2) que envía push a ≤ 1 km **una sola vez** por recorrido (`notificados[]`) | RF-04 | Simular a 2 km → 0 notificaciones; a ≤ 1 km → exactamente 1 |
| 3.3 | Banner "Sin conexión" con `connectivity_plus`; al volver la conexión, el stream se reanuda solo | RNF-02 | Modo avión → aviso; quitarlo → el mapa se actualiza sin reiniciar (video) |
| 3.4 | Pantalla *Alertas* (historial de eventos) del prototipo Figma | Doc. final | Captura |

### Fase 4 — QR de abordaje y panel de administrador

| # | Tarea | Requisito | Métrica / evidencia |
|---|---|---|---|
| 4.1 | QR del trabajador (`qr_flutter`) con su `uid` + firma/token, no solo el id en texto | RF-05 | Captura del QR |
| 4.2 | Escáner del conductor (`mobile_scanner`); el abordaje se guarda en una transacción con id `ruta_fecha_uid` | RF-05 | Válido → guardado; mismo QR otra vez → "Ya abordó"; QR ajeno → "Inválido" |
| 4.3 | Administrador: CRUD de usuarios, vehículos, rutas, paradas y asignaciones | Doc. final | Crear una ruta desde la app y verla en Firestore |
| 4.4 | Resumen por ruta y fecha: "abordaron X de Y" | RF-06 | 3 abordajes de 5 asignados → muestra **"3 de 5"** |

### Fase 5 — Pruebas, QA de campo y entrega

| # | Tarea | Métrica |
|---|---|---|
| 5.1 | Pruebas unitarias de la lógica (distancia, ETA, umbral, validación del QR, conteo X de Y) | Cobertura ≥ 70 % en `services/` (`flutter test --coverage`) |
| 5.2 | Pruebas de widget por pantalla y rol | ≥ 1 prueba por RF |
| 5.3 | Prueba de integración (`integration_test`): login → mapa en ≤ 3 toques | Valida RNF-01 automáticamente |
| 5.4 | CI en GitHub Actions: `analyze` + `test` + `build apk` en cada push | Insignia verde en el README |
| 5.5 | Prueba de campo real con dos teléfonos (Gantt S11) | Acta con resultados por RF |
| 5.6 | APK *release* firmado, `applicationId` propio (`co.edu.uts.rutix`), ícono y *splash* | APK instalable < 30 MB |
| 5.7 | Matriz de trazabilidad final (RF/RNF → código → prueba → evidencia) | 11/11 requisitos con evidencia |

## 4. Requisitos no funcionales adicionales sugeridos (medibles)

Se pueden añadir a la especificación para subir el nivel técnico:

| Código | Categoría | Condición | Verificación |
|---|---|---|---|
| RNF-06 | Rendimiento | La posición del vehículo llega al trabajador en ≤ 5 s | Comparar la marca de tiempo del conductor con la de recepción en 10 muestras; promedio ≤ 5 s |
| RNF-07 | Compatibilidad | Funciona en Android 8.0 (API 26) o superior | Pruebas en un emulador API 26 y en un teléfono real reciente |
| RNF-08 | Eficiencia | El conductor consume ≤ 10 % de batería por hora de recorrido | Medición en Ajustes → Batería durante 1 h |
| RNF-09 | Mantenibilidad | `flutter analyze` sin avisos y cobertura ≥ 70 % en la lógica | Ejecución en CI |

## 5. Orden recomendado y relación con el Gantt

| Gantt | Fase |
|---|---|
| S5–S6 · BD | Fase 0 + Fase 1 |
| S7–S9 · Funcionalidad principal | Fase 2 + Fase 3 |
| S10 · Integración (módulos y panel) | Fase 4 |
| S11 · Pruebas de campo (QA GPS) | Fase 5.1–5.5 |
| S12 · Despliegue y sustentación | Fase 5.6–5.7 |

**Prioridad si falta tiempo:** Fase 0 → 1 → 2 → 3.2 → 4.1–4.2 → 4.4. Con eso se cumplen todos los requisitos de prioridad *Alta* y el RF-06.

## 6. Posible reparto en el equipo (4 personas)

| Persona | Responsabilidad |
|---|---|
| A | Backend: Firebase, reglas, Cloud Functions, modelo de datos |
| B | Conductor: GPS, segundo plano, escáner QR |
| C | Trabajador: mapa, ETA, notificaciones, conectividad |
| D | Administrador, accesibilidad/tema, pruebas, CI y documentación |
