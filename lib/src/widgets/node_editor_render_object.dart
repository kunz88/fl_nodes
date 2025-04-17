import 'dart:ui' as ui;
import 'dart:ui';

import 'package:fl_nodes/src/widgets/node.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../core/controllers/node_editor/core.dart';
import '../core/models/entities.dart';
import '../core/models/styles.dart';
import 'builders.dart';

class NodeDrawData {
  String id;
  Offset offset;
  NodeState state;

  NodeDrawData({
    required this.id,
    required this.offset,
    required this.state,
  });
}

class LinkDrawData {
  final Offset outPortOffset;
  final Offset inPortOffset;
  final FlLinkStyle linkStyle;

  LinkDrawData({
    required this.outPortOffset,
    required this.inPortOffset,
    required this.linkStyle,
  });
}

/// This extends the [ContainerBoxParentData] class from the Flutter framework
/// for the data to be passed down to children for layout and painting.
class _ParentData extends ContainerBoxParentData<RenderBox> {
  String id = '';
  Offset nodeOffset = Offset.zero;
  NodeState state = NodeState();

  // // // This is used to prevent unnecessary layout and painting of children
  // // bool hasBeenLaidOut = false;

  // This is used to avoid unnecessary recomputations of the renderbox rect
  Rect rect = Rect.zero;
}

class NodeEditorRenderObjectWidget extends MultiChildRenderObjectWidget {
  final FlNodeEditorController controller;
  final FlNodeEditorStyle style;
  final FragmentShader gridShader;
  final FlNodeHeaderBuilder? headerBuilder;
  final FlNodeFieldBuilder? fieldBuilder;
  final FlNodePortBuilder? portBuilder;
  final FlNodeContextMenuBuilder? contextMenuBuilder;
  final FlNodeBuilder? nodeBuilder;

  NodeEditorRenderObjectWidget({
    super.key,
    required this.controller,
    required this.style,
    required this.gridShader,
    this.headerBuilder,
    this.fieldBuilder,
    this.portBuilder,
    this.contextMenuBuilder,
    this.nodeBuilder,
  }) : super(
          children: controller.nodesAsList
              .map(
                (node) => NodeWidget(
                  controller: controller,
                  node: node,
                  headerBuilder: headerBuilder,
                  fieldBuilder: fieldBuilder,
                  portBuilder: portBuilder,
                  contextMenuBuilder: contextMenuBuilder,
                  nodeBuilder: nodeBuilder,
                ),
              )
              .toList(),
        );

  @override
  NodeEditorRenderBox createRenderObject(BuildContext context) {
    return NodeEditorRenderBox(
      controller: controller,
      style: style,
      gridShader: gridShader,
      offset: controller.viewportOffset,
      zoom: controller.viewportZoom,
      tempLink: _getTempLinkData(),
      selectionArea: controller.selectionArea,
      nodesData: _getNodesData(),
      linksData: _getLinksData(),
    );
  }

  @override
  void updateRenderObject(
    // TODO this method rebuild the ui
    BuildContext context,
    NodeEditorRenderBox renderObject,
  ) {
    renderObject
      ..style = style
      ..offset = controller.viewportOffset
      ..zoom = controller.viewportZoom
      ..tempLinkDrawData = _getTempLinkData()
      ..selectionArea = controller.selectionArea
      ..shouldUpdateNodes(_getNodesData())
      ..linksData = _getLinksData();
  }

  List<NodeDrawData> _getNodesData() {
    return controller.nodesAsList
        .map(
          (node) => NodeDrawData(
            id: node.id,
            offset: node.offset,
            state: node.state,
          ),
        )
        .toList();
  }

  List<LinkDrawData> _getLinksData() {
    return controller.renderLinksAsList.map((link) {
      final nodes = controller.nodes;

      final outNode = nodes[link.fromTo.from]!;
      final inNode = nodes[link.fromTo.fromPort]!;
      final outPort = outNode.ports[link.fromTo.to]!;
      final inPort = inNode.ports[link.fromTo.toPort]!;

      // NOTE: The port offset is relative to the node
      return LinkDrawData(
        outPortOffset: outNode.offset + outPort.offset,
        inPortOffset: inNode.offset + inPort.offset,
        linkStyle: outPort.prototype.style.linkStyleBuilder(link.state),
      );
    }).toList();
  }

