##########################################################################
# Configuración de un proxy inverso para un sitio en IIS usando PowerShell
#
# Este script configura un proxy inverso para un sitio IIS existente,
# redirigiendo las solicitudes a una URL de destino especificada.
#
##########################################################################

param (
    [string]$siteName, # Nombre del sitio IIS al que se le aplicará el proxy inverso
    [string]$targetUrl, # URL de destino al que se redirigirán las solicitudes (Debe incluir el esquema, por ejemplo, http:// o https://)

    [string]$ipServer,  # Dirección IP del servidor IIS
    [string]$sshUser  # Usuario SSH para conectarse al servidor remoto
)

# Si no se especifica ipServer ni sshUser, se cancela la ejecución
if (-not $ipServer -or -not $sshUser -or -not $siteName -or -not $targetUrl) {
    Write-Error "ipServer, sshUser, siteName, and targetUrl must be specified."
    return
}

$remoteScript = @"
# Importamos el módulo WebAdministration para gestionar IIS
Import-Module WebAdministration

Write-Host "Setting up reverse proxy for site: '$siteName' to target: '$targetUrl'"

# Activamos la funcionalidad de proxy en IIS (Esto sirve para garantizar que ARR esté habilitado)
try {
    Set-WebConfigurationProperty -Filter "system.webServer/proxy" -Name "enabled" -Value `$true -PSPath "IIS:\"
    Write-Host "Enabled proxy functionality"
} catch {
    Write-Warning "Could not enable proxy functionality. Make sure Application Request Routing (ARR) module is installed."
}

#################################
# Configuración del proxy inverso
#################################

# Aseguramos que la sección de rewrite exista en el sitio especificado
`$sitePath = "IIS:\Sites\$siteName"
Write-Host "Site Path: `$sitePath"

# Eliminar cualquier regla existente con el mismo nombre para evitar conflictos
try {
    Remove-WebConfigurationProperty -Filter "system.webServer/rewrite/rules" -PSPath `$sitePath -Name "." -AtElement @{name="ReverseProxyRule"} -ErrorAction SilentlyContinue
    Write-Host "Removed existing rule with name: ReverseProxyRule"
} catch {
    Write-Host "No existing rule found or an error occurred while removing it."
}

# Añadimos la nueva regla de rewrite
try {
    Add-WebConfigurationProperty -Filter "system.webServer/rewrite/rules" -PSPath `$sitePath -Name "." -Value @{
        name = "ReverseProxyRule"
        stopProcessing = `$true
        match = @{
            url = "(.*)"
        }
        conditions = @{
            logicalGrouping = "MatchAll"
            trackAllCaptures = `$false
        }
        action = @{
            type = "Rewrite"
            url = "$targetUrl/{R:1}"
        }
    }
    Write-Host "Successfully created reverse proxy rule: ReverseProxyRule"
    Write-Host "All requests to $siteName will be forwarded to $targetUrl"
} catch {
    Write-Error "Failed to create reverse proxy rule: `$_"
    exit 1
}

"@

# Codificamos el script en Base64 para evitar problemas con caracteres especiales
$encodedScript = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($remoteScript))

# Ejecutamos el comando remotamente
ssh $sshUser@$ipServer "powershell -EncodedCommand $encodedScript" 2>$null 6>$null