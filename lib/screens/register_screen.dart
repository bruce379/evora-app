import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../services/auth_service.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  final _auth = AuthService();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      await _auth.register(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
        displayName: _nameCtrl.text.trim(),
      );
      if (mounted) context.go('/dashboard');
    } on Exception catch (e) {
      setState(() { _error = _friendlyError(e.toString()); });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  String _friendlyError(String e) {
    if (e.contains('email-already-in-use')) return 'An account with this email already exists.';
    if (e.contains('weak-password')) return 'Password is too weak. Use at least 8 characters.';
    return 'Something went wrong. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EvoraColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: EvoraColors.primaryAccent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.favorite_rounded, color: Colors.black, size: 24),
                ),
                const SizedBox(height: 32),
                Text('Create account', style: Theme.of(context).textTheme.displayMedium),
                const SizedBox(height: 8),
                Text('Start your health journey with Evora', style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 40),

                // Name
                TextFormField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  style: const TextStyle(color: EvoraColors.textPrimary),
                  decoration: const InputDecoration(hintText: 'Full name'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
                ),
                const SizedBox(height: 16),

                // Email
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  style: const TextStyle(color: EvoraColors.textPrimary),
                  decoration: const InputDecoration(hintText: 'Email address'),
                  validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                ),
                const SizedBox(height: 16),

                // Password
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _obscure,
                  style: const TextStyle(color: EvoraColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Password (min 8 characters)',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        color: EvoraColors.textMuted,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) => (v == null || v.length < 8) ? 'Min 8 characters' : null,
                ),
                const SizedBox(height: 8),

                // Terms note
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'By creating an account, you agree to our Terms of Service and Privacy Policy.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12),
                  ),
                ),
                const SizedBox(height: 16),

                // Error
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: EvoraColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: EvoraColors.error.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: EvoraColors.error, size: 16),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_error!, style: const TextStyle(color: EvoraColors.error, fontSize: 13))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Register button
                ElevatedButton(
                  onPressed: _loading ? null : _register,
                  child: _loading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : const Text('Create Account'),
                ),
                const SizedBox(height: 24),

                // Login link
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Already have an account?', style: Theme.of(context).textTheme.bodyMedium),
                      TextButton(
                        onPressed: () => context.go('/login'),
                        child: Text(
                          'Sign In',
                          style: TextStyle(color: EvoraColors.primaryAccent, fontWeight: FontWeight.w600),
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
    );
  }
}
