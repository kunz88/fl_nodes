import 'dart:math';

import 'package:fl_nodes/fl_nodes.dart';
import 'package:fl_nodes/src/constants.dart';
import 'package:fl_nodes/src/core/controllers/node_editor/history.dart';
import 'package:fl_nodes/src/core/controllers/node_editor/project.dart';
import 'package:fl_nodes/src/core/models/events.dart';
import 'package:fl_nodes/src/core/utils/renderbox.dart';
import 'package:fl_nodes/src/core/utils/snackbar.dart';
import 'package:fl_nodes/src/core/utils/spatial_hash_grid.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../models/config.dart';
import '../../models/entities.dart';
import 'clipboard.dart';
import 'event_bus.dart';
import 'runner.dart';
import 'utils.dart';

/// A controller class for the Node Editor.
///
/// This class is responsible for managing the state of the node editor,
/// including the nodes, links, and the viewport. It also provides methods
/// for adding, removing, and manipulating nodes and links.
///
/// The controller also provides an event bus for the node editor, allowing
/// different parts of the application to communicate with each other by
/// sending and receiving events.
class FlNodeEditorController {
  FlNodeEditorConfig config; // Dynamic, can be changed at runtime
  final FlNodeEditorStyle style; // Static, cannot be changed at runtime
  final eventBus = NodeEditorEventBus();

  late final FlNodeEditorClipboard clipboard;
  late final FlNodeEditorRunner runner;
  late final FlNodeEditorHistory history;
  late final FlNodeEditorProject project;

  FlNodeEditorController({
    this.config = const FlNodeEditorConfig(),
    this.style = const FlNodeEditorStyle(),
    Future<bool> Function(Map<String, dynamic> jsonData)? projectSaver,
    Future<Map<String, dynamic>?> Function(bool isSaved)? projectLoader,
    Future<bool> Function(bool isSaved)? projectCreator,
  }) {
    clipboard = FlNodeEditorClipboard(this);
    runner = FlNodeEditorRunner(this);
    history = FlNodeEditorHistory(this);
    project = FlNodeEditorProject(
      this,
      projectSaver: projectSaver,
      projectLoader: projectLoader,
      projectCreator: projectCreator,
    );
  }

  /// This method is used to dispose of the node editor controller and all of its resources, subsystems and members.
  void dispose() {
    eventBus.close();
    history.clear();
    project.clear();
    runner.dispose();

    clear();
  }

  /// This method is used to clear all members of the node editor controller.
  void clear() {
    _nodes.clear();
    _spatialHashGrid.clear();
    _selectedNodeIds.clear();
    _renderLinks.clear();
  }

  // Configuration

  /// Set the global configuration of the node editor.
  void setConfig(FlNodeEditorConfig config) {
    this.config = config;
  }

  /// Enable or disable zooming in the node editor.
  void enableSnapToGrid(bool enable) async {
    setConfig(config.copyWith(enableSnapToGrid: enable));

    if (!enable) {
      for (final node in _nodes.values) {
        node.offset = _unboundNodeOffsets[node.id]!;
      }
    } else {
      for (final node in _nodes.values) {
        if (enable) {
          node.offset = Offset(
            (node.offset.dx / config.snapToGridSize).round() *
                config.snapToGridSize,
            (node.offset.dy / config.snapToGridSize).round() *
                config.snapToGridSize,
          );
        }
      }
    }
  }

  /// Set the size of the grid to snap to in the node editor.
  void setSnapToGridSize(double size) =>
      setConfig(config.copyWith(snapToGridSize: size));

  /// Enable or disable auto placement of nodes in the node editor.
  void enableAutoPlacement(bool enable) =>
      setConfig(config = config.copyWith(enableAutoPlacement: enable));

  // Viewport
  Offset _viewportOffset = Offset.zero;
  double _viewportZoom = 1.0;

  Offset get viewportOffset => _viewportOffset;
  double get viewportZoom => _viewportZoom;

  set viewportOffset(Offset offset) {
    _viewportOffset = offset;
    eventBus.emit(
      ViewportOffsetEvent(
        id: const Uuid().v4(),
        _viewportOffset,
        animate: false,
        isHandled: true,
      ),
    );
  }

