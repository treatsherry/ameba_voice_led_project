$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Speech
Add-Type -Path (Join-Path $PSScriptRoot '..\ui\SpeechCapture.cs') -ReferencedAssemblies @(
    [System.Speech.Recognition.SpeechRecognitionEngine].Assembly.Location, 'System.Core')
$testDir = Join-Path $PSScriptRoot '..\build\speech-command-tests'
[void][System.IO.Directory]::CreateDirectory($testDir)
$voice = ([System.Speech.Synthesis.SpeechSynthesizer]::new()).GetInstalledVoices() |
    Where-Object { $_.VoiceInfo.Culture.Name -eq 'zh-TW' } | Select-Object -First 1
if (!$voice) { throw 'No zh-TW synthesis voice is installed.' }
$cases = @(
    @{ Text='左邊開燈'; Command='BLUE_ON' },
    @{ Text='右邊開燈'; Command='GREEN_ON' },
    @{ Text='今天天氣很好'; Command='' },
    @{ Text='不要左邊開燈'; Command='' },
    @{ Text='我想知道左邊開燈'; Command='' },
    @{ Text='請不要右邊開燈'; Command='' }
)
foreach ($case in $cases) {
    $safeName = if ($case.Command) { $case.Command } else { 'NON_CONTROL' }
    $wave = Join-Path $testDir ($safeName + '.wav')
    $synth = [System.Speech.Synthesis.SpeechSynthesizer]::new()
    try {
        $synth.SelectVoice($voice.VoiceInfo.Name)
        $synth.SetOutputToWaveFile($wave)
        $synth.Speak($case.Text)
        $synth.SetOutputToNull()
    } finally { $synth.Dispose() }
    $capture = New-Object SpeechCapture
    try {
        $capture.Start($wave)
        $deadline = [datetime]::Now.AddSeconds(15)
        while (!$capture.Completed -and [datetime]::Now -lt $deadline) { Start-Sleep -Milliseconds 50 }
        if (!$capture.Completed) { throw "Recognition timeout: $($case.Text)" }
        if ($case.Command) {
            if (!$capture.IsControlCommand -or $capture.ControlCommand -ne $case.Command) {
                throw "Command failed: said=$($case.Text), heard=$($capture.Text), confidence=$($capture.Confidence), command=$($capture.ControlCommand)"
            }
        } elseif ($capture.IsControlCommand -or $capture.ControlCommand) {
            throw "Non-control phrase triggered a command: $($capture.ControlCommand)"
        }
        Write-Output ("PASS: said={0}; heard={1}; confidence={2:0.00}; command={3}" -f $case.Text,$capture.Text,$capture.Confidence,$capture.ControlCommand)
    } finally { $capture.Dispose() }
}
