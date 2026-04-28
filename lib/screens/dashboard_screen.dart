import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/theme.dart';
import '../models/health_snapshot.dart';
import '../services/health_service.dart';
import '../services/insights_engine.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final _healthService = HealthService();
  bool _syncing = false;
  String? _syncMessage;
  DayInsights? _insights;
  List<HealthSnapshot> _history = [];

  @override
  void initState() {
    super.initState();
    _autoSync();
  }

  Future<void> _autoSync() async {
    setState(() => _syncing = true);
    final result = await _healthService.autoSync();
    final history = await _healthService.loadHistory(days: 30);
    setState(() {
      _syncing = false;
      _syncMessage = result.message;
      _history = history;
      if (result.snapshot != null) {
        _insights = InsightsEngine.analyze(result.snapshot!, history: history);
      }
    });
  }

  Future<void> _manualSync() async {
    setState(() { _syncing = true; _syncMessage = null; });
    final result = await _healthService.manualSync();
    final history = await _healthService.loadHistory(days: 30);
    setState(() {
      _syncing = false;
      _syncMessage = result.message;
      _history = history;
      if (result.snapshot != null) {
        _insights = InsightsEngine.analyze(result.snapshot!, history: history);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final firstName = user?.displayName?.split(' ').first ?? 'Athlete';

    return Scaffold(
      backgroundColor: EvoraColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(firstName),
            Expanded(
              child: RefreshIndicator(
                color: EvoraColors.primaryAccent,
                backgroundColor: EvoraColors.surface,
                onRefresh: _manualSync,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Sync status
                      if (_syncing) _buildSyncBanner(),
                      if (!_syncing && _syncMessage != null) _buildSyncDone(),

                      const SizedBox(height: 16),

                      // Readiness score card
                      if (_insights != null) _buildReadinessCard(_insights!),
                      if (_insights == null && !_syncing) _buildNoDataCard(),

                      const SizedBox(height: 16),

                      // Today's priorities
                      if (_insights != null) _buildPrioritiesCard(_insights!),

                      const SizedBox(height: 16),

                      // Key metrics row
                      if (_insights != null) _buildMetricsRow(_insights!.snapshot),

                      const SizedBox(height: 16),

                      // Insights list
                      if (_insights != null && _insights!.insights.isNotEmpty)
                        _buildInsightsList(_insights!),

                      const SizedBox(height: 16),

                      // Devices card
                      _buildDevicesCard(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _BottomNav(currentIndex: 0, onSync: _manualSync, syncing: _syncing),
    );
  }

  Widget _buildHeader(String firstName) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_greeting(), style: Theme.of(context).textTheme.bodyMedium),
              Text(firstName, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 22)),
            ],
          ),
          const Spacer(),
          // Manual sync button
          GestureDetector(
            onTap: _syncing ? null : _manualSync,
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: EvoraColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: EvoraColors.border),
              ),
              child: _syncing
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(strokeWidth: 2, color: EvoraColors.primaryAccent),
                    )
                  : const Icon(Icons.sync_rounded, color: EvoraColors.textSecondary, size: 20),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => context.go('/profile'),
            child: CircleAvatar(
              backgroundColor: EvoraColors.surface,
              radius: 20,
              child: Text(
                FirebaseAuth.instance.currentUser?.displayName?.isNotEmpty == true
                    ? FirebaseAuth.instance.currentUser!.displayName![0].toUpperCase()
                    : 'E',
                style: const TextStyle(color: EvoraColors.textPrimary, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: EvoraColors.primaryAccent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: EvoraColors.primaryAccent.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: EvoraColors.primaryAccent)),
          const SizedBox(width: 12),
          const Text('Syncing your health data...', style: TextStyle(color: EvoraColors.primaryAccent, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildSyncDone() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: EvoraColors.success.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: EvoraColors.success, size: 16),
          const SizedBox(width: 8),
          Text(_syncMessage ?? 'Synced', style: const TextStyle(color: EvoraColors.success, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildReadinessCard(DayInsights insights) {
    final score = insights.readinessScore;
    final color = score >= 80 ? EvoraColors.success : score >= 60 ? EvoraColors.warning : EvoraColors.error;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [EvoraColors.surface, EvoraColors.surfaceElevated],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Readiness', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13)),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('$score', style: TextStyle(fontSize: 52, fontWeight: FontWeight.w900, color: color, height: 1)),
                      const SizedBox(width: 4),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text('/100', style: TextStyle(fontSize: 16, color: EvoraColors.textMuted)),
                      ),
                    ],
                  ),
                  Text(insights.readinessLabel, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 14)),
                ],
              ),
              const Spacer(),
              // Score ring
              _ScoreRing(score: score, color: color, size: 80),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: EvoraColors.border, height: 1),
          const SizedBox(height: 16),
          // Sub-scores
          Row(
            children: [
              _SubScore(label: 'Recovery', score: insights.recoveryScore),
              _SubScore(label: 'Sleep', score: insights.sleepScore),
              _SubScore(label: 'Fitness', score: insights.fitnessScore),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNoDataCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: EvoraColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: EvoraColors.border),
      ),
      child: Column(
        children: [
          const Icon(Icons.health_and_safety_outlined, color: EvoraColors.textMuted, size: 40),
          const SizedBox(height: 12),
          Text('No health data yet', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Connect your Evora devices or grant health permissions to see your personalised insights.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => context.go('/devices'),
            style: ElevatedButton.styleFrom(minimumSize: const Size(160, 44)),
            child: const Text('Connect Devices'),
          ),
        ],
      ),
    );
  }

  Widget _buildPrioritiesCard(DayInsights insights) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: EvoraColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: EvoraColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt_rounded, color: EvoraColors.primaryAccent, size: 18),
              const SizedBox(width: 8),
              Text("Today's Focus", style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 12),
          ...insights.todaysPriorities.asMap().entries.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 22, height: 22,
                  decoration: BoxDecoration(
                    color: EvoraColors.primaryAccent.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text('${e.key + 1}', style: const TextStyle(color: EvoraColors.primaryAccent, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(e.value, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 14))),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildMetricsRow(HealthSnapshot s) {
    return Row(
      children: [
        _MetricCard(label: 'Steps', value: s.steps != null ? '${s.steps}' : '--', unit: 'today', icon: Icons.directions_walk_rounded),
        const SizedBox(width: 8),
        _MetricCard(label: 'Resting HR', value: s.restingHeartRate != null ? '${s.restingHeartRate!.round()}' : '--', unit: 'bpm', icon: Icons.favorite_rounded),
        const SizedBox(width: 8),
        _MetricCard(label: 'HRV', value: s.hrv != null ? '${s.hrv!.round()}' : '--', unit: 'ms', icon: Icons.show_chart_rounded),
        const SizedBox(width: 8),
        _MetricCard(label: 'Sleep', value: s.sleepDurationHours != null ? s.sleepDurationHours!.toStringAsFixed(1) : '--', unit: 'hrs', icon: Icons.bedtime_rounded),
      ],
    );
  }

  Widget _buildInsightsList(DayInsights insights) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text('Insights', style: Theme.of(context).textTheme.titleMedium),
        ),
        ...insights.insights.take(5).map((i) => _InsightCard(insight: i)),
      ],
    );
  }

  Widget _buildDevicesCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: EvoraColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: EvoraColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: EvoraColors.surfaceElevated, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.watch_rounded, color: EvoraColors.textMuted, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Evora Devices', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 14)),
                const Text('No devices connected', style: TextStyle(color: EvoraColors.deviceDisconnected, fontSize: 12)),
              ],
            ),
          ),
          TextButton(
            onPressed: () => context.go('/devices'),
            child: Text('Connect', style: TextStyle(color: EvoraColors.primaryAccent, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning,';
    if (h < 17) return 'Good afternoon,';
    return 'Good evening,';
  }
}

// ---------------------------------------------------------------------------
// COMPONENTS
// ---------------------------------------------------------------------------

class _ScoreRing extends StatelessWidget {
  final int score;
  final Color color;
  final double size;
  const _ScoreRing({required this.score, required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size, height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: 1.0,
            strokeWidth: 6,
            color: EvoraColors.border,
          ),
          CircularProgressIndicator(
            value: score / 100,
            strokeWidth: 6,
            color: color,
            strokeCap: StrokeCap.round,
          ),
        ],
      ),
    );
  }
}

