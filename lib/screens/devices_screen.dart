import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../services/bluetooth_service.dart';

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  final _bt = EvoraBluetoothService();

  Map<String, _DeviceState> _devices = {
    'band': _DeviceState(type: 'band', name: 'Evora Band', description: 'Heart rate, HRV, steps, sleep, SpO2', icon: Icons.watch_rounded),
    'scale': _DeviceState(type: 'scale', name: 'Evora Scale', description: 'Weight, body fat, muscle mass, hydration', icon: Icons.monitor_weight_rounded),
    'mask': _DeviceState(type: 'mask', name: 'Evora Mask', description: 'Breathing resistance training', icon: Icons.air_rounded),
  };

  StreamSubscription? _statusSub;
  StreamSubscription? _hrSub;
  StreamSubscription? _weightSub;
  int? _liveHR;
  double? _liveWeight;

  @override
  void initState() {
    super.initState();
    _loadSavedDevices();
    _listenToStatus();
  }

  Future<void> _loadSavedDevices() async {
    final saved = await _bt.loadSavedDevices();
    if (!mounted) return;
    for (final d in saved) {
      if (_devices.containsKey(d.type)) {
        setState(() {
          _devices[d.type] = _devices[d.type]!.copyWith(
            savedName: d.name,
            lastPairedAt: d.pairedAt,
            deviceId: d.id,
          );
        });
      }
    }
  }

  void _listenToStatus() {
    _statusSub = _bt.statusStream.listen((status) {
      if (!mounted) return;
      final parts = status.split(':');
      final event = parts[0];
      final name = parts.length > 1 ? parts[1] : '';

      setState(() {
        if (event == 'band_connected') {
          _devices['band'] = _devices['band']!.copyWith(isConnected: true, savedName: name);
        } else if (event == 'band_disconnected') {
          _devices['band'] = _devices['band']!.copyWith(isConnected: false);
        } else if (event == 'scale_connected') {
          _devices['scale'] = _devices['scale']!.copyWith(isConnected: true, savedName: name);
        } else if (event == 'scale_disconnected') {
          _devices['scale'] = _devices['scale']!.copyWith(isConnected: false);
        }
      });
    });

    _hrSub = _bt.heartRateStream.listen((hr) {
      if (mounted) setState(() => _liveHR = hr);
    });

    _weightSub = _bt.weightStream.listen((w) {
      if (mounted) setState(() => _liveWeight = w);
    });
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    _hrSub?.cancel();
    _weightSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EvoraColors.background,
      appBar: AppBar(
        title: const Text('My Devices'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => context.go('/dashboard'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Chrome requirement notice
              if (kIsWeb) _buildBrowserNotice(),

              const SizedBox(height: 8),
              Text('Evora Devices', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'Pair your devices via Bluetooth to start syncing your health data.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),

              // Band
              _DeviceCard(
                state: _devices['band']!,
                liveData: _devices['band']!.isConnected && _liveHR != null
                    ? '$_liveHR bpm'
                    : null,
                onPair: () => _pairDevice('band'),
                onSync: _devices['band']!.isConnected ? () => _syncBand() : null,
                onDisconnect: _devices['band']!.isConnected ? () => _disconnect('band') : null,
                onStartMonitor: _devices['band']!.isConnected ? () => _bt.startHeartRateMonitor() : null,
              ),
              const SizedBox(height: 14),

              // Scale
              _DeviceCard(
                state: _devices['scale']!,
                liveData: _devices['scale']!.isConnected && _liveWeight != null
                    ? '${_liveWeight!.toStringAsFixed(1)} kg'
                    : null,
                onPair: () => _pairDevice('scale'),
                onSync: _devices['scale']!.isConnected ? () => _bt.startWeightMonitor() : null,
                onDisconnect: _devices['scale']!.isConnected ? () => _disconnect('scale') : null,
                onStartMonitor: _devices['scale']!.isConnected ? () => _bt.startWeightMonitor() : null,
              ),
              const SizedBox(height: 14),

              // Mask - coming soon
              _DeviceCard(
                state: _devices['mask']!,
                comingSoon: true,
                onPair: null,
                onSync: null,
                onDisconnect: null,
                onStartMonitor: null,
              ),

              const SizedBox(height: 32),

              // How it works
              _buildHowItWorks(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBrowserNotice() {
    final supported = _bt.isSupported;
    final isChrome = _bt.isChromeWeb;

    if (supported) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: EvoraColors.success.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: EvoraColors.success.withOpacity(0.3)),
        ),
        child: const Row(
          children: [
            Icon(Icons.bluetooth_rounded, color: EvoraColors.success, size: 16),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Bluetooth ready. Make sure your device is on and nearby.',
                style: TextStyle(color: EvoraColors.success, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: EvoraColors.warning.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: EvoraColors.warning.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: EvoraColors.warning, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Chrome required for device pairing',
                  style: TextStyle(color: EvoraColors.warning, fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Device pairing uses Web Bluetooth, which is only available in Google Chrome. Open this page in Chrome to connect your Evora devices.',
                  style: TextStyle(color: EvoraColors.textSecondary, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHowItWorks() {
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
          Text('How pairing works', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 14)),
          const SizedBox(height: 12),
          _Step(number: '1', text: 'Make sure your device is charged and Bluetooth is on.'),
          _Step(number: '2', text: 'Tap "Pair" next to your device. A browser popup will appear.'),
          _Step(number: '3', text: 'Select your Evora device from the list and tap "Pair".'),
          _Step(number: '4', text: 'Your device will sync automatically every time you open the app.'),
        ],
      ),
    );
  }

  Future<void> _pairDevice(String type) async {
    if (!_bt.isSupported) {
      _showError('Open this page in Google Chrome to pair Bluetooth devices.');
      return;
    }

    setState(() => _devices[type] = _devices[type]!.copyWith(isPairing: true));

    final result = type == 'band'
        ? await _bt.pairBand()
        : await _bt.pairScale();

    if (!mounted) return;
    setState(() => _devices[type] = _devices[type]!.copyWith(isPairing: false));

    if (result.success) {
      _showSuccess(result.message);
    } else {
      _showError(result.message);
    }
  }

  Future<void> _syncBand() async {
    await _bt.syncBand();
    if (mounted) _showSuccess('Band synced');
  }

  void _disconnect(String type) {
    _bt.disconnect(type);
    if (mounted) {
      setState(() => _devices[type] = _devices[type]!.copyWith(isConnected: false));
    }
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: EvoraColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: EvoraColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// STATE MODEL
// ---------------------------------------------------------------------------

class _DeviceState {
  final String type;
  final String name;
  final String description;
  final IconData icon;
  final bool isConnected;
  final bool isPairing;
  final String? savedName;
  final String? deviceId;
  final DateTime? lastPairedAt;

  const _DeviceState({
    required this.type,
    required this.name,
    required this.description,
    required this.icon,
    this.isConnected = false,
    this.isPairing = false,
    this.savedName,
    this.deviceId,
    this.lastPairedAt,
  });

  _DeviceState copyWith({
    bool? isConnected,
    bool? isPairing,
    String? savedName,
    String? deviceId,
    DateTime? lastPairedAt,
  }) => _DeviceState(
    type: type,
    name: name,
    description: description,
    icon: icon,
    isConnected: isConnected ?? this.isConnected,
    isPairing: isPairing ?? this.isPairing,
    savedName: savedName ?? this.savedName,
    deviceId: deviceId ?? this.deviceId,
    lastPairedAt: lastPairedAt ?? this.lastPairedAt,
  );
}

// ---------------------------------------------------------------------------
// DEVICE CARD
// ---------------------------------------------------------------------------

class _DeviceCard extends StatelessWidget {
  final _DeviceState state;
  final String? liveData;
  final bool comingSoon;
  final VoidCallback? onPair;
  final VoidCallback? onSync;
  final VoidCallback? onDisconnect;
  final VoidCallback? onStartMonitor;

  const _DeviceCard({
    required this.state,
    this.liveData,
    this.comingSoon = false,
    required this.onPair,
    required this.onSync,
    required this.onDisconnect,
    required this.onStartMonitor,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = state.isConnected
        ? EvoraColors.deviceConnected.withOpacity(0.5)
        : comingSoon
            ? EvoraColors.border.withOpacity(0.4)
            : EvoraColors.border;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: EvoraColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: EvoraColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  state.icon,
                  color: state.isConnected ? EvoraColors.primaryAccent : EvoraColors.textMuted,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(state.savedName ?? state.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(state.description, style: const TextStyle(color: EvoraColors.textMuted, fontSize: 12)),
                    const SizedBox(height: 6),
                    // Status indicator
                    Row(
                      children: [
                        Container(
                          width: 6, height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: state.isConnected
                                ? EvoraColors.deviceConnected
                                : comingSoon
                                    ? EvoraColors.textMuted.withOpacity(0.4)
                                    : EvoraColors.deviceDisconnected,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          state.isPairing
                              ? 'Searching...'
                              : state.isConnected
                                  ? 'Connected'
                                  : comingSoon
                                      ? 'Coming in app'
                                      : state.lastPairedAt != null
                                          ? 'Previously paired'
                                          : 'Not connected',
                          style: TextStyle(
                            fontSize: 12,
                            color: state.isConnected
                                ? EvoraColors.deviceConnected
                                : EvoraColors.deviceDisconnected,
                          ),
                        ),
                        // Live data badge
                        if (liveData != null) ...[
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: EvoraColors.primaryAccent.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'LIVE  $liveData',
                              style: const TextStyle(
                                color: EvoraColors.primaryAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Action buttons
          if (!comingSoon) ...[
            const SizedBox(height: 14),
            const Divider(height: 1, color: EvoraColors.border),
            const SizedBox(height: 12),
            Row(
              children: [
                if (!state.isConnected) ...[
                  Expanded(
                    child: _ActionButton(
                      label: state.isPairing ? 'Searching...' : 'Pair Device',
                      icon: Icons.bluetooth_searching_rounded,
                      loading: state.isPairing,
                      primary: true,
                      onTap: state.isPairing ? null : onPair,
                    ),
                  ),
                ] else ...[
                  Expanded(
                    child: _ActionButton(
                      label: 'Sync Now',
                      icon: Icons.sync_rounded,
                      onTap: onSync,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (onStartMonitor != null)
                    Expanded(
                      child: _ActionButton(
                        label: 'Live Data',
                        icon: Icons.show_chart_rounded,
                        onTap: onStartMonitor,
                      ),
                    ),
                  const SizedBox(width: 8),
                  _ActionButton(
                    label: 'Disconnect',
                    icon: Icons.bluetooth_disabled_rounded,
                    danger: true,
                    onTap: onDisconnect,
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool primary;
  final bool danger;
  final bool loading;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    this.primary = false,
    this.danger = false,
    this.loading = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = primary
        ? EvoraColors.primaryAccent
        : danger
            ? EvoraColors.error.withOpacity(0.1)
            : EvoraColors.surfaceElevated;
    final fg = primary
        ? Colors.black
        : danger
            ? EvoraColors.error
            : EvoraColors.textSecondary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: danger ? Border.all(color: EvoraColors.error.withOpacity(0.3)) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: fg))
            else
              Icon(icon, color: fg, size: 14),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final String number;
  final String text;
  const _Step({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
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
              child: Text(number, style: const TextStyle(color: EvoraColors.primaryAccent, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: const TextStyle(color: EvoraColors.textSecondary, fontSize: 13, height: 1.4)),
          ),
        ],
      ),
    );
  }
}
