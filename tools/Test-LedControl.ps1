param([string]$Port = 'COM4')
$ErrorActionPreference = 'Stop'
$cases = @(
    @{ Command = 'ALL_OFF'; Blue = 0; Green = 0; Success = $true },
    @{ Command = 'BLUE_ON'; Blue = 1; Green = 0; Success = $true },
    @{ Command = 'BLUE_ON'; Blue = 1; Green = 0; Success = $true },
    @{ Command = 'INVALID'; Blue = 1; Green = 0; Success = $false },
    @{ Command = 'GREEN_ON'; Blue = 1; Green = 1; Success = $true },
    @{ Command = 'INVALID'; Blue = 1; Green = 1; Success = $false },
    @{ Command = 'STATUS'; Blue = 1; Green = 1; Success = $true },
    @{ Command = 'ALL_OFF'; Blue = 0; Green = 0; Success = $true }
)
foreach ($case in $cases) {
    $result = & "$PSScriptRoot\Send-LedCommand.ps1" -Port $Port -Command $case.Command
    $result
    if ($null -eq $result.Reply -or $result.Blue -ne $case.Blue -or
        $result.Green -ne $case.Green -or $result.Success -ne $case.Success) {
        throw "FAIL: $($case.Command) did not produce the expected board response."
    }
    Start-Sleep -Milliseconds 500
}
Write-Output 'PASS: command acknowledgements, independent LEDs, invalid commands, repeat command, status, all off.'
