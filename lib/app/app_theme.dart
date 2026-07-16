import 'package:flutter/material.dart';

ThemeData coralTheme(Brightness brightness) => ThemeData(
      colorScheme: ColorScheme.fromSeed(
        brightness: brightness,
        seedColor: const Color(0xffff6f61),
      ),
      useMaterial3: true,
    );
