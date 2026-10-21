import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

class MotionScreen extends StatefulWidget {
  const MotionScreen({super.key});

  @override
  State<MotionScreen> createState() => _MotionScreenState();
}

class _MotionScreenState extends State<MotionScreen>
    with WidgetsBindingObserver {
  StreamSubscription<UserAccelerometerEvent>? _subscription;

  double _x = 0;
  double _y = 0;
  double _z = 0;
  double _magnitude = 0;

  bool _enabled = true;
  bool _hasData = false;
  bool _active = true;

  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  void _start() {
    if (!_enabled || !_active || _subscription != null) return;

    _subscription = userAccelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 200),
    ).listen(
          (event) {
        if (!mounted || !_enabled || !_active) return;

        setState(() {
          _x = event.x;
          _y = event.y;
          _z = event.z;

          _magnitude = sqrt(
            _x * _x + _y * _y + _z * _z,
          );

          _hasData = true;
          _error = null;
        });
      },
      onError: (Object error) {
        _stop();

        if (!mounted) return;

        setState(() {
          _enabled = false;
          _error = 'Không đọc được cảm biến trên thiết bị này.';
        });
      },
      cancelOnError: true,
    );
  }

  void _stop() {
    _subscription?.cancel();
    _subscription = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;

    if (_active) {
      _start();
    } else {
      _stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stop();
    super.dispose();
  }

  Widget _valueCard(String label, double value) {
    return Card(
      child: ListTile(
        title: Text(label),
        trailing: Text(
          '${value.toStringAsFixed(2)} m/s²',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Đây là ngưỡng minh họa để nhận biết thay đổi vận động.
    final moving = _magnitude >= 2;

    final status = !_enabled
        ? 'Đã dừng đo'
        : !_hasData
        ? 'Đang chờ cảm biến...'
        : moving
        ? 'Phát hiện thay đổi chuyển động'
        : 'Ít thay đổi chuyển động';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Đo chuyển động'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Icon(
            Icons.vibration,
            size: 90,
            color: !_enabled
                ? Colors.grey
                : moving
                ? Colors.orange
                : Colors.green,
          ),
          const SizedBox(height: 20),
          Text(
            status,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          _valueCard('Gia tốc trục X', _x),
          _valueCard('Gia tốc trục Y', _y),
          _valueCard('Gia tốc trục Z', _z),
          _valueCard('Độ lớn gia tốc', _magnitude),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Bật đo chuyển động'),
            value: _enabled,
            onChanged: (value) {
              setState(() {
                _enabled = value;
                _error = null;
              });

              if (value) {
                _start();
              } else {
                _stop();
              }
            },
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          const SizedBox(height: 16),
          const Text(
            'Đặt điện thoại yên rồi cầm lên, nghiêng hoặc '
                'lắc nhẹ để quan sát số liệu thay đổi.\n\n'
                'Dữ liệu là gia tốc đã loại bỏ ảnh hưởng của '
                'trọng lực. Đây không phải bộ đếm bước chân.',
          ),
        ],
      ),
    );
  }
}