import 'package:flutter/material.dart';

import 'package:vidasaludable/pantallas/ajustes/settings_screen.dart';
import 'package:vidasaludable/pantallas/inicio/presentation_screen.dart';

class MagazineHomeScreen extends StatefulWidget {
  const MagazineHomeScreen({super.key});
  @override
  State<MagazineHomeScreen> createState() => _MagazineHomeScreenState();
}

class _MagazineHomeScreenState extends State<MagazineHomeScreen>
    with SingleTickerProviderStateMixin {
  static const Color _yellow = Color(0xFFFFEB3B);
  static const Color _black = Color(0xFF111111);
  static const Color _white = Colors.white;
  static const AssetImage _heroImageProvider = AssetImage(
    'assets/WhatsApp Image 2026-03-02 at 9.13.49 AM (1).jpeg',
  );
  late final TabController _tabs;
  int _bottomIndex = 0;
  final PageController _heroController = PageController();
  Color _seed = _yellow;
  Brightness _brightness = Brightness.light;
  String? _fontFamily;
  bool _followLocation = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(_heroImageProvider, context);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _heroController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                color: _yellow,
                child: Row(
                  children: [
                    const SizedBox.shrink(),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(
                                builder: (_) => const HomeTabs(initialIndex: 0),
                              ),
                              (route) => false,
                            );
                          },
                          style: TextButton.styleFrom(foregroundColor: _black),
                          child: const Text(
                            'Cerrar sesión',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: const [
                    ListTile(title: Text('QWERTY')),
                    ListTile(title: Text('ASDFG')),
                    ListTile(title: Text('ZXCVB')),
                    ListTile(title: Text('PLMKO')),
                    ListTile(title: Text('NJIUH')),
                    ListTile(title: Text('YTRSA')),
                    ListTile(title: Text('GHJKL')),
                    ListTile(title: Text('CVBNM')),
                    ListTile(title: Text('POIUY')),
                    ListTile(title: Text('LKJHG')),
                    ListTile(title: Text('MNBVC')),
                    Divider(),
                    ListTile(title: Text('TREWQ')),
                    ListTile(title: Text('DFGHJ')),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      appBar: AppBar(
        backgroundColor: _white,
        foregroundColor: _black,
        elevation: 0,
        titleSpacing: 0,
        title: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            'Vitu',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
        ),
        actions: const [SizedBox(width: 8)],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE0E0E0))),
            ),
            child: TabBar(
              controller: _tabs,
              isScrollable: true,
              labelColor: _black,
              unselectedLabelColor: Colors.grey,
              indicatorColor: _black,
              tabs: const [
                Tab(text: 'HOME'),
                Tab(text: 'CULTURE'),
                Tab(text: 'SCIENCE'),
                Tab(text: 'SOCIETY'),
                Tab(text: 'ECONOMY'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: List.generate(
          5,
          (i) => _HomeContent(controller: _heroController),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _bottomIndex,
        onTap: (i) async {
          if (i == 4) {
            final result = await Navigator.of(context).push<SettingsData>(
              MaterialPageRoute(
                builder: (_) => SettingsScreen(
                  brightness: _brightness,
                  seed: _seed,
                  fontFamily: _fontFamily,
                  followLocation: _followLocation,
                ),
              ),
            );
            if (!mounted) return;
            if (result != null) {
              setState(() {
                _brightness = result.brightness;
                _seed = result.seed;
                _fontFamily = result.fontFamily;
                _followLocation = result.followLocation;
              });
            }
          } else {
            setState(() => _bottomIndex = i);
          }
        },
        selectedItemColor: _seed,
        unselectedItemColor: Colors.grey.shade600,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bookmark_border),
            label: 'Saved',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications_none),
            label: 'Alerts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            label: 'Chat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class _HomeContent extends StatelessWidget {
  final PageController controller;
  const _HomeContent({required this.controller});
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        const SizedBox(height: 12),
        SizedBox(
          height: 220,
          child: PageView.builder(
            controller: controller,
            itemCount: 3,
            itemBuilder: (context, index) {
              return Container(
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  image: const DecorationImage(
                    image: _MagazineHomeScreenState._heroImageProvider,
                    fit: BoxFit.cover,
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.55),
                        Colors.black.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.all(16),
                  alignment: Alignment.bottomLeft,
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SOCIETY',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Glued to your phone? Generation Z\'s smartphone addiction',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