class _SubScore extends StatelessWidget {
  final String label;
  final int score;
  const _SubScore({required this.label, required this.score});

  @override
  Widget build(BuildContext context) {
    final color = score >= 80 ? EvoraColors.success : score >= 60 ? EvoraColors.warning : EvoraColors.error;
    return Expanded(
      child: Column(
        children: [
          Text('$score', style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w800)),
          Text(label, style: const TextStyle(color: EvoraColors.textMuted, fontSize: 11)),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final IconData icon;
  const _MetricCard({required this.label, required this.value, required this.unit, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: EvoraColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: EvoraColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: EvoraColors.textMuted, size: 16),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(color: EvoraColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w800, height: 1)),
            Text(unit, style: const TextStyle(color: EvoraColors.textMuted, fontSize: 10)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: EvoraColors.textMuted, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

class _InsightCard extends StatefulWidget {
  final Insight insight;
  const _InsightCard({required this.insight});

  @override
  State<_InsightCard> createState() => _InsightCardState();
}

class _InsightCardState extends State<_InsightCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final i = widget.insight;
    final borderColor = i.priority == InsightPriority.high
        ? EvoraColors.error.withOpacity(0.4)
        : i.priority == InsightPriority.medium
            ? EvoraColors.warning.withOpacity(0.3)
            : EvoraColors.border;
    final tagColor = i.priority == InsightPriority.high
        ? EvoraColors.error
        : i.priority == InsightPriority.medium
            ? EvoraColors.warning
            : EvoraColors.success;

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: EvoraColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(i.headline, style: const TextStyle(color: EvoraColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                      if (i.metric != null) ...[
                        const SizedBox(height: 2),
                        Text(i.metric!, style: TextStyle(color: tagColor, fontSize: 12, fontWeight: FontWeight.w700)),
                      ],
                    ],
                  ),
                ),
                Icon(
                  _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                  color: EvoraColors.textMuted,
                  size: 18,
                ),
              ],
            ),
            if (_expanded) ...[
              const SizedBox(height: 10),
              const Divider(color: EvoraColors.border, height: 1),
              const SizedBox(height: 10),
              Text(i.detail, style: const TextStyle(color: EvoraColors.textSecondary, fontSize: 13, height: 1.5)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: EvoraColors.primaryAccent.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.bolt_rounded, color: EvoraColors.primaryAccent, size: 14),
                    const SizedBox(width: 6),
                    Expanded(child: Text(i.action, style: const TextStyle(color: EvoraColors.primaryAccent, fontSize: 12, fontWeight: FontWeight.w500))),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final VoidCallback onSync;
  final bool syncing;
  const _BottomNav({required this.currentIndex, required this.onSync, required this.syncing});

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
            Text(label, style: TextStyle(fontSize: 10, color: active ? EvoraColors.primaryAccent : EvoraColors.textMuted, fontWeight: active ? FontWeight.w600 : FontWeight.w400)),
          ],
        ),
      ),
    );
  }
}
