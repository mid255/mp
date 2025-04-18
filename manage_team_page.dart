import 'package:flutter/material.dart';
import 'package:login/team_details_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'add_players_page.dart';

class ManageTeamPage extends StatefulWidget {
  const ManageTeamPage({Key? key}) : super(key: key);

  @override
  _ManageTeamPageState createState() => _ManageTeamPageState();
}

class _ManageTeamPageState extends State<ManageTeamPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _teams = [];
  List<Map<String, dynamic>> _players = [];
  String? _selectedTeamId;
  bool _isLoadingTeams = true;
  bool _isLoadingPlayers = false;

  @override
  void initState() {
    super.initState();
    _fetchTeams();
  }

  Future<void> _fetchTeams() async {
    try {
      final response =
          await supabase.from('teams').select('id, name').execute();

      if (response.status == 200 && response.data != null) {
        setState(() {
          _teams = List<Map<String, dynamic>>.from(response.data);
          _isLoadingTeams = false;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Failed to fetch teams: ${response.error?.message}')),
        );
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('An unexpected error occurred while fetching teams.')),
      );
    }
  }

  Future<void> _fetchPlayers(String teamId) async {
    setState(() {
      _isLoadingPlayers = true;
    });

    try {
      final response = await supabase
          .from('players')
          .select('id, name, role')
          .eq('team_id', teamId)
          .execute();

      if (response.status == 200 && response.data != null) {
        setState(() {
          _players = List<Map<String, dynamic>>.from(response.data);
          _isLoadingPlayers = false;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Failed to fetch players: ${response.error?.message}')),
        );
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('An unexpected error occurred while fetching players.')),
      );
    }
  }

  Future<void> _deleteTeam(String teamId) async {
    try {
      // Delete the team from the database
      final response =
          await supabase.from('teams').delete().eq('id', teamId).execute();

      if (response.error == null) {
        setState(() {
          _teams.removeWhere((team) => team['id'] == teamId);
          if (_selectedTeamId == teamId) {
            _selectedTeamId = null;
            _players.clear();
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Team deleted successfully!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Failed to delete team: ${response.error!.message}')),
        );
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('An unexpected error occurred while deleting the team.')),
      );
    }
  }

  Future<void> _deletePlayer(String playerId) async {
    try {
      final response =
          await supabase.from('players').delete().eq('id', playerId).execute();

      if (response.status == 200) {
        setState(() {
          _players.removeWhere((player) => player['id'] == playerId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Player deleted successfully!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Failed to delete player: ${response.error?.message}')),
        );
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'An unexpected error occurred while deleting the player.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Teams'),
      ),
      body: _isLoadingTeams
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Text(
                    'Teams',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _teams.length,
                      itemBuilder: (context, index) {
                        final team = _teams[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8.0),
                          child: ListTile(
                            title: Text(team['name']),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteTeam(team['id'].toString()),
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => TeamDetailsPage(
                                    teamId: team['id']
                                        .toString(), // Convert to String if necessary
                                    teamName:
                                        team['name'], // Ensure this is a String
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const AddPlayersPage(), // No teamId passed
                        ),
                      );
                    },
                    child: const Text('Add Players'),
                  ),
                ],
              ),
            ),
    );
  }
}

extension on PostgrestResponse {
  get error => null;
}
