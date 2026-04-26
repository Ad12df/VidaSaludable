import 'package:flutter/material.dart';

enum ActivityKind { stationary, walking, running, vehicle, unknown }

int colorToArgb(Color c) =>
    ((c.a * 255).round() << 24) |
    ((c.r * 255).round() << 16) |
    ((c.g * 255).round() << 8) |
    (c.b * 255).round();
