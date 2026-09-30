# 第二階段：電腦指令與開發板回覆

## 範圍

電腦 PowerShell → USB 串列（115200、8N1）→ AMB82-MINI → LED → 串列回覆。
本階段先使用文字測試工具，尚未加入圖形介面或語音辨識。

韌體：`led_control/led_control.ino`。上電或 RESET 時兩燈關閉；連線中斷不會自動改變燈號。
藍燈 D23 / PF9，綠燈 D24 / PE6，HIGH 亮、LOW 滅。

## 操作

在專案資料夾開啟 PowerShell，輸入：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Send-LedCommand.ps1 -Command STATUS
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Send-LedCommand.ps1 -Command BLUE_ON
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Send-LedCommand.ps1 -Command GREEN_ON
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Send-LedCommand.ps1 -Command INVALID
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Send-LedCommand.ps1 -Command ALL_OFF
```

預設 COM4，若埠號變動，附加 `-Port COM5` 等正確埠號。執行時關閉其他串列監控視窗。
`ExecutionPolicy Bypass` 只作用於本次 PowerShell 程序，不更改系統設定。

- `Sent`：成功交給串列寫入函式的指令，不代表板子已執行。
- `Reply`：收到且識別碼相符的板子原始回覆。
- `Success`：板子是否回覆 OK。
- `Blue` / `Green`：板子回報的軟體輸出狀態，1 亮、0 滅；不代表光學量測。
- `Error`：無效指令、開埠失敗或逾時原因。
- 未收到相符回覆時，Blue / Green 留空。指令可能已執行但回覆遺失，不能假設燈號不變。

## 通訊格式

每行以 LF 結尾，也接受 CRLF。請求：8 位小寫十六進位識別碼、空格、指令。

```text
1234abcd BLUE_ON
ACK 1234abcd OK BLUE=1 GREEN=0
1234abce INVALID
ACK 1234abce ERR_COMMAND BLUE=1 GREEN=0
```

只接受 `BLUE_ON`、`GREEN_ON`、`ALL_OFF`、`STATUS`，不做關鍵字包含比對。
未知指令、格式錯誤、含 NUL 或過長封包均不控制 LED。過長封包丟棄到下一個 LF，避免截斷後誤執行。
電腦每次連線先送 LF 清除未完成封包，再以新的識別碼送指令；忽略其他識別碼和啟動訊息。
目前不自動重送；逾時後可重新連線並查詢 STATUS。

## 驗證方式

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Test-LedControl.ps1
```

依序驗證全暗、藍燈開啟、重複開啟、無效指令、兩燈亮、無效指令、查詢及全暗。
腳本比對板子回覆，仍需目視確認燈號；這不是最終語音驗收。
另外拔除 USB 後送 STATUS，應出現通訊失敗、狀態留空；插回後 RESET 會讓燈號回到全暗。

## 進度

- 韌體編譯成功。
- 官方燒錄工具回報 `upload success`；按 RESET 後，使用者確認兩燈熄滅。
- 8 項實機指令測試全部通過，原始回覆見 `stage2-command-results.txt`。
- 追加測試格式錯誤、過長封包、含 NUL 封包及含控制關鍵字的未知指令，均被拒絕，藍燈開／綠燈關狀態不變。
- 藍燈單獨開啟：使用者已目視確認。
- 綠燈單獨開啟：板子回覆 BLUE=0 GREEN=1，使用者已目視確認。
- 指定不存在的串列埠：已驗證通訊失敗提示，Blue / Green 留空。
- 使用者實際拔除 USB 後查詢 COM4：工具顯示通訊失敗（埠不存在）、Success=False、Reply/Blue/Green 留空。紀錄見 `stage2-disconnect-result.txt`。
- 本階段通過指令控制與拔線錯誤處理；「埠仍存在但板子不回覆」的逾時分支已實作，尚未實機驗證。
