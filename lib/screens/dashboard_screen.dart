import 'package:flutter/material.dart';

import 'attendance_screen.dart';
import 'departments_screen.dart';
import 'employees_screen.dart';
import 'motion_screen.dart';
import 'qr_attendance_screen.dart';
import 'translation_screen.dart';

class AdminDashboard extends StatelessWidget {
  final Map<String, dynamic> account;
  final Future<void> Function() onLogout;
  final bool isLoading;

  const AdminDashboard({
    super.key,
    required this.account,
    required this.onLogout,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return _DashboardLayout(
      account: account,
      onLogout: onLogout,
      isLoading: isLoading,
      isAdmin: true,
    );
  }
}

class EmployeeDashboard extends StatelessWidget {
  final Map<String, dynamic> account;
  final Future<void> Function() onLogout;
  final bool isLoading;

  const EmployeeDashboard({
    super.key,
    required this.account,
    required this.onLogout,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return _DashboardLayout(
      account: account,
      onLogout: onLogout,
      isLoading: isLoading,
      isAdmin: false,
    );
  }
}

class _DashboardItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final WidgetBuilder builder;

  const _DashboardItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.builder,
  });
}

class _DashboardLayout extends StatelessWidget {
  final Map<String, dynamic> account;
  final Future<void> Function() onLogout;
  final bool isLoading;
  final bool isAdmin;

  const _DashboardLayout({
    required this.account,
    required this.onLogout,
    required this.isLoading,
    required this.isAdmin,
  });

  @override
  Widget build(BuildContext context) {
    final accent = isAdmin
        ? const Color(0xFF7C3AED)
        : const Color(0xFF2563EB);

    final roleName = isAdmin ? 'Quản trị viên' : 'Nhân viên';

    final items = <_DashboardItem>[
      _DashboardItem(
        title: isAdmin ? 'Bảng chấm công' : 'Chấm công',
        subtitle: isAdmin
            ? 'Theo dõi vào, ra của nhân viên'
            : 'Ghi nhận vào, ra và xem lịch sử',
        icon: Icons.fact_check_outlined,
        color: const Color(0xFF08916F),
        builder: (_) => AttendanceScreen(isAdmin: isAdmin),
      ),
      _DashboardItem(
        title: isAdmin ? 'Tạo mã QR' : 'Quét mã QR',
        subtitle: isAdmin
            ? 'Cấp mã chấm công cho nhân viên'
            : 'Chấm công nhanh bằng camera',
        icon: Icons.qr_code_scanner,
        color: const Color(0xFF4F46E5),
        builder: (_) => isAdmin
            ? const AdminQrScreen()
            : const ScanAttendanceScreen(),
      ),
      if (isAdmin) ...[
        _DashboardItem(
          title: 'Phòng ban',
          subtitle: 'Thêm, sửa và xóa phòng ban',
          icon: Icons.business_outlined,
          color: const Color(0xFF9333EA),
          builder: (_) => const DepartmentsScreen(),
        ),
        _DashboardItem(
          title: 'Nhân viên',
          subtitle: 'Thông tin và phân phòng ban',
          icon: Icons.groups_outlined,
          color: const Color(0xFF0284C7),
          builder: (_) => const EmployeesScreen(),
        ),
      ],
      _DashboardItem(
        title: 'Chuyển động',
        subtitle: 'Đo gia tốc theo ba trục',
        icon: Icons.vibration,
        color: const Color(0xFFEA580C),
        builder: (_) => const MotionScreen(),
      ),
      _DashboardItem(
        title: 'Dịch văn bản',
        subtitle: 'Thông báo và ghi chú Việt–Anh',
        icon: Icons.translate,
        color: const Color(0xFFDB2777),
        builder: (_) => const TranslationScreen(),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isAdmin ? 'Trang quản trị' : 'Trang nhân viên',
        ),
        actions: [
          IconButton(
            tooltip: 'Đăng xuất',
            onPressed: isLoading ? null : onLogout,
            icon: const Icon(Icons.logout),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 720
                ? 3
                : constraints.maxWidth >= 340
                ? 2
                : 1;

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        accent,
                        accent.withValues(alpha: 0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Icon(
                          isAdmin
                              ? Icons.admin_panel_settings_outlined
                              : Icons.badge_outlined,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Xin chào,',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              account['fullName']?.toString() ?? '',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 23,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              roleName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  'Chức năng',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF172033),
                  ),
                ),
                const SizedBox(height: 14),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                  SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisExtent: 190,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];

                    return Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: isLoading
                            ? null
                            : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: item.builder,
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: item.color.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  item.icon,
                                  color: item.color,
                                  size: 26,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                item.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                item.subtitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 28),
                const Text(
                  'Tài khoản của bạn',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 14),
                Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.person_outline),
                        title: const Text('Tên đăng nhập'),
                        subtitle: Text(
                          account['username']?.toString() ?? '',
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.email_outlined),
                        title: const Text('Email'),
                        subtitle: Text(
                          account['email']?.toString() ?? '',
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: Icon(
                          Icons.verified_user_outlined,
                          color: accent,
                        ),
                        title: const Text('Vai trò'),
                        subtitle: Text(roleName),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: isLoading ? null : onLogout,
                  icon: const Icon(Icons.logout),
                  label: Text(
                    isLoading ? 'Đang đăng xuất...' : 'Đăng xuất',
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Ứng dụng chấm công nhân viên\n'
                      'Hồng Thái Vinh • 2380602552',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
              ],
            );
          },
        ),
      ),
    );
  }
}