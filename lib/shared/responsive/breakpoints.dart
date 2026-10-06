import 'package:flutter/widgets.dart';

/// The only responsive breakpoint this app currently needs. Add more only
/// when a screen actually requires finer-grained layout switching.
abstract final class Breakpoints {
  static const double tabletMinWidth = 700;
}

bool isTablet(BuildContext context) => MediaQuery.sizeOf(context).width >= Breakpoints.tabletMinWidth;
