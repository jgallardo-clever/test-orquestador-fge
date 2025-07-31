##########################################################################
# Configuración de un proxy inverso para un sitio en IIS usando PowerShell
#
# Este script configura un proxy inverso para un sitio IIS existente,
# redirigiendo las solicitudes a una URL de destino especificada.
#
##########################################################################

param (
    [string]$siteName, # Nombre del sitio IIS al que se le aplicará el proxy inverso
    [string]$targetUrl # URL de destino al que se redirigirán las solicitudes
)

# Importamos el módulo WebAdministration para gestionar IIS
Import-Module WebAdministration

Write-Host "Setting up reverse proxy for site: $siteName to target: $targetUrl"

# # Verificamos si el sitio IIS existe
# if (-not (Get-Website -Name $siteName -ErrorAction SilentlyContinue)) {
#     Write-Error "Site '$siteName' does not exist. Please create the site first."
#     exit 1
# }

# Activamos la funcionalidad de proxy en IIS (Esto sirve para garantizar que ARR esté habilitado)
try {
    Set-WebConfigurationProperty -Filter "system.webServer/proxy" -Name "enabled" -Value $true -PSPath "IIS:\"
    Write-Host "Enabled proxy functionality"
} catch {
    Write-Warning "Could not enable proxy functionality. Make sure Application Request Routing (ARR) module is installed."
}

#################################
# Configuración del proxy inverso
#################################

# Aseguramos que la sección de rewrite exista en el sitio especificado
$sitePath = "IIS:\Sites\$siteName"
try {
    $rewriteSection = Get-WebConfiguration -Filter "system.webServer/rewrite" -PSPath $sitePath
    if ($null -eq $rewriteSection) {
        # Creamos la sección de rewrite si no existe
        Add-WebConfiguration -Filter "system.webServer" -PSPath $sitePath -Name "rewrite"
        Write-Host "Created rewrite section"
    }
} catch {
    Write-Host "Rewrite section may already exist or there was an issue creating it"
}

# Aseguramos que la sección de rules exista en el sitio especificado
try {
    $rulesSection = Get-WebConfiguration -Filter "system.webServer/rewrite/rules" -PSPath $sitePath
    if ($null -eq $rulesSection) {
        Add-WebConfiguration -Filter "system.webServer/rewrite" -PSPath $sitePath -Name "rules"
        Write-Host "Created rules section"
    }
} catch {
    Write-Host "Rules section may already exist or there was an issue creating it"
}

# Creamos una regla (rule) de rewrite para el proxy inverso
$ruleName = "ReverseProxyRule"

# Removemos cualquier regla existente con el mismo nombre para evitar conflictos
try {
    Remove-WebConfigurationProperty -Filter "system.webServer/rewrite/rules" -PSPath $sitePath -Name "." -AtElement @{name=$ruleName} -ErrorAction SilentlyContinue
    Write-Host "Removed existing rule with name: $ruleName"
} catch {
    # Si no se encuentra la regla, simplemente continuamos
}

# Añadimos la nueva regla de rewrite
try {
    Add-WebConfigurationProperty -Filter "system.webServer/rewrite/rules" -PSPath $sitePath -Name "." -Value @{
        name = $ruleName
        stopProcessing = $true
        match = @{
            url = "(.*)"
        }
        conditions = @{
            logicalGrouping = "MatchAll"
            trackAllCaptures = $false
        }
        action = @{
            type = "Rewrite"
            url = "$targetUrl/{R:1}"
        }
    }
    Write-Host "Successfully created reverse proxy rule: $ruleName"
    Write-Host "All requests to $siteName will be forwarded to $targetUrl"
} catch {
    Write-Error "Failed to create reverse proxy rule: $_"
    exit 1
}
