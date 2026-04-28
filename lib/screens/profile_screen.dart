import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/theme.dart';
import '../services/auth_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: EvoraColors.background,
      appBar: AppBar(
        title: const Text('Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => context.go('/dashboard'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Avatar
              CircleAvatar(
                backgroundColor: EvoraColors.surface,
                radius: 40,
                child: Text(
                  (user?.displayName?.isNotEmpty == true) ? user!.displayName![0].toUpperCase() : 'E',
                  style: const TextStyle(color: EvoraColors.textPrimary, fontSize: 32, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 16),
              Text(user?.displayName ?? 'Evora User', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(user?.email ?? '', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 32),

              // Settings list
              _SettingsTile(icon: Icons.person_outline_rounded, label: 'Edit Profile', onTap: () {}),
              _SettingsTile(icon: Icons.notifications_outlined, label: 'Notifications', onTap: () {}),
              _SettingsTile(icon: Icons.privacy_tip_outlined, label: 'Privacy', onTap: () {}),
              _SettingsTile(icon: Icons.help_outline_rounded, label: 'Help & Support', onTap: () {}),
              const SizedBox(height: 8),
              const Divider(color: EvoraColors.border),
              const SizedBox(height: 8),
              _SettingsTile(
                icon: Icons.logout_rounded,
                label: 'Sign Out',
                labelColor: EvoraColors.error,
                onTap: () async {
                  await AuthService().signOut();
                  if (context.mounted) context.go('/login');
                },
              ),
              const SizedBox(height: 32),
              Text('Evora Health App v1.0.0', style: const TextStyle(color: EvoraColors.textMuted, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? labelColor;
  final VoidCallback onTap;

  const _SettingsTile({required this.icon, required this.label, required this.onTap, this.labelColor});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: EvoraColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: EvoraColors.border),
        ),
        child: Icon(icon, color: labelColor ?? EvoraColors.textSecondary, size: 20),
      ),
      title: Text(label, style: TextStyle(color: labelColor ?? EvoraColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w500)),
      trailing: labelColor == null ? const Icon(Icons.chevron_right_rounded, color: EvoraColors.textMuted) : null,
      onTap: onTap,
    );
  }
}
