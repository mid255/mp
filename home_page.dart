import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'add_team_page.dart'; // Import the Add Team Page
import 'add_players_page.dart'; // Import the Add Players Page
import 'manage_team_page.dart'; // Import the Manage Team Page
import 'main.dart'; // Import the Login Page for logout functionality
import 'create_match_page.dart'; // Import the CreateMatchPage

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fantasy Cricket'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              // Logout and navigate back to the login page
              Supabase.instance.client.auth.signOut();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Create Match',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CreateMatchPage(),
                ),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Add Team'),
            Tab(text: 'Add Players'),
            Tab(text: 'Manage Team'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          const AddTeamPage(), // Add Team Page
          const AddPlayersPage(), // Add Players Page
          const ManageTeamPage(), // Manage Team Page
        ],
      ),
    );
  }
}
