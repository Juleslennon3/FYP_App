import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ChildProfilePage extends StatelessWidget {
  final int childId;
  final String clientId = '23PVVG'; // Replace with your Fitbit Client ID
  final String redirectUri =
      'https://db45-37-228-234-175.ngrok-free.app/fitbit_callback';

  ChildProfilePage({required this.childId});

  Future<void> _connectFitbit() async {
    final fitbitAuthUrl = 'https://www.fitbit.com/oauth2/authorize'
        '?response_type=code'
        '&client_id=$clientId'
        '&redirect_uri=$redirectUri'
        '&scope=activity%20heartrate%20sleep'
        '&expires_in=604800'
        '&state=$childId'; // Pass childId as state to identify the child in the backend

    if (await canLaunch(fitbitAuthUrl)) {
      await launch(fitbitAuthUrl);
    } else {
      throw 'Could not launch $fitbitAuthUrl';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Child Profile'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: _connectFitbit,
          child: Text('Connect Fitbit'),
        ),
      ),
    );
  }
}
