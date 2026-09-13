@echo off
setlocal
cd /d "%~dp0"
echo.
echo ================================================
echo  CONEIC - servidor local en la raiz del proyecto
echo ================================================
echo.
where py >nul 2>nul
if %errorlevel%==0 (
  echo Abre en el navegador: http://127.0.0.1:5500/
  echo Para detener: Ctrl+C
  py -m http.server 5500 --bind 127.0.0.1
  goto :eof
)
where python >nul 2>nul
if %errorlevel%==0 (
  echo Abre en el navegador: http://127.0.0.1:5500/
  echo Para detener: Ctrl+C
  python -m http.server 5500 --bind 127.0.0.1
  goto :eof
)
echo No se encontro Python. Instala Python o utiliza Live Server abriendo ESTA carpeta como raiz en VS Code.
pause
