import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/theme.dart';
import '../services/auth_service.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: EvoraColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Good ${_greeting()},',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      Text(
                        user?.displayName?.split(' ').first ?? 'Athlete',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => context.go('/profile'),
                    child: CircleAvatar(
                      backgroundColor: EvoraColors.surface,
                      radius: 20,
                      child: Text(
                        (user?.displayName?.isNotEmpty == true)
                            ? user!.displayName![0].toUpperCase()
                            : 'E',
                        style: const TextStyle(color: EvoraColors.textPrimary, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content - placeholder until design finalised
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    // Devices card
                    _SectionCard(
                      title: 'My Devices',
                      icon: Icons.watch_rounded,
                      action: 'Manage',
                      onAction: () => context.go('/devices'),
                      child: const _DevicesPlaceholder(),
                    ),
                    const SizedBox(height: 16),

                    // Activity placeholder
                    _SectionCard(
                      title: 'Today',
                      icon: Icons.bar_chart_rounded,
                      child: const _ActivityPlaceholder(),
                    ),
                    const SizedBox(height: 16),

                    // Health metrics placeholder
                    _SectionCard(
                      title: 'Health Overview',
                      icon: Icons.favorite_rounded,
                      child: const _HealthPlaceholder(),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _BottomNav(currentIndex: 0),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'morning';
    if (h < 17) return 'afternoon';
    return 'evening';
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final String? action;
  final VoidCallback? onAction;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    this.action,
    this.onAction,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: EvoraColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: EvoraColors.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
            child: Row(
              children: [
                Icon(icon, color: EvoraColors.primaryAccent, size: 18),
                const SizedBox(width: 8),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                if (action != null)
                  TextButton(
                    onPressed: onAction,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      action!,
                      style: TextStyle(color: EvoraColors.primaryAccent, fontSize: 13),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: EvoraColors.border),
          child,
        ],
      ),
    );
  }
}

class _DevicesPlaceholder extends StatelessWidget {
  const _DevicesPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _DeviceRow(icon: Icons.watch_rounded, name: 'Evora Band', status: 'Not connected'),
          const SizedBox(height: 12),
          _DeviceRow(icon: Icons.monitor_weight_rounded, name: 'Evora Scale', status: 'Not connected'),
        ],
      ),
    );
  }
}

class _DeviceRow extends StatelessWidget {
  final IconData icon;
  final String name;
  final String status;

  const _DeviceRow({required this.icon, required this.name, required this.status});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: EvoraColors.surfaceElevated,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: EvoraColors.textMuted, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 14)),
              Text(status, style: const TextStyle(color: EvoraColors.deviceDisconnected, fontSize: 12)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: EvoraColors.surfaceElevated,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: EvoraColors.border),
          ),
          child: const Text('Connect', style: TextStyle(color: EvoraColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

class _ActivityPlaceholder extends StatelessWidget {
  const _ActivityPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.directions_run_rounded, color: EvoraColors.textMuted, size: 32),
            const SizedBox(height: 8),
            Text('No activity yet today', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 4),
            Text('Connect your band to start tracking', style: const TextStyle(color: EvoraColors.textMuted, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _HealthPlaceholder extends StatelessWidget {
  const _HealthPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _MetricTile(label: 'Weight', value: '--', unit: 'kg'),
          const SizedBox(width: 12),
          _MetricTile(label: 'Resting HR', value: '--', unit: 'bpm'),
          const SizedBox(width: 12),
          _MetricTile(label: 'Steps', value: '--', unit: 'today'),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final String unit;

  const _MetricTile({required this.label, required this.value, required this.unit});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: EvoraColors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: EvoraColors.textMuted, fontSize: 11)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(color: EvoraColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w700)),
            Text(unit, style: const TextStyle(color: EvoraColors.textMuted, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  const _BottomNav({required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: EvoraColors.surface,
        border: Border(top: BorderSide(color: EvoraColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(icon: Icons.grid_view_rounded, label: 'Home', active: currentIndex == 0, onTap: () => context.go('/dashboard')),
              _NavItem(icon: Icons.watch_rounded, label: 'Devices', active: currentIndex == 1, onTap: () => context.go('/devices')),
              _NavItem(icon: Icons.bar_chart_rounded, label: 'Activity', active: currentIndex == 2, onTap: () {}),
              _NavItem(icon: Icons.person_outline_rounded, label: 'Profile', active: currentIndex == 3, onTap: () => context.go('/profile')),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({required this.icon, required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: active ? EvoraColors.primaryAccent : EvoraColors.textMuted, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: active ? EvoraColors.primaryAccent : EvoraColors.textMuted,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
