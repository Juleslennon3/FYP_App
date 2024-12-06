import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CalendarPage extends StatefulWidget {
  final int childId; // Use child_id directly

  CalendarPage({required this.childId});

  @override
  _CalendarPageState createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  Map<DateTime, List<Map<String, dynamic>>> calendarEntries = {};
  late DateTime selectedDay;

  @override
  void initState() {
    super.initState();
    selectedDay = DateTime.now();
    fetchCalendarEntries();
  }

  // Fetch calendar entries for the child
  Future<void> fetchCalendarEntries() async {
    final String apiUrl =
        'https://a20b-37-228-210-166.ngrok-free.app/calendar_entries/${widget.childId}';
    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body)['activities'] as List<dynamic>;
        print('Fetched activities: $data'); // Debug log for fetched data
        setState(() {
          calendarEntries = {};
          for (var entry in data) {
            // Normalize the start_time to ignore time
            final DateTime date = DateTime.parse(entry['start_time']).toLocal();
            final DateTime normalizedDate =
                DateTime(date.year, date.month, date.day);
            calendarEntries.putIfAbsent(normalizedDate, () => []);
            calendarEntries[normalizedDate]?.add(entry);
          }
        });
        print(
            'Parsed calendarEntries: $calendarEntries'); // Debug log for calendarEntries
      } else {
        print(
            'Failed to load calendar entries. Status code: ${response.statusCode}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load calendar entries')),
        );
      }
    } catch (e) {
      print('Error fetching calendar entries: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching calendar entries')),
      );
    }
  }

  void _onDaySelected(DateTime selectedDate, DateTime focusedDate) {
    // Normalize selectedDay to ignore time
    setState(() {
      selectedDay =
          DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    });
  }

  // Build cards for events
  Widget _buildEventList(List<Map<String, dynamic>> events) {
    return ListView.builder(
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        return Card(
          margin: EdgeInsets.symmetric(vertical: 8.0, horizontal: 0.0),
          child: ListTile(
            title: Text(event['activity_name'] ?? 'No title'),
            subtitle: Text(
              'Start: ${event['start_time']}\nEnd: ${event['end_time']}',
            ),
            trailing: IconButton(
              icon: Icon(Icons.delete, color: Colors.red),
              onPressed: () async {
                final String apiUrl =
                    'https://a20b-37-228-210-166.ngrok-free.app/calendar_entry/${event['id']}';
                try {
                  final response = await http.delete(Uri.parse(apiUrl));

                  if (response.statusCode == 200) {
                    print('Event deleted successfully');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Event deleted successfully')),
                    );
                    fetchCalendarEntries(); // Refresh the calendar data after deletion
                  } else {
                    print('Failed to delete event: ${response.body}');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to delete event')),
                    );
                  }
                } catch (e) {
                  print('Error deleting event: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Error occurred while deleting event')),
                  );
                }
              },
            ),
            onTap: () {
              // Show notes in a dialog
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(event['activity_name'] ?? 'No title'),
                  content: Text(event['activity_notes'] ?? 'No notes'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text('Close'),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedDayEvents = calendarEntries[selectedDay] ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text('Calendar'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TableCalendar(
              focusedDay: selectedDay,
              firstDay: DateTime.utc(2020, 01, 01),
              lastDay: DateTime.utc(2030, 12, 31),
              selectedDayPredicate: (day) {
                return isSameDay(selectedDay, day);
              },
              onDaySelected: _onDaySelected,
              calendarStyle: CalendarStyle(
                todayDecoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
                weekendTextStyle: TextStyle(color: Colors.red),
              ),
            ),
            SizedBox(height: 20),
            Expanded(
              child: selectedDayEvents.isNotEmpty
                  ? _buildEventList(selectedDayEvents)
                  : Center(
                      child: Text(
                        'No events for this day',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Add functionality to add new events
          _showAddEventDialog();
        },
        child: Icon(Icons.add),
        backgroundColor: Colors.blue,
      ),
    );
  }

  // Show the dialog to add an event
  void _showAddEventDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AddEventDialog(
          selectedDate: selectedDay,
          onSave: (String activityName, DateTime startTime, DateTime endTime,
              String notes) {
            _saveEvent(activityName, startTime, endTime, notes);
          },
        );
      },
    );
  }

  // Save the event in the backend and refresh the calendar
  Future<void> _saveEvent(String activityName, DateTime startTime,
      DateTime endTime, String notes) async {
    final String apiUrl =
        'https://a20b-37-228-210-166.ngrok-free.app/calendar_entry';
    final Map<String, dynamic> requestBody = {
      'child_id': widget.childId,
      'activity_name': activityName,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'activity_notes': notes,
    };

    try {
      print('Request payload: $requestBody'); // Debug log
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 201) {
        print('Event added successfully: ${response.body}');
        fetchCalendarEntries(); // Refresh the calendar data
      } else {
        print('Failed to save event: ${response.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save event')),
        );
      }
    } catch (e) {
      print('Error saving event: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error occurred while saving event')),
      );
    }
  }
}

// Dialog for adding events
class AddEventDialog extends StatefulWidget {
  final Function(String, DateTime, DateTime, String) onSave;
  final DateTime selectedDate;

  AddEventDialog({required this.onSave, required this.selectedDate});

  @override
  _AddEventDialogState createState() => _AddEventDialogState();
}

class _AddEventDialogState extends State<AddEventDialog> {
  final TextEditingController _activityNameController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  late DateTime _startTime;
  late DateTime _endTime;

  @override
  void initState() {
    super.initState();
    _startTime = widget.selectedDate;
    _endTime = widget.selectedDate.add(Duration(hours: 1));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Add Event'),
      content: SingleChildScrollView(
        child: Column(
          children: [
            TextField(
              controller: _activityNameController,
              decoration: InputDecoration(labelText: 'Activity Name'),
            ),
            TextField(
              controller: _notesController,
              decoration: InputDecoration(labelText: 'Notes'),
            ),
            ListTile(
              title: Text("Start Time"),
              subtitle: Text(_startTime.toLocal().toString()),
              onTap: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.fromDateTime(_startTime),
                );
                if (time != null) {
                  setState(() {
                    _startTime = DateTime(
                      _startTime.year,
                      _startTime.month,
                      _startTime.day,
                      time.hour,
                      time.minute,
                    );
                  });
                }
              },
            ),
            ListTile(
              title: Text("End Time"),
              subtitle: Text(_endTime.toLocal().toString()),
              onTap: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.fromDateTime(_endTime),
                );
                if (time != null) {
                  setState(() {
                    _endTime = DateTime(
                      _endTime.year,
                      _endTime.month,
                      _endTime.day,
                      time.hour,
                      time.minute,
                    );
                  });
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            widget.onSave(
              _activityNameController.text,
              _startTime,
              _endTime,
              _notesController.text,
            );
            Navigator.of(context).pop();
          },
          child: Text('Save'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text('Cancel'),
        ),
      ],
    );
  }
}
