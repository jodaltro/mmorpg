# Faz o motor do Hospedeiro subir sozinho quando você entra no Windows (tarefa agendada
# "Hospedeiro Motor"), vigiado por scripts\hospedeiro-service.ps1.
#   powershell -File scripts\hospedeiro-install-task.ps1               # instala
#   powershell -File scripts\hospedeiro-install-task.ps1 -KeepAwake     # instala e impede suspensão na tomada
#   powershell -File scripts\hospedeiro-install-task.ps1 -Remove        # remove
# Nada aqui roda sozinho: é preciso chamá-lo. Mexe só na tarefa e, com -KeepAwake, nas
# opções de energia ligada na tomada (suspensão e hibernação nunca).
param([switch]$Remove, [switch]$KeepAwake, [string]$TaskName = 'Hospedeiro Motor')
$ErrorActionPreference = 'Stop'
$script = Join-Path $PSScriptRoot 'hospedeiro-service.ps1'

if ($Remove) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host "tarefa '$TaskName' removida"
    return
}

$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$script`""
$trigger = New-ScheduledTaskTrigger -AtLogOn -User "$env:USERDOMAIN\$env:USERNAME"
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable `
    -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances IgnoreNew -RestartCount 5 -RestartInterval (New-TimeSpan -Minutes 1)
Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -Force `
    -Description 'Mantém o motor do Hospedeiro vivo neste PC (scripts\hospedeiro-service.ps1).' | Out-Null
Write-Host "tarefa '$TaskName' instalada: o motor sobe quando você entra no Windows"

if ($KeepAwake) {
    powercfg /change standby-timeout-ac 0
    powercfg /change hibernate-timeout-ac 0
    Write-Host 'suspensão e hibernação desligadas na tomada (a tela pode apagar)'
} else {
    Write-Host 'atenção: se o PC suspender, o mundo para. Use -KeepAwake para evitar isso na tomada.'
}
