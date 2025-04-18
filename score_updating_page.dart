import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ScoreUpdatingPage extends StatefulWidget {
  final int matchId;
  const ScoreUpdatingPage({Key? key, required this.matchId}) : super(key: key);

  @override
  _ScoreUpdatingPageState createState() => _ScoreUpdatingPageState();
}

class _ScoreUpdatingPageState extends State<ScoreUpdatingPage> {
  // Match state variables
  bool _isLoading = true;
  bool _isFirstInnings = true;
  bool _isInningsStarted = false;
  int _totalRuns = 0;
  int _totalWickets = 0;
  int _overNumber = 0;
  int _ballNumber = 0;
  int? _target;

  // Player variables
  String? _striker;
  String? _nonStriker;
  String? _currentBowler;
  List<Map<String, dynamic>> _battingTeamPlayers = [];
  List<Map<String, dynamic>> _bowlingTeamPlayers = [];
  List<Map<String, dynamic>> _playerStats = [];

  // Current over details
  final Map<String, dynamic> _currentOverDetails = {
    'runs': 0,
    'wickets': 0,
    'balls': <String>[],
  };

  bool _showBattingStats = true; // Toggle between batting and bowling stats

  @override
  void initState() {
    super.initState();
    _initializeMatch();
  }

  Future<void> _initializeMatch() async {
    try {
      // Fetch match details
      final matchResponse = await Supabase.instance.client
          .from('matches')
          .select(
              '*, team1:team1_id(*), team2:team2_id(*), toss_winner:toss_winner_id(*)')
          .eq('id', widget.matchId)
          .single()
          .execute();

      if (matchResponse.error != null) throw matchResponse.error!;

      // Determine batting and bowling teams
      final matchData = matchResponse.data;
      final battingTeamId =
          matchData['toss_winner_id'] == matchData['team1_id'] &&
                  matchData['toss_decision'] == 'Bat'
              ? matchData['team1_id']
              : matchData['team2_id'];

      final bowlingTeamId = battingTeamId == matchData['team1_id']
          ? matchData['team2_id']
          : matchData['team1_id'];

      // Fetch players
      final playersResponse = await Supabase.instance.client
          .from('players')
          .select('*')
          .in_('team_id', [battingTeamId, bowlingTeamId]).execute();

      if (playersResponse.error != null) throw playersResponse.error!;

      setState(() {
        _battingTeamPlayers = List<Map<String, dynamic>>.from(
          playersResponse.data.where((p) => p['team_id'] == battingTeamId),
        );
        _bowlingTeamPlayers = List<Map<String, dynamic>>.from(
          playersResponse.data.where((p) => p['team_id'] == bowlingTeamId),
        );
        _isLoading = false;
      });

      // Show player selection dialog
      _showPlayerSelectionDialog();
    } catch (error) {
      _showError('Error initializing match: $error');
    }
  }

