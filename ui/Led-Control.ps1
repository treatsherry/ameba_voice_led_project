param([switch]$SmokeTest)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Speech
Add-Type -Path (Join-Path $PSScriptRoot 'SpeechCapture.cs') -ReferencedAssemblies @(
    [System.Speech.Recognition.SpeechRecognitionEngine].Assembly.Location, 'System.Core')
[System.Windows.Forms.Application]::EnableVisualStyles()
$script:senderPath = Join-Path $PSScriptRoot '..\tools\Send-LedCommand.ps1'
$script:worker = $null
$script:pending = $null
$script:automatic = $false
$script:nextPoll = [datetime]::Now.AddSeconds(3)
$script:lastSummary = ''
$script:lastResult = $null
$script:capture = $null
$script:speechCancelled = $false
$script:speechFinishing = $false
$script:speechCommandQueued = $null
$script:recordingPath = Join-Path $PSScriptRoot '..\build\speech-last.wav'
$script:player = New-Object System.Media.SoundPlayer

$form = New-Object System.Windows.Forms.Form
$form.Text = 'Ameba Mini｜LED 控制台'
$form.ClientSize = New-Object System.Drawing.Size(820, 720)
$form.MinimumSize = New-Object System.Drawing.Size(836, 759)
$form.StartPosition = 'CenterScreen'
$form.BackColor = [System.Drawing.Color]::FromArgb(245, 247, 251)
$form.Font = New-Object System.Drawing.Font('Microsoft JhengHei UI', 10)
$form.AutoScaleMode = 'Dpi'

function Add-Label($text, $x, $y, $width, $height) {
    $label = New-Object System.Windows.Forms.Label
    $label.Text = $text
    $label.SetBounds($x, $y, $width, $height)
    $form.Controls.Add($label)
    return $label
}
function Add-Button($text, $x, $y, $width, $height) {
    $button = New-Object System.Windows.Forms.Button
    $button.Text = $text
    $button.SetBounds($x, $y, $width, $height)
    $button.FlatStyle = 'Flat'
    $button.BackColor = [System.Drawing.Color]::White
    $form.Controls.Add($button)
    return $button
}
function Add-Field($y) {
    $field = New-Object System.Windows.Forms.TextBox
    $field.ReadOnly = $true
    $field.SetBounds(165, $y, 625, 30)
    $field.Anchor = 'Top, Left, Right'
    $field.BackColor = [System.Drawing.Color]::White
    $form.Controls.Add($field)
    return $field
}

$title = Add-Label 'Ameba Mini LED 控制台' 28 20 750 40
$title.Font = New-Object System.Drawing.Font('Microsoft JhengHei UI', 20, [System.Drawing.FontStyle]::Bold)
$subtitle = Add-Label '語音辨識測試 · 按鈕控制 · 開發板回覆' 30 65 750 30
$portLabel = Add-Label '連接埠' 30 108 70 28
$ports = New-Object System.Windows.Forms.ComboBox
$ports.SetBounds(104, 104, 130, 30)
$ports.DropDownStyle = 'DropDown'
$form.Controls.Add($ports)
$refresh = Add-Button '重新掃描' 246 102 108 34
$query = Add-Button '查詢狀態' 365 102 108 34
$autoPoll = New-Object System.Windows.Forms.CheckBox
$autoPoll.Text = '每 3 秒確認連線'
$autoPoll.SetBounds(492, 106, 260, 28)
$autoPoll.Checked = $true
$form.Controls.Add($autoPoll)
$connection = Add-Label '尚未確認連線' 30 148 750 44

$blue = Add-Label '藍燈：未知' 30 200 360 42
$green = Add-Label '綠燈：未知' 420 200 360 42
foreach ($indicator in @($blue, $green)) {
    $indicator.Font = New-Object System.Drawing.Font('Microsoft JhengHei UI', 17, [System.Drawing.FontStyle]::Bold)
}
$confirmed = Add-Label '狀態依據：尚未收到板子回覆' 30 246 750 26
$blueButton = Add-Button '左邊開燈（藍燈）' 30 286 240 58
$blueButton.BackColor = [System.Drawing.Color]::FromArgb(220, 234, 255)
$greenButton = Add-Button '右邊開燈（綠燈）' 290 286 240 58
$greenButton.BackColor = [System.Drawing.Color]::FromArgb(220, 245, 230)
$offButton = Add-Button '全部關燈' 550 286 240 58
$invalidButton = Add-Button '測試無效指令' 30 356 150 34
$exportButton = Add-Button '匯出操作紀錄' 194 356 150 34
$micButton = Add-Button '辨識一句' 358 356 140 34
$cancelSpeech = Add-Button '取消辨識' 510 356 120 34
$cancelSpeech.Enabled = $false
$playSpeech = Add-Button '播放辨識錄音' 642 356 148 34
$playSpeech.Enabled = $false
$speechLabel = Add-Label '語音辨識結果' 30 409 132 28
$speech = Add-Field 406
$speech.Text = '按「辨識一句」開始；只有兩句指定語音會控制燈號'
$sentLabel = Add-Label '傳送指令' 30 451 132 28
$sent = Add-Field 448
$replyLabel = Add-Label '開發板回覆' 30 493 132 28
$reply = Add-Field 490
$log = New-Object System.Windows.Forms.RichTextBox
$log.SetBounds(30, 535, 760, 160)
$log.Anchor = 'Top, Bottom, Left, Right'
$log.ReadOnly = $true
$log.BackColor = [System.Drawing.Color]::White
$log.Font = New-Object System.Drawing.Font('Consolas', 10)
$form.Controls.Add($log)
$script:controls = @($ports, $refresh, $query, $blueButton, $greenButton, $offButton, $invalidButton)

