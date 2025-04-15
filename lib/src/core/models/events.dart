import 'package:fl_nodes/src/core/controllers/node_editor/project.dart';
import 'package:flutter/material.dart';

import '../controllers/node_editor/core.dart';
import 'entities.dart';

/// Events are used to communicate between the [FlNodeEditorController] and the Widgets composing the Node Editor.
/// Events can (where applicable) carry data to be used by the Widgets to update their state.
/// Events can be used to trigger animations, or to update the state of the Widgets.
/// Events can be handled by the Widgets to prevent the event from bubbling up to the parent Widgets.
/// Event can be discarded using the [isHandled] flag to group Widgets rebuilds.
/// There is no one to one match between controller emthods and events, the latter only exist
/// if there is data to be passed or rebuilds to be triggered.

/// Event base class for the [FlNodeEditorController] events bus.
@immutable
abstract base class NodeEditorEvent {
  final String id;
  final bool isHandled;
  final bool isUndoable;

  const NodeEditorEvent({
    required this.id,
    this.isHandled = false,
    this.isUndoable = false,
  });

  Map<String, dynamic> toJson(Map<String, DataHandler> dataHandlers) => {
        'id': id,
        'isHandled': isHandled,
        'isUndoable': isUndoable,
      };
}

final class ViewportOffsetEvent extends NodeEditorEvent {
  final Offset offset;
  final bool animate;

  const ViewportOffsetEvent(
    this.offset, {
    this.animate = true,
    required super.id,
    super.isHandled,
  });
}

final class ViewportZoomEvent extends NodeEditorEvent {
  final double zoom;
  final bool animate;

  const ViewportZoomEvent(
    this.zoom, {
    this.animate = true,
    required super.id,
    super.isHandled,
  });
}

final class AreaSelectionEvent extends NodeEditorEvent {
  final Rect area;

  const AreaSelectionEvent(this.area, {required super.id, super.isHandled});
}

final class DragSelectionStartEvent extends NodeEditorEvent {
  final Set<String> nodeIds;
  final Offset position;

  const DragSelectionStartEvent(
    this.nodeIds,
    this.position, {
    required super.id,
    super.isHandled,
  });

  @override
  Map<String, dynamic> toJson(dataHandlers) => {
        ...super.toJson(dataHandlers),
        'nodeIds': nodeIds.toList(),
        'position': [position.dx, position.dy],
      };

  factory DragSelectionStartEvent.fromJson(Map<String, dynamic> json) {
    return DragSelectionStartEvent(
      (json['nodeIds'] as List).cast<String>().toSet(),
      Offset(json['position'][0], json['position'][1]),
      id: json['id'] as String,
      isHandled: json['isHandled'] as bool,
    );
  }
}

final class DragSelectionEvent extends NodeEditorEvent {
  final Set<String> nodeIds;
  final Offset delta;

  const DragSelectionEvent(
    this.nodeIds,
    this.delta, {
    required super.id,
    super.isHandled,
  }) : super(isUndoable: true);

  @override
  Map<String, dynamic> toJson(dataHandlers) => {
        ...super.toJson(dataHandlers),
        'nodeIds': nodeIds.toList(),
        'delta': [delta.dx, delta.dy],
      };
  factory DragSelectionEvent.fromJson(Map<String, dynamic> json) {
    return DragSelectionEvent(
      (json['nodeIds'] as List).cast<String>().toSet(),
      Offset(json['delta'][0], json['delta'][1]),
      id: json['id'] as String,
      isHandled: json['isHandled'] as bool,
    );
  }
}

final class DragSelectionEndEvent extends NodeEditorEvent {
  final Offset position;
  final Set<String> nodeIds;

  const DragSelectionEndEvent(
    this.position,
    this.nodeIds, {
    required super.id,
    super.isHandled,
  });

  @override
  Map<String, dynamic> toJson(dataHandlers) => {
        ...super.toJson(dataHandlers),
        'position': [position.dx, position.dy],
        'nodeIds': nodeIds.toList(),
      };

  factory DragSelectionEndEvent.fromJson(Map<String, dynamic> json) {
    return DragSelectionEndEvent(
      Offset(json['position'][0], json['position'][1]),
      (json['nodeIds'] as List).cast<String>().toSet(),
      id: json['id'] as String,
      isHandled: json['isHandled'] as bool,
    );
  }
}

final class SelectionEvent extends NodeEditorEvent {
  final Set<String> nodeIds;

  const SelectionEvent(this.nodeIds, {required super.id, super.isHandled});
}

final class AddNodeEvent extends NodeEditorEvent {
  final NodeInstance node;

