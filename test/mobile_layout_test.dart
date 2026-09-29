import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_comm/main.dart';

void main() {
  testWidgets('serial controls fit a narrow phone', (tester) async {
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
    });

    await tester.pumpWidget(const PhoneCommApp());
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('串口设置'), findsOneWidget);
    expect(find.text('数据日志'), findsOneWidget);
    expect(find.text('数据发送'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
