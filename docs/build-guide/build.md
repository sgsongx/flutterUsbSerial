# 构建与验证

在工程根目录 `E:\Studying\Project\PhoneComm` 执行。`.fvmrc` 指定 Flutter 3.0.5；本次运行 `fvm flutter --version` 显示 Dart 2.17.6。`pubspec.yaml` 使用本地 `third_party/usb_serial`；`android/build.gradle` 声明 Android Gradle Plugin 7.1.2、Kotlin 1.6.10，`android/gradle/wrapper/gradle-wrapper.properties` 使用 Gradle 7.4.2，`android/gradle.properties` 指向本机 JDK 11。`android/app/build.gradle` 设 `compileSdkVersion 33`，`minSdkVersion`/`targetSdkVersion` 来自 Flutter SDK，应用 ID 是 `com.example.phone_comm`。

```powershell
fvm flutter pub get
fvm flutter analyze
fvm flutter test
fvm flutter build apk --debug
fvm flutter run
```

- 2026-09-29：`fvm flutter --version`、`fvm flutter analyze` 成功，分析无问题；`fvm flutter test` 成功，3 个测试通过。
- 本次未执行 `pub get`、APK 构建或 `flutter run`。仓库 `build/app/outputs/flutter-apk/app-debug.apk` 有 2026-09-28 的本地旧产物，不能代表本次构建通过；该目录由 `.gitignore` 忽略。
- Debug APK 预期路径为 `build/app/outputs/flutter-apk/app-debug.apk`（`README.md`）。运行需 Android SDK、JDK、Gradle 依赖可用；部署与 USB 串口收发需目标手机及模块。串口侧电平/回环检查见 `README.md`。
- `test/hex_test.dart` 仅覆盖纯编码逻辑；`test/mobile_layout_test.dart` 以模拟通道验证窄屏控件。两者不能证明实机 USB 授权、芯片兼容、连续收发或文件选择器行为。

当前 `README.md` 给出网络无法访问 Flutter 默认制品站时的镜像变量。`.vscode/tasks.json` 中任务名为“Wi-Fi 无线调试配对”，实际执行的是 `adb connect`，不执行 `adb pair`；无线调试需先单独配对并使用手机显示的连接端口。此处是配置审计发现，未修改该任务。