  void _showPlayerSelectionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(_isFirstInnings
            ? 'Select Opening Players'
            : 'Select Second Innings Players'),
        content: StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Striker'),
                value: _striker,
                items: _battingTeamPlayers
                    .where((player) => player['id'].toString() != _nonStriker)
                    .map((player) => DropdownMenuItem<String>(
                          value: player['id'].toString(),
                          child: Text(player['name']),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() => _striker = value);
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Non-Striker'),
                value: _nonStriker,
                items: _battingTeamPlayers
                    .where((player) => player['id'].toString() != _striker)
                    .map((player) => DropdownMenuItem<String>(
                          value: player['id'].toString(),
                          child: Text(player['name']),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() => _nonStriker = value);
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Bowler'),
                value: _currentBowler,
                items: _bowlingTeamPlayers
                    .map((player) => DropdownMenuItem<String>(
                          value: player['id'].toString(),
                          child: Text(player['name']),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() => _currentBowler = value);
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (_striker != null &&
                  _nonStriker != null &&
                  _currentBowler != null) {
                setState(() => _isInningsStarted = true);
                Navigator.pop(context);
                _initializePlayerStats();
              } else {
                _showError('Please select all players');
              }
            },
            child: const Text('Start Innings'),
          ),
        ],
      ),
    );
  }

  Future<void> _initializePlayerStats() async {
    try {
      // Initialize stats for striker and non-striker
      await Future.wait([
        _createPlayerStats(_striker!),
        _createPlayerStats(_nonStriker!),
        _createPlayerStats(_currentBowler!),
      ]);
      await _fetchPlayerStats();
    } catch (error) {
      _showError('Error initializing player stats: $error');
    }
  }

  Future<void> _createPlayerStats(String playerId) async {
    await Supabase.instance.client.from('match_player_stats').upsert({
      'match_id': widget.matchId,
      'player_id': playerId,
      'runs_scored': 0,
      'balls_faced': 0,
      'fours': 0,
      'sixes': 0,
      'runs_conceded': 0,
      'wickets': 0,
      'overs_bowled': 0,
      'maidens': 0,
    }).execute();
  }

  Future<void> _fetchPlayerStats() async {
    try {
      final response = await Supabase.instance.client
          .from('match_player_stats')
          .select('*, player:player_id(*)')
          .eq('match_id', widget.matchId)
          .execute();

      if (response.error != null) throw response.error!;

      setState(() {
        _playerStats = List<Map<String, dynamic>>.from(response.data);
      });
    } catch (error) {
      _showError('Error fetching player stats: $error');
    }
  }

  Future<void> _updateScore(
    int runs, {
    bool isWicket = false,
    bool isExtra = false,
    String? extraType,
    String? wicketType,
    String? fielderId,
  }) async {
    try {
      // Update match details
      final matchDetailsResponse =
          await Supabase.instance.client.from('match_details').upsert({
        'match_id': widget.matchId,
        'innings': _isFirstInnings ? 1 : 2,
        'batting_team_id': _battingTeamPlayers[0]['team_id'],
        'bowling_team_id': _bowlingTeamPlayers[0]['team_id'],
        'total_runs': _totalRuns + runs,
        'wickets': isWicket ? _totalWickets + 1 : _totalWickets,
        'overs_completed': _overNumber,
        'balls_in_over': _ballNumber,
        'extras_wides': extraType == 'Wide' ? 1 : 0,
        'extras_noballs': extraType == 'No Ball' ? 1 : 0,
        'extras_byes': extraType == 'Bye' ? runs : 0,
        'extras_legbyes': extraType == 'Leg Bye' ? runs : 0,
      }).execute();

      if (matchDetailsResponse.error != null) throw matchDetailsResponse.error!;

      // Record ball-by-ball details
      final ballResponse =
          await Supabase.instance.client.from('ball_by_ball').insert({
        'match_id': widget.matchId,
        'innings': _isFirstInnings ? 1 : 2,
        'over_number': _overNumber,
        'ball_number': _ballNumber,
        'batsman_id': _striker,
        'bowler_id': _currentBowler,
        'runs_scored': runs,
        'is_wicket': isWicket,
        'wicket_type': wicketType,
        'fielder_id': fielderId,
        'is_extra': isExtra,
        'extra_type': extraType,
        'extra_runs': isExtra ? 1 : 0,
      }).execute();

      if (ballResponse.error != null) throw ballResponse.error!;

      // Rest of your existing update logic...
    } catch (error) {
      _showError('Error updating score: $error');
    }
  }

  Future<void> _updateBatsmanStats(int runs) async {
    await Supabase.instance.client
        .from('match_player_stats')
        .update({
          'runs_scored': Supabase.instance.client.rpc('increment',
              params: {'column': 'runs_scored', 'value': runs}),
          'balls_faced': Supabase.instance.client
              .rpc('increment', params: {'column': 'balls_faced', 'value': 1}),
          'fours': runs == 4
              ? Supabase.instance.client
                  .rpc('increment', params: {'column': 'fours', 'value': 1})
              : null,
          'sixes': runs == 6
              ? Supabase.instance.client
                  .rpc('increment', params: {'column': 'sixes', 'value': 1})
              : null,
        })
        .eq('player_id', _striker)
        .execute();
  }

  Future<void> _updateBowlerStats(int runs, bool isWicket) async {
    await Supabase.instance.client
        .from('match_player_stats')
        .update({
          'runs_conceded': Supabase.instance.client.rpc('increment',
              params: {'column': 'runs_conceded', 'value': runs}),
          'wickets': isWicket
              ? Supabase.instance.client
                  .rpc('increment', params: {'column': 'wickets', 'value': 1})
              : null,
          'overs_bowled': _ballNumber == 5
              ? Supabase.instance.client.rpc('increment',
                  params: {'column': 'overs_bowled', 'value': 1})
              : null,
        })
        .eq('player_id', _currentBowler)
        .execute();
  }

  void _rotateStrike() {
    setState(() {
      final temp = _striker;
      _striker = _nonStriker;
      _nonStriker = temp;
    });
  }

  void _showNewBowlerDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Select New Bowler'),
        content: StatefulBuilder(
          builder: (context, setState) => DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: 'New Bowler'),
            value: null,
            items: _bowlingTeamPlayers
                .where((player) => player['id'].toString() != _currentBowler)
                .map((player) => DropdownMenuItem<String>(
                      value: player['id'].toString(),
                      child: Text(player['name']),
                    ))
                .toList(),
            onChanged: (value) async {
              if (value != null) {
                setState(() => _currentBowler = value);
                await _createPlayerStats(value);
                Navigator.pop(context);
              }
            },
          ),
        ),
      ),
    );
  }

  void _completeInnings() async {
    try {
      // Update match details to mark innings as complete
      await Supabase.instance.client.from('match_details').upsert({
        'match_id': widget.matchId,
        'innings': _isFirstInnings ? 1 : 2,
        'total_runs': _totalRuns,
        'wickets': _totalWickets,
        'overs': _overNumber + _ballNumber / 6,
        'is_complete': true,
      }).execute();

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Innings Complete'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Total Score: $_totalRuns/$_totalWickets',
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Text(
                'Overs: $_overNumber.${_ballNumber}',
                style: const TextStyle(fontSize: 18),
              ),
              if (_isFirstInnings) ...[
                const SizedBox(height: 16),
                Text(
                  'Target: ${_totalRuns + 1}',
                  style: const TextStyle(fontSize: 20, color: Colors.blue),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                if (_isFirstInnings) {
                  // Start second innings
                  setState(() {
                    _isFirstInnings = false;
                    _target = _totalRuns + 1;
                    _totalRuns = 0;
                    _totalWickets = 0;
                    _overNumber = 0;
                    _ballNumber = 0;
                    _currentOverDetails['runs'] = 0;
                    _currentOverDetails['wickets'] = 0;
                    _currentOverDetails['balls'] = [];
                    _striker = null;
                    _nonStriker = null;
                    _currentBowler = null;
                    _isInningsStarted = false;
                  });
                  // Swap batting and bowling teams
                  final temp = _battingTeamPlayers;
                  _battingTeamPlayers = _bowlingTeamPlayers;
                  _bowlingTeamPlayers = temp;
                  _showPlayerSelectionDialog();
                } else {
                  // Match complete, return to previous screen
                  Navigator.pop(context);
                }
              },
              child: Text(
                  _isFirstInnings ? 'Start Second Innings' : 'Finish Match'),
            ),
          ],
        ),
      );
    } catch (error) {
      _showError('Error completing innings: $error');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showWicketDialog() {
    bool isExtra = false;
    String? extraType;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Wicket Details'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Wicket Type Selection
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Wicket Type'),
                value: null,
                items: const [
                  DropdownMenuItem(value: 'Bowled', child: Text('Bowled')),
                  DropdownMenuItem(value: 'Caught', child: Text('Caught')),
                  DropdownMenuItem(value: 'LBW', child: Text('LBW')),
                  DropdownMenuItem(value: 'Run Out', child: Text('Run Out')),
                  DropdownMenuItem(value: 'Stumped', child: Text('Stumped')),
                ],
                onChanged: (value) async {
                  if (value == 'Run Out') {
                    // Show fielder selection for run out
                    await _showFielderSelectionDialog();
                  }
                  Navigator.pop(context);
                  _updateScore(0,
                      isWicket: true,
                      wicketType: value,
                      isExtra: isExtra,
                      extraType: extraType);
                },
              ),
              const SizedBox(height: 16),
              // Extras Option
              CheckboxListTile(
                title: const Text('Include Extras'),
                value: isExtra,
                onChanged: (value) {
                  setState(() {
                    isExtra = value ?? false;
                  });
                },
              ),
              if (isExtra)
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Extra Type'),
                  value: extraType,
                  items: const [
                    DropdownMenuItem(value: 'Wide', child: Text('Wide')),
                    DropdownMenuItem(value: 'No Ball', child: Text('No Ball')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      extraType = value;
                    });
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showByeRunsDialog(String extraType) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(extraType),
        content: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (int i = 1; i <= 4; i++)
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _updateScore(
                    i,
                    isExtra: true,
                    extraType: extraType,
                  );
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
                child: Text('$i'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showFielderSelectionDialog() async {
    // Implement fielder selection dialog logic here
  }

  Widget _buildStatisticsPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 5,
          ),
        ],
      ),
      child: Column(
        children: [
          // Stats Toggle
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => setState(() => _showBattingStats = true),
                  style: ButtonStyle(
                    backgroundColor: MaterialStateProperty.all(
                      _showBattingStats ? Colors.blue[700] : Colors.grey[200],
                    ),
                  ),
                  child: Text(
                    'Batting',
                    style: TextStyle(
                      color: _showBattingStats ? Colors.white : Colors.black,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: TextButton(
                  onPressed: () => setState(() => _showBattingStats = false),
                  style: ButtonStyle(
                    backgroundColor: MaterialStateProperty.all(
                      !_showBattingStats ? Colors.blue[700] : Colors.grey[200],
                    ),
                  ),
                  child: Text(
                    'Bowling',
                    style: TextStyle(
                      color: !_showBattingStats ? Colors.white : Colors.black,
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Stats Table
          _showBattingStats ? _buildBattingTable() : _buildBowlingTable(),
        ],
      ),
    );
  }

  Widget _buildBattingTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Batsman')),
          DataColumn(label: Text('R')),
          DataColumn(label: Text('B')),
          DataColumn(label: Text('4s')),
          DataColumn(label: Text('6s')),
          DataColumn(label: Text('SR')),
        ],
        rows: _playerStats
            .where((p) => _battingTeamPlayers
                .any((b) => b['id'].toString() == p['player_id'].toString()))
            .map((p) {
          final sr = p['balls_faced'] > 0
              ? (p['runs_scored'] * 100 / p['balls_faced']).toStringAsFixed(2)
              : '0.00';
          return DataRow(
            selected: p['player_id'].toString() == _striker,
            cells: [
              DataCell(Text(p['player']['name'])),
              DataCell(Text('${p['runs_scored']}')),
              DataCell(Text('${p['balls_faced']}')),
              DataCell(Text('${p['fours']}')),
              DataCell(Text('${p['sixes']}')),
              DataCell(Text(sr)),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBowlingTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Bowler')),
          DataColumn(label: Text('O')),
          DataColumn(label: Text('M')),
          DataColumn(label: Text('R')),
          DataColumn(label: Text('W')),
          DataColumn(label: Text('Econ')),
        ],
        rows: _playerStats
            .where((p) => _bowlingTeamPlayers
                .any((b) => b['id'].toString() == p['player_id'].toString()))
            .map((p) {
          final overs = (p['overs_bowled'] ?? 0).toString();
          final econ = p['overs_bowled'] > 0
              ? (p['runs_conceded'] / p['overs_bowled']).toStringAsFixed(2)
              : '0.00';
          return DataRow(
            selected: p['player_id'].toString() == _currentBowler,
            cells: [
              DataCell(Text(p['player']['name'])),
              DataCell(Text(overs)),
              DataCell(Text('${p['maidens'] ?? 0}')),
              DataCell(Text('${p['runs_conceded']}')),
              DataCell(Text('${p['wickets']}')),
              DataCell(Text(econ)),
            ],
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isFirstInnings ? '1st Innings' : '2nd Innings'),
        backgroundColor: Colors.blue[900],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Match Summary Card
                Container(
                  color: Colors.blue[900],
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$_totalRuns/$_totalWickets',
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '(${_overNumber}.${_ballNumber})',
                            style: const TextStyle(
                              fontSize: 24,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      if (!_isFirstInnings) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Target: $_target',
                          style: const TextStyle(
                            fontSize: 20,
                            color: Colors.white,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      // Batsmen and Bowler Info
                      Row(
                        children: [
                          // Batsmen Column (Left Side)
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildBatsmanRow(_striker, true),
                                const SizedBox(height: 4),
                                _buildBatsmanRow(_nonStriker, false),
                              ],
                            ),
                          ),
                          // Bowler Column (Right Side)
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                _buildBowlerRow(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      // Score Update Controls
                      Expanded(
                        flex: 3,
                        child: SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                // Current Over
                                Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Current Over',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            for (String ball
                                                in _currentOverDetails['balls'])
                                              Container(
                                                margin: const EdgeInsets.only(
                                                    right: 8),
                                                padding:
                                                    const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: _getBallColor(ball),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Text(
                                                  ball,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // Run Buttons
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    for (int i = 0; i <= 6; i++)
                                      ElevatedButton(
                                        onPressed: () => _updateScore(i),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: i == 4 || i == 6
                                              ? Colors.blue[700]
                                              : null,
                                          padding: const EdgeInsets.all(16),
                                        ),
                                        child: Text('$i'),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                // Extras Buttons
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _buildExtraButton('Wide', Colors.orange),
                                    _buildExtraButton('No Ball', Colors.red),
                                    _buildExtraButton('Bye', Colors.purple),
                                    _buildExtraButton('Leg Bye', Colors.green),
                                    ElevatedButton(
                                      onPressed: () => _showWicketDialog(),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                      ),
                                      child: const Text('Wicket'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Statistics Panel
                      if (_isInningsStarted)
                        Expanded(
                          flex: 2,
                          child: _buildStatisticsPanel(),
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildBatsmanRow(String? batsmanId, bool isStriker) {
    if (batsmanId == null) return const SizedBox.shrink();
    final stats = _playerStats.firstWhere(
      (p) => p['player_id'].toString() == batsmanId,
      orElse: () => {'runs_scored': 0, 'balls_faced': 0},
    );
    return Row(
      children: [
        if (isStriker)
          const Icon(Icons.sports_cricket, color: Colors.yellow, size: 16),
        Text(
          '${_battingTeamPlayers.firstWhere((p) => p['id'].toString() == batsmanId)['name']} '
          '${stats['runs_scored']}(${stats['balls_faced']})',
          style: const TextStyle(color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildBowlerRow() {
    if (_currentBowler == null) return const SizedBox.shrink();
    final stats = _playerStats.firstWhere(
      (p) => p['player_id'].toString() == _currentBowler,
      orElse: () => {'wickets': 0, 'runs_conceded': 0},
    );
    return Text(
      '${_bowlingTeamPlayers.firstWhere((p) => p['id'].toString() == _currentBowler)['name']} '
      '${stats['wickets']}-${stats['runs_conceded']}',
      style: const TextStyle(color: Colors.white),
    );
  }

  Widget _buildExtraButton(String label, Color color) {
    return ElevatedButton(
      onPressed: () {
        if (label == 'Wide' || label == 'No Ball') {
          _updateScore(1, isExtra: true, extraType: label);
        } else {
          _showByeRunsDialog(label);
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
      ),
      child: Text(label),
    );
  }

  Color _getBallColor(String ball) {
    switch (ball) {
      case 'W':
        return Colors.red;
      case '4':
        return Colors.blue;
      case '6':
        return Colors.purple;
      case 'Wd':
      case 'Nb':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}

extension on PostgrestResponse {
  get error => null;
}