function Add-Log([string]$message) {
    if ($log.TextLength -gt 60000) { $log.Clear() }
    $log.AppendText(('[' + (Get-Date -Format 'HH:mm:ss') + '] ' + $message + "`r`n"))
    $log.SelectionStart = $log.TextLength
    $log.ScrollToCaret()
}
function Set-Unknown {
    $blue.Text = '藍燈：未知'
    $green.Text = '綠燈：未知'
    $blue.ForeColor = [System.Drawing.Color]::DimGray
    $green.ForeColor = [System.Drawing.Color]::DimGray
    $confirmed.Text = '狀態依據：目前沒有有效確認，請查詢狀態'
}
function Refresh-Ports {
    $previous = $ports.Text
    $ports.Items.Clear()
    foreach ($name in ([System.IO.Ports.SerialPort]::GetPortNames() | Sort-Object)) {
        [void]$ports.Items.Add($name)
    }
    if ($previous) { $ports.Text = $previous }
    elseif ($ports.Items.Count -gt 0) { $ports.SelectedIndex = 0 }
}
function Start-Command([string]$command, [bool]$isAutomatic = $false) {
    if ($null -ne $script:worker) { return }
    if ($ports.Text -notmatch '^COM[0-9]+$') {
        $connection.Text = '請選擇有效連接埠，例如 COM4'
        Set-Unknown
        return
    }
    $script:automatic = $isAutomatic
    foreach ($control in $script:controls) { $control.Enabled = $false }
    if (!$isAutomatic) {
        Set-Unknown
        $connection.Text = '等待板子確認…'
        $sent.Text = '等待傳送結果…'
        $reply.Text = ''
        Add-Log "要求：$command（$($ports.Text)）"
    }
    # Run serial I/O in a separate runspace so a timeout cannot freeze the UI.
    $script:worker = [powershell]::Create()
    [void]$script:worker.AddCommand($script:senderPath).AddParameter('Port', $ports.Text).AddParameter('Command', $command)
    $script:pending = $script:worker.BeginInvoke()
}
function Receive-Result($result, [bool]$isAutomatic) {
    $script:lastResult = $result
    if ($null -ne $result.Reply) {
        $blue.Text = '藍燈：' + @('關', '開')[[int]$result.Blue]
        $green.Text = '綠燈：' + @('關', '開')[[int]$result.Green]
        $blue.ForeColor = if ($result.Blue) { [System.Drawing.Color]::RoyalBlue } else { [System.Drawing.Color]::DimGray }
        $green.ForeColor = if ($result.Green) { [System.Drawing.Color]::SeaGreen } else { [System.Drawing.Color]::DimGray }
        $confirmed.Text = '板子最後回報：' + (Get-Date -Format 'HH:mm:ss') + '（輸出狀態，非光學量測）'
        if ($result.Success) {
            $connection.Text = '通訊正常｜板子已確認'
            $connection.ForeColor = [System.Drawing.Color]::SeaGreen
        } else {
            $connection.Text = '板子拒絕無效指令｜燈號以回覆為準'
            $connection.ForeColor = [System.Drawing.Color]::DarkOrange
        }
    } else {
        Set-Unknown
        $connection.Text = if ($result.Error -like 'Response timeout*') {
            '回覆逾時｜執行結果與目前燈號未知'
        } else { '通訊失敗｜請檢查 USB、連接埠或其他程式是否占用' }
        $connection.ForeColor = [System.Drawing.Color]::Firebrick
    }
    # Background STATUS must not overwrite the user's last command/response.
    if (!$isAutomatic) {
        $sent.Text = if ($result.Sent) { $result.Sent } else { '未送出' }
        $reply.Text = if ($result.Reply) { $result.Reply } else { '未收到有效回覆' }
    }
    $summary = "$($result.Success)|$($result.Blue)|$($result.Green)|$($result.Error)"
    if (!$isAutomatic -or $summary -ne $script:lastSummary) {
        if ($result.Sent) { Add-Log "TX：$($result.Sent)" }
        if ($result.Reply) { Add-Log "RX：$($result.Reply)" }
        if ($result.Error) { Add-Log "錯誤：$($result.Error)" }
    }
    $script:lastSummary = $summary
}
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 80
$timer.Add_Tick({
    if ($null -ne $script:capture) {
        if ($script:capture.Completed) {
            if ($script:capture.Error) {
                $speech.Text = '語音辨識失敗：' + $script:capture.Error
            } elseif ($script:speechCancelled -or $script:capture.Cancelled) {
                $speech.Text = '辨識已取消或超時；未傳送 LED 指令'
            } elseif (!$script:capture.Text) {
                $speech.Text = '未辨識到語音，請確認麥克風並重試'
            } else {
                $speech.Text = $script:capture.Text
            }
            $speechCommand = if ($script:capture.IsControlCommand) { $script:capture.ControlCommand } else { $null }
            $speechDecision = if ($speechCommand) { '有效控制語句，準備傳送 ' + $speechCommand } else { '非控制語句或信心不足，未傳送 LED 指令' }
            Add-Log ('語音：' + $speech.Text + '｜信心分數 ' + $script:capture.Confidence.ToString('0.00') + '｜收音峰值 ' + $script:capture.PeakLevel + '/100｜偵測語音 ' + $script:capture.SpeechDetected + '｜音訊診斷 ' + $script:capture.AudioProblem + '｜' + $speechDecision)
            $playSpeech.Enabled = $script:capture.RecordingSaved
            if ($script:capture.RecordingSaved) { Add-Log '本次辨識語音片段已存於 build/speech-last.wav，可按「播放辨識錄音」聽取。' }
            if ($script:capture.RecordingError) { Add-Log ('儲存錄音失敗：' + $script:capture.RecordingError) }
            $script:capture.Dispose()
            $script:capture = $null
            $micButton.Enabled = $true
            $cancelSpeech.Enabled = $false
            if ($speechCommand) { $script:speechCommandQueued = $speechCommand }
        } elseif ($script:capture.Seconds -gt 18 -and !$script:speechCancelled) {
            $script:speechCancelled = $true
            $script:capture.Cancel()
        } elseif ($script:capture.Seconds -gt 8 -and !$script:speechFinishing -and !$script:speechCancelled) {
            $script:speechFinishing = $true
            $script:capture.Finish()
            $speech.Text = '已停止收音，正在處理辨識結果…'
        } elseif (!$script:speechFinishing -and !$script:speechCancelled) {
            $speech.Text = '正在聆聽｜目前音量 ' + $script:capture.CurrentLevel + '/100｜請說一句後停頓'
        }
    }
    if ($null -eq $script:worker -and $null -ne $script:speechCommandQueued) {
        $queuedCommand = $script:speechCommandQueued
        $script:speechCommandQueued = $null
        Start-Command $queuedCommand
    }
    if ($null -ne $script:worker -and $script:pending.IsCompleted) {
        try {
            $items = $script:worker.EndInvoke($script:pending)
            if ($items.Count -ne 1 -or $script:worker.HadErrors) { throw 'Serial worker did not return one valid result.' }
            Receive-Result $items[0] $script:automatic
        } catch {
            Receive-Result ([pscustomobject]@{ Sent=$null; Reply=$null; Success=$false; Blue=$null; Green=$null; Error=$_.Exception.Message }) $script:automatic
        } finally {
            $script:worker.Dispose()
            $script:worker = $null
            $script:pending = $null
            foreach ($control in $script:controls) { $control.Enabled = $true }
            $script:nextPoll = [datetime]::Now.AddSeconds(3)
        }
    } elseif ($null -eq $script:worker -and $autoPoll.Checked -and [datetime]::Now -ge $script:nextPoll) {
        $script:nextPoll = [datetime]::Now.AddSeconds(3)
        Start-Command 'STATUS' $true
    }
})
$blueButton.Add_Click({ Start-Command 'BLUE_ON' })
$greenButton.Add_Click({ Start-Command 'GREEN_ON' })
$offButton.Add_Click({ Start-Command 'ALL_OFF' })
$invalidButton.Add_Click({ Start-Command 'INVALID' })
$query.Add_Click({ Start-Command 'STATUS' })
$refresh.Add_Click({ Refresh-Ports })
$micButton.Add_Click({
    try {
        $script:speechCancelled = $false
        $script:speechFinishing = $false
        $script:player.Stop()
        $playSpeech.Enabled = $false
        [void][System.IO.Directory]::CreateDirectory((Join-Path $PSScriptRoot '..\build'))
        $script:capture = New-Object SpeechCapture
        $script:capture.RecordingPath = $script:recordingPath
        $script:capture.Start($null)
        $micButton.Enabled = $false
        $cancelSpeech.Enabled = $true
        $speech.Text = '正在聆聽，請說「左邊開燈」「右邊開燈」或其他測試語句…'
        Add-Log '開始麥克風辨識：zh-TW，指定控制語句＋一般語句'
    } catch {
        if ($null -ne $script:capture) { $script:capture.Dispose(); $script:capture = $null }
        $speech.Text = '無法啟動辨識；請檢查麥克風及 Windows 麥克風權限'
        Add-Log ('語音啟動失敗：' + $_.Exception.Message)
    }
})
$cancelSpeech.Add_Click({
    if ($null -ne $script:capture) { $script:speechCancelled = $true; $script:capture.Cancel() }
})
$playSpeech.Add_Click({
    try {
        $script:player.SoundLocation = $script:recordingPath
        $script:player.Load()
        $script:player.Play()
    } catch { Add-Log ('錄音播放失敗：' + $_.Exception.Message) }
})
$ports.Add_TextChanged({
    Set-Unknown
    $connection.Text = '連接埠已變更，等待查詢'
    $sent.Text = ''
    $reply.Text = ''
})
$exportButton.Add_Click({
    $dialog = New-Object System.Windows.Forms.SaveFileDialog
    $dialog.Filter = '文字紀錄 (*.txt)|*.txt'
    $dialog.FileName = 'ameba-led-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.txt'
    try {
        if ($dialog.ShowDialog() -eq 'OK') {
            [System.IO.File]::WriteAllText($dialog.FileName, $log.Text, [System.Text.Encoding]::UTF8)
        }
    } catch { [void][System.Windows.Forms.MessageBox]::Show('匯出失敗：' + $_.Exception.Message) }
    finally { $dialog.Dispose() }
})
$form.Add_FormClosing({
    $timer.Stop()
    if ($null -ne $script:worker) {
        $script:worker.Stop()
        $script:worker.Dispose()
        $script:worker = $null
    }
})
Refresh-Ports
$timer.Start()
try {
    if ($SmokeTest) {
        # Exercise the real event loop and serial worker, then briefly show a preview.
        $autoPoll.Checked = $false
        function Wait-Command {
            $deadline = [datetime]::Now.AddSeconds(10)
            while ($null -ne $script:worker) {
                [System.Windows.Forms.Application]::DoEvents()
                Start-Sleep -Milliseconds 20
                if ([datetime]::Now -gt $deadline) { throw 'UI worker did not finish.' }
            }
        }
        $ports.Text = 'COM4'
        Start-Command 'STATUS'
        Wait-Command
        if (!$script:lastResult.Success -or !$reply.Text.StartsWith('ACK ')) { throw 'Real board STATUS did not reach UI.' }
        $oldBlue = $blue.Text
        $oldGreen = $green.Text
        Start-Command 'INVALID'
        Wait-Command
        if ($script:lastResult.Success -or $blue.Text -ne $oldBlue -or $green.Text -ne $oldGreen -or $reply.Text -notmatch 'ERR_COMMAND') { throw 'Invalid command UI check failed.' }
        $ports.Text = 'COM9999'
        Start-Command 'STATUS'
        Wait-Command
        if ($script:lastResult.Success -or $blue.Text -ne '藍燈：未知' -or $sent.Text -ne '未送出') { throw 'Connection failure UI check failed.' }
        $ports.Text = 'COM4'
        Start-Command 'STATUS'
        Wait-Command
        if (!$script:lastResult.Success) { throw 'UI did not recover after port correction.' }
        $bitmap = New-Object System.Drawing.Bitmap($form.Width, $form.Height)
        try {
            [void][System.IO.Directory]::CreateDirectory((Join-Path $PSScriptRoot '..\build'))
            $form.Show()
            [System.Windows.Forms.Application]::DoEvents()
            $form.DrawToBitmap($bitmap, (New-Object System.Drawing.Rectangle(0, 0, $form.Width, $form.Height)))
            $bitmap.Save((Join-Path $PSScriptRoot '..\build\ui-preview.png'))
        } finally { $form.Hide(); $bitmap.Dispose() }
        Write-Output 'PASS: UI event loop, live board ACK, invalid command, missing port, recovery.'
    } else {
        $form.Add_Shown({ Start-Command 'STATUS' })
        [void]$form.ShowDialog()
    }
} finally {
    $timer.Stop()
    $timer.Dispose()
    if ($null -ne $script:capture) { $script:capture.Dispose() }
    $script:player.Stop()
    $script:player.Dispose()
    if ($null -ne $script:worker) { $script:worker.Stop(); $script:worker.Dispose() }
    $form.Dispose()
}
