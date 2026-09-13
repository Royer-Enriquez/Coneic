Set-Location $PSScriptRoot
Write-Host "CONEIC - servidor local en la raiz del proyecto"
Write-Host "Abre: http://127.0.0.1:5500/"
Write-Host "Detener: Ctrl+C"
if (Get-Command py -ErrorAction SilentlyContinue) {
    py -m http.server 5500 --bind 127.0.0.1
} elseif (Get-Command python -ErrorAction SilentlyContinue) {
    python -m http.server 5500 --bind 127.0.0.1
} else {
    Write-Error "No se encontro Python. Instala Python o usa Live Server abriendo esta carpeta como raiz."
}