  LinkDrawData? _getTempLinkData() {
    final tempLink = controller.renderTempLink;
    if (tempLink == null) return null;

    // NOTE: The port offset its fake, it's just the position of the mouse
    return LinkDrawData(
      linkStyle: tempLink.style,
      outPortOffset: tempLink.from,
      inPortOffset: tempLink.to,
    );
  }
}

class NodeEditorRenderBox extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _ParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _ParentData> {
  NodeEditorRenderBox({
    required FlNodeEditorController controller,
    required FlNodeEditorStyle style,
    required FragmentShader gridShader,
    required Offset offset,
    required double zoom,
    required LinkDrawData? tempLink,
    required Rect selectionArea,
    required List<NodeDrawData> nodesData,
    required List<LinkDrawData> linksData,
  })  : _controller = controller,
        _style = style,
        _gridShader = gridShader,
        _offset = offset,
        _zoom = zoom,
        _tempLinkDrawData = tempLink,
        _selectionArea = selectionArea,
        _linksData = linksData {
    _loadGridShader();
    shouldUpdateNodes(nodesData);
  }

  final FlNodeEditorController _controller;
  final Map<String, RenderBox> _childrenById = {};

  // We keep track of the layout operation manually beacuse the hasSize getter
  // calls the size method which implementation causes assertions to be thrown.
  // See: https://api.flutter.dev/flutter/rendering/RenderBox/size.html
  final Map<String, RenderBox> _childrenNotLaidOut = {};

  FlNodeEditorStyle _style;
  FlNodeEditorStyle get style => _style;
  set style(FlNodeEditorStyle value) {
    if (_style == value) return;
    _style = value;
    markNeedsPaint();
  }

  bool gridShaderStyleLoaded = false;
  FragmentShader _gridShader;
  FragmentShader get gridShader => _gridShader;
  set gridShader(FragmentShader value) {
    if (_gridShader == value) return;
    _gridShader = value;
    markNeedsPaint();
  }

  Offset _offset;
  Offset _lastOffset = Offset.zero;
  Offset get offset => _offset;
  set offset(Offset value) {
    if (_offset == value) return;
    _lastOffset = _offset;
    _offset = value;
    markNeedsPaint();
  }

  double _zoom;
  double _lastZoom = 1.0;
  double get zoom => _zoom;
  set zoom(double value) {
    if (_zoom == value) return;
    _lastZoom = _zoom;
    _zoom = value;
    markNeedsPaint();
  }

  Rect _selectionArea;
  Rect get selectionArea => _selectionArea;
  set selectionArea(Rect value) {
    if (_selectionArea == value) return;
    _selectionArea = value;
    markNeedsPaint();
  }

  LinkDrawData? _tempLinkDrawData;
  LinkDrawData? get tempLinkDrawData => _tempLinkDrawData;
  set tempLinkDrawData(LinkDrawData? value) {
    if (_tempLinkDrawData == value) return;
    _tempLinkDrawData = value;
    markNeedsPaint();
  }

  List<LinkDrawData> _linksData;
  List<LinkDrawData> get linksData => _linksData;
  set linksData(List<LinkDrawData> value) {
    if (_linksData == value) return;
    _linksData = value;
    markNeedsPaint();
  }

  List<NodeDrawData> _nodesData = [];
  List<NodeDrawData> get nodesData => _nodesData;
  set nodesData(List<NodeDrawData> value) {
    if (_nodesData == value) return;
    _nodesData = value;
    markNeedsLayout();
  }

