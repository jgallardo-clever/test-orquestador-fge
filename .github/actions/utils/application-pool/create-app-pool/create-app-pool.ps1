##########################################################################
# Crear Application Pool en IIS
# (Los parámetros avanzados del Application Pool deben ser
# configurados con otro script)
##########################################################################

param (
    # Parámetros del Application Pool
    [string]$appPoolName,                           # Nombre del Application Pool
    [string]$managedRuntimeVersion = "",            # Versión de .NET a utilizar
    [string]$managedPipelineMode = "Integrated",    # Modo de pipeline (Integrated o Classic)

    # Parámetros de conexión al servidor IIS
    [string]$ipServer,                              # Dirección IP del servidor IIS
    [string]$sshUser                                # Usuario SSH para conectarse al servidor remoto
)

##########################################################################
# Validación de parámetros
##########################################################################

# Si no se especifica ipServer ni sshUser, se cancela la ejecución
if (-not $ipServer -or -not $sshUser -or -not $appPoolName) {
    Write-Error "ipServer, sshUser, y appPoolName deben ser especificados."
    return
}

##########################################################################
# Script remoto para crear el Application Pool
##########################################################################

# Cargamos el script remoto que se ejecutará en el servidor IIS
$remoteScript = @"
# Importamos el módulo WebAdministration para gestionar IIS
try {
    Import-Module WebAdministration
}
catch {
    Write-Error "Error al importar el módulo WebAdministration."
    return
}

# Verificar si el Application Pool ya existe
try {
    Get-WebAppPoolState -Name $appPoolName -ErrorAction SilentlyContinue | Out-Null
    Write-Host "El Application Pool $appPoolName ya existe."
    # Eliminar el Application Pool si ya existe
    Remove-WebAppPool -Name $appPoolName -ErrorAction SilentlyContinue
    Write-Host "Se eliminó el Application Pool existente: $appPoolName"
}
catch {
    Write-Host "No se pudo encontrar el Application Pool $appPoolName."
}

# Crear el Application Pool
try {
    # Si no existe, lo creamos
    New-WebAppPool -Name $appPoolName | Out-Null
    Write-Host "Se creó el Application Pool: $appPoolName"
    Set-ItemProperty "IIS:\AppPools\$appPoolName" -Name "managedRuntimeVersion" -Value '$managedRuntimeVersion'
    Set-ItemProperty "IIS:\AppPools\$appPoolName" -Name "managedPipelineMode" -Value '$managedPipelineMode'
    Write-Host "Se configuró el Application Pool $appPoolName con la versión de .NET $managedRuntimeVersion y el modo de canalización $managedPipelineMode."
} catch {
    Write-Error "Error al crear el Application Pool $appPoolName. Verifique los parámetros e intente nuevamente."
    Write-Host "`$_"
    return
}
"@

##########################################################################
# Cofificación del script
##########################################################################

# Codificar en Base64 para evitar problemas con caracteres especiales
$encodedScript = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($remoteScript))

##########################################################################
# Ejecutar el script remoto
##########################################################################

# Ejecutar remotamente, suprimiendo streams de información para no saturar la salida
ssh $sshUser@$ipServer "powershell -EncodedCommand $encodedScript" 2>$null 6>$null