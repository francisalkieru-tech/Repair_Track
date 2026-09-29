import 'package:flutter/material.dart';
import 'admin_theme.dart';
import 'dashboard_screen.dart';
import 'requests_screen.dart';
import 'completed_screen.dart';
import 'technicians_screen.dart';
import 'schedule_screen.dart';
import 'settings_screen.dart';
import '../../widget/tech_chat.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;

  static const _sections = [
    _NavItem('Dashboard', Icons.dashboard_rounded),
    _NavItem('Repair Request', Icons.assignment_rounded),
    _NavItem('Completed', Icons.check_circle_outline_rounded),
    _NavItem('Technicians', Icons.engineering_rounded),
    _NavItem('Schedule', Icons.calendar_month_rounded),
  ];

  static const _settingsItem = _NavItem('Settings', Icons.settings_rounded);
  static const _settingsIndex = 5;

  static const _allSections = [..._sections, _settingsItem];

  List<Widget> get _pages => [
        DashboardScreen(
          onNavigate: (i) => setState(() => _selectedIndex = i),
        ),
        const RequestsScreen(),
        const CompletedScreen(),
        const TechniciansScreen(),
        const ScheduleScreen(),
        const SettingsScreen(),
      ];

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: kAdminBg,
      body: Stack(
        children: [
          SafeArea(
            child: isWide
                ? Row(
                    children: [
                      _SideNav(
                        items: _sections,
                        settingsItem: _settingsItem,
                        settingsIndex: _settingsIndex,
                        selectedIndex: _selectedIndex,
                        onSelect: (i) => setState(() => _selectedIndex = i),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            AdminTopBar(
                              title: _allSections[_selectedIndex].label,
                              onAvatarTap: () => setState(
                                  () => _selectedIndex = _settingsIndex),
                            ),
                            Expanded(child: _pages[_selectedIndex]),
                          ],
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      AdminTopBar(
                        title: _allSections[_selectedIndex].label,
                        onAvatarTap: () =>
                            setState(() => _selectedIndex = _settingsIndex),
                      ),
                      Expanded(child: _pages[_selectedIndex]),
                    ],
                  ),
          ),
          // Floating chat bubble,
          const AdminChatBubble(),
        ],
      ),
      bottomNavigationBar: isWide
          ? null
          : NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (i) => setState(() => _selectedIndex = i),
              backgroundColor: Colors.white,
              indicatorColor: Colors.black,
              height: 64,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              destinations: _allSections
                  .map(
                    (s) => NavigationDestination(
                      icon: Icon(s.icon, color: kAdminTextGray),
                      selectedIcon: Icon(s.icon, color: Colors.white),
                      label: s.label,
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  const _NavItem(this.label, this.icon);
}

class _SideNav extends StatelessWidget {
  final List<_NavItem> items;
  final _NavItem settingsItem;
  final int settingsIndex;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const _SideNav({
    required this.items,
    required this.settingsItem,
    required this.settingsIndex,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.black,
                  child: Icon(Icons.build_rounded,
                      color: Colors.white, size: 16),
                ),
                SizedBox(width: 8),
                Text(
                  'RepairTrack',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Column(
              children: List.generate(items.length, (index) {
                final item = items[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: _NavTile(
                    item: item,
                    selected: index == selectedIndex,
                    onTap: () => onSelect(index),
                  ),
                );
              }),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Divider(height: 1, color: kAdminCardBorder),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 16, 10, 16),
            child: _NavTile(
              item: settingsItem,
              selected: selectedIndex == settingsIndex,
              onTap: () => onSelect(settingsIndex),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  const _NavTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Colors.black : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Icon(
                item.icon,
                size: 20,
                color: selected ? Colors.white : kAdminTextGray,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected ? Colors.white : kAdminTextDark,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}