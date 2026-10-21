import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../services/qr_attendance_api.dart';

// ================= ADMIN: TẠO QR =================

class AdminQrScreen extends StatefulWidget {
  const AdminQrScreen({super.key});

  @override
  State<AdminQrScreen> createState() => _AdminQrScreenState();
}

class _AdminQrScreenState extends State<AdminQrScreen> {
  final _api = QrAttendanceApi();

  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _api.generate();
  }

  void _generate() {
    setState(() {
      _future = _api.generate();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR chấm công'),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      snapshot.error.toString(),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _generate,
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
            );
          }

          final data = snapshot.data!;

          final expires = DateTime.parse(
            data['expiresAtUtc'].toString(),
          ).toLocal();

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text(
                'Nhân viên quét mã này để chấm công',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: QrImageView(
                  data: data['qrText'].toString(),
                  version: QrVersions.auto,
                  size: 260,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Hết hạn: $expires',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Mã có hiệu lực 5 phút. '
                    'Tạo mã mới sẽ vô hiệu hóa mã trước.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _generate,
                icon: const Icon(Icons.refresh),
                label: const Text('Tạo mã mới'),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ================= EMPLOYEE: QUÉT QR =================

class ScanAttendanceScreen extends StatefulWidget {
  const ScanAttendanceScreen({super.key});

  @override
  State<ScanAttendanceScreen> createState() =>
      _ScanAttendanceScreenState();
}

class _ScanAttendanceScreenState
    extends State<ScanAttendanceScreen> {
  final _api = QrAttendanceApi();

  final _controller = MobileScannerController(
    formats: [BarcodeFormat.qrCode],
  );

  bool _checkOut = false;
  bool _locked = false;
  bool _busy = false;

  String? _message;
  bool _success = false;

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_locked || _busy) return;

    String? code;

    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;

      if (value != null && value.isNotEmpty) {
        code = value;
        break;
      }
    }

    if (code == null) return;

    // Khóa ngay để một lần quét không gửi nhiều yêu cầu.
    setState(() {
      _locked = true;
      _busy = true;
      _message = null;
      _success = false;
    });

    try {
      await _controller.stop();

      if (!code.startsWith('HTV-KT:') || code.length > 100) {
        throw Exception('Đây không phải QR chấm công của ứng dụng.');
      }

      final message = await _api.scan(
        qrCode: code,
        checkOut: _checkOut,
      );

      if (!mounted) return;

      setState(() {
        _success = true;
        _message = message;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _success = false;
        _message = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _scanAgain() async {
    setState(() {
      _locked = false;
      _message = null;
      _success = false;
    });

    try {
      await _controller.start();
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _locked = true;
        _message = 'Không mở được camera: $error';
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quét QR chấm công'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment<bool>(
                  value: false,
                  label: Text('Chấm công vào'),
                  icon: Icon(Icons.login),
                ),
                ButtonSegment<bool>(
                  value: true,
                  label: Text('Chấm công ra'),
                  icon: Icon(Icons.logout),
                ),
              ],
              selected: {_checkOut},
              onSelectionChanged: _busy
                  ? null
                  : (selection) {
                setState(() {
                  _checkOut = selection.first;
                });
              },
            ),
          ),
          Expanded(
            child: MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                if (_busy)
                  const CircularProgressIndicator()
                else
                  Text(
                    _message ??
                        'Đưa QR do Admin tạo vào trước camera.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _message == null
                          ? null
                          : _success
                          ? Colors.green
                          : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                if (_locked && !_busy) ...[
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _scanAgain,
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Quét lại'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}