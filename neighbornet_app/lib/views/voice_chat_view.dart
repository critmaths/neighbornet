import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
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
  void dispose() {
    _callTimer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _secondsElapsed = 0;
    _callTimer?.cancel();
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _secondsElapsed++;
        });
      }
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
    final voiceService = context.watch<VoiceChatService>();

    // Handle timer based on state transitions
    if (voiceService.state == CallState.connected && _previousState != CallState.connected) {
      _startTimer();
    } else if (voiceService.state != CallState.connected && _previousState == CallState.connected) {
      _stopTimer();
    }
    _previousState = voiceService.state;

    final peerName = voiceService.activePeerNickname ?? 'Mesh Peer';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice & Video Comms'),
      ),
      body: Center(
        child: SingleChildScrollView(
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
                  // Video Viewport Area (when video enabled and connected)
                  if (voiceService.state == CallState.connected && voiceService.isVideoEnabled)
                    Container(
                      height: 260,
                      width: 360,
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Theme.of(context).colorScheme.primary, width: 2),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          RTCVideoView(
                            voiceService.localRenderer,
                            mirror: true,
                            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            margin: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.videocam, color: Colors.greenAccent, size: 14),
                                SizedBox(width: 4),
                                Text('Camera Live', style: TextStyle(color: Colors.white, fontSize: 11)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    _buildStatusIndicator(voiceService.state, voiceService.isVideoEnabled, peerName),

                  const SizedBox(height: 16),

                  // Call timer display
                  if (voiceService.state == CallState.connected)
                    Text(
                      _formatDuration(_secondsElapsed),
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),

                  // Error / Fallback message display
                  if (voiceService.lastError.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: (voiceService.state == CallState.error
                              ? Theme.of(context).colorScheme.errorContainer
                              : Colors.amber.withValues(alpha: 0.2)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          voiceService.lastError,
                          style: TextStyle(
                            fontSize: 13,
                            color: voiceService.state == CallState.error
                                ? Theme.of(context).colorScheme.error
                                : Colors.amber.shade900,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),

                  const SizedBox(height: 32),

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

  Widget _buildStatusIndicator(CallState state, bool isVideo, String peerName) {
    IconData icon;
    Color color;
    String text;

    switch (state) {
      case CallState.idle:
        icon = Icons.mic_none_outlined;
        color = Colors.grey;
        text = 'Ready to Call (Mesh Standby)';
        break;
      case CallState.calling:
        icon = Icons.phone_forwarded;
        color = Colors.blue;
        text = 'Calling $peerName across mesh...';
        break;
      case CallState.ringing:
        icon = Icons.ring_volume;
        color = Colors.orange;
        text = 'Incoming Call from $peerName!';
        break;
      case CallState.connected:
        icon = isVideo ? Icons.videocam : Icons.record_voice_over;
        color = Colors.green;
        text = isVideo ? 'Video Call with $peerName' : 'Voice Call with $peerName';
        break;
      case CallState.error:
        icon = Icons.error_outline;
        color = Colors.red;
        text = 'Call Interrupted';
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
            fontSize: 18,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildControls(BuildContext context, VoiceChatService service) {
    if (service.state == CallState.idle || service.state == CallState.error) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton.icon(
            onPressed: () => service.startCall('nearby_peer', peerNickname: 'Nearby Peer', withVideo: false),
            icon: const Icon(Icons.call),
            label: const Text('Voice Call'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(width: 16),
          FilledButton.tonalIcon(
            onPressed: () => service.startCall('nearby_peer', peerNickname: 'Nearby Peer', withVideo: true),
            icon: const Icon(Icons.videocam),
            label: const Text('Video Call'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
          ),
        ],
      );
    }

    // Incoming Call Ringing Controls
    if (service.state == CallState.ringing) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FloatingActionButton.extended(
            heroTag: 'answerVoice',
            onPressed: () => service.answerCall(withVideo: false),
            backgroundColor: Colors.green,
            icon: const Icon(Icons.call, color: Colors.white),
            label: const Text('Answer Voice', style: TextStyle(color: Colors.white)),
          ),
          const SizedBox(width: 16),
          FloatingActionButton.extended(
            heroTag: 'answerVideo',
            onPressed: () => service.answerCall(withVideo: true),
            backgroundColor: Colors.blue,
            icon: const Icon(Icons.videocam, color: Colors.white),
            label: const Text('Answer Video', style: TextStyle(color: Colors.white)),
          ),
          const SizedBox(width: 16),
          FloatingActionButton(
            heroTag: 'declineCall',
            onPressed: service.declineCall,
            backgroundColor: Colors.red,
            child: const Icon(Icons.call_end, color: Colors.white),
          ),
        ],
      );
    }

    // Outgoing Calling State
    if (service.state == CallState.calling) {
      return FloatingActionButton.extended(
        heroTag: 'cancelCalling',
        onPressed: service.endCall,
        backgroundColor: Colors.red,
        icon: const Icon(Icons.call_end, color: Colors.white),
        label: const Text('Cancel Call', style: TextStyle(color: Colors.white)),
      );
    }

    // Connected Call Controls
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
        const SizedBox(width: 24),
        // Video Toggle
        FloatingActionButton(
          heroTag: 'videoBtn',
          onPressed: service.toggleVideo,
          backgroundColor: service.isVideoEnabled ? Theme.of(context).colorScheme.primary : Colors.grey[200],
          child: Icon(
            service.isVideoEnabled ? Icons.videocam : Icons.videocam_off,
            color: service.isVideoEnabled ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(width: 24),
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