  set viewportZoom(double zoom) {
    _viewportZoom = zoom;
    eventBus.emit(
      ViewportZoomEvent(
        id: const Uuid().v4(),
        _viewportZoom,
        animate: false,
        isHandled: true,
      ),
    );
  }

  /// This method is used to set the offset of the viewport.
  ///
  /// The 'animate' parameter is used to animate the transition to the new offset.
  /// The 'absolute' parameter is used to choose whether the offset is added to the the current
  /// offset or set as an absolute value. The 'isHandled' parameter is used to indicate whether
  void setViewportOffset(
    Offset coords, {
    bool animate = true,
    bool absolute = false,
    bool isHandled = false,
  }) {
    eventBus.emit(
      ViewportOffsetEvent(
        id: const Uuid().v4(),
        absolute ? coords : _viewportOffset + coords,
        animate: animate,
        isHandled: isHandled,
      ),
    );
  }

  /// This method is used to set the zoom level of the viewport.
  ///
  /// The 'animate' parameter is used to animate the zoom transition.
  ///
  /// NOTE: The focal point deafults to the current viewport offset if not provided and uses cursor position from mouse events.
  void setViewportZoom(
    double amount, {
    bool animate = true,
    bool isHandled = false,
  }) {
    eventBus.emit(
      ViewportZoomEvent(
        id: const Uuid().v4(),
        amount,
        animate: animate,
        isHandled: isHandled,
      ),
    );
  }

  // Nodes, links and groups
  final Map<String, NodePrototype> _nodePrototypes = {};
  final SpatialHashGrid _spatialHashGrid = SpatialHashGrid();
  final Map<String, NodeInstance> _nodes = {};
  final Map<String, Offset> _unboundNodeOffsets = {};

  List<NodePrototype> get nodePrototypesAsList =>
      _nodePrototypes.values.map((e) => e).toList();
  Map<String, NodePrototype> get nodePrototypes => _nodePrototypes;

  List<NodeInstance> get nodesAsList => _nodes.values.toList();
  Map<String, NodeInstance> get nodes => _nodes;
  SpatialHashGrid get spatialHashGrid => _spatialHashGrid;

  /// This method is used to register a node prototype with the node editor.
  ///
  /// NOTE: node prototypes are identified by human-readable strings instead of UUIDs.
  void registerNodePrototype(NodePrototype prototype) {
    _nodePrototypes.putIfAbsent(
      prototype.idName,
      () => prototype,
    );
  }

  /// This method is used to remove a node prototype by its name.
  ///
  /// NOTE: node prototypes are identified by human-readable strings instead of UUIDs.
  void unregisterNodePrototype(String name) {
    if (!_nodePrototypes.containsKey(name)) {
      throw Exception('Node prototype $name does not exist.');
    } else {
      _nodePrototypes.remove(name);
    }
  }

  /// This method is used to add a [NodeInstance] to the node editor by its prototype name.
  ///
  /// The method takes the name of the node prototype and creates an instance of the node
  /// based on the prototype. The method also takes an optional offset parameter to set the
  /// initial position of the node in the node editor. The node is also inserted into the
  /// spatial hash grid for efficient querying of nodes based on their positions
  ///
  /// See [SpatialHashGrid] and [selectNodesByArea].
  ///
  /// Emits an [AddNodeEvent] event.
  NodeInstance addNode(String name, {Offset offset = Offset.zero}) {
    if (!_nodePrototypes.containsKey(name)) {
      throw Exception('Node prototype $name does not exist.');
    }

    if (config.enableSnapToGrid) {
      offset = Offset(
        (offset.dx / config.snapToGridSize).round() * config.snapToGridSize,
        (offset.dy / config.snapToGridSize).round() * config.snapToGridSize,
      );
    }

    final instance = createNode(
      _nodePrototypes[name]!,
      controller: this,
      offset: offset,
    );

    _nodes.putIfAbsent(instance.id, () => instance);
    _unboundNodeOffsets.putIfAbsent(instance.id, () => instance.offset);

    eventBus.emit(
      AddNodeEvent(id: const Uuid().v4(), instance),
    );

    return instance;
  }

