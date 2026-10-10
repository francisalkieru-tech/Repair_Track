import 'package:flutter/material.dart';
import 'admin_theme.dart';
import 'dashboard_screen.dart';
import 'requests_screen.dart';
import 'completed_screen.dart';
import 'technicians_screen.dart';
import 'schedule_screen.dart';
import 'activity_screen.dart';
import 'settings_screen.dart';
import '../../widget/tech_chat.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;
  int _requestsTab = 0; // tab the Repair Request page opens on

  // Go to a page; [tab] only matters for Repair Request (0 New, 1 Accepted,
  // 2 In Process). Normal menu taps always open its first tab.
  void _goTo(int index, {int tab = 0}) => setState(() {
        _selectedIndex = index;
        _requestsTab = tab;
      });

  // From a notification: open the page/tab that holds a request by its status.
  void _openRequestByStatus(String status) {
    switch (status) {
      case 'Pending':
        _goTo(1, tab: 0);
      case 'Accepted':
        _goTo(1, tab: 1);
      case 'Completed':
        _goTo(2);
      case 'Declined':
        _goTo(5);
      default:
        _goTo(1, tab: 2); // In Process, Waiting for Parts, Pending Review...
    }
  }

  static const _sections = [
    _NavItem('Dashboard', Icons.dashboard_rounded),
    _NavItem('Repair Request', Icons.assignment_rounded),
    _NavItem('Completed', Icons.check_circle_outline_rounded),
    _NavItem('Technicians', Icons.engineering_rounded),
    _NavItem('Schedule', Icons.calendar_month_rounded),
    _NavItem('Activity', Icons.history_rounded),
  ];

  static const _settingsItem = _NavItem('Settings', Icons.settings_rounded);
  static const _settingsIndex = 6;

  static const _allSections = [..._sections, _settingsItem];

  // Phones: 7 tabs don't fit in one bottom bar, so show the 4 most-used pages
  // and tuck the rest (Completed, Activity, Settings) under "More".
  static const _mobilePrimary = [0, 1, 3, 4];
  static const _mobileLabels = {
    0: 'Dashboard',
    1: 'Requests',
    3: 'Technicians',
    4: 'Schedule',
  };
  static const _moreIndexes = [2, 5, 6];

  Future<void> _showMoreSheet() async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: kAdminCardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              for (final i in _moreIndexes)
                ListTile(
                  leading: Icon(_allSections[i].icon,
                      color: i == _selectedIndex
                          ? Colors.black
                          : kAdminTextGray),
                  title: Text(
                    _allSections[i].label,
                    style: TextStyle(
                      fontWeight: i == _selectedIndex
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: kAdminTextDark,
                    ),
                  ),
                  trailing: i == _selectedIndex
                      ? const Icon(Icons.check, size: 18)
                      : null,
                  onTap: () => Navigator.pop(ctx, i),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked != null && mounted) _goTo(picked);
  }

  List<Widget> get _pages => [
        DashboardScreen(
          onNavigate: (i) => _goTo(i),
          // Active Jobs card → straight to the In Process tab
          onOpenRequestsTab: (tab) => _goTo(1, tab: tab),
        ),
        RequestsScreen(
          key: ValueKey('requests-$_requestsTab'),
          initialTab: _requestsTab,
        ),
        const CompletedScreen(),
        const TechniciansScreen(),
        const ScheduleScreen(),
        const ActivityScreen(),
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
                        onSelect: (i) => _goTo(i),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            AdminTopBar(
                              title: _allSections[_selectedIndex].label,
                              onAvatarTap: () => setState(
                                  () => _selectedIndex = _settingsIndex),
                              onOpenRequest: _openRequestByStatus,
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
                        onOpenRequest: _openRequestByStatus,
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
              selectedIndex: _mobilePrimary.contains(_selectedIndex)
                  ? _mobilePrimary.indexOf(_selectedIndex)
                  : _mobilePrimary.length, // "More" is highlighted
              onDestinationSelected: (i) {
                if (i < _mobilePrimary.length) {
                  _goTo(_mobilePrimary[i]);
                } else {
                  _showMoreSheet();
                }
              },
              backgroundColor: Colors.white,
              indicatorColor: Colors.black,
              height: 64,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              destinations: [
                for (final i in _mobilePrimary)
                  NavigationDestination(
                    icon: Icon(_allSections[i].icon, color: kAdminTextGray),
                    selectedIcon:
                        Icon(_allSections[i].icon, color: Colors.white),
                    label: _mobileLabels[i]!,
                  ),
                const NavigationDestination(
                  icon: Icon(Icons.more_horiz_rounded, color: kAdminTextGray),
                  selectedIcon:
                      Icon(Icons.more_horiz_rounded, color: Colors.white),
                  label: 'More',
                ),
              ],
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