  void _loadGridShader() {
    final style = this.style.gridStyle;

    gridShader.setFloat(0, style.gridSpacingX);
    gridShader.setFloat(1, style.gridSpacingY);

    final lineColor = style.lineColor;

    gridShader.setFloat(4, style.lineWidth);
    gridShader.setFloat(5, lineColor.r * lineColor.a);
    gridShader.setFloat(6, lineColor.g * lineColor.a);
    gridShader.setFloat(7, lineColor.b * lineColor.a);
    gridShader.setFloat(8, lineColor.a);

    final intersectionColor = style.intersectionColor;

    gridShader.setFloat(9, style.intersectionRadius);
    gridShader.setFloat(10, intersectionColor.r * intersectionColor.a);
    gridShader.setFloat(11, intersectionColor.g * intersectionColor.a);
    gridShader.setFloat(12, intersectionColor.b * intersectionColor.a);
    gridShader.setFloat(13, intersectionColor.a);
  }

  Set<String> visibleNodes = {};

  void shouldUpdateNodes(List<NodeDrawData> nodesData) {
    if (!_didNodesUpdate(nodesData)) {
      _updateNodes(nodesData);
      markNeedsLayout();
    }
  }

  void _updateNodes(List<NodeDrawData> nodesData) {
    _nodesData = nodesData;

    _childrenById.clear();

    RenderBox? child = firstChild;
    int index = 0;

    final nodesAsList = _controller.nodesAsList;

    while (child != null && index < nodesData.length) {
      final childParentData = child.parentData! as _ParentData;
      final nodeData = nodesData[index];

      if (childParentData.id != nodesAsList[index].id ||
          childParentData.offset != nodeData.offset ||
          childParentData.state != nodeData.state) {
        childParentData.id = nodesAsList[index].id;
        childParentData.offset = nodeData.offset;
        childParentData.state = NodeState(
          isSelected: nodeData.state.isSelected,
          isCollapsed: nodeData.state.isCollapsed,
        );
        _childrenNotLaidOut[childParentData.id] = child;
        childParentData.rect = Rect.zero;
      }

      _childrenById[childParentData.id] = child;

      child = childParentData.nextSibling;
      index++;
    }
  }

