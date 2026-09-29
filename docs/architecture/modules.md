# 模块职责

范围：当前 Android Flutter 工程；Flutter 3.0.5 配置见 `.fvmrc`。一方应用代码在 `lib/main.dart` 和 `android/app/src/main/kotlin/`；`third_party/usb_serial` 是本地第三方插件副本，不把它的辅助 `echo_port.dart`、`transaction.dart` 当作应用模块。

## Flutter 串口页面

- 路径/职责：`lib/main.dart` 的 `main()`、`PhoneCommApp`、`SerialPage`、`_SerialPageState` 提供设备选择、参数设置、收发、日志和文件操作界面。
- 所有权：页面持有 `UsbPort? _port`、`_receiveSubscription`、`_usbSubscription`、控制器、`_entries`、`_history`、计数器、记录状态和 `Timer`。`_connect()` 将临时端口转交 `_port`；`_disconnect()` 与 `dispose()` 清理连接/订阅/定时器。页面不拥有 Android USB 权限和文件 URI。
- 入口/接口：`_scanDevices()`、`_connect()`、`_disconnect()`、`_send()`、`_onReceived()`、`_sendFile()`、`_saveLog()`、`_toggleRecording()`、`_appendRecentToRecording()`；公开纯函数 `parseHex()`、`toHex()`、`encodeText()`、`formatTimestamp()`。`_generation` 用于丢弃过期连接/文件发送流程。
- 依赖：`UsbSerial`/`UsbPort`；`phone_comm/files` 方法通道。依据：`lib/main.dart` 的 `initState`、`_connect`、`_sendFile`、`_saveLog`。
- 范围：界面日志保留最近 800 条，发送历史仅在页面内存；实时记录按收到的日志持续写入文件。接收文本对每次 USB 收包独立解码，跨包 UTF-8 字符可能显示异常。依据：`_entries`、`_record`、`_history`、`_logItem`。

## 本地 USB 串口插件

- 路径/职责：`third_party/usb_serial/lib/usb_serial.dart` 提供 Dart 的 `UsbSerial`、`UsbDevice`、`UsbPort`；`android/src/main/java/dev/bessems/usbserial/UsbSerialPlugin.java` 负责设备枚举、USB 广播和权限；`UsbSerialPortAdapter.java` 负责每个端口的读写和参数设置。
- 所有权：Android 插件拥有 `UsbManager`、USB 广播接收器和端口适配器；端口适配器持有 `UsbDeviceConnection` 及底层 `UsbSerialDevice`。页面仅持有 Dart 侧 `UsbPort` 句柄。依据：`UsbSerialPlugin.register`、`openDevice`，`UsbSerialPortAdapter` 构造与 `close`。
- 入口/接口：`UsbSerial.listDevices()`、`UsbDevice.create()`、`UsbPort.open()`/`write()`/`inputStream`，以及 `UsbSerial.usbEventStream`。底层依赖 `com.github.felHR85:UsbSerial:6.1.0`，见插件 `android/build.gradle`。
- 边界：这是第三方代码的本地副本，修改时核对原许可 `third_party/usb_serial/LICENSE`；主工程 `analysis_options.yaml` 排除了该目录的 Dart 分析。

## Android 文件桥接与应用壳

- 路径/职责：`android/app/src/main/kotlin/com/example/phone_comm/MainActivity.kt` 继承 `FlutterActivity`，提供 `pickFile`、`saveLog`、`startRecording`、`appendRecording`、`stopRecording` 等 `phone_comm/files` 方法；`android/app/src/main/AndroidManifest.xml` 声明 USB Host 和启动 Activity。
- 所有权：`MainActivity` 保存一次待完成的文档选择器结果，并在 `onActivityResult()` 中处理；打开文件后在缓存目录生成临时文件，页面 `_sendFile()` 使用后删除。记录流由单线程执行器串行写入并在停止或页面销毁时关闭。它不处理串口数据。
- 入口/接口：`configureFlutterEngine()` 注册方法通道，`onActivityResult()` 分发 `ACTION_OPEN_DOCUMENT`/`ACTION_CREATE_DOCUMENT` 的结果；Android 10+ 通过 MediaStore 写入 `下载/PhoneComm/`，旧版写入应用专属文档目录。依据：`MainActivity.kt`。

## 测试与构建

- `test/hex_test.dart` 覆盖 HEX、转义编码及记录格式；`test/mobile_layout_test.dart` 模拟窄屏；`test/log_recording_test.dart` 覆盖自动滚屏及记录交互。
- `pubspec.yaml` 引入 Flutter 和本地插件；`android/build.gradle`、`android/app/build.gradle`、`android/gradle/wrapper/gradle-wrapper.properties` 定义 Android 构建。命令及本次验证见 [构建说明](../build-guide/build.md)。