  /// This method is used to add a node from an existing node object.
  ///
  /// This method is used when loading a project from a file or in copy/paste operations
  /// and preserves all properties of the node object.
  ///
  /// Emits an [AddNodeEvent] event.
  void addNodeFromExisting(
    NodeInstance node, {
    bool isHandled = false,
    String? eventId,
  }) {
    if (_nodes.containsKey(node.id)) return;

    Offset offset = node.offset;

    if (config.enableSnapToGrid) {
      offset = Offset(
        (offset.dx / config.snapToGridSize).round() * config.snapToGridSize,
        (offset.dy / config.snapToGridSize).round() * config.snapToGridSize,
      );
    }

    _nodes.putIfAbsent(node.id, () => node.copyWith(offset: offset));
    _unboundNodeOffsets.putIfAbsent(node.id, () => node.offset);

    eventBus.emit(
      AddNodeEvent(
        id: eventId ?? const Uuid().v4(),
        node,
        isHandled: isHandled,
      ),
    );

    for (final port in node.ports.values) {
      for (final link in port.links) {
        addLinkFromExisting(link, isHandled: isHandled);
      }
    }
  }

  /// This method is used to remove a node by its ID.
  ///
  /// Emits a [RemoveNodeEvent] event.
  void removeNode(
    String id, {
    String? eventId,
    bool isHandled = false,
  }) async {
    if (!_nodes.containsKey(id)) return;

    final node = _nodes[id]!;

    for (final port in node.ports.values) {
      final linksToRemove = port.links.map((link) => link.id).toList();

      for (final linkId in linksToRemove) {
        removeLinkById(linkId, isHandled: true);
      }
    }

    _spatialHashGrid.remove(id);
    _nodes.remove(id);

    eventBus.emit(
      RemoveNodeEvent(
        id: eventId ?? const Uuid().v4(),
        node,
        isHandled: isHandled,
      ),
    );
  }

  /// This method is used to add a link between two ports.
  ///
  /// The method takes the IDs of the two nodes and the two ports and creates a link
  /// between them. The method also checks if the link is valid based on the port types
  /// and the number of links allowed on each port. Moreover, the method enforces the
  /// direction of the link based on the port types, i.e., an output port can only be
  /// connected to an input port guaranteeing that the graph is directed the right way.
  ///
  /// Emits an [AddLinkEvent] event.
  Link? addLink(
    String node1Id,
    String port1IdName,
    String node2Id,
    String port2IdName, {
    String? eventId,
  }) {
    bool areTypesCompatible(Type type1, Type type2) {
      if (type1 == dynamic || type2 == dynamic) return true;

      if ((type1 == int || type1 == double) &&
          (type2 == int || type2 == double)) {
        return true;
      }

      return type1 == type2;
    }

    // Check for self-links
    if (node1Id == node2Id) return null;

    final node1 = _nodes[node1Id]!;
    final port1 = node1.ports[port1IdName]!;
    final node2 = _nodes[node2Id]!;
    final port2 = node2.ports[port2IdName]!;

    if (!areTypesCompatible(
      port1.prototype.dataType,
      port2.prototype.dataType,
    )) {
      showNodeEditorSnackbar(
        'Cannot connect ports of different data types: ${port1.prototype.dataType} and ${port2.prototype.dataType}',
        SnackbarType.error,
      );
      return null;
    } else if (port1.prototype.type != port2.prototype.type) {
      showNodeEditorSnackbar(
        'Cannot connect ports of different types: ${port1.prototype.type} and ${port2.prototype.type}',
        SnackbarType.error,
      );
      return null;
    } else if (port1.prototype.direction == port2.prototype.direction) {
      showNodeEditorSnackbar(
        'Cannot connect two ports with the same direction: ${port1.prototype.displayName} and ${port2.prototype.displayName}',
        SnackbarType.error,
      );
      return null;
    } else if (port1.links.any(
          (link) =>
              link.fromTo.from == node2Id && link.fromTo.to == port2IdName,
        ) ||
        port2.links.any(
          (link) =>
              link.fromTo.from == node1Id && link.fromTo.to == port1IdName,
        )) {
      return null;
    }

    late FromTo fromTo;

    // Determine the order to insert the node references in the link based on the port direction.
    if (port1.prototype.direction == PortDirection.output) {
      fromTo = (
        from: node1Id,
        to: port1IdName,
        fromPort: node2Id,
        toPort: port2IdName
      );
    } else {
      fromTo = (
        from: node2Id,
        to: port2IdName,
        fromPort: node1Id,
        toPort: port1IdName
      );
    }

    bool canConnect(FromTo fromTo) {
      final fromNode = _nodes[fromTo.from]!;
      final fromPort = fromNode.ports[fromTo.to]!;
      final toNode = _nodes[fromTo.fromPort]!;
      final toPort = toNode.ports[fromTo.toPort]!;

      // Check if the ports are compatible
      if (fromPort.prototype.direction == toPort.prototype.direction) {
        showNodeEditorSnackbar(
          'Cannot connect two ports of the same type: ${fromPort.prototype.displayName} and ${toPort.prototype.displayName}',
          SnackbarType.error,
        );
        return false;
      }

      // Check if the input port already has a link
      if (toPort.prototype.type == PortType.data && toPort.links.isNotEmpty) {
        showNodeEditorSnackbar(
          'Cannot connect multiple links to an data input port: ${toPort.prototype.displayName} in node ${toNode.prototype.displayName}',
          SnackbarType.error,
        );
        return false;
      }

      return true;
    }

    if (!canConnect(fromTo)) return null;

    final link = Link(id: const Uuid().v4(), fromTo: fromTo);

    port1.links.add(link);
    port2.links.add(link);

    _renderLinks.putIfAbsent(
      link.id,
      () => link,
    );

    eventBus.emit(
      AddLinkEvent(id: eventId ?? const Uuid().v4(), link),
    );

    return link;
  }

