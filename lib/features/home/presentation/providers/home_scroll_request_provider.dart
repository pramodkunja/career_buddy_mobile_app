import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Phase 71 — the real site's nav menu ("About Us", "Industries", the
/// Resources submenu's "Tutorials: How CareerBuddy Works") links to
/// same-page anchor fragments on the landing page
/// (`{% url 'home' %}#why`/`#choose-path`/`#videos`,
/// `templates/includes/site_nav.html:206,240`, Resources item 4) rather
/// than separate screens. [HomeScreen] already renders each of these
/// sections (`HomeAboutSection`/`HomeChoosePath`/`HomeTutorialsSection`,
/// all inside [PublicHomeBody]) — what's missing is a way for a tap on
/// [AppNavDrawer], a widget mounted on every screen, to tell an
/// already-or-not-yet-mounted [HomeScreen] which section to scroll to.
///
/// Mirrors [BuddyOverlayOpenRequestController]'s own established pattern
/// in this codebase exactly (`buddy_chatbot_overlay.dart`): a tiny
/// `Notifier` the requester writes to and the one consumer reads/listens
/// to, rather than threading a scroll target through route `extra` (which
/// would only cover the "navigating in from elsewhere" case, not "already
/// on Home, tap a different anchor").
enum HomeScrollTarget { about, choosePath, tutorials, contact }

class HomeScrollRequestController extends Notifier<HomeScrollTarget?> {
  @override
  HomeScrollTarget? build() => null;

  void request(HomeScrollTarget target) => state = target;

  void clear() => state = null;
}

final homeScrollRequestProvider =
    NotifierProvider<HomeScrollRequestController, HomeScrollTarget?>(
      HomeScrollRequestController.new,
    );
