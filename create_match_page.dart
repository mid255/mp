import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'score_updating_page.dart';

class CreateMatchPage extends StatefulWidget {
  const CreateMatchPage({Key? key}) : super(key: key);

  @override
  _CreateMatchPageState createState() => _CreateMatchPageState();
}

class _CreateMatchPageState extends State<CreateMatchPage> {
  String? _selectedTeam1;
  String? _selectedTeam2;
  String? _tossWinner;
  String? _tossDecision;
  final List<Map<String, dynamic>> _teams = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchTeams();
  }

  Future<void> _fetchTeams() async {
    try {
      final response = await Supabase.instance.client
          .from('teams')
          .select('id, name')
          .execute();

      if (response.error == null && response.data != null) {
        setState(() {
          _teams.addAll(List<Map<String, dynamic>>.from(response.data));
          _isLoading = false;
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

  Future<void> _createMatch() async {
    if (_selectedTeam1 == null ||
        _selectedTeam2 == null ||
        _tossWinner == null ||
        _tossDecision == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    try {
      // Insert the match and return the inserted row
      final response = await Supabase.instance.client
          .from('matches')
          .insert({
            'team1_id': _selectedTeam1,
            'team2_id': _selectedTeam2,
            'toss_winner_id': _tossWinner,
            'toss_decision': _tossDecision,
          })
          .select()
          .execute();

      if (response.error == null &&
          response.data != null &&
          response.data.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Match created successfully!')),
        );

        // Navigate to the Score Updating Page
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                ScoreUpdatingPage(matchId: response.data[0]['id']),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Failed to create match: ${response.error?.message}')),
        );
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('An unexpected error occurred while creating the match.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Match'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    value: _selectedTeam1,
                    decoration:
                        const InputDecoration(labelText: 'Select Team 1'),
                    items: _teams.map((team) {
                      return DropdownMenuItem<String>(
                        value: team['id'].toString(),
                        child: Text(team['name']),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedTeam1 = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedTeam2,
                    decoration:
                        const InputDecoration(labelText: 'Select Team 2'),
                    items: _teams.map((team) {
                      return DropdownMenuItem<String>(
                        value: team['id'].toString(),
                        child: Text(team['name']),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedTeam2 = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _tossWinner,
                    decoration: const InputDecoration(labelText: 'Toss Winner'),
                    items: _teams
                        .where((team) =>
                            team['id'].toString() == _selectedTeam1 ||
                            team['id'].toString() == _selectedTeam2)
                        .map((team) {
                      return DropdownMenuItem<String>(
                        value: team['id'].toString(),
                        child: Text(team['name']),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _tossWinner = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _tossDecision,
                    decoration:
                        const InputDecoration(labelText: 'Toss Decision'),
                    items: ['Bat', 'Bowl'].map((decision) {
                      return DropdownMenuItem<String>(
                        value: decision,
                        child: Text(decision),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _tossDecision = value;
                      });
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 45,
                    child: ElevatedButton(
                      onPressed: _createMatch,
                      child: const Text('Create Match'),
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
