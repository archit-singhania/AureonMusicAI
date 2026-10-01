import 'package:flutter/material.dart';
import '../theme/premium_theme.dart';
import '../services/haptic_service.dart';

class TimeTravelSlider extends StatefulWidget {
  const TimeTravelSlider({Key? key}) : super(key: key);

  @override
  State<TimeTravelSlider> createState() => _TimeTravelSliderState();
}

class _TimeTravelSliderState extends State<TimeTravelSlider> {
  double _historyValue = 100;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Mix History", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            Text(
              _historyValue == 100 ? "Current State" : "Reverted State",
              style: TextStyle(color: _historyValue == 100 ? PremiumTheme.accentNeonGreen : Colors.orange),
            )
          ],
        ),
        Slider(
          value: _historyValue,
          min: 0,
          max: 100,
          divisions: 10,
          activeColor: PremiumTheme.accentNeonPurple,
          inactiveColor: PremiumTheme.surfaceElevated,
          onChanged: (val) {
            setState(() => _historyValue = val);
            HapticService.selectionClick();
          },
        ),
      ],
    );
  }
}
