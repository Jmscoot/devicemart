import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial_plus/flutter_bluetooth_serial_plus.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: BluetoothPage());
  }
}

class BluetoothPage extends StatefulWidget {
  const BluetoothPage({super.key});

  @override
  State<BluetoothPage> createState() => _BluetoothPageState();
}

class _BluetoothPageState extends State<BluetoothPage> {
  BluetoothDevice? selectedDevice;
  BluetoothConnection? connection;
  StreamSubscription<Uint8List>? inputSubscription;

  List<BluetoothDevice> bondedDevices = [];
  String receivedText = '';
  bool isConnected = false;
  bool isLoadingDevices = false;
  bool isSending = false;

  @override
  void initState() {
    super.initState();
    loadBondedDevices();
  }

  Future<void> loadBondedDevices() async {
    setState(() {
      isLoadingDevices = true;
    });

    try {
      final devices = await FlutterBluetoothSerial.instance.getBondedDevices();

      if (!mounted) return;
      setState(() {
        bondedDevices = devices;
      });
    } catch (e) {
      debugPrint('페어링된 기기 목록 불러오기 실패: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('기기 목록 불러오기 실패: $e')));
    } finally {
      if (mounted) {
        setState(() {
          isLoadingDevices = false;
        });
      }
    }
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    try {
      await disconnect(silent: true);

      final conn = await BluetoothConnection.toAddress(device.address);

      inputSubscription = conn.input?.listen(
        (Uint8List data) {
          final text = String.fromCharCodes(data);

          if (!mounted) return;
          setState(() {
            receivedText += text;
          });
        },
        onDone: () {
          if (!mounted) return;
          setState(() {
            isConnected = false;
            connection = null;
          });
        },
        onError: (error) {
          debugPrint('수신 오류: $error');
        },
      );

      if (!mounted) return;
      setState(() {
        selectedDevice = device;
        connection = conn;
        isConnected = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${device.name ?? device.address} 연결됨')),
      );
    } catch (e) {
      debugPrint('연결 실패: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('연결 실패: $e')));
    }
  }

  Future<void> sendRepeatedYes() async {
    if (connection == null || !isConnected || isSending) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('먼저 기기를 연결하세요')));
      return;
    }

    setState(() {
      isSending = true;
    });

    try {
      const interval = Duration(milliseconds: 300);
      final endTime = DateTime.now().add(const Duration(seconds: 3));

      while (DateTime.now().isBefore(endTime)) {
        connection!.output.add(Uint8List.fromList('yes\n'.codeUnits));
        await connection!.output.allSent;
        await Future.delayed(interval);
      }
    } catch (e) {
      debugPrint('전송 실패: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('전송 실패: $e')));
    } finally {
      if (mounted) {
        setState(() {
          isSending = false;
        });
      }
    }
  }

  Future<void> disconnect({bool silent = false}) async {
    try {
      await inputSubscription?.cancel();
      inputSubscription = null;

      await connection?.close();
      connection = null;

      if (!mounted) return;
      setState(() {
        isConnected = false;
      });

      if (!silent) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('연결 해제됨')));
      }
    } catch (e) {
      debugPrint('연결 해제 실패: $e');
    }
  }

  @override
  void dispose() {
    inputSubscription?.cancel();
    connection?.dispose();
    super.dispose();
  }

  Widget buildDeviceList() {
    if (isLoadingDevices) {
      return const Center(child: CircularProgressIndicator());
    }

    if (bondedDevices.isEmpty) {
      return const Text(
        '페어링된 기기가 없습니다.\n먼저 휴대폰 설정에서 HC-05를 페어링하세요.',
        textAlign: TextAlign.center,
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: bondedDevices.length,
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (context, index) {
        final device = bondedDevices[index];
        final isCurrent =
            selectedDevice?.address == device.address && isConnected;

        return ListTile(
          leading: const Icon(Icons.bluetooth),
          title: Text(device.name?.isNotEmpty == true ? device.name! : '이름 없음'),
          subtitle: Text(device.address),
          trailing: isCurrent
              ? const Text('연결됨', style: TextStyle(fontWeight: FontWeight.bold))
              : ElevatedButton(
                  onPressed: () => connectToDevice(device),
                  child: const Text('선택'),
                ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final connectedName =
        selectedDevice?.name ?? selectedDevice?.address ?? '-';

    return Scaffold(
      appBar: AppBar(title: const Text('HC-05 Classic Bluetooth')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '연결 상태: ${isConnected ? "연결됨" : "안 됨"}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text('선택된 기기: $connectedName'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: loadBondedDevices,
                child: const Text('페어링된 기기 새로고침'),
              ),
              const SizedBox(height: 16),
              const Text(
                '페어링된 기기 목록',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              buildDeviceList(),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: isConnected && !isSending ? sendRepeatedYes : null,
                child: Text(isSending ? '전송 중...' : 'YES (방송 수신)'),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: isConnected ? () => disconnect() : null,
                child: const Text('연결 해제'),
              ),
              const SizedBox(height: 24),
              const Text(
                'Received:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 120),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  receivedText.isEmpty
                      ? 'Waiting for message...'
                      : receivedText,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    receivedText = '';
                  });
                },
                child: const Text('수신창 비우기'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
