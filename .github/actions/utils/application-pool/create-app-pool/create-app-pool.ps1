###############################################################
# Crear un Application Pool en IIS
###############################################################

param (
    [string]$appPoolName,   # Nombre del Application Pool
    [string]$managedRuntimeVersion = "",  # Versión de .NET a utilizar
    [string]$managedPipelineMode = "Integrated" # Modo de pipeline (Integrated o Classic)
)

Import-Module WebAdministration

# Verificar si el Application Pool ya existe
try {
    Get-WebAppPoolState -Name $appPoolName -ErrorAction SilentlyContinue | Out-Null
    Write-Host "Application Pool '$appPoolName' already exists."
    return
}
catch {
    # Si no existe, lo creamos
    New-WebAppPool -Name $appPoolName
    Write-Host "Created Application Pool: $appPoolName"
    Set-ItemProperty "IIS:\AppPools\$appPoolName" -Name "managedRuntimeVersion" -Value $managedRuntimeVersion
    Set-ItemProperty "IIS:\AppPools\$appPoolName" -Name "managedPipelineMode" -Value $managedPipelineMode
    Write-Host "Configured Application Pool '$appPoolName' with .NET version '$managedRuntimeVersion' and pipeline mode '$managedPipelineMode'."
}