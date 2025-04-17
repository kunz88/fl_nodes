import 'dart:async';

import 'package:fl_nodes/src/core/models/events.dart';

/// A class that acts as an event bus for the Node Editor.
///
/// This class is responsible for handling and dispatching events
/// related to the node editor. It allows different parts of the
/// application to communicate with each other by sending and
/// receiving events.
///
/// Events can object instances should extend the [NodeEditorEvent] class.
class NodeEditorEventBus { // TODO controller per la gestione globale degli eventi , viene chiamato da FlNodeEditorController
  final _streamController = StreamController<NodeEditorEvent>.broadcast();

  /// Emits an event to the event bus.
  void emit(NodeEditorEvent event) {
    _streamController.add(event);
  }

  /// Closes the underlying stream controller.
  void close() {
    _streamController.close();
  }

  Stream<NodeEditorEvent> get events => _streamController.stream;
}
