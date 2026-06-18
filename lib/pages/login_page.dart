import 'package:flutter/material.dart';

import '../services/http_auth_service.dart';
import '../services/session_service.dart';
import 'admin_page.dart';
import 'home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _doLogin() async {
    final user = _userCtrl.text.trim();
    final pass = _passCtrl.text;
    if (user.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入用户名和密码')));
      return;
    }

    setState(() => _loading = true);
    try {
      final loginResult = await HttpAuthService().login(user, pass);
      if (!mounted) {
        return;
      }

      if (loginResult == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('用户名或密码错误')));
        return;
      }

      final role = loginResult['role'] as String? ?? 'USER';
      final username = loginResult['username'] as String? ?? user;
      final storeCode = (loginResult['storeCode'] as String?)?.trim();
      final uiLanguage = (loginResult['uiLanguage'] as String?)?.trim() ?? 'ZH';
      final allowedCategoryCodes = List<String>.from(
        loginResult['allowedCategoryCodes'] ?? const [],
      );

      SessionService().setSession(
        username: username,
        role: role,
        storeCode: storeCode,
        uiLanguage: uiLanguage,
        allowedCategoryCodes: allowedCategoryCodes,
      );

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) =>
              role == 'ADMIN' ? const AdminPage() : const HomePage(),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('登录失败: $e')));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      backgroundColor: const Color(0xFFD2D6DE),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    color: primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 20,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            Icons.admin_panel_settings,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Text(
                          '系统登录',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: _userCtrl,
                          decoration: const InputDecoration(labelText: '用户名'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _passCtrl,
                          decoration: const InputDecoration(labelText: '密码'),
                          obscureText: true,
                          onSubmitted: (_) => _loading ? null : _doLogin(),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _doLogin,
                            child: _loading
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('登录'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