  bool _didNodesUpdate(List<NodeDrawData> nodesData) {
    if (childCount != nodesData.length) {
      return false;
    }

    RenderBox? child = firstChild;
    int index = 0;

    final nodesAsList = _controller.nodesAsList;

    while (child != null && index < nodesData.length) {
      final childParentData = child.parentData! as _ParentData;
      final nodeData = nodesData[index];

      if (childParentData.id != nodesAsList[index].id ||
          childParentData.offset != nodeData.offset ||
          childParentData.state != nodeData.state) {
        return false;
      }
      child = childParentData.nextSibling;
      index++;
    }

    return true;
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! NodeDrawData) {
      child.parentData = _ParentData();
    }
  }

  @override
  @override
  void insert(RenderBox child, {RenderBox? after}) {
    setupParentData(child);
    super.insert(child, after: after);

    final index = indexOf(child);
    final parentData = child.parentData as _ParentData;

    if (index >= 0 && index < _nodesData.length) {
      parentData.id = _nodesData[index].id;
      parentData.offset = _nodesData[index].offset;
      parentData.state = _nodesData[index].state;

      _childrenById[parentData.id] = child;
      _childrenNotLaidOut[parentData.id] = child;
    }
  }

  int indexOf(RenderBox child) {
    int index = 0;
    RenderBox? current = firstChild;

    while (current != null) {
      if (current == child) return index;
      current = childAfter(current);
      index++;
    }

    return -1;
  }

  @override
  void performLayout() {
    // TODO this method is used to get the costraints of the box and determin the dimentions
    size = constraints.biggest;

    // If the child has not been laid out yet, we need to layout it.
    // Otherwise, we only need to layout it if it's within the viewport.

    final Set<String> childrenLaidOut = {};

    for (final nodeId in _childrenNotLaidOut.keys) {
      final child = _childrenNotLaidOut[nodeId]!;
      final _ParentData childParentData = child.parentData! as _ParentData;

      child.layout(
        BoxConstraints.loose(constraints.biggest),
        parentUsesSize: true,
      );

      childParentData.rect = Rect.fromLTWH(
        childParentData.offset.dx,
        childParentData.offset.dy,
        child.size.width,
        child.size.height,
      );

      childrenLaidOut.add(childParentData.id);
    }

    for (final nodeId in childrenLaidOut) {
      _childrenNotLaidOut.remove(nodeId);
    }

    for (final nodeId in visibleNodes) {
      final child = _childrenById[nodeId];

      if (child == null) continue;

      final childParentData = child.parentData as _ParentData;

      child.layout(
        BoxConstraints.loose(constraints.biggest),
        parentUsesSize: true,
      );

      childParentData.rect = Rect.fromLTWH(
        childParentData.offset.dx,
        childParentData.offset.dy,
        child.size.width,
        child.size.height,
      );
    }

    // Here we should be updating the visibleNodes set with the nodes that are within the viewport.
    // This action is delayed until the paint method to ensure all layout operations are done.
  }

  Rect _calculateViewport() {
    return Rect.fromLTWH(
      -size.width / 2 / zoom - _offset.dx,
      -size.height / 2 / zoom - _offset.dy,
      size.width / zoom,
      size.height / zoom,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final Canvas canvas = context.canvas;

    final (viewport, startX, startY) = _prepareCanvas(canvas, size);

    if (style.gridStyle.showGrid && _offset != _lastOffset ||
        _zoom != _lastZoom) {
      _paintGrid(canvas, viewport, startX, startY);
    }

    _paintLinks(canvas);

    // Performing the update here ensures all layout operations are done.
    visibleNodes = _controller.spatialHashGrid.queryNodeIdsInArea(
      _calculateViewport().inflate(300),
    );

    final List<RenderBox> selectedChildren = [];

    // Only process children within the viewport.
    for (final nodeId in visibleNodes) {
      final child = _childrenById[nodeId];

      if (child == null) continue;

      final childParentData = child.parentData as _ParentData;

      if (childParentData.state.isSelected) {
        // Save selected nodes to paint later.
        selectedChildren.add(child);
      } else {
        // Draw shadow for unselected nodes.
        canvas.drawShadow(
          Path()
            ..addRRect(
              RRect.fromRectAndRadius(
                childParentData.rect.inflate(4),
                const Radius.circular(4),
              ),
            ),
          const ui.Color(0xC8000000),
          4,
          true,
        );

        context.paintChild(child, childParentData.offset);
      }
    }

    // Now paint all selected nodes so they appear over the others.
    for (final selectedChild in selectedChildren) {
      final childParentData = selectedChild.parentData! as _ParentData;

      canvas.drawShadow(
        Path()
          ..addRRect(
            RRect.fromRectAndRadius(
              childParentData.rect.inflate(4),
              const Radius.circular(4),
            ),
          ),
        const ui.Color(0xC8000000),
        4,
        true,
      );

      context.paintChild(selectedChild, childParentData.offset);
    }

    // We paint this after the nodes so that the temporary link is always on top
    _paintTemporaryLink(canvas);

    // Same as above, we paint this after the nodes so that the selection area is always on top
    _paintSelectionArea(canvas, viewport);

    if (kDebugMode) {
      paintDebugViewport(canvas, viewport);
      paintDebugOffset(canvas, size);
    }
  }

  (Rect, double, double) _prepareCanvas(Canvas canvas, Size size) {
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(zoom);
    canvas.translate(offset.dx, offset.dy);

    final viewport = _calculateViewport();
    final startX = _calculateStart(viewport.left, style.gridStyle.gridSpacingX);
    final startY = _calculateStart(viewport.top, style.gridStyle.gridSpacingY);

    canvas.clipRect(
      viewport,
      clipOp: ui.ClipOp.intersect,
      doAntiAlias: false,
    );

    return (viewport, startX, startY);
  }

  double _calculateStart(double viewportEdge, double gridSpacing) {
    return (viewportEdge / gridSpacing).floor() * gridSpacing;
  }

  @visibleForTesting
  void paintDebugViewport(Canvas canvas, Rect viewport) {
    final Paint debugPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke;

    // Draw the viewport rect
    canvas.drawRect(viewport, debugPaint);
  }

  @visibleForTesting
  void paintDebugOffset(Canvas canvas, Size size) {
    final Paint debugPaint = Paint()
      ..color = Colors.green.withAlpha(200)
      ..style = PaintingStyle.fill;

    // Draw the offset point
    canvas.drawCircle(Offset.zero, 5, debugPaint);
  }

  void _paintGrid(Canvas canvas, Rect viewport, double startX, double startY) {
    gridShader.setFloat(2, startX);
    gridShader.setFloat(3, startY);

    gridShader.setFloat(14, viewport.left);
    gridShader.setFloat(15, viewport.top);
    gridShader.setFloat(16, viewport.right);
    gridShader.setFloat(17, viewport.bottom);

    canvas.drawRect(
      viewport,
      Paint()
        ..shader = gridShader
        ..isAntiAlias = true,
    );
  }

  void _paintLinks(Canvas canvas) {
    for (final linkDrawData in linksData) {
      switch (linkDrawData.linkStyle.curveType) {
        case FlLinkCurveType.straight:
          _paintStraightLink(
            canvas,
            linkDrawData,
          );
          break;
        case FlLinkCurveType.bezier:
          _paintBezierLink(
            canvas,
            linkDrawData,
          );
          break;
        case FlLinkCurveType.ninetyDegree:
          _paintNinetyDegreesLink(
            canvas,
            linkDrawData,
          );
          break;
      }
    }
  }

  void _paintBezierLink(Canvas canvas, LinkDrawData drawData) {
    final path = Path()
      ..moveTo(
        drawData.outPortOffset.dx,
        drawData.outPortOffset.dy,
      );

    const double defaultOffset = 400.0;

    //  How far the bezier follows the horizontal direction before curving based on the distance between ports
    final dx = (drawData.inPortOffset.dx - drawData.outPortOffset.dx).abs();
    final controlOffset = dx < defaultOffset * 2 ? dx / 2 : defaultOffset;

    // First control point: a few pixels to the right of the output port.
    final cp1 = Offset(
      drawData.outPortOffset.dx + controlOffset,
      drawData.outPortOffset.dy,
    );

    // Second control point: a few pixels to the left of the input port.
    final cp2 = Offset(
      drawData.inPortOffset.dx - controlOffset,
      drawData.inPortOffset.dy,
    );

    path.cubicTo(
      cp1.dx,
      cp1.dy,
      cp2.dx,
      cp2.dy,
      drawData.inPortOffset.dx,
      drawData.inPortOffset.dy,
    );

    final shader = drawData.linkStyle.gradient.createShader(
      Rect.fromPoints(drawData.outPortOffset, drawData.inPortOffset),
    );

    final Paint paint = Paint()
      ..shader = shader
      ..style = PaintingStyle.stroke
      ..strokeWidth = drawData.linkStyle.lineWidth;

    canvas.drawPath(path, paint);
  }

  void drawArrowHead(
    //TODO qui ho aggiunto il painter per la creazione della testa della freccia
    Canvas canvas,
    Offset from,
    Offset to, {
    double tipLength = 10.0,
    double tipWidth = 16.0,
    Color color = const Color(0xFF000000),
    double strokeWidth = 2.0,
  }) {
    // Determina la direzione in base alle coordinate x:
    // se to.dx è maggiore di from.dx, la freccia punta a destra,
    // altrimenti a sinistra.
    final isRight = to.dx >= from.dx;
    // La coordinata y per la testa è quella del punto "to"
    final y = to.dy;

    // Creiamo il Path che rappresenta il triangolo (testa della freccia)
    final arrowPath = Path()
      ..moveTo(to.dx, to.dy); // il vertice della freccia (punta)

    if (isRight) {
      // Partendo da 'to' (la punta), disegniamo due linee separate:
      arrowPath
        ..moveTo(to.dx, y)
        ..lineTo(to.dx - tipLength, y - tipWidth / 2)
        ..moveTo(to.dx, y)
        ..lineTo(to.dx - tipLength, y + tipWidth / 2);
    } else {
      arrowPath
        ..moveTo(to.dx, y)
        ..lineTo(to.dx + tipLength, y - tipWidth / 2)
        ..moveTo(to.dx, y)
        ..lineTo(to.dx + tipLength, y + tipWidth / 2);
    }
    // Disegna la testa della freccia
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    canvas.drawPath(arrowPath, paint);
  }

  void _paintStraightLink(
    Canvas canvas,
    LinkDrawData drawData,
  ) {
    final shader = drawData.linkStyle.gradient.createShader(
      Rect.fromPoints(drawData.outPortOffset, drawData.inPortOffset),
    );

    final Paint gradientPaint = Paint()
      ..shader = shader
      ..style = PaintingStyle.stroke
      ..strokeWidth = drawData.linkStyle.lineWidth;

    canvas.drawLine(
      drawData.outPortOffset,
      drawData.inPortOffset,
      gradientPaint,
    );
  }

  void _paintNinetyDegreesLink(
    Canvas canvas,
    LinkDrawData drawData,
  ) {
    final shader = drawData.linkStyle.gradient.createShader(
      Rect.fromPoints(drawData.outPortOffset, drawData.inPortOffset),
    );

    final from = drawData.outPortOffset;
    final to = drawData.inPortOffset;
    final color = drawData.linkStyle.gradient.colors.first;

    final Paint gradientPaint = Paint()
      ..shader = shader
      ..style = PaintingStyle.stroke
      ..strokeWidth = drawData.linkStyle.lineWidth;

    final midX = (drawData.outPortOffset.dx + drawData.inPortOffset.dx) / 2;

    final path = Path()
      ..moveTo(drawData.outPortOffset.dx, drawData.outPortOffset.dy)
      ..lineTo(midX, drawData.outPortOffset.dy)
      ..lineTo(midX, drawData.inPortOffset.dy)
      ..lineTo(drawData.inPortOffset.dx, drawData.inPortOffset.dy);

    drawArrowHead(canvas, from, to, color: color);

    canvas.drawPath(path, gradientPaint);
  }

  void _paintTemporaryLink(Canvas canvas) {
    if (_tempLinkDrawData == null) return;

    switch (_tempLinkDrawData!.linkStyle.curveType) {
      case FlLinkCurveType.straight:
        _paintStraightLink(canvas, tempLinkDrawData!);
        break;
      case FlLinkCurveType.bezier:
        _paintBezierLink(canvas, tempLinkDrawData!);
        break;
      case FlLinkCurveType.ninetyDegree:
        _paintNinetyDegreesLink(canvas, tempLinkDrawData!);
        break;
    }
  }

  void _paintSelectionArea(Canvas canvas, Rect viewport) {
    if (selectionArea.isEmpty) return;

    final Paint selectionPaint = Paint()
      ..color = Colors.blue.withAlpha(50)
      ..style = PaintingStyle.fill;

    canvas.drawRect(selectionArea, selectionPaint);

    final Paint borderPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    canvas.drawRect(selectionArea, borderPaint);
  }

  @override
  bool hitTestSelf(Offset position) {
    return true;
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final Offset centeredPosition =
        position - Offset(size.width / 2, size.height / 2);
    final Offset scaledPosition = centeredPosition.scale(1 / zoom, 1 / zoom);
    final Offset transformedPosition = scaledPosition - _offset;

    for (final nodeId in visibleNodes) {
      final child = _childrenById[nodeId]!;
      final childParentData = child.parentData as _ParentData;

      final bool isHit = result.addWithPaintOffset(
        offset: childParentData.offset,
        position: transformedPosition,
        hitTest: (BoxHitTestResult result, Offset transformed) {
          return child.hitTest(result, position: transformed);
        },
      );

      if (isHit) {
        return true;
      }
    }

    return false;
  }
}
