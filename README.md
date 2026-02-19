# UpDown

Aplicacion Flutter para gestionar equipos, miembros y sugerencias de positivos/negativos.

## Funcionalidades

- Gestion de equipos y miembros.
- Solicitudes de vinculacion con autoaprobacion opcional por equipo.
- Roles: `admin`, `gestor`, `user`.
- Historial de acciones por equipo e integrante.
- Pantalla de usuarios para cambiar rol/equipo y eliminar usuarios.
- Estadisticas configurables por secciones.

## Requisitos

- Flutter 3.x
- Dart
- Firebase (Auth + Firestore)
- Firebase CLI (para reglas y hosting)

## Setup rapido

1. Instalar dependencias:

```powershell
flutter pub get
```

2. Crear variables locales para web:

```powershell
Copy-Item .env.web.example .env.web
```

3. Completar `.env.web` con credenciales Firebase Web.

4. Ejecutar en local:

```powershell
.\run_web.ps1
```

5. Ejecutar en release local (opcional):

```powershell
.\run_web.ps1 -Release
```

## Firebase

1. Crear proyecto en Firebase.
2. Habilitar Authentication (Email/Password).
3. Configurar Firestore y publicar reglas:

```powershell
firebase deploy --only firestore:rules
```

## Deploy

Deploy completo (web + reglas):

```powershell
flutter build web
firebase deploy --only firestore:rules,hosting
```

Solo reglas:

```powershell
firebase deploy --only firestore:rules
```

Solo hosting:

```powershell
firebase deploy --only hosting
```

Si hace falta iniciar sesion/seleccionar proyecto:

```powershell
firebase login
firebase use updown-9f356
```

## Notas

- El archivo `.env.web` no se sube a git.
- Si usas Git Bash para scripts PowerShell:

```bash
powershell -ExecutionPolicy Bypass -File ./run_web.ps1
```
