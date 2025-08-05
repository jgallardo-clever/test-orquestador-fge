###############################################################
# Crear Application Pool en IIS
###############################################################

param (
    [string]$appPoolName,   # Nombre del Application Pool
    [string]$managedRuntimeVersion = "",  # Versión de .NET a utilizar
    [string]$managedPipelineMode = "Integrated", # Modo de pipeline (Integrated o Classic)

    [string]$ipServer,
    [string]$sshUser
)

# Si no se especifica ipServer ni sshUser, se cancela la ejecución
if (-not $ipServer -or -not $sshUser -or -not $appPoolName) {
    Write-Error "ipServer, sshUser, and appPoolName must be specified."
    return
}

# Crear el script remoto con las variables ya interpoladas
$remoteScript = @"
try {
    Import-Module WebAdministration
}
catch {
    Write-Error "Failed to import WebAdministration module. Ensure IIS is installed and the module is available."
    return
}

# Verificar si el Application Pool ya existe
try {
    Get-WebAppPoolState -Name $appPoolName -ErrorAction SilentlyContinue | Out-Null
    Write-Host "Application Pool $appPoolName already exists."
    # Eliminar el Application Pool si ya existe
    Remove-WebAppPool -Name $appPoolName -ErrorAction SilentlyContinue
    Write-Host "Removed existing Application Pool: $appPoolName"
}
catch {
    Write-Host "Application Pool $appPoolName does not exist or could not be retrieved."
}
# Crear el Application Pool
try {
    # Si no existe, lo creamos
    New-WebAppPool -Name $appPoolName | Out-Null
    Write-Host "Created Application Pool: $appPoolName"
    Set-ItemProperty "IIS:\AppPools\$appPoolName" -Name "managedRuntimeVersion" -Value '$managedRuntimeVersion'
    Set-ItemProperty "IIS:\AppPools\$appPoolName" -Name "managedPipelineMode" -Value '$managedPipelineMode'
    Write-Host "Configured Application Pool $appPoolName with .NET version $managedRuntimeVersion and pipeline mode $managedPipelineMode."
} catch {
    Write-Error "Failed to create Application Pool $appPoolName. Please check the parameters and try again."
    Write-Host "`$_"
    return
}
"@

# Codificar el script en Base64 para evitar problemas con caracteres especiales
$encodedScript = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($remoteScript))

# Ejecutar el comando remotamente
ssh $sshUser@$ipServer "powershell -EncodedCommand $encodedScript" 2>$null 6>$null