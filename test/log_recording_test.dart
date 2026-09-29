import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_comm/main.dart';

void main() {
  testWidgets('paused log stays put and file timestamps stay independent',
      (tester) async {
    const usb = MethodChannel('usb_serial');
    const port = MethodChannel('fake_port');
    const stream = MethodChannel('fake_port/stream');
    const files = MethodChannel('phone_comm/files');
    final writes = <String>[];
    final appendModes = <bool>[];

    usb.setMockMethodCallHandler((call) async {
      if (call.method == 'listDevices') {
        return <Object>[
          <String, Object>{
            'deviceName': 'fake',
            'vid': 1,
            'pid': 2,
            'productName': 'Fake serial',
            'deviceId': 3,
          }
        ];
      }
      if (call.method == 'create') return 'fake_port';
      return null;
    });
    port.setMockMethodCallHandler((call) async =>
        call.method == 'open' || call.method == 'close' ? true : null);
    stream.setMockMethodCallHandler((call) async => null);
    files.setMockMethodCallHandler((call) async {
      if (call.method == 'startRecording') {
        appendModes.add((call.arguments as Map)['append'] as bool);
        return '下载/PhoneComm/serial-log.txt';
      }
      if (call.method == 'appendRecording') {
        writes.add((call.arguments as Map)['text'] as String);
        return true;
      }
      if (call.method == 'stopRecording') return true;
      return null;
    });
    addTearDown(() {
      usb.setMockMethodCallHandler(null);
      port.setMockMethodCallHandler(null);
      stream.setMockMethodCallHandler(null);
      files.setMockMethodCallHandler(null);
      tester.binding.window.clearPhysicalSizeTestValue();
      tester.binding.window.clearDevicePixelRatioTestValue();
    });
    tester.binding.window.physicalSizeTestValue = const Size(360, 800);
    tester.binding.window.devicePixelRatioTestValue = 1;

    Future<void> receive(String value) async {
      await TestDefaultBinaryMessengerBinding.instance!.defaultBinaryMessenger
          .handlePlatformMessage(
        'fake_port/stream',
        const StandardMethodCodec()
            .encodeSuccessEnvelope(Uint8List.fromList(utf8.encode(value))),
        (_) {},
      );
    }

    await tester.pumpWidget(const PhoneCommApp());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('打开'));
    await tester.pump(const Duration(milliseconds: 100));
    for (var i = 0; i < 25; i++) {
      await receive('message $i');
    }
    await tester.pump(const Duration(milliseconds: 100));
    final list = find.byType(ListView).first;
    final scrollable = tester.state<ScrollableState>(
        find.descendant(of: list, matching: find.byType(Scrollable)).first);
    expect(scrollable.position.maxScrollExtent, greaterThan(0));
    expect(scrollable.position.pixels, scrollable.position.maxScrollExtent);

    await tester.tap(find.byTooltip('关闭自动滚屏'));
    scrollable.position.jumpTo(0);
    await tester.pump();
    final firstVisible = tester.widget<SelectableText>(
        find.descendant(of: list, matching: find.byType(SelectableText)).first);
    await receive('message 25');
    await tester.pump(const Duration(milliseconds: 100));
    expect(scrollable.position.pixels, 0);
    expect(
        tester
            .widget<SelectableText>(find
                .descendant(of: list, matching: find.byType(SelectableText))
                .first)
            .data,
        firstVisible.data);

    await tester.tap(find.byTooltip('隐藏界面时间戳'));
    await tester.pump();
    await tester.tap(find.byTooltip('开始实时记录'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();
    expect(appendModes, [true]);
    await receive('recorded');
    await tester.pump(const Duration(milliseconds: 100));
    expect(writes.join(),
        contains(RegExp(r'\d{4}-\d\d-\d\d \d\d:\d\d:\d\d\.\d{3} RX')));
    expect(find.byTooltip('显示界面时间戳'), findsOneWidget);

    await tester.tap(find.byTooltip('停止实时记录'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('开始实时记录'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('清空同名文件'));
    await tester.tap(find.text('文件包含时间戳'));
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();
    expect(appendModes, [true, false]);

    await tester.tap(find.byTooltip('显示界面时间戳'));
    await tester.pump();
    await receive('no timestamp');
    await tester.pump(const Duration(milliseconds: 100));
    expect(writes.last, startsWith('RX '));
    expect(find.byTooltip('隐藏界面时间戳'), findsOneWidget);

    await tester.tap(find.byTooltip('日志操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('追加最近800条到记录文件'));
    await tester.pumpAndSettle();
    expect(writes.last, contains('message 0'));
    expect(writes.last, startsWith('SYS '));
  });
}
