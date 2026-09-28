import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:usb_serial/usb_serial.dart';

void main() => runApp(const PhoneCommApp());

Uint8List parseHex(String input) {
  final value = input.replaceAll(RegExp(r'\s+'), '');
  if (value.isEmpty ||
      value.length.isOdd ||
      !RegExp(r'^[0-9a-fA-F]+$').hasMatch(value)) {
    throw const FormatException('请输入偶数个十六进制字符，例如 01 A0 FF');
  }
  return Uint8List.fromList(List<int>.generate(
    value.length ~/ 2,
    (index) => int.parse(value.substring(index * 2, index * 2 + 2), radix: 16),
  ));
}

String toHex(List<int> bytes) => bytes
    .map((byte) => byte.toRadixString(16).padLeft(2, '0').toUpperCase())
    .join(' ');

class PhoneCommApp extends StatelessWidget {
  const PhoneCommApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'PhoneComm 串口测试',
        theme: ThemeData(primarySwatch: Colors.blue),
        home: const SerialPage(),
      );
}

class SerialPage extends StatefulWidget {
  const SerialPage({Key? key}) : super(key: key);

  @override
  State<SerialPage> createState() => _SerialPageState();
}

class _SerialPageState extends State<SerialPage> {
  final _sendController = TextEditingController();
  final _lines = <String>[];
  List<UsbDevice> _devices = [];
  UsbDevice? _selectedDevice;
  UsbPort? _port;
  StreamSubscription<Uint8List>? _receiveSubscription;
  StreamSubscription<UsbEvent>? _usbSubscription;
  String? _connectedDeviceName;
  String _status = '请连接 USB 转串口模块并扫描设备';
  int _baudRate = 115200;
  int _generation = 0;
  bool _busy = false;
  bool _hexSend = false;
  bool _dtr = false;

  @override
  void initState() {
    super.initState();
    _usbSubscription = UsbSerial.usbEventStream?.listen((event) {
      if (event.event == UsbEvent.ACTION_USB_DETACHED &&
          event.device?.deviceName == _selectedDevice?.deviceName) {
        _disconnect('设备已拔出');
      }
      _scanDevices();
    }, onError: (Object error) => _showError('USB 事件错误：$error'));
    _scanDevices();
  }

  Future<void> _scanDevices() async {
    try {
      final devices = await UsbSerial.listDevices();
      if (!mounted) return;
      final selectedName = _selectedDevice?.deviceName;
      final selected =
          devices.where((device) => device.deviceName == selectedName);
      setState(() {
        _devices = devices;
        _selectedDevice = selected.isNotEmpty
            ? selected.first
            : (devices.isEmpty ? null : devices.first);
      });
      if (_connectedDeviceName != null &&
          !devices.any((device) => device.deviceName == _connectedDeviceName)) {
        await _disconnect('设备已断开');
      }
    } catch (error) {
      _showError('扫描失败：$error');
    }
  }

