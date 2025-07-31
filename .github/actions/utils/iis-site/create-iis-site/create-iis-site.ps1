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
    [string]$appPoolName,               # Nombre del Application Pool para el sitio
    [string]$sitePath,                  # Ruta física al directorio del sitio
    [string]$ipAddress = "*",           # Dirección IP en la que escuchará el sitio
    [int]$port = 80,                    # Puerto que escuchará el sitio
    [string]$hostHeader = "localhost"   # Dominio o encabezado del sitio
)

# Importamos el módulo WebAdministration para gestionar IIS
Import-Module WebAdministration

Write-Host "Setting up IIS Site: $siteName"

# Verificamos si el Application Pool ya existe
Write-Host "Checking if Application Pool '$appPoolName' exists..."
try{
    # Si el Application Pool ya existe, no devolverá error, por lo que podemos continuar con la ejecución
    Get-WebAppPoolState -Name $appPoolName -ErrorAction SilentlyContinue | Out-Null
} catch {
    # Si no existe, informamos al usuario y finalizamos el script
    Write-Host "Application Pool '$appPoolName' does not exist."
    return
}

# Verificamos si el sitio IIS ya existe
Write-Host "Checking if IIS Site '$siteName' exists..."
try {
    $exists = Get-Website -Name $siteName -ErrorAction SilentlyContinue
    # Si el resultado de Get-Website -Name $siteName es vacío, significa que el sitio no existe
    if($exists -eq $null) {
        Write-Host "Site '$siteName' does not exist."
        # Creamos el sitio IIS
        try {
            New-Website -Name $siteName -ApplicationPool $appPoolName -PhysicalPath $sitePath -IPAddress $ipAddress -Port $port -HostHeader $hostHeader
            Write-Host "Created Site: $siteName with Application Pool: $appPoolName"
        }
        catch {
            Write-Host "Failed to create site '$siteName'. Please check the parameters and try again."
            Write-Host "$_"
            return
        }
    } else {
        # Si el sitio ya existe, informamos al usuario y finalizamos el script
        Write-Host "Site '$siteName' already exists."
        return
    }
} catch {
    Write-Host "An error occurred: $_"
}