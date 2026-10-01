import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'studio_model.dart';
import 'studio_ui.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => StudioModel(),
      child: const AureonApp(),
    ),
  );
}