  Future<void> _connect() async {
    final device = _selectedDevice;
    if (device == null || _busy) return;
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _status = '正在请求 USB 权限并连接…';
    });

    UsbPort? port;
    try {
      port = await device.create();
      if (port == null) throw StateError('不支持此 USB 设备');
      if (generation != _generation) return;
      if (!await port.open()) throw StateError('串口打开失败');
      if (generation != _generation) return;
      await port.setPortParameters(
        _baudRate,
        UsbPort.DATABITS_8,
        UsbPort.STOPBITS_1,
        UsbPort.PARITY_NONE,
      );
      await port.setDTR(_dtr);
      if (generation != _generation || !mounted) return;
      _receiveSubscription = port.inputStream?.listen(
        (bytes) => _addLine(
            'RX ${toHex(bytes)}  |  ${jsonEncode(utf8.decode(bytes, allowMalformed: true))}'),
        onError: (Object error) => _disconnect('读取失败：$error'),
        onDone: () => _disconnect('串口已关闭'),
      );
      setState(() {
        _port = port;
        _connectedDeviceName = device.deviceName;
        _busy = false;
        _status = '已连接 · $_baudRate 8N1';
      });
      _addLine('已连接 ${device.productName ?? device.deviceName}');
      port = null; // Ownership moved to _port.
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() {
          _busy = false;
          _status = '连接失败：$error';
        });
      }
    } finally {
      if (port != null) {
        try {
          await port.close();
        } catch (_) {}
      }
    }
  }

  Future<void> _disconnect([String message = '已断开']) async {
    ++_generation;
    final port = _port;
    final subscription = _receiveSubscription;
    _port = null;
    _receiveSubscription = null;
    _connectedDeviceName = null;
    if (mounted) {
      setState(() {
        _busy = false;
        _status = message;
      });
    }
    await subscription?.cancel();
    if (port != null) {
      try {
        await port.close();
      } catch (error) {
        _showError('关闭串口失败：$error');
      }
    }
  }

  Future<void> _send() async {
    final port = _port;
    if (port == null) return;
    try {
      final bytes = _hexSend
          ? parseHex(_sendController.text)
          : Uint8List.fromList(utf8.encode(_sendController.text));
      if (bytes.isEmpty) return;
      await port.write(bytes);
      _addLine('TX ${toHex(bytes)}');
    } catch (error) {
      _showError('发送失败：$error');
    }
  }

  Future<void> _setDtr(bool value) async {
    setState(() => _dtr = value);
    try {
      await _port?.setDTR(value);
    } catch (error) {
      _showError('设置 DTR 失败：$error');
    }
  }

  void _showError(String message) {
    if (mounted) setState(() => _status = message);
  }

  void _addLine(String message) {
    if (!mounted) return;
    setState(() {
      _lines.add(message);
      if (_lines.length > 200) _lines.removeAt(0);
    });
  }

  @override
  void dispose() {
    ++_generation;
    _usbSubscription?.cancel();
    _receiveSubscription?.cancel();
    _port?.close();
    _sendController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('PhoneComm 串口测试')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(children: [
              Expanded(
                  child: DropdownButtonFormField<UsbDevice>(
                value: _selectedDevice,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'USB 设备'),
                items: _devices
                    .map((device) => DropdownMenuItem(
                          value: device,
                          child: Text(
                            '${device.productName ?? device.deviceName} '
                            '(${device.vid?.toRadixString(16) ?? '?'}:'
                            '${device.pid?.toRadixString(16) ?? '?'})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ))
                    .toList(),
                onChanged: _busy || _port != null
                    ? null
                    : (device) => setState(() => _selectedDevice = device),
              )),
              IconButton(
                tooltip: '扫描设备',
                onPressed: _busy ? null : _scanDevices,
                icon: const Icon(Icons.refresh),
              ),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                  child: DropdownButtonFormField<int>(
                value: _baudRate,
                decoration: const InputDecoration(labelText: '波特率'),
                items: [
                  9600,
                  19200,
                  38400,
                  57600,
                  115200,
                  128000,
                  230400,
                  256000,
                  460800,
                  500000,
                  576000,
                  921600,
                  1000000,
                  1152000,
                  1500000,
                  2000000,
                  2500000,
                  3000000,
                ]
                    .map((rate) =>
                        DropdownMenuItem(value: rate, child: Text('$rate')))
                    .toList(),
                onChanged: _port != null || _busy
                    ? null
                    : (rate) => setState(() => _baudRate = rate ?? _baudRate),
              )),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _busy || (_port == null && _selectedDevice == null)
                    ? null
                    : (_port == null ? _connect : () => _disconnect()),
                child: Text(_port == null ? '连接' : '断开'),
              ),
            ]),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('DTR（部分开发板会因此复位）'),
              value: _dtr,
              onChanged: _setDtr,
            ),
            Text(_status,
                style:
                    TextStyle(color: Theme.of(context).colorScheme.secondary)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                  child: TextField(
                controller: _sendController,
                decoration: InputDecoration(
                  labelText: _hexSend ? 'HEX 数据，例如 01 A0 FF' : '文本（UTF-8）',
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => _send(),
              )),
              const SizedBox(width: 8),
              ElevatedButton(
                  onPressed: _port == null ? null : _send,
                  child: const Text('发送')),
            ]),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('HEX 发送'),
              value: _hexSend,
              onChanged: (value) => setState(() => _hexSend = value),
            ),
            Row(children: [
              const Expanded(child: Text('收发日志（HEX 为原始数据）')),
              TextButton(
                  onPressed: () => setState(_lines.clear),
                  child: const Text('清空')),
            ]),
            Container(
              height: 320,
              padding: const EdgeInsets.all(8),
              color: Colors.black87,
              child: ListView.builder(
                reverse: true,
                itemCount: _lines.length,
                itemBuilder: (context, index) => SelectableText(
                  _lines[_lines.length - 1 - index],
                  style: const TextStyle(
                      color: Colors.white, fontFamily: 'monospace'),
                ),
              ),
            ),
          ],
        ),
      );
}
