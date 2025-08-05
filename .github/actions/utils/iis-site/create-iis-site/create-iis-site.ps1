##########################################################################
#
# Creación de un sitio IIS básico de IIS usando PowerShell
#
# Este script crea un sitio IIS con un Application Pool específico y
# configura sus parámetros básicos.
#
# Los parámetros avanzados del sitio deben ser configurados con otro
# script.
#
##########################################################################

param (
    [string]$siteName,                  # Nombre del sitio IIS a crear    
    [string]$appPoolName,                # Nombre del Application Pool para el sitio
    [string]$sitePath,# Ruta física al directorio del sitio
    [string]$ipAddress = "*",           # Dirección IP en la que escuchará el sitio
    [int]$port = 80,                    # Puerto que escuchará el sitio
    [string]$hostHeader = "localhost",   # Dominio o encabezado del sitio

    [string]$ipServer,
    [string]$sshUser  # Usuario SSH para conectarse al servidor remoto
)

# Si no se especifica ipServer ni sshUser, se cancela la ejecución
if (-not $ipServer -or -not $sshUser -or -not $siteName -or -not $appPoolName -or -not $sitePath) {
    Write-Error "ipServer, sshUser, siteName, appPoolName, and sitePath must be specified."
    return
}

$remoteScript = @"
# Importamos el módulo WebAdministration para gestionar IIS
try {
    Import-Module WebAdministration
}
catch {
    Write-Error "Failed to import WebAdministration module. Ensure IIS is installed and the module is available."
    return
}

Write-Host "Setting up IIS Site: $siteName"

# Verificamos si el Application Pool ya existe
Write-Host "Checking if Application Pool $appPoolName exists..."
try{
    # Si el Application Pool ya existe, no devolverá error, por lo que podemos continuar con la ejecución
    Get-WebAppPoolState -Name $appPoolName -ErrorAction SilentlyContinue | Out-Null
    Write-Host "Application Pool $appPoolName already exists."
} catch {
    # Si no existe, informamos al usuario y finalizamos el script
    Write-Host "Application Pool $appPoolName does not exist."
    return
}

# Verificamos si el sitio IIS ya existe
Write-Host "Checking if IIS Site $siteName exists..."
try {
    `$exists = Get-Website -Name $siteName -ErrorAction SilentlyContinue
    Write-Host "Resultado validacion: `$exists"
    # Si sitio web existe, lo eliminamos
    if(`$exists -ne `$null) {
        Write-Host "Site $siteName already exists. Removing it..."
        Remove-Website -Name $siteName -ErrorAction SilentlyContinue
        Write-Host "Removed existing site: $siteName"
    }
    # Creamos el sitio IIS
    try {
        New-Website -Name '$siteName' -ApplicationPool '$appPoolName' -PhysicalPath '$sitePath' -IPAddress '$ipAddress' -Port '$port' -HostHeader '$hostHeader'
        Write-Host "Created Site: $siteName with Application Pool: $appPoolName"
    }
    catch {
        Write-Host "Failed to create site $siteName. Please check the parameters and try again."
        Write-Host "`$_"
        return
    }
} catch {
    Write-Host "An error occurred: `$_"
}
"@

# Codificamos el script en Base64 para evitar problemas con caracteres especiales
$encodedScript = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($remoteScript))

# Ejecutar el comando remotamente suprimiendo streams de información
ssh $sshUser@$ipServer "powershell -EncodedCommand $encodedScript" 2>$null 6>$null