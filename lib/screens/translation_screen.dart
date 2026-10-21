import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';

class TranslationScreen extends StatefulWidget {
  const TranslationScreen({super.key});

  @override
  State<TranslationScreen> createState() =>
      _TranslationScreenState();
}

class _TranslationScreenState extends State<TranslationScreen> {
  final _controller = TextEditingController();
  final _modelManager = OnDeviceTranslatorModelManager();

  final _viToEn = OnDeviceTranslator(
    sourceLanguage: TranslateLanguage.vietnamese,
    targetLanguage: TranslateLanguage.english,
  );

  final _enToVi = OnDeviceTranslator(
    sourceLanguage: TranslateLanguage.english,
    targetLanguage: TranslateLanguage.vietnamese,
  );

  Timer? _debounce;
  Future<void>? _runningTask;

  bool _vietnameseToEnglish = true;
  bool _preparing = false;
  bool _ready = false;
  bool _translating = false;

  int _revision = 0;

  String _result = '';
  String? _error;

  @override
  void initState() {
    super.initState();

    _controller.addListener(_onInput);
    _prepareModels();
  }

  Future<void> _prepareModels() async {
    if (_preparing) return;

    setState(() {
      _preparing = true;
      _error = null;
    });

    try {
      for (final language in [
        TranslateLanguage.vietnamese,
        TranslateLanguage.english,
      ]) {
        final downloaded = await _modelManager
            .isModelDownloaded(language.bcpCode);

        if (!downloaded) {
          final success = await _modelManager.downloadModel(
            language.bcpCode,
            isWifiRequired: false,
          );

          if (!success) {
            throw Exception('Không tải được mô hình ngôn ngữ.');
          }
        }

        if (!mounted) return;
      }

      setState(() => _ready = true);

      if (_controller.text.trim().isNotEmpty) {
        _scheduleTranslation();
      }
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error = 'Không chuẩn bị được bộ dịch. '
            'Kiểm tra Internet rồi bấm Thử lại.';
      });
    } finally {
      if (mounted) {
        setState(() => _preparing = false);
      }
    }
  }

  void _onInput() {
    if (!mounted) return;

    _revision++;
    _debounce?.cancel();

    setState(() {
      _result = '';
      _error = null;
    });

    if (_ready && _controller.text.trim().isNotEmpty) {
      _scheduleTranslation();
    }
  }

  void _scheduleTranslation() {
    _debounce?.cancel();

    // Dịch sau khi người dùng ngừng gõ khoảng 0,6 giây.
    _debounce = Timer(
      const Duration(milliseconds: 600),
          () {
        if (!mounted) return;
        _runningTask = _translate();
      },
    );
  }

  Future<void> _translate() async {
    if (!_ready || _translating) return;

    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final revision = _revision;
    final translator =
    _vietnameseToEnglish ? _viToEn : _enToVi;

    setState(() {
      _translating = true;
      _error = null;
    });

    try {
      final translated = await translator.translateText(text);

      if (!mounted || revision != _revision) return;

      setState(() => _result = translated);
    } catch (_) {
      if (!mounted || revision != _revision) return;

      setState(() {
        _error = 'Không dịch được nội dung. Hãy thử lại.';
      });
    } finally {
      if (mounted) {
        setState(() => _translating = false);

        // Nếu nội dung đã đổi trong lúc đang dịch,
        // tiếp tục xử lý nội dung mới nhất.
        if (revision != _revision &&
            _controller.text.trim().isNotEmpty) {
          _scheduleTranslation();
        }
      }
    }
  }

  Future<void> _closeTranslators() async {
    final task = _runningTask;

    if (task != null) {
      await task;
    }

    await _viToEn.close();
    await _enToVi.close();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.removeListener(_onInput);
    _controller.dispose();

    unawaited(_closeTranslators());

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dịch thông báo và ghi chú'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Icon(
            Icons.translate,
            size: 64,
            color: Colors.indigo,
          ),
          const SizedBox(height: 20),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment<bool>(
                value: true,
                label: Text('Việt → Anh'),
              ),
              ButtonSegment<bool>(
                value: false,
                label: Text('Anh → Việt'),
              ),
            ],
            selected: {_vietnameseToEnglish},
            onSelectionChanged: !_ready || _translating
                ? null
                : (selection) {
              setState(() {
                _vietnameseToEnglish = selection.first;
              });

              _controller.clear();
            },
          ),
          const SizedBox(height: 20),
          if (_preparing) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: 12),
            const Text(
              'Đang chuẩn bị bộ dịch. Lần đầu cần tải '
                  'dữ liệu ngôn ngữ, hãy giữ kết nối Internet.',
            ),
            const SizedBox(height: 20),
          ],
          if (!_ready && !_preparing)
            FilledButton(
              onPressed: _prepareModels,
              child: const Text('Thử lại'),
            ),
          TextField(
            controller: _controller,
            enabled: _ready,
            minLines: 4,
            maxLines: 8,
            maxLength: 1000,
            decoration: InputDecoration(
              labelText: _vietnameseToEnglish
                  ? 'Nhập tiếng Việt'
                  : 'Nhập tiếng Anh',
              hintText: 'Nội dung sẽ được dịch tự động khi bạn gõ.',
              border: const OutlineInputBorder(),
            ),
          ),
          TextButton.icon(
            onPressed: !_ready
                ? null
                : () {
              _controller.text = _vietnameseToEnglish
                  ? 'Tôi xin phép đến muộn 15 phút hôm nay.'
                  : 'Please check in before starting work.';
            },
            icon: const Icon(Icons.edit_note),
            label: const Text('Điền câu mẫu'),
          ),
          if (_translating)
            const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Bản dịch',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SelectableText(
                    _result.isEmpty
                        ? 'Kết quả sẽ xuất hiện tại đây.'
                        : _result,
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Image.network(
                      'https://docs.cloud.google.com/static/'
                          'translate/images/text-attribution.png',
                      width: 180,
                      errorBuilder: (context, error, stackTrace) {
                        return const Text(
                          'Bản dịch tự động bởi Google Translate',
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _result.isEmpty
                        ? null
                        : () async {
                      await Clipboard.setData(
                        ClipboardData(text: _result),
                      );

                      if (!context.mounted) return;

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Đã sao chép bản dịch.'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('Sao chép bản dịch'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}