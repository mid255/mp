import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';

class AddTeamPage extends StatefulWidget {
  const AddTeamPage({Key? key}) : super(key: key);

  @override
  _AddTeamPageState createState() => _AddTeamPageState();
}

class _AddTeamPageState extends State<AddTeamPage> {
  final _formKey = GlobalKey<FormState>();
  final _teamNameController = TextEditingController();
  File? _selectedImage;
  bool _isLoading = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _uploadTeam() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String? imageUrl;

      // If an image is selected, upload it to Supabase storage
      if (_selectedImage != null) {
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.png';
        final response = await Supabase.instance.client.storage
            .from('team-logos') // Ensure this matches the bucket name
            .upload(fileName, _selectedImage!);

        if (response.error != null) {
          print('Error uploading image: ${response.error!.message}');
          throw Exception('Image upload failed: ${response.error!.message}');
        }

        imageUrl = Supabase.instance.client.storage
            .from('team-logos')
            .getPublicUrl(fileName);

        print('Image uploaded successfully: $imageUrl');
      }

      // Insert team data into the database
      final teamName = _teamNameController.text.trim();
      final insertResponse = await Supabase.instance.client
          .from('teams')
          .insert({'name': teamName, 'logo': imageUrl}).execute();

      if (insertResponse.error != null) {
        throw Exception('Failed to add team: ${insertResponse.error!.message}');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Team added successfully!')),
      );

      // Clear the form
      _teamNameController.clear();
      setState(() {
        _selectedImage = null;
      });
    } catch (error) {
      print('Error: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $error')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _teamNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Team'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _teamNameController,
                decoration: const InputDecoration(
                  labelText: 'Team Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a team name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: _selectedImage != null
                      ? Image.file(
                          _selectedImage!,
                          fit: BoxFit.cover,
                        )
                      : const Center(
                          child: Text('Tap to select a team logo (Optional)'),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _uploadTeam,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Add Team'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension on String {
  get error => null;
}

extension on PostgrestResponse {
  get error => null;
}
