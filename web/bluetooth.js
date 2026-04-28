// Evora Health App - Web Bluetooth Bridge
// Called from Flutter via dart:js interop
// Requires Chrome 56+ or any Chromium-based browser

window.EvoraBluetooth = {

  // ─── BLE UUIDs ──────────────────────────────────────────────────────────────
  // Standard BLE health service UUIDs
  SERVICES: {
    HEART_RATE:       '0000180d-0000-1000-8000-00805f9b34fb',
    WEIGHT_SCALE:     '0000181d-0000-1000-8000-00805f9b34fb',
    BODY_COMPOSITION: '0000181b-0000-1000-8000-00805f9b34fb',
    BATTERY:          '0000180f-0000-1000-8000-00805f9b34fb',
    DEVICE_INFO:      '0000180a-0000-1000-8000-00805f9b34fb',
    // Evora custom service - replace with actual UUID from firmware team
    EVORA_BAND:       'evora0001-0000-1000-8000-00805f9b34fb',
    EVORA_SCALE:      'evora0002-0000-1000-8000-00805f9b34fb',
  },

  CHARACTERISTICS: {
    HEART_RATE_MEASUREMENT: '00002a37-0000-1000-8000-00805f9b34fb',
    WEIGHT_MEASUREMENT:     '00002a9d-0000-1000-8000-00805f9b34fb',
    BODY_COMPOSITION:       '00002a9b-0000-1000-8000-00805f9b34fb',
    BATTERY_LEVEL:          '00002a19-0000-1000-8000-00805f9b34fb',
    STEPS:                  '00002a56-0000-1000-8000-00805f9b34fb',
  },

  // Active connections store
  _connections: {},
  _notifyCallbacks: {},

  // ─── CHECK SUPPORT ────────────────────────────────────────────────────────
  isSupported: function() {
    return !!(navigator.bluetooth);
  },

  // ─── SCAN AND PAIR BAND ──────────────────────────────────────────────────
  pairBand: async function(onSuccess, onError) {
    if (!navigator.bluetooth) {
      onError('Web Bluetooth not supported. Use Chrome on desktop or Android.');
      return;
    }
    try {
      const device = await navigator.bluetooth.requestDevice({
        filters: [
          { namePrefix: 'Evora' },
          { namePrefix: 'EVORA' },
        ],
        optionalServices: [
          window.EvoraBluetooth.SERVICES.HEART_RATE,
          window.EvoraBluetooth.SERVICES.BATTERY,
          window.EvoraBluetooth.SERVICES.DEVICE_INFO,
          // Remove custom UUID until firmware team confirms it
          // window.EvoraBluetooth.SERVICES.EVORA_BAND,
        ]
      });

      device.addEventListener('gattserverdisconnected', () => {
        console.log('Evora Band disconnected:', device.name);
        if (window.EvoraBluetooth._notifyCallbacks['band_disconnect']) {
          window.EvoraBluetooth._notifyCallbacks['band_disconnect'](device.id, device.name);
        }
      });

      const server = await device.gatt.connect();
      window.EvoraBluetooth._connections['band'] = { device, server };

      onSuccess(JSON.stringify({
        id: device.id,
        name: device.name || 'Evora Band',
        connected: true,
        type: 'band',
      }));
    } catch (e) {
      if (e.name === 'NotFoundError') {
        onError('No Evora Band found nearby. Make sure it is charged and in range.');
      } else if (e.name === 'SecurityError') {
        onError('Bluetooth permission denied. Allow Bluetooth access in your browser settings.');
      } else {
        onError(e.message || 'Pairing failed.');
      }
    }
  },

  // ─── SCAN AND PAIR SCALE ─────────────────────────────────────────────────
  pairScale: async function(onSuccess, onError) {
    if (!navigator.bluetooth) {
      onError('Web Bluetooth not supported. Use Chrome on desktop or Android.');
      return;
    }
    try {
      const device = await navigator.bluetooth.requestDevice({
        filters: [
          { namePrefix: 'Evora' },
          { namePrefix: 'EVORA' },
        ],
        optionalServices: [
          window.EvoraBluetooth.SERVICES.WEIGHT_SCALE,
          window.EvoraBluetooth.SERVICES.BODY_COMPOSITION,
          window.EvoraBluetooth.SERVICES.BATTERY,
          window.EvoraBluetooth.SERVICES.DEVICE_INFO,
        ]
      });

      device.addEventListener('gattserverdisconnected', () => {
        if (window.EvoraBluetooth._notifyCallbacks['scale_disconnect']) {
          window.EvoraBluetooth._notifyCallbacks['scale_disconnect'](device.id, device.name);
        }
      });

      const server = await device.gatt.connect();
      window.EvoraBluetooth._connections['scale'] = { device, server };

      onSuccess(JSON.stringify({
        id: device.id,
        name: device.name || 'Evora Scale',
        connected: true,
        type: 'scale',
      }));
    } catch (e) {
      if (e.name === 'NotFoundError') {
        onError('No Evora Scale found nearby. Make sure it is powered on and in range.');
      } else {
        onError(e.message || 'Pairing failed.');
      }
    }
  },

  // ─── READ HEART RATE FROM BAND ───────────────────────────────────────────
  readHeartRate: async function(onData, onError) {
    const conn = window.EvoraBluetooth._connections['band'];
    if (!conn) { onError('Band not connected'); return; }

    try {
      const service = await conn.server.getPrimaryService(
        window.EvoraBluetooth.SERVICES.HEART_RATE
      );
      const char = await service.getCharacteristic(
        window.EvoraBluetooth.CHARACTERISTICS.HEART_RATE_MEASUREMENT
      );

      // Subscribe to notifications for live HR
      await char.startNotifications();
      char.addEventListener('characteristicvaluechanged', (event) => {
        const value = event.target.value;
        const hr = window.EvoraBluetooth._parseHeartRate(value);
        onData(JSON.stringify({ heartRate: hr, timestamp: Date.now() }));
      });
    } catch (e) {
      onError('Could not read heart rate: ' + e.message);
    }
  },

  // ─── READ WEIGHT FROM SCALE ──────────────────────────────────────────────
  readWeight: async function(onData, onError) {
    const conn = window.EvoraBluetooth._connections['scale'];
    if (!conn) { onError('Scale not connected'); return; }

    try {
      const service = await conn.server.getPrimaryService(
        window.EvoraBluetooth.SERVICES.WEIGHT_SCALE
      );
      const char = await service.getCharacteristic(
        window.EvoraBluetooth.CHARACTERISTICS.WEIGHT_MEASUREMENT
      );

      await char.startNotifications();
      char.addEventListener('characteristicvaluechanged', (event) => {
        const value = event.target.value;
        const weight = window.EvoraBluetooth._parseWeight(value);
        onData(JSON.stringify({ weightKg: weight, timestamp: Date.now() }));
      });
    } catch (e) {
      onError('Could not read weight: ' + e.message);
    }
  },

  // ─── SYNC ALL DATA FROM BAND ─────────────────────────────────────────────
  syncBand: async function(onData, onError) {
    const conn = window.EvoraBluetooth._connections['band'];
    if (!conn) { onError('Band not connected'); return; }

    try {
      const data = {};

      // Battery level
      try {
        const batService = await conn.server.getPrimaryService(window.EvoraBluetooth.SERVICES.BATTERY);
        const batChar = await batService.getCharacteristic(window.EvoraBluetooth.CHARACTERISTICS.BATTERY_LEVEL);
        const batValue = await batChar.readValue();
        data.batteryLevel = batValue.getUint8(0);
      } catch(_) {}

      onData(JSON.stringify({ ...data, timestamp: Date.now(), type: 'band_sync' }));
    } catch (e) {
      onError('Sync failed: ' + e.message);
    }
  },

  // ─── DISCONNECT ──────────────────────────────────────────────────────────
  disconnect: function(deviceType) {
    const conn = window.EvoraBluetooth._connections[deviceType];
    if (conn && conn.device.gatt.connected) {
      conn.device.gatt.disconnect();
    }
    delete window.EvoraBluetooth._connections[deviceType];
  },

  disconnectAll: function() {
    window.EvoraBluetooth.disconnect('band');
    window.EvoraBluetooth.disconnect('scale');
  },

  // ─── REGISTER DISCONNECT CALLBACK ────────────────────────────────────────
  onDisconnect: function(deviceType, callback) {
    window.EvoraBluetooth._notifyCallbacks[deviceType + '_disconnect'] = callback;
  },

  // ─── PARSERS ─────────────────────────────────────────────────────────────
  // BLE Heart Rate Measurement characteristic (0x2A37) parser
  _parseHeartRate: function(value) {
    const flags = value.getUint8(0);
    const is16bit = flags & 0x1;
    return is16bit ? value.getUint16(1, true) : value.getUint8(1);
  },

  // BLE Weight Scale Measurement characteristic (0x2A9D) parser
  // Resolution: 0.005 kg (metric flag)
  _parseWeight: function(value) {
    const flags = value.getUint8(0);
    const isImperial = flags & 0x1;
    const rawWeight = value.getUint16(1, true);
    return isImperial ? rawWeight * 0.01 * 0.453592 : rawWeight * 0.005;
  },
};

console.log('Evora Bluetooth bridge loaded. Web Bluetooth supported:', !!navigator.bluetooth);
