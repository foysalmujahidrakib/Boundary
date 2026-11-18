import 'package:firebase_auth/firebase_auth.dart';

import '../../app_services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui.dart';
import 'brand_logo.dart';
import 'responsive.dart';

/// The frame of every signed-in screen: top bar with the brand and an
/// account menu (`.dash-topbar`), and a width-limited scrolling body.
class WorkspaceScaffold extends StatelessWidget {
  const WorkspaceScaffold({
    super.key,
    required this.user,
    required this.children,
    this.onRefresh,
  });

  final User user;

  /// The page content, laid out as a vertical list.
  final List<Widget> children;

  /// When set, pulling down on the page calls this.
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final list = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        ContentWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: const BrandLogo(size: 19),
        actions: [
          AccountMenu(user: user),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: onRefresh == null
            ? list
            : RefreshIndicator(onRefresh: onRefresh!, child: list),
      ),
    );
  }
}

/// Avatar button with the signed-in email and a sign-out action.
class AccountMenu extends StatelessWidget {
  const AccountMenu({super.key, required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    final label = (user.displayName?.isNotEmpty ?? false)
        ? user.displayName!
        : (user.email ?? 'Account');
    final initial = label.isEmpty ? '?' : label.substring(0, 1).toUpperCase();

    return PopupMenuButton<String>(
      tooltip: 'Account',
      offset: const Offset(0, 44),
      onSelected: (value) {
        if (value == 'signout') {
          AppScope.of(context).auth.signOut();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Text(user.email ?? label, style: AppText.muted(size: 12)),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'signout',
          child: Row(
            children: [
              Icon(Icons.logout, size: 18),
              SizedBox(width: 10),
              Text('Sign out'),
            ],
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: CircleAvatar(
          radius: 16,
          backgroundColor: AppColors.mint,
          child: Text(
            initial,
            style: AppText.heading(size: 14, color: AppColors.onMint),
          ),
        ),
      ),
    );
  }
}
