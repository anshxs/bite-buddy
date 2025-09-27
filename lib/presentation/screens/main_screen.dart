import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'graph_screen.dart';
import 'settings_screen.dart';

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  
  Widget _getCurrentScreen() {
    switch (_currentIndex) {
      case 0:
        // Create a new HomeScreen instance each time to refresh data
        return HomeScreen();
      case 1:
        return GraphScreen();
      case 2:
        return SettingsScreen();
      default:
        return HomeScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _getCurrentScreen(),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color.fromARGB(255, 235, 235, 235),
        unselectedItemColor: Colors.grey,
        selectedItemColor: const Color.fromARGB(255, 0, 140, 255),
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Progress',
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