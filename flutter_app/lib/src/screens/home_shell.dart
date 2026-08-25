import 'package:flutter/material.dart';

import '../models/torbox_models.dart';
import '../services/app_settings_repository.dart';
import '../theme/app_colors.dart';
import '../theme/layout_options.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'profile_screen.dart';
import 'search_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;
  AppSettings _settings = const AppSettings();
  final AppSettingsRepository _settingsRepository = AppSettingsRepository();

  @override
  void initState() {
    super.initState();
    AppSettingsRepository.settingsNotifier.addListener(_syncSettings);
    _loadSettings();
  }

  @override
  void dispose() {
    AppSettingsRepository.settingsNotifier.removeListener(_syncSettings);
    super.dispose();
  }

  void _syncSettings() {
    if (!mounted) {
      return;
    }
    setState(() {
      _settings = AppSettingsRepository.settingsNotifier.value;
    });
  }

  Future<void> _loadSettings() async {
    final AppSettings settings = await _settingsRepository.loadSettings();
    if (!mounted) {
      return;
    }
    setState(() {
      _settings = settings;
    });
  }

  @override
  Widget build(BuildContext context) {
    final Color accent = LayoutOptions.accentFor(_settings);
    final List<_ShellTab> tabs = <_ShellTab>[
      _ShellTab(
        label: 'Home',
        icon: Icons.home_outlined,
        activeIcon: Icons.home,
        builder: (_) => HomeScreen(
          settingsRepository: _settingsRepository,
          onSettingsChanged: _loadSettings,
        ),
      ),
      _ShellTab(
        label: 'Search',
        icon: Icons.search_outlined,
        activeIcon: Icons.search,
        builder: (_) => const SearchScreen(),
      ),
      _ShellTab(
        label: 'Library',
        icon: Icons.favorite_border,
        activeIcon: Icons.favorite,
        builder: (_) => LibraryScreen(),
      ),
      _ShellTab(
        label: 'Settings',
        icon: Icons.settings_outlined,
        activeIcon: Icons.settings_rounded,
        builder: (_) => ProfileScreen(showBackButton: false),
      ),
    ];

    return Scaffold(
      extendBody: false,
      backgroundColor: LayoutOptions.backgroundFor(_settings),
      body: tabs[_currentIndex].builder(context),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          height: 78,
          decoration: BoxDecoration(
            color: LayoutOptions.backgroundFor(_settings),
            border: Border(
              top: BorderSide(color: Colors.white.withOpacity(0.10)),
            ),
          ),
          child: Row(
            children: List<Widget>.generate(tabs.length, (int index) {
              final _ShellTab tab = tabs[index];
              final bool selected = index == _currentIndex;
              return Expanded(
                child: _OmnioNavItem(
                  label: tab.label,
                  icon: selected ? tab.activeIcon : tab.icon,
                  selected: selected,
                  accent: accent,
                  onTap: () {
                    setState(() {
                      _currentIndex = index;
                    });
                    _loadSettings();
                  },
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _OmnioNavItem extends StatelessWidget {
  const _OmnioNavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 7),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              width: selected ? 54 : 42,
              height: selected ? 30 : 28,
              decoration: BoxDecoration(
                color: selected ? accent : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Icon(
                icon,
                size: selected ? 21 : 22,
                color: selected ? AppColors.background : AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: selected ? AppColors.text : AppColors.textMuted,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShellTab {
  const _ShellTab({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.builder,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final WidgetBuilder builder;
}
