import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/voice_chat_service.dart';

class VoiceChatView extends StatefulWidget {
  const VoiceChatView({super.key});

  @override
  State<VoiceChatView> createState() => _VoiceChatViewState();
}

class _VoiceChatViewState extends State<VoiceChatView> {
  Timer? _callTimer;
  int _secondsElapsed = 0;
  CallState _previousState = CallState.idle;

  @override
  void initState() {
    super.initState();
    // Use addPostFrameCallback if we needed to trigger something after build
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _secondsElapsed = 0;
    _callTimer?.cancel();
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _secondsElapsed++;
      });
    });
  }

  void _stopTimer() {
    _callTimer?.cancel();
    _secondsElapsed = 0;
  }

  String _formatDuration(int totalSeconds) {
    int minutes = totalSeconds ~/ 60;
    int seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    // Note: Provider should be provided higher up in the widget tree,
    // but for the sake of the view structure, we'll assume it's available.
    final voiceService = context.watch<VoiceChatService>();

    // Handle timer based on state transitions
    if (voiceService.state == CallState.connected && _previousState != CallState.connected) {
      _startTimer();
    } else if (voiceService.state != CallState.connected && _previousState == CallState.connected) {
      _stopTimer();
    }
    _previousState = voiceService.state;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice Chat'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildStatusIndicator(voiceService.state),
                  const SizedBox(height: 24),
                  
                  // Call timer display
                  if (voiceService.state == CallState.connected)
                    Text(
                      _formatDuration(_secondsElapsed),
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  
                  // Error message display
                  if (voiceService.state == CallState.error && voiceService.lastError.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      child: Text(
                        voiceService.lastError,
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                        textAlign: TextAlign.center,
                      ),
                    ),

                  const SizedBox(height: 48),

                  // Controls
                  _buildControls(context, voiceService),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(CallState state) {
    IconData icon;
    Color color;
    String text;

    switch (state) {
      case CallState.idle:
        icon = Icons.phone_android;
        color = Colors.grey;
        text = 'Ready to call';
        break;
      case CallState.calling:
        icon = Icons.phone_forwarded;
        color = Colors.blue;
        text = 'Calling...';
        break;
      case CallState.ringing:
        icon = Icons.ring_volume;
        color = Colors.orange;
        text = 'Ringing...';
        break;
      case CallState.connected:
        icon = Icons.record_voice_over;
        color = Colors.green;
        text = 'Connected';
        break;
      case CallState.error:
        icon = Icons.error_outline;
        color = Colors.red;
        text = 'Call Failed';
        break;
    }

    return Column(
      children: [
        CircleAvatar(
          radius: 48,
          backgroundColor: color.withValues(alpha: 0.2),
          child: Icon(icon, size: 48, color: color),
        ),
        const SizedBox(height: 16),
        Text(
          text,
          style: TextStyle(
            fontSize: 20,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildControls(BuildContext context, VoiceChatService service) {
    if (service.state == CallState.idle || service.state == CallState.error) {
      return ElevatedButton.icon(
        onPressed: () => service.startCall('dummy_peer'),
        icon: const Icon(Icons.call),
        label: const Text('Start Test Call'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Mute Toggle
        FloatingActionButton(
          heroTag: 'muteBtn',
          onPressed: service.toggleMute,
          backgroundColor: service.isMuted ? Colors.red : Colors.grey[200],
          child: Icon(
            service.isMuted ? Icons.mic_off : Icons.mic,
            color: service.isMuted ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(width: 32),
        // Hang Up
        FloatingActionButton(
          heroTag: 'hangupBtn',
          onPressed: service.endCall,
          backgroundColor: Colors.red,
          child: const Icon(Icons.call_end, color: Colors.white),
        ),
      ],
    );
  }
}
