import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import 'brand_strip.dart';

class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.title,
    required this.role,
    required this.body,
    required this.onBottomTap,
    required this.bottomIndex,
    this.junta = false,
    this.showBack = false,
    this.floatingActionButton,
  });

  final String title;
  final String role;
  final Widget body;
  final ValueChanged<int> onBottomTap;
  final int bottomIndex;
  final bool junta;
  final bool showBack;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    final items = junta
        ? const [
            BottomNavigationBarItem(icon: Icon(Icons.groups_outlined), activeIcon: Icon(Icons.groups), label: 'Junta'),
            BottomNavigationBarItem(icon: Icon(Icons.history_outlined), activeIcon: Icon(Icons.history), label: 'Historial'),
            BottomNavigationBarItem(icon: Icon(Icons.publish_outlined), activeIcon: Icon(Icons.publish), label: 'Publicar'),
            BottomNavigationBarItem(icon: Icon(Icons.manage_accounts_outlined), activeIcon: Icon(Icons.manage_accounts), label: 'Accesos'),
          ]
        : const [
            BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Inicio'),
            BottomNavigationBarItem(icon: Icon(Icons.work_outline), activeIcon: Icon(Icons.work), label: 'Oficios'),
            BottomNavigationBarItem(icon: Icon(Icons.assignment_outlined), activeIcon: Icon(Icons.assignment), label: 'Solicitudes'),
            BottomNavigationBarItem(icon: Icon(Icons.more_horiz), activeIcon: Icon(Icons.more_horiz), label: 'Más'),
          ];

    final windowWidth = MediaQuery.sizeOf(context).width;
    final shellWidth = windowWidth > 390 ? 390.0 : windowWidth;

    return ColoredBox(
      color: const Color(0xFFF3F6F4),
      child: Center(
        child: SizedBox(
          width: shellWidth,
          height: double.infinity,
          child: Scaffold(
            appBar: PreferredSize(
              preferredSize: const Size.fromHeight(62),
              child: AppBar(
                automaticallyImplyLeading: false,
                toolbarHeight: 62,
                titleSpacing: 8,
                title: Row(
                  children: [
                    const BrandStrip(),
                    const SizedBox(width: 6),
                    if (showBack)
                      SizedBox(
                        width: 34,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.chevron_left, size: 28),
                          tooltip: 'Volver',
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                      ),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        border: Border.all(color: junta ? AppColors.darkBlue : AppColors.primary),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        role,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: junta ? AppColors.darkBlue : AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            body: SafeArea(top: false, child: body),
            floatingActionButton: floatingActionButton,
            bottomNavigationBar: BottomNavigationBar(
              currentIndex: bottomIndex,
              onTap: onBottomTap,
              type: BottomNavigationBarType.fixed,
              selectedItemColor: AppColors.primary,
              unselectedItemColor: AppColors.muted,
              selectedFontSize: 12,
              unselectedFontSize: 12,
              items: items,
            ),
          ),
        ),
      ),
    );
  }
}
