// Create a new file: lib/utils/deep_link_diagnostics.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DeepLinkDiagnostics {
  static final DeepLinkDiagnostics _instance = DeepLinkDiagnostics._internal();
  factory DeepLinkDiagnostics() => _instance;
  DeepLinkDiagnostics._internal();

  // Store diagnostic events with timestamps
  final List<DiagnosticEvent> _events = [];

  // Add an event to the log
  void addEvent(String message, {String? details, bool isError = false}) {
    _events.add(DiagnosticEvent(
      message: message,
      details: details,
      timestamp: DateTime.now(),
      isError: isError,
    ));
  }

  // Get all diagnostic events
  List<DiagnosticEvent> get events => List.unmodifiable(_events);

  // Clear events
  void clear() {
    _events.clear();
  }
}

// Event class to store diagnostic information
class DiagnosticEvent {
  final String message;
  final String? details;
  final DateTime timestamp;
  final bool isError;

  DiagnosticEvent({
    required this.message,
    this.details,
    required this.timestamp,
    this.isError = false,
  });
}

// Widget to display diagnostic information
class DeepLinkDiagnosticsScreen extends StatelessWidget {
  const DeepLinkDiagnosticsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final events = DeepLinkDiagnostics().events;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Deep Link Diagnostics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: () {
              // Copy all events to clipboard
              final text = events.map((e) =>
              '${e.timestamp.toString()} - ${e.isError ? "ERROR: " : ""}${e.message}${e.details != null ? "\n  Details: ${e.details}" : ""}'
              ).join('\n\n');

              // Copy text to clipboard
              Clipboard.setData(ClipboardData(text: text));
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Diagnostic data copied to clipboard'))
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {
              DeepLinkDiagnostics().clear();
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
      body: events.isEmpty
          ? const Center(child: Text('No deep link events recorded'))
          : ListView.builder(
        itemCount: events.length,
        itemBuilder: (context, index) {
          final event = events[index];
          return ListTile(
            title: Text(
              event.message,
              style: TextStyle(
                color: event.isError ? Colors.red : null,
                fontWeight: event.isError ? FontWeight.bold : null,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.timestamp.toString()),
                if (event.details != null)
                  Text(
                    event.details!,
                    style: const TextStyle(fontStyle: FontStyle.italic),
                  ),
              ],
            ),
            isThreeLine: event.details != null,
          );
        },
      ),
    );
  }
}