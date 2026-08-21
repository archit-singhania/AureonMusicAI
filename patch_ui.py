import os
import re

file_path = 'flutter_app/aureon/lib/screens/player_screen.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Add imports if not there
imports_to_add = '''import '../widgets/spectrogram_3d.dart';
import '../widgets/time_travel_slider.dart';
import '../widgets/node_graph_editor.dart';
'''
if 'spectrogram_3d.dart' not in content:
    content = content.replace("import '../widgets/spectral_visualizer.dart';", "import '../widgets/spectral_visualizer.dart';\n" + imports_to_add)

# Replace SpectralVisualizer with Spectrogram3D (if it's not already done)
content = content.replace("SpectralVisualizer(", "Spectrogram3D(audioPath: widget.audioPath, ")

# Add TimeTravelSlider below the audio player controls
if 'TimeTravelSlider' not in content:
    content = content.replace("const SizedBox(height: 16),", "const SizedBox(height: 16),\n                  const TimeTravelSlider(),\n                  const SizedBox(height: 16),", 1)

# Add NodeGraphEditor in the FX tab
if 'NodeGraphEditor' not in content:
    content = content.replace("StudioEffectsRack(", "Container(height: 300, child: const NodeGraphEditor()),\n                const SizedBox(height: 16),\n                StudioEffectsRack(")

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

