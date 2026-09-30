# AMB82-MINI 語音控制 LED

目前進行第五階段：本機繁體中文語音辨識已串接 LED。只有指定控制語句文法、完全相符且信心分數至少 0.20 時才送出指令；門檻依本機引擎測試結果設定。

真人功能測試已通過：左邊開燈、右邊開燈及非控制語句均符合預期。下一階段進行正式驗收紀錄（兩句各五次、非控制語句及通訊中斷）。

**啟動介面：雙擊 `Start-LedControl.cmd`。** 使用第二階段韌體，不需重新燒錄。

- [第三階段介面操作](docs/stage3.md)
- [第四階段語音辨識測試](docs/stage4.md)
- [第五階段安全語音控制](docs/stage5.md)
- [第二階段操作與通訊格式](docs/stage2.md)
- [AI 協作紀錄](docs/ai-collaboration.md)
- 現用韌體：`led_control/led_control.ino`。
- 電腦測試工具：`tools/Send-LedCommand.ps1`。

下列保留第一階段的硬體驗證紀錄。

## 測試程式

`led_test/led_test.ino`

- 藍燈：`LED_B`，D23 / PF9。
- 綠燈：`LED_G`，D24 / PE6。
- 循環：藍燈亮 → 全暗 → 綠燈亮 → 全暗，每步 1 秒。
- 串列輸出：115200 baud。`LED_TEST` 訊息表示程式執行的輸出狀態，實際發光仍須目視確認。

## 目前驗證紀錄

- Windows 偵測到 USB-SERIAL CH340（COM4）。
- COM4 可開啟。
- 使用已安裝的 Realtek AmebaPro2 4.0.9-build20250805 編譯成功。
- 編譯目標：`realtek:AmebaPro2:Ameba_AMB82-MINI`。
- 程式映像大小：4,788,224 bytes（28%）。
- 編譯工具須在命令環境中設定 `LC_ALL=C`、`LANG=C`，避免語系錯誤。
- 官方 `image_windows.exe` 燒錄工具透過 COM4 回報 `upload success`，上傳成功。
- Arduino CLI 1.5.1 的獨立 upload 命令無法辨識此套件的產物，改用套件 `platform.txt` 定義的官方燒錄工具完成。
- 上傳前已確認工具目錄與編譯目錄的 `flash_ntz.bin` SHA-256 相同：`53390335CA3FA1D643C1AADF970EF39731C52B65CFB89E4B860278ABF9339791`。
- 上傳後按 RESET 啟動，使用者確認藍燈與綠燈依序閃爍。
- 電腦已收到循環的 `LED_TEST BLUE=ON GREEN=OFF`、`LED_TEST BLUE=OFF GREEN=ON` 及全暗訊息；擷取紀錄在 `build/led_test/serial-check.txt`。
- 第一階段驗收通過：USB 串列連線、燒錄、板上兩顆 LED 輸出、板子到電腦的串列訊息。
- 尚未測試電腦傳送應用層指令控制 LED；目前韌體為自動循環測試。

## 手動進入下載模式

USB 保持連接，按住 UART_DOWNLOAD，按下並放開 RESET，最後放開 UART_DOWNLOAD。
上傳完成後，若程式未啟動，按一下 RESET。

官方參考：https://github.com/Ameba-AIoT/ameba-arduino-doc/blob/main/source/ameba_pro2/amb82-mini/Getting_Started/Getting%20Started%20with%20Ameba.rst
