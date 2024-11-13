import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AddChildDialog extends StatefulWidget {
  final int userId; // Pass the user's ID to link the child

  AddChildDialog({required this.userId});

  @override
  _AddChildDialogState createState() => _AddChildDialogState();
}

class _AddChildDialogState extends State<AddChildDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  bool isLoading = false;

  Future<void> addChild() async {
    setState(() {
      isLoading = true;
    });

    final String apiUrl =
        'https://2927-37-228-233-126.ngrok-free.app/add_child';
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': _nameController.text,
          'age': int.parse(_ageController.text),
          'guardian_id': widget.userId,
        }),
      );

      if (response.statusCode == 201) {
        Navigator.pop(context, true); // Return true to indicate success
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Child added successfully!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add child.')),
        );
      }
    } catch (e) {
      print('Error adding child: $e');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred. Please try again.')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("Add Child"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: InputDecoration(labelText: 'Child Name'),
          ),
          TextField(
            controller: _ageController,
            decoration: InputDecoration(labelText: 'Child Age'),
            keyboardType: TextInputType.number,
          ),
        ],
      ),
      actions: [
        TextButton(
          child: Text("Cancel"),
          onPressed: () {
            Navigator.of(context).pop(false); // Return false to indicate cancel
          },
        ),
        ElevatedButton(
          child: isLoading
              ? CircularProgressIndicator(color: Colors.white)
              : Text("Add"),
          onPressed: isLoading ? null : addChild,
        ),
      ],
    );
  }
}
