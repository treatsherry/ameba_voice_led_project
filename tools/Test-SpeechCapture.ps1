$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Speech
Add-Type -Path (Join-Path $PSScriptRoot '..\ui\SpeechCapture.cs') -ReferencedAssemblies @(
    [System.Speech.Recognition.SpeechRecognitionEngine].Assembly.Location, 'System.Core')
$build = Join-Path $PSScriptRoot '..\build'
[void][System.IO.Directory]::CreateDirectory($build)
$wave = Join-Path $build 'speech-silence.wav'
$writer = [System.IO.BinaryWriter]::new([System.IO.File]::Create($wave))
try {
    # Two seconds, PCM mono 16-bit at 16 kHz.
    $writer.Write([System.Text.Encoding]::ASCII.GetBytes('RIFF'))
    $writer.Write([int]64036)
    $writer.Write([System.Text.Encoding]::ASCII.GetBytes('WAVEfmt '))
    $writer.Write([int]16)
    $writer.Write([int16]1); $writer.Write([int16]1)
    $writer.Write([int]16000); $writer.Write([int]32000)
    $writer.Write([int16]2); $writer.Write([int16]16)
    $writer.Write([System.Text.Encoding]::ASCII.GetBytes('data'))
    $writer.Write([int]64000)
    $writer.Write([byte[]]::new(64000))
} finally { $writer.Dispose() }
$capture = New-Object SpeechCapture
try {
    $capture.Start($wave)
    $deadline = [datetime]::Now.AddSeconds(15)
    while (!$capture.Completed -and [datetime]::Now -lt $deadline) { Start-Sleep -Milliseconds 50 }
    if (!$capture.Completed -or $capture.Text -or $capture.Error) { throw 'Silent audio test failed.' }
    Write-Output 'PASS: silent audio completes with no recognized text.'
} finally { $capture.Dispose() }
$capture = New-Object SpeechCapture
try {
    $capture.Start($null)
    $capture.Cancel()
    $deadline = [datetime]::Now.AddSeconds(10)
    while (!$capture.Completed -and [datetime]::Now -lt $deadline) { Start-Sleep -Milliseconds 50 }
    if (!$capture.Completed -or !$capture.Cancelled -or $capture.Text) { throw 'Microphone cancellation failed.' }
    Write-Output 'PASS: default microphone opens and cancellation completes without text.'
} finally { $capture.Dispose() }
$capture = New-Object SpeechCapture
try {
    $capture.Start($wave)
    $capture.Finish()
    $deadline = [datetime]::Now.AddSeconds(10)
    while (!$capture.Completed -and [datetime]::Now -lt $deadline) { Start-Sleep -Milliseconds 50 }
    if (!$capture.Completed -or $capture.Cancelled -or $capture.Error) { throw 'Graceful stop failed.' }
    Write-Output 'PASS: graceful stop completes without cancellation.'
} finally { $capture.Dispose() }