  /// This method is used to add a link from an existing link object.
  ///
  /// This method is used when loading a project from a file or in copy/paste operations
  /// and preserves all properties of the link object.
  ///
  /// Emits an [AddLinkEvent] event.
  void addLinkFromExisting(
    Link link, {
    String? eventId,
    bool isHandled = false,
  }) {
    if (!_nodes.containsKey(link.fromTo.from) ||
        !_nodes.containsKey(link.fromTo.fromPort)) {
      return;
    }

    final fromNode = _nodes[link.fromTo.from]!;
    final toNode = _nodes[link.fromTo.fromPort]!;

    if (!fromNode.ports.containsKey(link.fromTo.to) ||
        !toNode.ports.containsKey(link.fromTo.toPort)) {
      return;
    }

    final fromPort = _nodes[link.fromTo.from]!.ports[link.fromTo.to]!;
    final toPort = _nodes[link.fromTo.fromPort]!.ports[link.fromTo.toPort]!;

    fromPort.links.add(link);
    toPort.links.add(link);

    _renderLinks.putIfAbsent(
      link.id,
      () => link,
    );

    eventBus.emit(
      AddLinkEvent(
        id: eventId ?? const Uuid().v4(),
        link,
        isHandled: isHandled,
      ),
    );
  }

  /// This method is used to remove a link by its ID.
  ///
  /// Emits a [RemoveLinkEvent] event.
  void removeLinkById(
    String id, {
    String? eventId,
    bool isHandled = false,
  }) {
    if (!_renderLinks.containsKey(id)) return;

    final link = _renderLinks[id]!;

    // Remove the link from its associated ports
    final fromPort = _nodes[link.fromTo.from]?.ports[link.fromTo.to];
    final toPort = _nodes[link.fromTo.fromPort]?.ports[link.fromTo.toPort];

    fromPort?.links.remove(link);
    toPort?.links.remove(link);

    _renderLinks.remove(id);

    eventBus.emit(
      RemoveLinkEvent(
        id: eventId ?? const Uuid().v4(),
        link,
        isHandled: isHandled,
      ),
    );
  }

  // This is used for rendering purposes only. For computation, use the links list in the Port class.
  final Map<String, Link> _renderLinks = {};
  TempLink? _renderTempLink;

  List<Link> get renderLinksAsList => _renderLinks.values.toList();
  TempLink? get renderTempLink => _renderTempLink;

