import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/vpn_provider.dart';
import '../theme/colors.dart';
import '../widgets/steam_gauge.dart';
import 'dashboard_screen.dart';
import 'peers_screen.dart';
import 'controls_screen.dart';
import 'logs_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  static const _screens = [
    DashboardScreen(),
    PeersScreen(),
    ControlsScreen(),
    LogsScreen(),
    SettingsScreen(),
  ];

  static const _navItems = [
    NavigationRailDestination(
      icon: Icon(Icons.dashboard_outlined),
      selectedIcon: Icon(Icons.dashboard),
      label: Text('STATUS'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.people_outline),
      selectedIcon: Icon(Icons.people),
      label: Text('PEERS'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.settings_outlined),
      selectedIcon: Icon(Icons.settings),
      label: Text('CONTROLS'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.terminal_outlined),
      selectedIcon: Icon(Icons.terminal),
      label: Text('LOGS'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.tune_outlined),
      selectedIcon: Icon(Icons.tune),
      label: Text('CONFIG'),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 600;
    final prov = context.watch<VpnProvider>();
    final online = prov.status?.isReachable ?? false;

    if (isWide) {
      // Desktop: side navigation rail
      return Scaffold(
        body: Row(
          children: [
            _buildSideRail(online, prov),
            const VerticalDivider(width: 1, color: kBorder),
            Expanded(child: _screens[_selectedIndex]),
          ],
        ),
      );
    } else {
      // Mobile: bottom navigation bar
      return Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              GearSpinner(size: 20, color: online ? kGreenOn : kParchDim),
              const SizedBox(width: 10),
              Text(
                'VPN COMMANDER',
                style: GoogleFonts.cinzel(
                  fontSize: 14,
                  color: kBrassLight,
                  letterSpacing: 3,
                ),
              ),
            ],
          ),
        ),
        body: _screens[_selectedIndex],
        bottomNavigationBar: _buildBottomNav(online),
      );
    }
  }

  Widget _buildSideRail(bool online, VpnProvider prov) {
    return Container(
      color: kBgDark,
      child: Column(
        children: [
          // Logo area
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: kBorder)),
            ),
            child: Column(
              children: [
                GearSpinner(
                  size: 36,
                  color: online ? kGreenOn : kBrassDark,
                ),
                const SizedBox(height: 8),
                Text(
                  'VPN',
                  style: TextStyle(
                    color: kBrassLight,
                    fontSize: 10,
                    letterSpacing: 3,
                    fontFamily: 'Cinzel',
                  ),
                ),
                Text(
                  'COMMANDER',
                  style: TextStyle(
                    color: kBrass,
                    fontSize: 8,
                    letterSpacing: 2,
                    fontFamily: 'Cinzel',
                  ),
                ),
              ],
            ),
          ),

          // Connection dot
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: online ? kGreenOn : kRedOn,
                    boxShadow: [
                      BoxShadow(
                        color: (online ? kGreenOn : kRedOn).withOpacity(0.5),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  online ? 'ONLINE' : 'OFFLINE',
                  style: TextStyle(
                    color: online ? kGreenOn : kRedOn,
                    fontSize: 8,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),

          // Nav rail
          Expanded(
            child: NavigationRail(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (i) => setState(() => _selectedIndex = i),
              destinations: _navItems,
              labelType: NavigationRailLabelType.all,
              groupAlignment: -1,
            ),
          ),

          // Version footer
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'v1.0.0',
              style: const TextStyle(color: kParchDim, fontSize: 9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav(bool online) {
    return Container(
      decoration: const BoxDecoration(
        color: kBgDark,
        border: Border(top: BorderSide(color: kBorder)),
      ),
      child: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        backgroundColor: kBgDark,
        selectedItemColor: kBrassLight,
        unselectedItemColor: kParchDim,
        type: BottomNavigationBarType.fixed,
        selectedFontSize: 9,
        unselectedFontSize: 9,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard, size: 20), label: 'Status'),
          BottomNavigationBarItem(icon: Icon(Icons.people, size: 20), label: 'Peers'),
          BottomNavigationBarItem(icon: Icon(Icons.settings, size: 20), label: 'Controls'),
          BottomNavigationBarItem(icon: Icon(Icons.terminal, size: 20), label: 'Logs'),
          BottomNavigationBarItem(icon: Icon(Icons.tune, size: 20), label: 'Config'),
        ],
      ),
    );
  }
}
