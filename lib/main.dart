import 'package:flutter/material.dart';

void main() {
  runApp(const PadelXApp());
}

class PadelXApp extends StatelessWidget {
  const PadelXApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PadelX',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    Padding(
  padding: EdgeInsets.all(20),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Ready to play?',
        style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
      ),
      SizedBox(height: 8),
      Text(
        'Find players and fill your next padel match.',
        style: TextStyle(fontSize: 16, color: Colors.white70),
      ),
      SizedBox(height: 24),
      Card(
        child: ListTile(
          leading: Icon(Icons.add_circle_outline),
          title: Text('Create a match'),
          subtitle: Text('Set time, place, and level'),
        ),
      ),
      Card(
        child: ListTile(
          leading: Icon(Icons.search),
          title: Text('Find open matches'),
          subtitle: Text('Join games near you'),
        ),
      ),
    ],
  ),
),
    Padding(
  padding: EdgeInsets.all(20),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Open matches',
        style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
      ),
      SizedBox(height: 8),
      Text(
        'Join games that need players.',
        style: TextStyle(fontSize: 16, color: Colors.white70),
      ),
      SizedBox(height: 24),
      Card(
  child: ListTile(
    onTap: () {
      debugPrint('Match tapped');
    },
    leading: Icon(Icons.sports_tennis),
    title: Text('Today · 7:00 PM'),
    subtitle: Text('Club Padel MX · Level 3–4 · 1 spot left'),
    trailing: Icon(Icons.arrow_forward_ios),
  ),
),

Card(
  child: ListTile(
    onTap: () {
      debugPrint('Match tapped');
    },
    leading: Icon(Icons.sports_tennis),
    title: Text('Tomorrow · 8:30 AM'),
    subtitle: Text('Padel Center · Level 2–3 · 2 spots left'),
    trailing: Icon(Icons.arrow_forward_ios),
  ),
),
    ],
  ),
),
    Center(child: Text('Profile 👤', style: TextStyle(fontSize: 24))),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PadelX 🎾'),
        centerTitle: true,
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.sports_tennis),
            label: 'Matches',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}