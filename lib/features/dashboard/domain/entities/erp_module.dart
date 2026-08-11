import 'package:flutter/material.dart';

class ErpModule {
  const ErpModule(
      {required this.title,
      required this.icon,
      required this.color,
      this.enabled = true});

  final String title;
  final IconData icon;
  final Color color;
  final bool enabled;
}
