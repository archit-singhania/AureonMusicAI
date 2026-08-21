import 'package:flutter/material.dart';
import '../theme/premium_theme.dart';
import '../services/signalr_service.dart';

class MultiplayerRoomScreen extends StatefulWidget {
  final SignalRService signalRService;
  const MultiplayerRoomScreen({Key? key, required this.signalRService}) : super(key: key);

  @override
  State<MultiplayerRoomScreen> createState() => _MultiplayerRoomScreenState();
}

class _MultiplayerRoomScreenState extends State<MultiplayerRoomScreen> {
  final TextEditingController _roomController = TextEditingController();
  bool _inRoom = false;
  String _currentRoom = '';
  
  void _joinRoom() {
    if (_roomController.text.isNotEmpty) {
      widget.signalRService.hubConnection.invoke('JoinStudioRoom', args: [_roomController.text, 'FlutterUser1']);
      setState(() {
        _inRoom = true;
        _currentRoom = _roomController.text;
      });
    }
  }

  void _leaveRoom() {
    widget.signalRService.hubConnection.invoke('LeaveStudioRoom', args: [_currentRoom, 'FlutterUser1']);
    setState(() {
      _inRoom = false;
      _currentRoom = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Collab Studio")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.group_work, size: 80, color: PremiumTheme.accentNeonPurple),
            const SizedBox(height: 24),
            Text(
              "Real-Time Multiplayer",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: PremiumTheme.textPrimary),
            ),
            const SizedBox(height: 12),
            Text(
              "Join a session room to collaborate on DSP racks and stems in real-time.",
              textAlign: TextAlign.center,
              style: TextStyle(color: PremiumTheme.textSecondary),
            ),
            const SizedBox(height: 48),
            if (!_inRoom) ...[
              TextField(
                controller: _roomController,
                decoration: InputDecoration(
                  labelText: 'Session Room ID',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: PremiumTheme.surfaceElevated,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _joinRoom,
                  child: const Text("Join Session"),
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: PremiumTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: PremiumTheme.accentNeonGreen),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.sensors, color: PremiumTheme.accentNeonGreen),
                    const SizedBox(width: 16),
                    Expanded(child: Text("Connected to Room: $_currentRoom", style: const TextStyle(fontWeight: FontWeight.bold))),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                  onPressed: _leaveRoom,
                  child: const Text("Leave Session"),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
