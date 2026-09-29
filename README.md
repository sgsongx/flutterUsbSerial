# PhoneComm 串口测试 Demo

Android 手机通过 USB-C/OTG 连接 USB 转串口模块，提供设备扫描、授权、连接、常用波特率的 8N1 通信、文本/HEX 发送和收发日志。USB 权限由系统在连接时弹窗申请；无需给手机安装 PC 串口驱动。`third_party/usb_serial` 是 [usb_serial 0.5.2](https://pub.dev/packages/usb_serial/versions/0.5.2) 的本地副本，补上该版本缺少的 `dart:typed_data` 导入，并复用应用的 Android Gradle 插件；原许可见该目录 `LICENSE`。

```powershell
fvm flutter pub get
fvm flutter run
```

当前网络若无法连接 Flutter 默认制品站，可按 [Flutter 官方镜像说明](https://docs.flutter.dev/community/china) 在当前 PowerShell 会话中设置 `$env:FLUTTER_STORAGE_BASE_URL='https://storage.flutter-io.cn'`，然后执行 `fvm flutter build apk --debug`。APK 输出为 `build/app/outputs/flutter-apk/app-debug.apk`。

手机 USB 口被模块占用时，可以安装调试 APK 或用 Android 11+ 无线 ADB 部署。运行前确认手机支持 USB Host、OTG 线可传数据、模块芯片受插件支持，并检查目标板电平。首次验证建议先断开目标板，仅短接模块串口侧 TX/RX 做回环：打开 HEX 发送，发送 `01 A0 FF`，日志应收到同样的 HEX 字节。接目标板前先确认 TTL/RS-232/RS-485 类型以及 3.3 V/5 V 电平。

数据日志区的时钟控制界面时间戳，向下箭头控制收到新记录时是否滚到底部。圆形记录按钮可输入文件名，选择文件时间戳及追加或清空同名文件；再次点击停止。实时文件保存在 Android 10+ 的 `下载/PhoneComm/`，旧版 Android 保存在应用专属文档目录。日志菜单可将内存中最近 800 条另存为文件，也可将它们追加到正在记录的文件。界面时间戳开关不影响文件时间戳；两者均显示到毫秒。安装新 APK 后如显示“未连接”，需重新点击“打开”连接串口才能发送。

此 Demo 仅支持 Android 前台交互；界面日志仅保留最近 800 条，实时记录按收到的日志持续写入文件。文本预览按每次 USB 收包解码，跨包 UTF-8 字符可能显示为替换字符，HEX 字节不受影响。高波特率持续收数、具体硬件兼容性和锁屏后台运行仍须实机验证。详情见 [可行性报告](USB_SERIAL_FEASIBILITY.md)。
