import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/ptt_service.dart';
import '../state/neighbornet_state.dart';

class PttWalkieTalkieView extends StatefulWidget {
  final NeighborNetState? state;

  const PttWalkieTalkieView({super.key, this.state});

  @override
  State<PttWalkieTalkieView> createState() => _PttWalkieTalkieViewState();
}

class _PttWalkieTalkieViewState extends State<PttWalkieTalkieView> with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  final FocusNode _focusNode = FocusNode();
  bool _spacebarPressed = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleKeyEvent(KeyEvent event, PttService ptt) {
    if (event.logicalKey == LogicalKeyboardKey.space) {
      if (event is KeyDownEvent && !_spacebarPressed) {
        _spacebarPressed = true;
        ptt.pressPtt();
      } else if (event is KeyUpEvent && _spacebarPressed) {
        _spacebarPressed = false;
        ptt.releasePtt();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final netState = widget.state ?? (context.mounted ? context.watch<NeighborNetState>() : null);
    if (netState == null) {
      return const SizedBox.shrink();
    }
    final ptt = netState.pttService;
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: ptt,
      builder: (context, _) {
        final isEmergency = ptt.activeChannel.isEmergency;

        return Focus(
          focusNode: _focusNode,
          autofocus: true,
          onKeyEvent: (node, event) {
            _handleKeyEvent(event, ptt);
            return KeyEventResult.ignored;
          },
          child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.radio,
                color: isEmergency ? Colors.redAccent : theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              const Flexible(
                child: Text('Tactical Walkie-Talkie (PTT)', overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isEmergency
                      ? Colors.redAccent.withValues(alpha: 0.2)
                      : theme.colorScheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isEmergency ? Colors.redAccent : theme.colorScheme.primary,
                    width: 1,
                  ),
                ),
                child: Text(
                  'SIMPLEX HALF-DUPLEX',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                    color: isEmergency ? Colors.redAccent : theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            // Quick mesh simulator button for testing/demos
            IconButton(
              tooltip: 'Simulate Net Traffic',
              onPressed: () {
                _showSimulateDialog(context, ptt);
              },
              icon: const Icon(Icons.cell_tower, size: 18),
              color: theme.colorScheme.secondary,
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Row(
          children: [
            // LEFT PANEL: Main Radio Dial, LCD Frequency Display, and PTT Button
            Expanded(
              flex: 3,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // LCD Tactical Frequency & Channel Display
                    _buildLcdDisplay(context, ptt),
                    const SizedBox(height: 20),

                    // VU Meter Audio Bar
                    _buildVuMeter(context, ptt),
                    const SizedBox(height: 24),

                    // Main Giant PTT Push-To-Talk Button
                    _buildPttButton(context, ptt),
                    const SizedBox(height: 20),

                    // Keyboard Spacebar Hint & Roger Beep Status
                    _buildPttStatusFooter(context, ptt),
                    const SizedBox(height: 24),

                    // Tactical Radio Controls (Volume, Squelch, Roger Beep, VOX)
                    _buildRadioControlsCard(context, ptt),
                  ],
                ),
              ),
            ),

            // RIGHT PANEL: Transmission History Log & Channel Selector
            Expanded(
              flex: 2,
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: theme.colorScheme.primary.withValues(alpha: 0.15),
                      width: 1,
                    ),
                  ),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Channel List Selector
                    Text(
                      'TACTICAL CHANNELS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildChannelSelector(context, ptt),
                    const Divider(height: 32),

                    // Live Net Activity Log Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'CHANNEL TRAFFIC LOG',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                        if (ptt.transmissionLogs.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.delete_sweep, size: 18),
                            tooltip: 'Clear Traffic Log',
                            onPressed: () => ptt.clearLogs(),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Transmission Logs List
                    Expanded(
                      child: _buildTransmissionLogsList(context, ptt),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
      },
    );
  }

  Widget _buildLcdDisplay(BuildContext context, PttService ptt) {
    final theme = Theme.of(context);
    final chan = ptt.activeChannel;
    final isEmergency = chan.isEmergency;

    Color stateColor;
    String stateText;
    IconData stateIcon;

    switch (ptt.state) {
      case PttState.transmitting:
        stateColor = Colors.redAccent;
        stateText = 'TRANSMITTING (TX: ${ptt.txSeconds}s)';
        stateIcon = Icons.mic;
        break;
      case PttState.receiving:
        stateColor = Colors.lightBlueAccent;
        stateText = 'RECEIVING (RX)';
        stateIcon = Icons.volume_up;
        break;
      case PttState.busy:
        stateColor = Colors.amber;
        stateText = 'FLOOR BUSY (CARRIER DETECT)';
        stateIcon = Icons.block;
        break;
      case PttState.idle:
        stateColor = Colors.greenAccent;
        stateText = 'STANDBY / SQUELCH OPEN';
        stateIcon = Icons.check_circle_outline;
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF030712),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isEmergency ? Colors.redAccent.withValues(alpha: 0.8) : const Color(0xFF1E293B),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: (isEmergency ? Colors.redAccent : theme.colorScheme.primary).withValues(alpha: 0.08),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Frequency Readout & Emergency Indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(stateIcon, size: 14, color: stateColor),
                  const SizedBox(width: 6),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: stateColor,
                      boxShadow: [
                        BoxShadow(
                          color: stateColor.withValues(alpha: 0.6),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    stateText,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                      color: stateColor,
                    ),
                  ),
                ],
              ),
              if (ptt.recentRogerBeep)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.amber, width: 1),
                  ),
                  child: const Text(
                    'ROGER BEEP',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Main LCD Frequency Readout
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                chan.id,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: isEmergency ? Colors.redAccent : theme.colorScheme.primary,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      chan.name.toUpperCase(),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      chan.frequencyLabel,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Active Speaker Details (if receiving)
          if (ptt.isReceiving && ptt.activeSpeakerNickname != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.lightBlueAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.lightBlueAccent.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.account_circle, size: 16, color: Colors.lightBlueAccent),
                  const SizedBox(width: 6),
                  Text(
                    'SPEAKER: ${ptt.activeSpeakerCallsign != null && ptt.activeSpeakerCallsign!.isNotEmpty ? "[${ptt.activeSpeakerCallsign}] " : ""}${ptt.activeSpeakerNickname}',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.lightBlueAccent,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVuMeter(BuildContext context, PttService ptt) {
    final level = ptt.vuMeterLevel;
    final isActive = ptt.isTransmitting || ptt.isReceiving;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'AUDIO MODULATION (VU METER)',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
              Text(
                '${(level * 100).toInt()}%',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: level > 0.8
                      ? Colors.redAccent
                      : (level > 0.5 ? Colors.amber : Colors.greenAccent),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 24-Segment LED Bar
          Row(
            children: List.generate(24, (index) {
              final segmentThreshold = (index + 1) / 24.0;
              final isLit = isActive && (level >= segmentThreshold);

              Color litColor;
              if (index >= 20) {
                litColor = Colors.redAccent;
              } else if (index >= 14) {
                litColor = Colors.amber;
              } else {
                litColor = Colors.greenAccent;
              }

              return Expanded(
                child: Container(
                  height: 14,
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(
                    color: isLit ? litColor : litColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: isLit
                        ? [
                            BoxShadow(
                              color: litColor.withValues(alpha: 0.6),
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildPttButton(BuildContext context, PttService ptt) {
    final isTx = ptt.isTransmitting;
    final isRx = ptt.isReceiving;
    final isEmergency = ptt.activeChannel.isEmergency;

    Color btnColor = isEmergency ? Colors.redAccent : Theme.of(context).colorScheme.primary;
    if (isTx) btnColor = Colors.red;
    if (isRx) btnColor = Colors.blueGrey;

    return Center(
      child: GestureDetector(
        onTapDown: (_) {
          _focusNode.requestFocus();
          ptt.pressPtt();
        },
        onTapUp: (_) {
          ptt.releasePtt();
        },
        onTapCancel: () {
          ptt.releasePtt();
        },
        child: AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            final pulseVal = isTx ? _pulseController.value : 0.0;
            return Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    btnColor,
                    btnColor.withValues(alpha: 0.8),
                    const Color(0xFF0F172A),
                  ],
                  stops: const [0.6, 0.85, 1.0],
                ),
                border: Border.all(
                  color: isTx ? Colors.white : btnColor.withValues(alpha: 0.7),
                  width: isTx ? 4 : 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: btnColor.withValues(alpha: isTx ? (0.4 + pulseVal * 0.4) : 0.2),
                    blurRadius: isTx ? (24 + pulseVal * 20) : 16,
                    spreadRadius: isTx ? (4 + pulseVal * 8) : 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isTx ? Icons.mic : (isRx ? Icons.volume_up : Icons.mic_none),
                    size: 56,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isTx ? 'TRANSMITTING' : (isRx ? 'RECEIVING' : 'PRESS & HOLD'),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 1.4,
                    ),
                  ),
                  Text(
                    isTx ? 'RELEASE TO END' : 'PTT BUTTON',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPttStatusFooter(BuildContext context, PttService ptt) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: const Text(
                'SPACEBAR',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white70,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Hold Spacebar or Click & Hold PTT button to transmit',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        if (ptt.lastError != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.warning_amber, size: 16, color: Colors.redAccent),
                const SizedBox(width: 6),
                Text(
                  ptt.lastError!,
                  style: const TextStyle(fontSize: 12, color: Colors.redAccent, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRadioControlsCard(BuildContext context, PttService ptt) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'RADIO HARDWARE SETTINGS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                // Squelch Slider
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Flexible(
                            child: Text('Squelch (Threshold)', style: TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                          ),
                          const SizedBox(width: 4),
                          Text('${(ptt.squelchLevel * 100).toInt()}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Slider(
                        value: ptt.squelchLevel,
                        min: 0.0,
                        max: 1.0,
                        onChanged: (val) => ptt.setSquelch(val),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Volume Slider
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Flexible(
                            child: Text('RF RX Volume', style: TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                          ),
                          const SizedBox(width: 4),
                          Text('${(ptt.volume * 100).toInt()}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Slider(
                        value: ptt.volume,
                        min: 0.0,
                        max: 1.0,
                        onChanged: (val) => ptt.setVolume(val),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                // Roger Beep Switch
                Expanded(
                  child: SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Roger Beep Tone', style: TextStyle(fontSize: 13)),
                    subtitle: const Text('Audible burst when transmission releases', style: TextStyle(fontSize: 11)),
                    value: ptt.rogerBeepEnabled,
                    onChanged: (val) => ptt.toggleRogerBeep(val),
                  ),
                ),
                // VOX Switch
                Expanded(
                  child: SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('VOX (Voice Activated)', style: TextStyle(fontSize: 13)),
                    subtitle: const Text('Auto-transmit on voice detection', style: TextStyle(fontSize: 11)),
                    value: ptt.voxEnabled,
                    onChanged: (val) => ptt.toggleVox(val),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChannelSelector(BuildContext context, PttService ptt) {
    final theme = Theme.of(context);

    return Column(
      children: ptt.availableChannels.map((channel) {
        final isSelected = ptt.activeChannel.id == channel.id;
        final isEmergency = channel.isEmergency;

        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: InkWell(
            onTap: () => ptt.selectChannel(channel),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? (isEmergency ? Colors.redAccent.withValues(alpha: 0.15) : theme.colorScheme.primary.withValues(alpha: 0.15))
                    : const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected
                      ? (isEmergency ? Colors.redAccent : theme.colorScheme.primary)
                      : const Color(0xFF1E293B),
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isEmergency ? Colors.redAccent : theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      channel.id,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          channel.name,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? Colors.white : Colors.white70,
                          ),
                        ),
                        Text(
                          channel.frequencyLabel,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    Icon(
                      Icons.radio_button_checked,
                      size: 16,
                      color: isEmergency ? Colors.redAccent : theme.colorScheme.primary,
                    ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTransmissionLogsList(BuildContext context, PttService ptt) {
    if (ptt.transmissionLogs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 36, color: Colors.white.withValues(alpha: 0.2)),
            const SizedBox(height: 8),
            Text(
              'No recent transmissions',
              style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.4)),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: ptt.transmissionLogs.length,
      itemBuilder: (context, index) {
        final log = ptt.transmissionLogs[index];
        final dt = DateTime.fromMillisecondsSinceEpoch(log.timestampSec * 1000);
        final timeStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
        final isEmergency = log.priority == 'emergency';

        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isEmergency ? Colors.redAccent.withValues(alpha: 0.4) : const Color(0xFF1E293B),
            ),
          ),
          child: Row(
            children: [
              Icon(
                isEmergency ? Icons.warning_amber : Icons.record_voice_over,
                size: 18,
                color: isEmergency ? Colors.redAccent : Colors.cyanAccent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          log.senderCallsign.isNotEmpty ? '[${log.senderCallsign}] ' : '',
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amberAccent),
                        ),
                        Text(
                          log.senderNickname,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const Spacer(),
                        Text(
                          timeStr,
                          style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.white.withValues(alpha: 0.4)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            log.channel,
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 9, color: Colors.white70),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${log.durationSec}s duration (${log.chunkCount} chunks)',
                          style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.5)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSimulateDialog(BuildContext context, PttService ptt) {
    final nickController = TextEditingController(text: 'Alice (CERT-Leader)');
    final callController = TextEditingController(text: 'K9-CERT');
    int durationSec = 3;
    bool isEmergency = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.cell_tower, color: Colors.cyanAccent),
              SizedBox(width: 8),
              Text('Simulate Mesh Radio Traffic'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nickController,
                decoration: const InputDecoration(labelText: 'Speaker Nickname'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: callController,
                decoration: const InputDecoration(labelText: 'Speaker Callsign'),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Transmission Duration:'),
                  DropdownButton<int>(
                    value: durationSec,
                    items: const [
                      DropdownMenuItem(value: 2, child: Text('2 seconds')),
                      DropdownMenuItem(value: 3, child: Text('3 seconds')),
                      DropdownMenuItem(value: 5, child: Text('5 seconds')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => durationSec = val);
                      }
                    },
                  ),
                ],
              ),
              CheckboxListTile(
                title: const Text('Simulate Emergency Priority'),
                value: isEmergency,
                onChanged: (val) => setDialogState(() => isEmergency = val ?? false),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogCtx).pop();
                ptt.simulateRemoteTransmission(
                  nickname: nickController.text.trim(),
                  callsign: callController.text.trim(),
                  durationSeconds: durationSec,
                  isEmergency: isEmergency,
                );
              },
              child: const Text('Start Transmission'),
            ),
          ],
        ),
      ),
    );
  }
}
