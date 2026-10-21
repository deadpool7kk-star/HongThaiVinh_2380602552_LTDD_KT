import 'package:flutter/material.dart';

import '../services/department_api.dart';
import '../services/employee_api.dart';

class EmployeesScreen extends StatefulWidget {
  const EmployeesScreen({super.key});

  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> {
  final _employeeApi = EmployeeApi();
  final _departmentApi = DepartmentApi();

  late Future<List<Map<String, dynamic>>> _employeesFuture;

  bool _openingForm = false;

  @override
  void initState() {
    super.initState();
    _employeesFuture = _employeeApi.getAll();
  }

  void _reload() {
    setState(() {
      _employeesFuture = _employeeApi.getAll();
    });
  }

  Future<void> _editEmployee(
      Map<String, dynamic> employee,
      ) async {
    if (_openingForm) return;

    setState(() => _openingForm = true);

    try {
      final departments = await _departmentApi.getAll();

      if (!mounted) return;

      final updated = await Navigator.push<bool>(
        context,
        MaterialPageRoute<bool>(
          builder: (context) => _EmployeeFormScreen(
            employee: employee,
            departments: departments,
          ),
        ),
      );

      if (!mounted) return;

      if (updated == true) {
        _reload();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cập nhật nhân viên thành công.'),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _openingForm = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý nhân viên'),
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            onPressed: _openingForm ? null : _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_openingForm) const LinearProgressIndicator(),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _employeesFuture,
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

                final employees = snapshot.data ?? [];

                if (employees.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Chưa có nhân viên.\n'
                            'Tài khoản đăng ký mới sẽ xuất hiện tại đây.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: employees.length,
                  itemBuilder: (context, index) {
                    final employee = employees[index];

                    final departmentName =
                        employee['departmentName']?.toString() ??
                            'Chưa có phòng ban';

                    return Card(
                      child: ListTile(
                        isThreeLine: true,
                        leading: const CircleAvatar(
                          child: Icon(Icons.person),
                        ),
                        title: Text(
                          employee['fullName']?.toString() ?? '',
                        ),
                        subtitle: Text(
                          '${employee['email'] ?? ''}\n'
                              '$departmentName',
                        ),
                        trailing: IconButton(
                          tooltip: 'Sửa nhân viên',
                          onPressed: _openingForm
                              ? null
                              : () => _editEmployee(employee),
                          icon: const Icon(
                            Icons.edit,
                            color: Colors.blue,
                          ),
                        ),
                        onTap: _openingForm
                            ? null
                            : () => _editEmployee(employee),
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

class _EmployeeFormScreen extends StatefulWidget {
  final Map<String, dynamic> employee;
  final List<Map<String, dynamic>> departments;

  const _EmployeeFormScreen({
    required this.employee,
    required this.departments,
  });

  @override
  State<_EmployeeFormScreen> createState() =>
      _EmployeeFormScreenState();
}

class _EmployeeFormScreenState extends State<_EmployeeFormScreen> {
  final _api = EmployeeApi();
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _fullNameController;

  // Giá trị 0 trong giao diện nghĩa là chưa chọn phòng ban.
  int _selectedDepartmentId = 0;

  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _fullNameController = TextEditingController(
      text: widget.employee['fullName']?.toString() ?? '',
    );

    final currentId = widget.employee['departmentId'];

    final exists = widget.departments.any(
          (department) => department['id'] == currentId,
    );

    if (currentId is int && exists) {
      _selectedDepartmentId = currentId;
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await _api.update(
        id: widget.employee['id'].toString(),
        fullName: _fullNameController.text,
        departmentId: _selectedDepartmentId == 0
            ? null
            : _selectedDepartmentId,
      );

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isSaving = false;
        _errorMessage = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSaving,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Sửa nhân viên'),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.manage_accounts,
                  size: 72,
                  color: Colors.blue,
                ),
                const SizedBox(height: 24),
                Text(
                  'Tên đăng nhập: '
                      '${widget.employee['username'] ?? ''}',
                ),
                const SizedBox(height: 8),
                Text(
                  'Email: ${widget.employee['email'] ?? ''}',
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _fullNameController,
                  enabled: !_isSaving,
                  maxLength: 100,
                  decoration: const InputDecoration(
                    labelText: 'Họ và tên',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Vui lòng nhập họ tên.';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: _selectedDepartmentId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Phòng ban',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.business),
                  ),
                  items: [
                    const DropdownMenuItem<int>(
                      value: 0,
                      child: Text('Chưa có phòng ban'),
                    ),
                    ...widget.departments.map((department) {
                      return DropdownMenuItem<int>(
                        value: department['id'] as int,
                        child: Text(
                          department['name'].toString(),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }),
                  ],
                  onChanged: _isSaving
                      ? null
                      : (value) {
                    setState(() {
                      _selectedDepartmentId = value ?? 0;
                    });
                  },
                ),
                if (widget.departments.isEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Chưa có phòng ban để chọn. '
                        'Hãy tạo phòng ban ở mục Quản lý phòng ban.',
                  ),
                ],
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
                const SizedBox(height: 28),
                FilledButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: const Icon(Icons.save),
                  label: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                    ),
                    child: Text(
                      _isSaving ? 'Đang lưu...' : 'Lưu thay đổi',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}