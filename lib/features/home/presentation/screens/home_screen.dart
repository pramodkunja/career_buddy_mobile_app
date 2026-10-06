import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../../shared/widgets/app_footer.dart';
import '../../../../shared/widgets/app_nav_drawer.dart';
import '../../../../shared/widgets/app_top_bar.dart';
import '../../../../shared/widgets/buddy_chatbot_overlay.dart';
import '../widgets/authenticated_home_body.dart';
import '../widgets/public_home_body.dart';

/// W024 — Home (`templates/home.html`, `activities/views.py:76 home()`).
/// A [Scaffold] wired with the shared global shell
/// ([AppTopBar]/[AppNavDrawer]/[AppFooter]/[BuddyChatbotOverlay]) around
/// a body that branches on [authControllerProvider] exactly like the web
/// template's own `{% if not user.is_authenticated %}` branch
/// (`home.html:1185`).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final user = authState is AuthAuthenticated ? authState.user : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppTopBar(),
      drawer: const AppNavDrawer(),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                if (user != null)
                  AuthenticatedHomeBody(
                    isEmployer: user.isEmployer,
                    onParseResume: () => context.push(RoutePaths.resumeBuilder),
                    onDashboard: () => context.go(RoutePaths.dashboard),
                    onBrowseActivities: () => context.push(RoutePaths.activities),
                    onEmployerDashboard: () => context.go(RoutePaths.employerDashboard),
                    onFindCandidates: () => context.push(RoutePaths.employerSearchCandidates),
                  )
                else
                  PublicHomeBody(
                    onLogin: () => context.go(RoutePaths.login),
                    onRegister: () => context.push(RoutePaths.register),
                    onEmployerLogin: () => context.push(RoutePaths.employerLogin),
                    onEmployerRegister: () => context.push(RoutePaths.employerRegister),
                  ),
                const AppFooter(),
              ],
            ),
          ),
          const BuddyChatbotOverlay(),
        ],
      ),
    );
  }
}
