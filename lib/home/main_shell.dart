import 'package:bumble/constants/app_colors.dart';
import 'package:bumble/controllers/profile_controller.dart';
import 'package:bumble/home/home_screen.dart';
import 'package:bumble/profile/profile_tab_screen.dart';
import 'package:bumble/screens/match_screen.dart';
import 'package:bumble/services/match_chat_service.dart';
import 'package:flutter/material.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  final List<Widget> _tabs = const [
    HomeScreen(),
    MatchChatScreen(),
    ProfileTabScreen(),
  ];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ProfileController.to.refreshLocationIfNeeded(force: true);
    });
  }

  void _selectTab(int index) {
    if (_index == index) return;

    setState(() {
      _index = index;
    });

    if (index == 1) {
      MatchChatService.notifyMatchesChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: List.generate(_tabs.length, (index) {
          final isSelected = _index == index;

          return Positioned.fill(
            child: IgnorePointer(
              ignoring: !isSelected,
              child: ExcludeSemantics(
                excluding: !isSelected,
                child: AnimatedOpacity(
                  opacity: isSelected ? 1 : 0,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  child: AnimatedSlide(
                    offset: isSelected ? Offset.zero : const Offset(0, 0.008),
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    child: _tabs[index],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
      bottomNavigationBar: _MeetchaBottomNavigation(
        selectedIndex: _index,
        onChanged: _selectTab,
      ),
    );
  }
}

class _MeetchaBottomNavigation extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const _MeetchaBottomNavigation({
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: Container(
        height: 72,
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.borderSoft),
          boxShadow: [
            BoxShadow(
              color: AppColors.ink.withValues(alpha: 0.065),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            const itemCount = 3;
            final itemWidth = constraints.maxWidth / itemCount;

            return Stack(
              children: [
                // Sliding selection pill
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutCubic,
                  left: itemWidth * selectedIndex,
                  top: 0,
                  bottom: 0,
                  width: itemWidth,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.matchaSoft.withValues(alpha: 0.78),
                        borderRadius: BorderRadius.circular(17),
                      ),
                    ),
                  ),
                ),

                // Fixed navigation items
                Row(
                  children: [
                    Expanded(
                      child: _NavigationItem(
                        icon: Icons.local_cafe_outlined,
                        selectedIcon: Icons.local_cafe_rounded,
                        label: 'Brew',
                        selected: selectedIndex == 0,
                        onTap: () => onChanged(0),
                      ),
                    ),
                    Expanded(
                      child: _NavigationItem(
                        icon: Icons.favorite_border_rounded,
                        selectedIcon: Icons.favorite_rounded,
                        label: 'Match',
                        selected: selectedIndex == 1,
                        onTap: () => onChanged(1),
                      ),
                    ),
                    Expanded(
                      child: _NavigationItem(
                        icon: Icons.person_outline_rounded,
                        selectedIcon: Icons.person_rounded,
                        label: 'Profile',
                        selected: selectedIndex == 2,
                        onTap: () => onChanged(2),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _NavigationItem extends StatefulWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavigationItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_NavigationItem> createState() => _NavigationItemState();
}

class _NavigationItemState extends State<_NavigationItem> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;

    setState(() {
      _pressed = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapCancel: () => _setPressed(false),
      onTapUp: (_) => _setPressed(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: SizedBox.expand(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                scale: widget.selected ? 1.06 : 1,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeOutCubic,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(
                        scale: Tween<double>(
                          begin: 0.88,
                          end: 1,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: Icon(
                    widget.selected ? widget.selectedIcon : widget.icon,
                    key: ValueKey(widget.selected),
                    size: 21,
                    color: widget.selected
                        ? AppColors.matchaDeep
                        : AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 7),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                style: TextStyle(
                  color: widget.selected
                      ? AppColors.matchaDeep
                      : AppColors.textSecondary,
                  fontSize: 12.5,
                  height: 1,
                  fontWeight: widget.selected
                      ? FontWeight.w700
                      : FontWeight.w600,
                ),
                child: Text(widget.label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
