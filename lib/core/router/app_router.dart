import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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

final appRouter = GoRouter(
  initialLocation: '/chat',
  routes: [
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(path: '/chat', builder: (c, s) => const ChatScreen()),
        GoRoute(path: '/voice', builder: (c, s) => const VoiceScreen()),
        GoRoute(path: '/agent', builder: (c, s) => const AgentScreen()),
        GoRoute(path: '/research', builder: (c, s) => const ResearchScreen()),
        GoRoute(path: '/workflow', builder: (c, s) => const WorkflowScreen()),
        GoRoute(path: '/knowledge', builder: (c, s) => const KnowledgeBaseScreen()),
        GoRoute(path: '/skills', builder: (c, s) => const SkillScreen()),
        GoRoute(path: '/models', builder: (c, s) => const ModelHubScreen()),
        GoRoute(path: '/memory', builder: (c, s) => const MemoryScreen()),
        GoRoute(path: '/settings', builder: (c, s) => const SettingsScreen()),
        GoRoute(path: '/study', builder: (c, s) => const StudyScreen()),
      ],
    ),
  ],
);

class AppShell extends StatelessWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  static const _tabs = [
    _TabItem(icon: Icons.chat_bubble_outline, label: 'Chat', path: '/chat'),
    _TabItem(icon: Icons.mic_none, label: 'Voice', path: '/voice'),
    _TabItem(icon: Icons.smart_toy_outlined, label: 'Agent', path: '/agent'),
    _TabItem(icon: Icons.search, label: 'Research', path: '/research'),
    _TabItem(icon: Icons.auto_stories_outlined, label: 'Knowledge', path: '/knowledge'),
    _TabItem(icon: Icons.settings_outlined, label: 'Settings', path: '/settings'),
  ];

  int _indexFromLocation(String location) {
    if (location.startsWith('/voice')) return 1;
    if (location.startsWith('/agent')) return 2;
    if (location.startsWith('/research')) return 3;
    if (location.startsWith('/knowledge')) return 4;
    if (location.startsWith('/settings') || location.startsWith('/models') || location.startsWith('/memory') || location.startsWith('/workflow') || location.startsWith('/study') || location.startsWith('/skills')) return 5;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final currentIndex = _indexFromLocation(location);

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (i) => context.go(_tabs[i].path),
        destinations: _tabs
            .map((t) => NavigationDestination(icon: Icon(t.icon), label: t.label))
            .toList(),
      ),
    );
  }
}

class _TabItem {
  final IconData icon;
  final String label;
  final String path;
  const _TabItem({required this.icon, required this.label, required this.path});
}
