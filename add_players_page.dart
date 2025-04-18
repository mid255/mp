import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddPlayersPage extends StatefulWidget {
  const AddPlayersPage({Key? key}) : super(key: key);

  @override
  _AddPlayersPageState createState() => _AddPlayersPageState();
}

class _AddPlayersPageState extends State<AddPlayersPage> {
  final _formKey = GlobalKey<FormState>();
  final _playerNameController = TextEditingController();
  String? _selectedRole;
  String? _selectedTeamId;
  bool _isLoading = false;

  final List<String> _roles = [
    'Batsman',
    'Bowler',
    'All-Rounder',
    'Wicketkeeper'
  ];
  List<Map<String, dynamic>> _teams = [];

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

      if (!mounted) return; // Add this check before accessing context

      if (response.status == 200 && response.data != null) {
        setState(() {
          _teams = List<Map<String, dynamic>>.from(response.data);
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Failed to fetch teams: ${response.error?.message}')),
        );
      }
    } catch (error) {
      if (!mounted) return; // Add this check before accessing context

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('An unexpected error occurred while fetching teams.')),
      );
    }
  }

  Future<void> _submitPlayer() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedTeamId == null || _selectedRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a team and role')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await Supabase.instance.client.from('players').insert({
        'name': _playerNameController.text.trim(),
        'role': _selectedRole,
        'team_id': _selectedTeamId,
      }).execute();

      if (response.status == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Player added successfully!')),
        );

        // Clear the form
        _playerNameController.clear();
        setState(() {
          _selectedRole = null;
          _selectedTeamId = null;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Failed to add player: ${response.error?.message}')),
        );
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('An unexpected error occurred.')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Players'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add a New Player',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _playerNameController,
                decoration: InputDecoration(
                  labelText: 'Player Name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the player name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: _selectedRole,
                decoration: InputDecoration(
                  labelText: 'Select Role',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                items: _roles.map((role) {
                  return DropdownMenuItem<String>(
                    value: role,
                    child: Text(role),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedRole = value;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a role';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: _selectedTeamId,
                decoration: InputDecoration(
                  labelText: 'Select Team',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                items: _teams.map((team) {
                  return DropdownMenuItem<String>(
                    value: team['id'].toString(),
                    child: Text(team['name']),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedTeamId = value;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a team';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isLoading ? null : _submitPlayer,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Add Player'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension on PostgrestResponse {
  get error => null;
}
