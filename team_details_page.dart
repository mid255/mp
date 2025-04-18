import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TeamDetailsPage extends StatefulWidget {
  final String teamId;
  final String teamName;

  const TeamDetailsPage(
      {Key? key, required this.teamId, required this.teamName})
      : super(key: key);

  @override
  _TeamDetailsPageState createState() => _TeamDetailsPageState();
}

class _TeamDetailsPageState extends State<TeamDetailsPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _players = [];
  bool _isLoadingPlayers = true;

  @override
  void initState() {
    super.initState();
    _fetchPlayers();
  }

  Future<void> _fetchPlayers() async {
    try {
      final response = await supabase
          .from('players')
          .select('id, name, role')
          .eq('team_id', widget.teamId)
          .execute();

      if (response.error == null && response.data != null) {
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

  Future<void> _deletePlayer(String playerId) async {
    try {
      final response =
          await supabase.from('players').delete().eq('id', playerId).execute();

      if (response.error == null) {
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
        title: Text('Team: ${widget.teamName}'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Players',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            _isLoadingPlayers
                ? const Center(child: CircularProgressIndicator())
                : Expanded(
                    child: ListView.builder(
                      itemCount: _players.length,
                      itemBuilder: (context, index) {
                        final player = _players[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8.0),
                          child: ListTile(
                            title: Text(player['name']),
                            subtitle: Text(player['role']),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deletePlayer(player['id'].toString()),
                            ),
                          ),
                        );
                      },
                    ),
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
