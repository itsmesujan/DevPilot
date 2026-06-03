import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../features/chat/chat_screen.dart';
import '../../features/voice/voice_screen.dart';
import '../../features/agent/agent_screen.dart';
import '../../features/research/research_screen.dart';
import '../../features/workflow/workflow_screen.dart';
import '../../features/model_hub/model_hub_screen.dart';
import '../../features/memory/memory_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/study/study_screen.dart';
import '../../features/knowledge/knowledge_base_screen.dart';
import '../../features/skills/skill_screen.dart';
import '../../features/agent/council_screen.dart';
import '../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Router
// ─────────────────────────────────────────────────────────────────────────────

final appRouter = GoRouter(
  initialLocation: '/chat',
  routes: [
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(path: '/chat', builder: (c, s) => const ChatScreen()),
        GoRoute(path: '/agent', builder: (c, s) => const AgentScreen()),
        GoRoute(path: '/research', builder: (c, s) => const ResearchScreen()),
        GoRoute(path: '/voice', builder: (c, s) => const VoiceScreen()),
        GoRoute(path: '/knowledge', builder: (c, s) => const KnowledgeBaseScreen()),
        GoRoute(path: '/skills', builder: (c, s) => const SkillScreen()),
        GoRoute(path: '/council', builder: (c, s) => const CouncilScreen()),
        GoRoute(path: '/workflow', builder: (c, s) => const WorkflowScreen()),
        GoRoute(path: '/models', builder: (c, s) => const ModelHubScreen()),
        GoRoute(path: '/memory', builder: (c, s) => const MemoryScreen()),
        GoRoute(path: '/settings', builder: (c, s) => const SettingsScreen()),
        GoRoute(path: '/study', builder: (c, s) => const StudyScreen()),
      ],
    ),
  ],
);

// ─────────────────────────────────────────────────────────────────────────────
// App Shell — Main navigation container
// ─────────────────────────────────────────────────────────────────────────────

class AppShell extends StatelessWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  static const _navItems = [
    _NavItem(icon: Icons.chat_bubble_outline_rounded, activeIcon: Icons.chat_bubble_rounded, label: 'Chat', path: '/chat'),
    _NavItem(icon: Icons.smart_toy_outlined, activeIcon: Icons.smart_toy_rounded, label: 'Agent', path: '/agent'),
    _NavItem(icon: Icons.travel_explore_outlined, activeIcon: Icons.travel_explore, label: 'Research', path: '/research'),
    _NavItem(icon: Icons.mic_none_rounded, activeIcon: Icons.mic_rounded, label: 'Voice', path: '/voice'),
    _NavItem(icon: Icons.grid_view_outlined, activeIcon: Icons.grid_view_rounded, label: 'More', path: ''),
  ];

  int _indexFromLocation(String location) {
    if (location.startsWith('/agent') || location.startsWith('/council')) return 1;
    if (location.startsWith('/research')) return 2;
    if (location.startsWith('/voice')) return 3;
    if (_isSecondaryRoute(location)) return 4;
    return 0;
  }

  bool _isSecondaryRoute(String location) {
    return location.startsWith('/knowledge') ||
        location.startsWith('/skills') ||
        location.startsWith('/workflow') ||
        location.startsWith('/models') ||
        location.startsWith('/memory') ||
        location.startsWith('/settings') ||
        location.startsWith('/study');
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final currentIndex = _indexFromLocation(location);

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: child,
      bottomNavigationBar: _AppBottomNav(
        currentIndex: currentIndex,
        items: _navItems,
        onTap: (index) {
          if (index == 4) {
            Scaffold.of(context).openDrawer();
          } else {
            context.go(_navItems[index].path);
          }
        },
      ),
      drawer: _AppDrawer(currentLocation: location),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom Bottom Navigation Bar
// ─────────────────────────────────────────────────────────────────────────────

class _AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final List<_NavItem> items;
  final ValueChanged<int> onTap;

  const _AppBottomNav({
    required this.currentIndex,
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        border: const Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(items.length, (index) {
              final item = items[index];
              final isSelected = currentIndex == index;
              return Expanded(
                child: _NavTile(
                  item: item,
                  isSelected: isSelected,
                  onTap: () => onTap(index),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final _NavItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavTile({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
              decoration: BoxDecoration(
                gradient: isSelected ? AppGradients.brand : null,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                isSelected ? item.activeIcon : item.icon,
                color: isSelected ? Colors.white : AppColors.textMuted,
                size: 22,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              item.label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? AppColors.primary : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Side Drawer
// ─────────────────────────────────────────────────────────────────────────────

class _AppDrawer extends StatelessWidget {
  final String currentLocation;
  const _AppDrawer({required this.currentLocation});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: 300,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: AppGradients.brand,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('DevPilot Edge',
                          style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary)),
                      Text('AI Ecosystem',
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              color: AppColors.textMuted)),
                    ],
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Divider(color: AppColors.border),
            ),
            const SizedBox(height: 8),

            // Section: Intelligence
            _DrawerSection(
              title: 'Intelligence',
              items: [
                _DrawerItem(icon: Icons.psychology_outlined, label: 'Custom Skills', path: '/skills', currentPath: currentLocation),
                _DrawerItem(icon: Icons.groups_outlined, label: 'Agent Council', path: '/council', currentPath: currentLocation),
                _DrawerItem(icon: Icons.account_tree_outlined, label: 'Workflows', path: '/workflow', currentPath: currentLocation),
              ],
            ),

            const SizedBox(height: 8),

            // Section: Knowledge
            _DrawerSection(
              title: 'Knowledge',
              items: [
                _DrawerItem(icon: Icons.auto_stories_outlined, label: 'Knowledge Base', path: '/knowledge', currentPath: currentLocation),
                _DrawerItem(icon: Icons.memory_outlined, label: 'Memory', path: '/memory', currentPath: currentLocation),
                _DrawerItem(icon: Icons.school_outlined, label: 'Study Mode', path: '/study', currentPath: currentLocation),
              ],
            ),

            const SizedBox(height: 8),

            // Section: System
            _DrawerSection(
              title: 'System',
              items: [
                _DrawerItem(icon: Icons.model_training_outlined, label: 'Local Models', path: '/models', currentPath: currentLocation),
                _DrawerItem(icon: Icons.settings_outlined, label: 'Settings', path: '/settings', currentPath: currentLocation),
              ],
            ),

            const Spacer(),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Divider(color: AppColors.border),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'DevPilot Edge v1.0.0\nCognitive AI Ecosystem',
                style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerSection extends StatelessWidget {
  final String title;
  final List<_DrawerItem> items;

  const _DrawerSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
          child: Text(
            title.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
              letterSpacing: 1.2,
            ),
          ),
        ),
        ...items,
      ],
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String path;
  final String currentPath;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.path,
    required this.currentPath,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = currentPath.startsWith(path);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: ListTile(
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        tileColor: isSelected ? AppColors.primary.withAlpha(20) : null,
        leading: Icon(
          icon,
          size: 20,
          color: isSelected ? AppColors.primary : AppColors.textSecondary,
        ),
        title: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? AppColors.primary : AppColors.textPrimary,
          ),
        ),
        onTap: () {
          Navigator.of(context).pop(); // close drawer
          context.go(path);
        },
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String path;
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.path,
  });
}
