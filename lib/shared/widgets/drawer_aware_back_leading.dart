import 'package:flutter/material.dart';

/// `AppBar`'s own automatic leading-icon resolution shows the drawer's
/// hamburger instead of a back arrow whenever a `Scaffold` has **both** a
/// `drawer` and a pop-able route (`AppBar._getEffectiveLeading`) — every
/// screen in this app that sets `drawer: const AppNavDrawer()` does, since
/// the same screen is reachable both as a drawer destination (nothing to
/// pop to) and by being pushed on top of another screen (something to pop
/// to). That leaves pushed screens with no visible way back at all — the
/// system/hardware back gesture still works, but there's no on-screen
/// affordance for it, confirmed as a genuine client-facing gap during the
/// real-device verification pass.
///
/// Pass this to such a screen's `AppBar.leading`: `null` (Flutter's own
/// automatic hamburger) when there's nothing to pop to — i.e. this
/// instance was reached directly from the drawer, not pushed — and a real
/// back button when there is, so the drawer is never broken on a
/// root-level visit but a pushed visit always gets a clear way back.
Widget? drawerAwareBackLeading(BuildContext context) {
  if (!Navigator.canPop(context)) return null;
  return BackButton(onPressed: () => Navigator.of(context).pop());
}