  const AddNodeEvent(
    this.node, {
    required super.id,
    super.isHandled,
  }) : super(isUndoable: true);

  @override
  Map<String, dynamic> toJson(dataHandlers) => {
        ...super.toJson(dataHandlers),
        'node': node.toJson(dataHandlers),
      };

  factory AddNodeEvent.fromJson(
    Map<String, dynamic> json, {
    required FlNodeEditorController controller,
  }) {
    return AddNodeEvent(
      NodeInstance.fromJson(
        json['node'] as Map<String, dynamic>,
        nodePrototypes: controller.nodePrototypes,
        onRenderedCallback: controller.onRenderedCallback,
        dataHandlers: controller.project.dataHandlers,
      ),
      id: json['id'] as String,
      isHandled: json['isHandled'] as bool,
    );
  }
}

final class RemoveNodeEvent extends NodeEditorEvent {
  final NodeInstance node;

  const RemoveNodeEvent(this.node, {required super.id, super.isHandled})
      : super(isUndoable: true);

  @override
  Map<String, dynamic> toJson(dataHandlers) => {
        ...super.toJson(dataHandlers),
        'node': node.toJson(dataHandlers),
      };

  factory RemoveNodeEvent.fromJson(
    Map<String, dynamic> json, {
    required FlNodeEditorController controller,
  }) {
    return RemoveNodeEvent(
      NodeInstance.fromJson(
        json['node'] as Map<String, dynamic>,
        nodePrototypes: controller.nodePrototypes,
        onRenderedCallback: controller.onRenderedCallback,
        dataHandlers: controller.project.dataHandlers,
      ),
      id: json['id'] as String,
      isHandled: json['isHandled'] as bool,
    );
  }
}

final class AddLinkEvent extends NodeEditorEvent {
  final Link link;

  const AddLinkEvent(
    this.link, {
    required super.id,
    super.isHandled,
  }) : super(isUndoable: true);

  @override
  Map<String, dynamic> toJson(dataHandlers) => {
        ...super.toJson(dataHandlers),
        'link': link.toJson(),
      };

  factory AddLinkEvent.fromJson(Map<String, dynamic> json) {
    return AddLinkEvent(
      Link.fromJson(json['link'] as Map<String, dynamic>),
      id: json['id'] as String,
      isHandled: json['isHandled'] as bool,
    );
  }
}

final class RemoveLinkEvent extends NodeEditorEvent {
  final Link link;

  const RemoveLinkEvent(this.link, {required super.id, super.isHandled})
      : super(isUndoable: true);

  @override
  Map<String, dynamic> toJson(dataHandlers) => {
        ...super.toJson(dataHandlers),
        'link': link.toJson(),
      };

  factory RemoveLinkEvent.fromJson(Map<String, dynamic> json) {
    return RemoveLinkEvent(
      Link.fromJson(json['link'] as Map<String, dynamic>),
      id: json['id'] as String,
      isHandled: json['isHandled'] as bool,
    );
  }
}

final class DrawTempLinkEvent extends NodeEditorEvent {
  final Offset from;
  final Offset to;

  const DrawTempLinkEvent(
    this.from,
    this.to, {
    required super.id,
    super.isHandled,
  });
}

final class CollapseEvent extends NodeEditorEvent {
  final bool collpased;
  final Set<String> nodeIds;

  const CollapseEvent(
    this.collpased,
    this.nodeIds, {
    required super.id,
    super.isHandled,
  });
}

final class PasteSelectionEvent extends NodeEditorEvent {
  final Offset position;
  final String clipboardContent;

  const PasteSelectionEvent(
    this.position,
    this.clipboardContent, {
    required super.id,
    super.isHandled,
  });
}

final class CutSelectionEvent extends NodeEditorEvent {
  final String clipboardContent;

  const CutSelectionEvent(
    this.clipboardContent, {
    required super.id,
    super.isHandled,
  });
}

enum FieldEventType {
  change,
  submit,
  cancel,
}

final class NodeFieldEvent extends NodeEditorEvent {
  final String nodeId;
  final dynamic value;
  final FieldEventType eventType;

  const NodeFieldEvent(
    this.nodeId,
    this.value,
    this.eventType, {
    required super.id,
    super.isHandled,
  });
}

final class UpdateStyleEvent extends NodeEditorEvent {
  const UpdateStyleEvent({required super.id});
}

final class SaveProjectEvent extends NodeEditorEvent {
  const SaveProjectEvent({required super.id});
}

final class LoadProjectEvent extends NodeEditorEvent {
  const LoadProjectEvent({required super.id});
}

final class NewProjectEvent extends NodeEditorEvent {
  const NewProjectEvent({required super.id});
}