  /// This method is used to draw a temporary link between two points in the node editor.
  ///
  /// Usually, this method is called when the user is dragging a link from a port to another port.
  ///
  /// Emits a [DrawTempLinkEvent] event.
  void drawTempLink(FlLinkStyle style, Offset from, Offset to) {
    _renderTempLink = TempLink(style: style, from: from, to: to);
    eventBus.emit(DrawTempLinkEvent(id: const Uuid().v4(), from, to));
  }

  /// This method is used to clear the temporary link from the node editor.
  ///
  /// Emits a [DrawTempLinkEvent] event.
  void clearTempLink() {
    _renderTempLink = null;
    eventBus.emit(
      DrawTempLinkEvent(id: const Uuid().v4(), Offset.zero, Offset.zero),
    );
  }

  /// This method is used to break all links associated with a port.
  ///
  /// Emits a [RemoveLinkEvent] event for each link that is removed.
  void breakPortLinks(String nodeId, String portId, {bool isHandled = false}) {
    if (!_nodes.containsKey(nodeId)) return;
    if (!_nodes[nodeId]!.ports.containsKey(portId)) return;

    final port = _nodes[nodeId]!.ports[portId]!;
    final linksToRemove = port.links.map((link) => link.id).toList();

    for (final linkId in linksToRemove) {
      removeLinkById(linkId, isHandled: linkId != linksToRemove.last);
    }
  }

  /// This method is used to set the data of a field in a node.
  ///
  /// Emits a [NodeFieldEvent] event.
  void setFieldData(
    String nodeId,
    String fieldId, {
    dynamic data,
    required FieldEventType eventType,
  }) {
    if (eventType == FieldEventType.change) return;

    final node = _nodes[nodeId]!;
    final field = node.fields[fieldId]!;
    field.data = data;

    eventBus.emit(
      NodeFieldEvent(
        id: const Uuid().v4(),
        nodeId,
        data,
        eventType,
      ),
    );
  }

  /// This method is used to toggle the collapse state of all selected nodes.
  ///
  /// Emit a [NodeRenderModeEvent] event.
  void toggleCollapseSelectedNodes(bool collapse) {
    for (final id in _selectedNodeIds) {
      final node = _nodes[id];
      node?.state.isCollapsed = collapse;
    }

    eventBus.emit(
      CollapseEvent(id: const Uuid().v4(), collapse, _selectedNodeIds),
    );
  }

  // Selection
  final Set<String> _selectedNodeIds = {};
  Rect _selectionArea = Rect.zero;

  Set<String> get selectedNodeIds => _selectedNodeIds;
  Rect get selectionArea => _selectionArea;

  /// This method is used to drag the selected nodes by a given delta affecting their offsets.
  ///
  /// Emits a [DragSelectionEvent] event.
  void dragSelection(
    Offset delta, {
    String? eventId,
    bool isWorldDelta =
        false, // If true, delta is already in world coordinates (e.g., from an undo/redo event)
    bool resetUnboundOffset =
        false, // If true, reset the baseline for _unboundNodeOffsets before applying the delta
  }) async {
    if (_selectedNodeIds.isEmpty) return;

    // If the delta is not already in world coordinates,
    // convert it by dividing by the viewport zoom.
    final Offset effectiveDelta = isWorldDelta ? delta : delta / _viewportZoom;

    for (final id in _selectedNodeIds) {
      final node = _nodes[id]!;

      // Reset the unbound offset if requested (e.g. during undo/redo)
      if (resetUnboundOffset) {
        _unboundNodeOffsets[id] = node.offset;
      } else {
        _unboundNodeOffsets.putIfAbsent(id, () => node.offset);
      }

      // Update the unbound offset by adding the effective delta.
      _unboundNodeOffsets[id] = _unboundNodeOffsets[id]! + effectiveDelta;

      if (config.enableSnapToGrid) {
        final unboundOffset = _unboundNodeOffsets[id]!;
        // Snap the node's offset to the grid using rounding.
        node.offset = Offset(
          (unboundOffset.dx / config.snapToGridSize).round() *
              config.snapToGridSize,
          (unboundOffset.dy / config.snapToGridSize).round() *
              config.snapToGridSize,
        );
      } else {
        // Apply the effective delta directly to the node's offset.
        node.offset += effectiveDelta;
      }
    }

    // Emit a DragSelectionEvent with the effective delta (in world coordinates).
    eventBus.emit(
      DragSelectionEvent(
        id: eventId ?? const Uuid().v4(),
        _selectedNodeIds.toSet(),
        effectiveDelta,
      ),
    );
  }

