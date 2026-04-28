import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../services/device_service.dart';

class DevicesScreen extends StatelessWidget {
  const DevicesScreen({super.key});

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
              Text('Connected Devices', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text('Sync your Evora hardware to track your health data.',
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 24),

              // Band card
              _DeviceCard(
                icon: Icons.watch_rounded,
                name: 'Evora Band',
                description: 'Heart rate, steps, sleep, SpO2',
                isConnected: false,
                onConnect: () => _showConnectSheet(context, DeviceType.band),
              ),
              const SizedBox(height: 16),

              // Scale card
              _DeviceCard(
                icon: Icons.monitor_weight_rounded,
                name: 'Evora Scale',
                description: 'Weight, BMI, body composition',
                isConnected: false,
                onConnect: () => _showConnectSheet(context, DeviceType.scale),
              ),
              const SizedBox(height: 16),

              // Mask card
              _DeviceCard(
                icon: Icons.air_rounded,
                name: 'Evora Mask',
                description: 'Breathing resistance training',
                isConnected: false,
                onConnect: () => _showConnectSheet(context, DeviceType.mask),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showConnectSheet(BuildContext context, DeviceType type) {
    showModalBottomSheet(
      context: context,
      backgroundColor: EvoraColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: EvoraColors.border, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            Icon(Icons.bluetooth_searching_rounded, color: EvoraColors.primaryAccent, size: 48),
            const SizedBox(height: 16),
            Text('Connect ${_deviceName(type)}', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Make sure your device is charged, in range, and Bluetooth is enabled on your device.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Bluetooth pairing coming soon on the mobile app.')),
                );
              },
              child: const Text('Start Pairing'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: EvoraColors.textMuted)),
            ),
          ],
        ),
      ),
    );
  }

  String _deviceName(DeviceType t) {
    switch (t) {
      case DeviceType.band: return 'Evora Band';
      case DeviceType.scale: return 'Evora Scale';
      case DeviceType.mask: return 'Evora Mask';
    }
  }
}

class _DeviceCard extends StatelessWidget {
  final IconData icon;
  final String name;
  final String description;
  final bool isConnected;
  final VoidCallback onConnect;

  const _DeviceCard({
    required this.icon,
    required this.name,
    required this.description,
    required this.isConnected,
    required this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: EvoraColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isConnected ? EvoraColors.deviceConnected.withOpacity(0.4) : EvoraColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: EvoraColors.surfaceElevated,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: isConnected ? EvoraColors.primaryAccent : EvoraColors.textMuted, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 15)),
                const SizedBox(height: 2),
                Text(description, style: const TextStyle(color: EvoraColors.textMuted, fontSize: 12)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      width: 6, height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isConnected ? EvoraColors.deviceConnected : EvoraColors.deviceDisconnected,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isConnected ? 'Connected' : 'Not connected',
                      style: TextStyle(
                        fontSize: 12,
                        color: isConnected ? EvoraColors.deviceConnected : EvoraColors.deviceDisconnected,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: onConnect,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(80, 36),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              backgroundColor: isConnected ? EvoraColors.surfaceElevated : EvoraColors.primaryAccent,
              foregroundColor: isConnected ? EvoraColors.textSecondary : Colors.black,
            ),
            child: Text(isConnected ? 'Sync' : 'Connect', style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
