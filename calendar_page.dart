import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CalendarPage extends StatefulWidget {
  final int childId;

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
        'https://3efd-80-233-12-225.ngrok-free.app/calendar_entries/${widget.childId}';
    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body)['activities'] as List<dynamic>;
        setState(() {
          calendarEntries = {};
          for (var entry in data) {
            final DateTime date = DateTime.parse(entry['start_time']).toLocal();
            final DateTime normalizedDate =
                DateTime(date.year, date.month, date.day);
            calendarEntries.putIfAbsent(normalizedDate, () => []);
            calendarEntries[normalizedDate]?.add(entry);
          }
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load calendar entries')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching calendar entries: $e')),
      );
    }
  }

  void _onDaySelected(DateTime selectedDate, DateTime focusedDate) {
    setState(() {
      selectedDay =
          DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    });
  }

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
              'Category: ${event['category']}\n'
              'Start: ${event['start_time']}\nEnd: ${event['end_time']}',
            ),
            trailing: IconButton(
              icon: Icon(Icons.delete, color: Colors.red),
              onPressed: () async {
                await _deleteEvent(event['id']);
              },
            ),
            onTap: () {
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

  Future<void> _deleteEvent(int eventId) async {
    final String apiUrl =
        'https://3efd-80-233-12-225.ngrok-free.app/calendar_entry/$eventId';
    try {
      final response = await http.delete(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Event deleted successfully')),
        );
        fetchCalendarEntries();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete event')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting event: $e')),
      );
    }
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
        onPressed: _showAddEventDialog,
        child: Icon(Icons.add),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _showAddEventDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AddEventDialog(
          selectedDate: selectedDay,
          onSave: (String activityName, String category, DateTime startTime,
              DateTime endTime, String notes) {
            _saveEvent(activityName, category, startTime, endTime, notes);
          },
        );
      },
    );
  }

  Future<void> _saveEvent(String activityName, String category,
      DateTime startTime, DateTime endTime, String notes) async {
    final String apiUrl =
        'https://3efd-80-233-12-225.ngrok-free.app/calendar_entry';
    final Map<String, dynamic> requestBody = {
      'child_id': widget.childId,
      'activity_name': activityName,
      'category': category,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'activity_notes': notes,
    };

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Event added successfully')),
        );
        fetchCalendarEntries();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save event')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding event: $e')),
      );
    }
  }
}

class AddEventDialog extends StatefulWidget {
  final DateTime selectedDate;
  final Function(String, String, DateTime, DateTime, String) onSave;

  AddEventDialog({required this.selectedDate, required this.onSave});

  @override
  _AddEventDialogState createState() => _AddEventDialogState();
}

class _AddEventDialogState extends State<AddEventDialog> {
  final TextEditingController _activityNameController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  late DateTime _startTime;
  late DateTime _endTime;
  String _selectedCategory = 'Activity';

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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _activityNameController,
              decoration: InputDecoration(labelText: 'Activity Name'),
            ),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              items: ['Activity', 'Food', 'Social']
                  .map((category) => DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCategory = value!;
                });
              },
              decoration: InputDecoration(labelText: 'Category'),
            ),
            TextField(
              controller: _notesController,
              decoration: InputDecoration(labelText: 'Notes'),
            ),
            ListTile(
              title: Text('Start Time'),
              subtitle: Text('${_startTime.toLocal()}'),
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
              title: Text('End Time'),
              subtitle: Text('${_endTime.toLocal()}'),
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
              _activityNameController.text.trim(),
              _selectedCategory,
              _startTime,
              _endTime,
              _notesController.text.trim(),
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
