param(
    [string]$Port = 'COM4',
    [ValidateSet('STATUS', 'BLUE_ON', 'GREEN_ON', 'ALL_OFF', 'INVALID')]
    [string]$Command = 'STATUS',
    [ValidateRange(200, 10000)]
    [int]$TimeoutMs = 3000
)

# Windows PowerShell 5.1 / PowerShell 7; no extra packages required.
# Return an object so the next UI layer can consume confirmed results.
$requestId = [guid]::NewGuid().ToString('N').Substring(0, 8)
$serial = [System.IO.Ports.SerialPort]::new($Port, 115200,
    [System.IO.Ports.Parity]::None, 8, [System.IO.Ports.StopBits]::One)
$serial.DtrEnable = $false
$serial.RtsEnable = $false
$serial.NewLine = "`n"
$serial.ReadTimeout = 100
$serial.WriteTimeout = $TimeoutMs
$result = [ordered]@{
    Port = $Port; Sent = $null; Reply = $null; Success = $false
    Blue = $null; Green = $null; Error = $null
}
try {
    $serial.Open()
    $serial.DiscardInBuffer()
    # Discard any unfinished frame from a previous disconnected session.
    $serial.Write("`n")
    $wire = "$requestId $Command"
    $serial.WriteLine($wire)
    $result.Sent = $wire
    $timer = [System.Diagnostics.Stopwatch]::StartNew()
    $received = ''
    $pattern = '^ACK ' + $requestId + ' (OK|ERR_[A-Z_]+) BLUE=([01]) GREEN=([01])$'
    while ($timer.ElapsedMilliseconds -lt $TimeoutMs) {
        $received += $serial.ReadExisting()
        $newline = $received.IndexOf("`n")
        while ($newline -ge 0) {
            $line = $received.Substring(0, $newline).TrimEnd([char]13)
            $received = $received.Substring($newline + 1)
            if ($line -match $pattern) {
                $result.Reply = $line
                $result.Success = $Matches[1] -eq 'OK'
                $result.Blue = [int]$Matches[2]
                $result.Green = [int]$Matches[3]
                if (!$result.Success) { $result.Error = 'Board rejected command: ' + $Matches[1] }
                return [pscustomobject]$result
            }
            $newline = $received.IndexOf("`n")
        }
        if ($received.Length -gt 4096) { throw 'Unexpected oversized serial response.' }
        Start-Sleep -Milliseconds 20
    }
    $result.Error = 'Response timeout. Execution and current LED state are unknown.'
} catch {
    $result.Error = 'Communication failed; current LED state is unknown: ' + $_.Exception.Message
} finally {
    if ($serial.IsOpen) { $serial.Close() }
    $serial.Dispose()
}
[pscustomobject]$result
