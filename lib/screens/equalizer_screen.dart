import 'package:flutter/material.dart';
import '../services/equalizer_service.dart';
import '../theme/app_theme.dart';

class EqualizerScreen extends StatefulWidget {
  const EqualizerScreen({super.key});
  @override
  State<EqualizerScreen> createState() => _EqualizerScreenState();
}

class _EqualizerScreenState extends State<EqualizerScreen> {
  final Map<int, double> _gains = {};
  int _bandCount = 5;
  bool _loading = true;
  bool _enabled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    _bandCount = await EqualizerService.bandCount();
    for (int i = 0; i < _bandCount; i++) {
      _gains[i] = 0.0;
    }
    setState(() {
      _enabled = EqualizerService.enabled;
      _loading = false;
    });
  }

  Future<void> _toggleEq(bool v) async {
    await EqualizerService.setEnabled(v);
    setState(() => _enabled = v);
  }

  Future<void> _applyPreset(String name) async {
    await EqualizerService.applyPreset(name);
    final preset = EqualizerService.presets.firstWhere(
      (e) => e['name'] == name,
      orElse: () => EqualizerService.presets.first,
    );
    final gains = (preset['gains'] as List).cast<double>();
    setState(() {
      _enabled = true;
      for (int i = 0; i < _bandCount && i < gains.length; i++) {
        _gains[i] = gains[i];
      }
    });
  }

  Future<void> _setBand(int i, double value) async {
    setState(() => _gains[i] = value);
    await EqualizerService.setBandGain(i, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('المعادل الصوتي'),
        actions: [
          Switch(
            value: _enabled,
            onChanged: _toggleEq,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _enabled
                        ? AppTheme.primary.withValues(alpha: 0.15)
                        : Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _enabled ? Icons.graphic_eq : Icons.graphic_eq_outlined,
                        color: _enabled ? AppTheme.primary : Colors.grey,
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _enabled ? 'مفعّل' : 'معطّل',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _enabled
                                    ? AppTheme.primary
                                    : Colors.grey,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _enabled
                                  ? 'تأثير ${EqualizerService.preset}'
                                  : 'المعادل متوقف',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                const Text(
                  'الأنماط الجاهزة',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: EqualizerService.presets
                      .where((p) => p['name'] != 'flat' && p['name'] != 'normal')
                      .map((p) {
                    final selected = EqualizerService.preset == p['name'];
                    return ActionChip(
                      avatar: Icon(
                        _iconForPreset(p['name'] as String),
                        size: 16,
                        color: selected ? Colors.white : AppTheme.primary,
                      ),
                      label: Text(p['label'] as String),
                      backgroundColor: selected
                          ? AppTheme.primary
                          : AppTheme.primary.withValues(alpha: 0.1),
                      labelStyle: TextStyle(
                        color: selected ? Colors.white : null,
                        fontWeight:
                            selected ? FontWeight.bold : FontWeight.normal,
                      ),
                      onPressed: () => _applyPreset(p['name'] as String),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 24),

                const Text(
                  'التحكم اليدوي',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 12),

                Container(
                  height: 260,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: List.generate(_bandCount, (i) {
                      return Expanded(
                        child: _bandSlider(i),
                      );
                    }),
                  ),
                ),

                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      for (int i = 0; i < _bandCount; i++) {
                        _gains[i] = 0.0;
                        EqualizerService.setBandGain(i, 0.0);
                      }
                    });
                  },
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('إعادة ضبط'),
                ),
              ],
            ),
    );
  }

  Widget _bandSlider(int i) {
    final value = _gains[i] ?? 0.0;
    final freqLabels = ['60Hz', '230Hz', '910Hz', '3.6kHz', '14kHz'];
    final label = i < freqLabels.length ? freqLabels[i] : '${i + 1}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          Text(
            '${value >= 0 ? "+" : ""}${value.toStringAsFixed(1)}',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: RotatedBox(
              quarterTurns: 3,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 4,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape:
                      const RoundSliderOverlayShape(overlayRadius: 12),
                ),
                child: Slider(
                  value: value.clamp(-10.0, 10.0),
                  min: -10.0,
                  max: 10.0,
                  divisions: 40,
                  onChanged: _enabled ? (v) => _setBand(i, v) : null,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.color
                  ?.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForPreset(String name) {
    switch (name) {
      case 'bass':
        return Icons.speaker;
      case 'vocal':
        return Icons.mic;
      case 'rock':
        return Icons.electric_bolt;
      case 'pop':
        return Icons.star;
      case 'jazz':
        return Icons.music_note;
      case 'classical':
        return Icons.piano;
      default:
        return Icons.equalizer;
    }
  }
}
