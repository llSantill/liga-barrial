@echo off
cd /d "%~dp0"

set PY=
where py >nul 2>nul && set PY=py
if not defined PY ( where python >nul 2>nul && set PY=python )
if not defined PY (
  echo No se encontro Python. Instalalo desde https://www.python.org/downloads/
  echo y marca la casilla "Add python.exe to PATH". Luego vuelve a abrir este archivo.
  pause
  exit /b 1
)

if not exist "api\.env" copy "api\.env.example" "api\.env" >nul
findstr /c:"tu_contrase" "api\.env" >nul
if not errorlevel 1 (
  echo.
  echo Falta tu contrasena de PostgreSQL en api\.env
  echo Se abrira el Bloc de notas: cambia tu_contrasena_aqui por tu clave, guarda con Ctrl+S y cierra.
  notepad "api\.env"
)

if not exist "api\venv\Scripts\python.exe" (
  echo Creando entorno virtual...
  %PY% -m venv api\venv
)
echo Instalando dependencias...
"api\venv\Scripts\python.exe" -m pip install -q -r api\requirements.txt

start "API Liga Barrial (puerto 8000)" cmd /k "cd /d "%~dp0api" && venv\Scripts\python.exe -m uvicorn main:app --reload --port 8000"
start "App Liga Barrial (puerto 5500)" cmd /k "cd /d "%~dp0app" && "%~dp0api\venv\Scripts\python.exe" -m http.server 5500"

timeout /t 4 >nul
start "" http://127.0.0.1:8000/docs
start "" http://localhost:5500
echo.
echo Listo. Deja abiertas las dos ventanas negras mientras usas la app.
pause
