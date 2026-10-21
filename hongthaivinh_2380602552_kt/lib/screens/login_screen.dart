import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_api.dart';
import 'register_screen.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _authApi = AuthApi();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _otpController = TextEditingController();

  bool _isLoading = false;
  bool _hidePassword = true;

  String? _challengeId;
  Map<String, dynamic>? _account;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // Bước 1: Kiểm tra tài khoản và yêu cầu gửi OTP.
  Future<void> _login() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      _showMessage('Vui lòng nhập tên đăng nhập và mật khẩu.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      final result = await _authApi.beginLogin(
        username: username,
        password: password,
      );

      if (!mounted) return;

      setState(() {
        _challengeId = result['challengeId'].toString();
        _otpController.clear();
        _passwordController.clear();
      });

      _showMessage('Đã gửi OTP. Hãy kiểm tra email của bạn.');
    } catch (error) {
      if (!mounted) return;
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Bước 2: Xác thực OTP rồi lấy thông tin từ API.
  Future<void> _verifyOtp() async {
    final code = _otpController.text.trim();
    final challengeId = _challengeId;

    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      _showMessage('Vui lòng nhập đủ 6 chữ số OTP.');
      return;
    }

    if (challengeId == null) return;

    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      await _authApi.verifyOtp(
        challengeId: challengeId,
        code: code,
      );

      // API kiểm tra token rồi trả về thông tin tài khoản.
      final account = await _authApi.getCurrentAccount();

      if (!mounted) return;

      setState(() {
        _account = account;
        _otpController.clear();
      });
    } catch (error) {
      if (!mounted) return;
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _logout() async {
    setState(() => _isLoading = true);

    try {
      await _authApi.logout();

      if (!mounted) return;

      setState(() {
        _account = null;
        _challengeId = null;
        _passwordController.clear();
        _otpController.clear();
      });
    } catch (error) {
      if (!mounted) return;
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  Future<void> _openRegister() async {
    final registered = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (context) => const RegisterScreen(),
      ),
    );

    if (!mounted) return;

    if (registered == true) {
      _showMessage(
        'Đăng ký thành công! Hãy đăng nhập bằng tài khoản mới.',
      );
    }
  }
  @override
  Widget build(BuildContext context) {
    final account = _account;

    // Màn hình kiểm tra sau khi đăng nhập thành công.
    if (account != null) {
      final rawRoles = account['roles'];

      final roles = rawRoles is List
          ? rawRoles.map((role) => role.toString()).toList()
          : <String>[];

      if (roles.contains('Admin')) {
        return AdminDashboard(
          account: account,
          onLogout: _logout,
          isLoading: _isLoading,
        );
      }

      if (roles.contains('Employee')) {
        return EmployeeDashboard(
          account: account,
          onLogout: _logout,
          isLoading: _isLoading,
        );
      }

      return Scaffold(
        appBar: AppBar(
          title: const Text('Thông báo'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.no_accounts,
                  size: 64,
                  color: Colors.orange,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Tài khoản chưa có vai trò được hỗ trợ. '
                      'Vui lòng liên hệ quản trị viên.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _isLoading ? null : _logout,
                  child: const Text('Đăng xuất'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final waitingForOtp = _challengeId != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chấm công nhân viên'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.badge_outlined,
                size: 80,
                color: Colors.blue,
              ),
              const SizedBox(height: 20),
              Text(
                waitingForOtp ? 'Xác thực OTP' : 'Đăng nhập',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 28),
              if (!waitingForOtp) ...[
                TextField(
                  controller: _usernameController,
                  enabled: !_isLoading,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Tên đăng nhập',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  enabled: !_isLoading,
                  obscureText: _hidePassword,
                  decoration: InputDecoration(
                    labelText: 'Mật khẩu',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          _hidePassword = !_hidePassword;
                        });
                      },
                      icon: Icon(
                        _hidePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                    ),
                  ),
                ),
              ] else ...[
                const Text(
                  'Nhập mã gồm 6 chữ số được gửi tới email '
                      'đã đăng ký. Mã có hiệu lực trong 5 phút.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _otpController,
                  enabled: !_isLoading,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Mã OTP',
                    prefixIcon: Icon(Icons.security),
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _isLoading
                    ? null
                    : waitingForOtp
                    ? _verifyOtp
                    : _login,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: _isLoading
                      ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                      : Text(
                    waitingForOtp
                        ? 'Xác nhận OTP'
                        : 'Đăng nhập và nhận OTP',
                  ),
                ),
              ),
              if (!waitingForOtp)
                TextButton(
                  onPressed: _isLoading ? null : _openRegister,
                  child: const Text(
                    'Chưa có tài khoản? Đăng ký ngay',
                  ),
                ),

              if (waitingForOtp)
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                    setState(() {
                      _challengeId = null;
                      _otpController.clear();
                    });
                  },
                  child: const Text('Quay lại đăng nhập'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}