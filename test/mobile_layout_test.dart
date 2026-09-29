import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_comm/main.dart';

void main() {
  testWidgets('send field keeps focus when keyboard opens', (tester) async {
    const MethodChannel('usb_serial')
        .setMockMethodCallHandler((call) async => <Object>[]);
    const MethodChannel('usb_serial/usb_events')
        .setMockMethodCallHandler((call) async => null);
    addTearDown(() {
      const MethodChannel('usb_serial').setMockMethodCallHandler(null);
      const MethodChannel('usb_serial/usb_events')
          .setMockMethodCallHandler(null);
    });
    tester.binding.window.physicalSizeTestValue = const Size(360, 800);
    tester.binding.window.devicePixelRatioTestValue = 1;
    addTearDown(() {
      tester.binding.window.clearPhysicalSizeTestValue();
      tester.binding.window.clearDevicePixelRatioTestValue();
      tester.binding.window.clearViewInsetsTestValue();
    });

    await tester.pumpWidget(const PhoneCommApp());
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('串口设置'), findsOneWidget);
    expect(find.text('数据日志'), findsOneWidget);
    expect(find.text('数据发送'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(
        tester
            .widget<EditableText>(find.byType(EditableText))
            .focusNode
            .hasFocus,
        isTrue);

    tester.binding.window.viewInsetsTestValue = const _TestWindowPadding(300);
    await tester.pump();
    expect(
        tester
            .widget<EditableText>(find.byType(EditableText))
            .focusNode
            .hasFocus,
        isTrue);
  });
}

class _TestWindowPadding implements ui.WindowPadding {
  const _TestWindowPadding(this.bottom);

  @override
  final double bottom;
  @override
  double get top => 0;
  @override
  double get left => 0;
  @override
  double get right => 0;
}
