
---

````markdown
# UpDown

Aplicación Flutter para la gestión de equipos y miembros, donde se pueden asignar **puntos positivos y negativos** según el desempeño de cada integrante.  
El objetivo es dar seguimiento a las acciones de los miembros y permitir al administrador visualizar estadísticas y rankings de forma sencilla.

---

## ✨ Funcionalidades principales

- **Gestión de equipos**  
  - Crear y listar equipos.  
  - Activar/inactivar equipos.  
  - Filtrar equipos activos.  

- **Gestión de miembros**  
  - Alta de nuevos miembros.  
  - Baja lógica (no se borran, solo se marcan inactivos).  
  - Asignación de positivos y negativos.  
  - Historial detallado de acciones por miembro.  

- **Ranking y puntuación**  
  - Ranking dinámico por equipo según puntuación.  
  - Valores de positivos y negativos parametrizables desde configuración.  

- **Estadísticas visuales**  
  - Totales globales (positivos/negativos).  
  - Comparación entre equipos.  
  - Detalle de cada integrante con gráficos.  
  - Secciones activables/desactivables desde configuración.  

- **Configuración centralizada**  
  - Clase `AppConfig` para gestionar la puntuación y la visibilidad de estadísticas.  
  - Pantalla de configuración accesible desde el menú lateral.  

- **Menú lateral (Drawer)**  
  - Navegación entre equipos, estadísticas, configuración y logout.  
  - Presente en todas las pantallas principales.  

---

## 🚀 Instalación y ejecución

1. Clonar el repositorio:
   ```bash
   git clone <url-del-repositorio>
   cd up_down
````

2. Instalar dependencias:

   ```bash
   flutter pub get
   ```

3. Ejecutar en navegador (modo web):

   ```bash
   flutter run -d chrome
   ```

   O en emulador Android/iOS:

   ```bash
   flutter run
   ```

---

## 📂 Estructura del proyecto

```
lib/
 ├── config/         # Configuración global (AppConfig)
 ├── data/           # Datos de prueba (mock data)
 ├── models/         # Modelos de negocio (Team, Member, HistoryItem)
 ├── pages/          # Páginas principales (login, teams, team_detail, history, stats, settings)
 ├── widgets/        # Widgets reutilizables (AppDrawer, MemberCard, TeamCard, etc.)
 └── main.dart       # Punto de entrada de la aplicación
```

---

## 📸 Mockups (futuros)

* Pantalla de equipos con listado.
* Pantalla de detalle de equipo con miembros y ranking.
* Pantalla de estadísticas con gráficos.
* Pantalla de configuración con switches y controles de puntuación.

---

## 🛠️ Tecnologías

* **Flutter** (3.x)
* **Dart**
* **fl\_chart** (para gráficos)
* **Material Design**

---

## 📌 Próximos pasos

* Persistencia de datos en Firebase.
* Autenticación real con Firebase Auth.
* Estadísticas avanzadas con exportación.
* Diseño más personalizado con temas y estilos.

---

## 👨‍💻 Autor

Proyecto desarrollado como práctica y evolución en Flutter por Daniel Campos.

```


## Firebase setup

1. Crea un proyecto en Firebase y habilita Authentication (Email/Password).
2. Agrega app Android e iOS y descarga:
   - android/app/google-services.json
   - ios/Runner/GoogleService-Info.plist
3. Crea reglas/colecciones en Firestore para users y pp_state.
4. Para Web, ejecuta con variables:
   flutter run -d chrome --dart-define=FIREBASE_WEB_API_KEY=... --dart-define=FIREBASE_WEB_APP_ID=... --dart-define=FIREBASE_WEB_MESSAGING_SENDER_ID=... --dart-define=FIREBASE_WEB_PROJECT_ID=...
5. Reglas por rol en Firestore:
   - El proyecto incluye `firestore.rules`.
   - Publica reglas con Firebase CLI:
     `firebase deploy --only firestore:rules`