  /// This method is used to set the selection area for selecting nodes.
  ///
  /// See [selectNodesByArea] for more information.
  ///
  /// Emits a [SelectionAreaEvent] event.
  void setSelectionArea(Rect area) {
    _selectionArea = area;
    eventBus.emit(AreaSelectionEvent(id: const Uuid().v4(), area));
  }

  /// This method is used to select nodes by their IDs.
  ///
  /// Emits a [SelectionEvent] event.
  void selectNodesById(
    Set<String> ids, {
    bool holdSelection = false,
    bool isHandled = false,
  }) async {
    if (ids.isEmpty) {
      return clearSelection();
    } else if (!holdSelection) {
      clearSelection();
    }

    _selectedNodeIds.addAll(ids);

    for (final id in _selectedNodeIds) {
      final node = _nodes[id];
      node?.state.isSelected = true;
    }

    eventBus.emit(
      SelectionEvent(id: const Uuid().v4(), _selectedNodeIds.toSet()),
    );
  }

  /// This method is used to select nodes that are contained within the selection area.
  ///
  /// This method is used in conjunction with the [setSelectionArea] method to select
  /// nodes that are contained within the selection area. The method queries the spatial
  /// hash grid to find nodes that are within the selection area and then selects them.
  ///
  /// See [selectNodesById] for more information.
  void selectNodesByArea({bool holdSelection = false}) async {
    final containedNodes = _spatialHashGrid.queryNodeIdsInArea(_selectionArea);
    selectNodesById(containedNodes, holdSelection: holdSelection);
    _selectionArea = Rect.zero;
  }

  /// This method is used to deselect all selected nodes.
  void clearSelection({bool isHandled = false}) {
    for (final id in _selectedNodeIds) {
      final node = _nodes[id];
      node?.state.isSelected = false;
    }

    eventBus.emit(
      SelectionEvent(
        id: const Uuid().v4(),
        _selectedNodeIds.toSet(),
        isHandled: isHandled,
      ),
    );

    _selectedNodeIds.clear();
  }

  /// This method is used to focus the viweport on a set of nodes by their IDs.
  ///
  /// The method calculates the encompassing rectangle of the nodes and then
  /// centers the viewport on the center of the rectangle. The method also
  /// calculates the zoom level required to fit all the nodes in the viewport.
  ///
  /// See [calculateEncompassingRect], [selectNodesById], [setViewportOffset], and [setViewportZoom] for more information.
  void focusNodesById(Set<String> ids) {
    final encompassingRect = calculateEncompassingRect(
      ids,
      _nodes,
      margin: 256,
    );

    selectNodesById(ids, holdSelection: false);

    final nodeEditorSize = getSizeFromGlobalKey(kNodeEditorWidgetKey)!;

    setViewportOffset(
      -encompassingRect.center,
      animate: true,
      absolute: true,
    );

    final fitZoom = min(
      nodeEditorSize.width / encompassingRect.width,
      nodeEditorSize.height / encompassingRect.height,
    );

    setViewportZoom(fitZoom, animate: true);
  }

  /// This method is used to find all nodes with the specified display name.
  Future<List<String>> searchNodesByName(String name) async {
    final results = <String>[];

    final regex = RegExp(name, caseSensitive: false);

    for (final node in _nodes.values) {
      if (regex.hasMatch(node.prototype.displayName)) {
        results.add(node.id);
      }
    }

    return results;
  }

  /// Callback function that is called when a node is rendered.
  ///
  /// This function is used to update the spatial hash grid with the new bounds
  /// of the node after it has been rendered. This is necessary to keep the grid
  /// up to date with the latest positions of the nodes.
  ///
  /// See [SpatialHashGrid] and [getNodeBoundsInWorld] for more information.
  void onRenderedCallback(NodeInstance node) {
    _spatialHashGrid.update(
      (id: node.id, rect: getNodeBoundsInWorld(node)!),
    );
  }
}
