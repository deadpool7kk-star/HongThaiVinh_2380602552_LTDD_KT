import 'package:flutter/material.dart';

import '../services/attendance_api.dart';

class AttendanceScreen extends StatefulWidget {
  final bool isAdmin;

  const AttendanceScreen({
    super.key,
    this.isAdmin = false,
  });

  @override
  State<AttendanceScreen> createState() =>
      _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final _api = AttendanceApi();

  late Future<Map<String, dynamic>> _future;

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _future = _api.load(isAdmin: widget.isAdmin);
  }

  void _reload() {
    setState(() {
      _future = _api.load(isAdmin: widget.isAdmin);
    });
  }

  String _formatDate(dynamic value) {
    final parts = value?.toString().split('-') ?? [];

    if (parts.length != 3) return '—';

    return '${parts[2]}/${parts[1]}/${parts[0]}';
  }

  String _formatTime(dynamic value) {
    if (value == null) return 'Chưa có';

    final time = DateTime.tryParse(value.toString())?.toLocal();

    if (time == null) return '—';

    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    final second = time.second.toString().padLeft(2, '0');

    return '$hour:$minute:$second';
  }

  String _duration(Map<String, dynamic> record) {
    final start = DateTime.tryParse(
      record['checkInUtc']?.toString() ?? '',
    );

    final end = DateTime.tryParse(
      record['checkOutUtc']?.toString() ?? '',
    );

    if (start == null || end == null) {
      return 'Chưa hoàn tất';
    }

    final duration = end.difference(start);

    return '${duration.inHours} giờ '
        '${duration.inMinutes.remainder(60)} phút';
  }

  Future<void> _submit({required bool checkIn}) async {
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      if (checkIn) {
        await _api.checkIn();
      } else {
        await _api.checkOut();
      }

      if (!mounted) return;

      _reload();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            checkIn
                ? 'Chấm công vào thành công.'
                : 'Chấm công ra thành công.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      // Tải lại trạng thái nếu server đã nhận một yêu cầu trước đó.
      _reload();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isAdmin ? 'Bảng chấm công' : 'Chấm công của tôi',
        ),
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            onPressed: _isSubmitting ? null : _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
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
                      onPressed: _reload,
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
            );
          }

          final data = snapshot.data!['data'];

          final personal = widget.isAdmin
              ? <String, dynamic>{}
              : Map<String, dynamic>.from(data as Map);

          final today = personal['today'] == null
              ? null
              : Map<String, dynamic>.from(
            personal['today'] as Map,
          );

          final rawRecords = widget.isAdmin
              ? data as List
              : personal['history'] as List;

          final records = rawRecords.map((item) {
            return Map<String, dynamic>.from(item as Map);
          }).toList();

          final completed = today?['checkOutUtc'] != null;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (!widget.isAdmin) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Hôm nay: '
                              '${_formatDate(personal['workDate'])}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Giờ vào: '
                              '${_formatTime(today?['checkInUtc'])}',
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Giờ ra: '
                              '${_formatTime(today?['checkOutUtc'])}',
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: _isSubmitting || today != null
                              ? null
                              : () => _submit(checkIn: true),
                          icon: const Icon(Icons.login),
                          label: const Text('Chấm công vào'),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _isSubmitting ||
                              today == null ||
                              completed
                              ? null
                              : () => _submit(checkIn: false),
                          icon: const Icon(Icons.logout),
                          label: const Text('Chấm công ra'),
                        ),
                        if (_isSubmitting)
                          const Padding(
                            padding: EdgeInsets.only(top: 12),
                            child: LinearProgressIndicator(),
                          ),
                        if (completed)
                          const Padding(
                            padding: EdgeInsets.only(top: 12),
                            child: Text(
                              'Bạn đã hoàn tất chấm công hôm nay.',
                              style: TextStyle(color: Colors.green),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
              Text(
                widget.isAdmin
                    ? 'Chấm công nhân viên — 30 ngày gần nhất'
                    : 'Lịch sử — 30 ngày gần nhất',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              if (records.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Chưa có dữ liệu chấm công.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ...records.map((record) {
                return Card(
                  child: ListTile(
                    leading: Icon(
                      record['checkOutUtc'] == null
                          ? Icons.access_time
                          : Icons.check_circle,
                      color: record['checkOutUtc'] == null
                          ? Colors.orange
                          : Colors.green,
                    ),
                    title: Text(
                      widget.isAdmin
                          ? '${record['fullName']}'
                          : _formatDate(record['workDate']),
                    ),
                    subtitle: Text(
                      '${widget.isAdmin ? '${_formatDate(record['workDate'])}\n'
                          '${record['departmentName'] ?? 'Chưa có phòng ban'}\n' : ''}'
                          'Vào: ${_formatTime(record['checkInUtc'])}\n'
                          'Ra: ${_formatTime(record['checkOutUtc'])}\n'
                          'Thời gian: ${_duration(record)}',
                    ),
                    isThreeLine: true,
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}