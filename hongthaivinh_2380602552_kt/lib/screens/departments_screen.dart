import 'package:flutter/material.dart';

import '../services/department_api.dart';

class DepartmentsScreen extends StatefulWidget {
  const DepartmentsScreen({super.key});

  @override
  State<DepartmentsScreen> createState() =>
      _DepartmentsScreenState();
}

class _DepartmentsScreenState extends State<DepartmentsScreen> {
  final _api = DepartmentApi();

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  late Future<List<Map<String, dynamic>>> _departmentsFuture;

  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _departmentsFuture = _api.getAll();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _departmentsFuture = _api.getAll();
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // Có department: sửa. Không có: thêm mới.
  Future<void> _openForm({
    Map<String, dynamic>? department,
  }) async {
    final isEditing = department != null;
    final formKey = GlobalKey<FormState>();

    _nameController.text =
        department?['name']?.toString() ?? '';

    _descriptionController.text =
        department?['description']?.toString() ?? '';

    bool isSaving = false;
    String? errorMessage;

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return PopScope(
              canPop: !isSaving,
              child: AlertDialog(
                title: Text(
                  isEditing ? 'Sửa phòng ban' : 'Thêm phòng ban',
                ),
                content: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: _nameController,
                          enabled: !isSaving,
                          maxLength: 100,
                          decoration: const InputDecoration(
                            labelText: 'Tên phòng ban',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null ||
                                value.trim().isEmpty) {
                              return 'Vui lòng nhập tên phòng ban.';
                            }

                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _descriptionController,
                          enabled: !isSaving,
                          maxLength: 500,
                          minLines: 2,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'Mô tả',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        if (errorMessage != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            errorMessage!,
                            style: const TextStyle(
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: isSaving
                        ? null
                        : () {
                      Navigator.pop(dialogContext, false);
                    },
                    child: const Text('Hủy'),
                  ),
                  FilledButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                      if (!formKey.currentState!.validate()) {
                        return;
                      }

                      setDialogState(() {
                        isSaving = true;
                        errorMessage = null;
                      });

                      try {
                        if (isEditing) {
                          await _api.update(
                            department['id'] as int,
                            _nameController.text,
                            _descriptionController.text,
                          );
                        } else {
                          await _api.create(
                            _nameController.text,
                            _descriptionController.text,
                          );
                        }

                        if (!dialogContext.mounted) return;

                        Navigator.pop(dialogContext, true);
                      } catch (error) {
                        if (!dialogContext.mounted) return;

                        setDialogState(() {
                          isSaving = false;
                          errorMessage = error.toString();
                        });
                      }
                    },
                    child: Text(
                      isSaving ? 'Đang lưu...' : 'Lưu',
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (!mounted) return;

    if (saved == true) {
      _reload();

      _showMessage(
        isEditing
            ? 'Cập nhật phòng ban thành công.'
            : 'Thêm phòng ban thành công.',
      );
    }
  }

  Future<void> _delete(
      Map<String, dynamic> department,
      ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Xóa phòng ban?'),
          content: Text(
            'Bạn có muốn xóa "${department['name']}" không?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Xóa'),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmed != true) return;

    setState(() => _isDeleting = true);

    try {
      await _api.delete(department['id'] as int);

      if (!mounted) return;

      _reload();
      _showMessage('Xóa phòng ban thành công.');
    } catch (error) {
      if (!mounted) return;
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý phòng ban'),
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            onPressed: _isDeleting ? null : _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Thêm phòng ban',
        onPressed: _isDeleting ? null : () => _openForm(),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          if (_isDeleting) const LinearProgressIndicator(),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _departmentsFuture,
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

                final departments = snapshot.data ?? [];

                if (departments.isEmpty) {
                  return const Center(
                    child: Text(
                      'Chưa có phòng ban.\n'
                          'Bấm dấu + để thêm.',
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    12,
                    12,
                    12,
                    100,
                  ),
                  itemCount: departments.length,
                  itemBuilder: (context, index) {
                    final department = departments[index];

                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.business),
                        ),
                        title: Text(
                          department['name']?.toString() ?? '',
                        ),
                        subtitle: Text(
                          department['description']?.toString() ??
                              '',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Sửa',
                              onPressed: _isDeleting
                                  ? null
                                  : () => _openForm(
                                department: department,
                              ),
                              icon: const Icon(
                                Icons.edit,
                                color: Colors.blue,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Xóa',
                              onPressed: _isDeleting
                                  ? null
                                  : () => _delete(department),
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}