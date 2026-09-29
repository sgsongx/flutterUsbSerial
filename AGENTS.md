# PhoneComm 工程导航

Android 前台 USB 串口调试 Demo，Flutter 3.0.5 / Dart 2.17.6（`.fvmrc`、`pubspec.yaml`）。应用入口为 `lib/main.dart:main()`；Android USB Host 声明在 `android/app/src/main/AndroidManifest.xml`。

- 修改 UI、收发、日志或连接生命周期时，先读 [模块职责](docs/architecture/modules.md) 和 [事件与通道](docs/interfaces/event-map.md)，再定位 `lib/main.dart` 的相关方法。
- 修改启动或平台通道时，读 [启动流程](docs/architecture/startup-flow.md)，核对 `MainActivity.kt`、`UsbSerialPlugin.java` 的注册和回调两端。
- 构建、测试和设备验证读 [构建说明](docs/build-guide/build.md)；基础使用和硬件前提读 [README](README.md)。
- 一方代码在 `lib/` 与 `android/app/`；`third_party/usb_serial` 是带许可的本地第三方插件副本。`.fvm/`、`.dart_tool/`、`build/` 和 Android 生成文件是构建产物。
- 代码检查：在仓库根目录运行 `fvm flutter analyze`、`fvm flutter test`。2026-09-29 两者均通过；APK 构建、USB 授权与实机串口收发仍需分别验证。

<!-- CODEGRAPH_START -->
## CodeGraph

In repositories indexed by CodeGraph (a `.codegraph/` directory exists at the repo root), reach for it BEFORE grep/find or reading files when you need to understand or locate code:

- **MCP tool** (when available): `codegraph_explore` answers most code questions in one call — the relevant symbols' verbatim source plus the call paths between them, including dynamic-dispatch hops grep can't follow. Name a file or symbol in the query to read its current line-numbered source. If it's listed but deferred, load it by name via tool search.
- **Shell** (always works): `codegraph explore "<symbol names or question>"` prints the same output.

If there is no `.codegraph/` directory, skip CodeGraph entirely — indexing is the user's decision.
<!-- CODEGRAPH_END -->

当前仓库没有 `.codegraph/`；可用时先查语言服务，再用 `rg` 和源码定位。架构入口见 [ARCHITECTURE.md](ARCHITECTURE.md)，全部知识文档见 [docs/index.md](docs/index.md)。

