import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import 'drawer_aware_back_leading.dart';

/// `#mainNav` (`templates/base.html:88-101`,
/// `static/css/style.css:158-198`) — white/translucent bar with a
/// bottom border, the brand mark, and a hamburger menu (via
/// [AppNavDrawer]) on a root-level visit, or a real back button when this
/// screen was pushed on top of another one — see
/// [drawerAwareBackLeading]'s doc comment for why both can't come from
/// `Scaffold`'s own automatic leading-icon resolution alone. The web's own
/// navbar only expands into a horizontal row at `≥1200px`
/// (`navbar-expand-xl`, `style.css:224-278`) — every width this app
/// targets is already inside the web's own "collapsed" breakpoint, so a
/// hamburger-triggered drawer isn't an invented mobile pattern, it's the
/// web's actual behavior at this width, reproduced via [AppNavDrawer].
class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  const AppTopBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 0,
      shape: const Border(bottom: BorderSide(color: AppColors.border)),
      leading: drawerAwareBackLeading(context),
      titleSpacing: 0,
      title: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(6)),
            child: const Icon(Icons.school_outlined, color: Colors.white, size: 19),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text.rich(
            TextSpan(
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
              children: const [
                TextSpan(text: 'Career '),
                TextSpan(text: 'Buddy', style: TextStyle(color: AppColors.accent)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
