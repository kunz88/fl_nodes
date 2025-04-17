import 'package:fl_nodes/src/core/models/entities.dart';
import 'package:flutter/material.dart';

class FlGridStyle { // TODO classi per la costumizzazione dei nodi, delle freccie e della griglia
  final double gridSpacingX;
  final double gridSpacingY;
  final double lineWidth;
  final Color lineColor;
  final Color intersectionColor;
  final double intersectionRadius;
  final bool showGrid;

  const FlGridStyle({
    this.gridSpacingX = 64.0,
    this.gridSpacingY = 64.0,
    this.lineWidth = 1.0,
    this.lineColor = const Color.fromARGB(0, 50, 47, 53),
    this.intersectionColor = const Color(0xFF322F35),
    this.intersectionRadius = 1,
    this.showGrid = true,
  });

  FlGridStyle copyWith({
    double? gridSpacingX,
    double? gridSpacingY,
    double? lineWidth,
    Color? lineColor,
    Color? intersectionColor,
    double? intersectionRadius,
    bool? showGrid,
  }) {
    return FlGridStyle(
      gridSpacingX: gridSpacingX ?? this.gridSpacingX,
      gridSpacingY: gridSpacingY ?? this.gridSpacingY,
      lineWidth: lineWidth ?? this.lineWidth,
      lineColor: lineColor ?? this.lineColor,
      intersectionColor: intersectionColor ?? this.intersectionColor,
      intersectionRadius: intersectionRadius ?? this.intersectionRadius,
      showGrid: showGrid ?? this.showGrid,
    );
  }
}

enum FlLinkCurveType {
  straight,
  bezier,
  ninetyDegree,
}

enum FlLinkDrawMode {
  solid,
  dashed,
  dotted,
}

class FlLinkStyle {
  final LinearGradient gradient;
  final double lineWidth;
  final FlLinkDrawMode drawMode;
  final FlLinkCurveType curveType;

  const FlLinkStyle({
    required this.gradient,
    required this.lineWidth,
    required this.drawMode,
    required this.curveType,
  });

  FlLinkStyle copyWith({
    LinearGradient? gradient,
    double? lineWidth,
    FlLinkDrawMode? drawMode,
    FlLinkCurveType? curveType,
  }) {
    return FlLinkStyle(
      gradient: gradient ?? this.gradient,
      lineWidth: lineWidth ?? this.lineWidth,
      drawMode: drawMode ?? this.drawMode,
      curveType: curveType ?? this.curveType,
    );
  }
}

typedef FlLinkStyleBuilder = FlLinkStyle Function(LinkState style);

FlLinkStyle defaultLinkStyle(LinkState state) {
  return const FlLinkStyle(
    gradient: LinearGradient(
      colors: [Color(0xFF29303E), Color(0xFF29303E)],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    ),
    lineWidth: 2.0,
    drawMode: FlLinkDrawMode.solid,
    curveType: FlLinkCurveType.ninetyDegree,
  );
}

enum FlPortShape {
  circle,
  triangle,
  square,
}

class FlPortStyle {
  final FlPortShape shape;
  final Color color;
  final FlLinkStyleBuilder linkStyleBuilder;

  const FlPortStyle({
    this.shape = FlPortShape.square,
    this.color = Colors.blue,
    this.linkStyleBuilder = defaultLinkStyle,
  });

  FlPortStyle copyWith({
    FlPortShape? shape,
    Color? color,
    FlLinkStyleBuilder? linkStyleBuilder,
  }) {
    return FlPortStyle(
      shape: shape ?? this.shape,
      color: color ?? this.color,
      linkStyleBuilder: linkStyleBuilder ?? this.linkStyleBuilder,
    );
  }
}

/* class FlFieldStyle {
  final BoxDecoration decoration;
  final EdgeInsetsGeometry padding;

  const FlFieldStyle({
    this.decoration = const BoxDecoration(
      color: Color(0xFF424242),
      borderRadius: BorderRadius.all(Radius.circular(8)),
    ),
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  });

  FlFieldStyle copyWith({
    BoxDecoration? decoration,
    EdgeInsetsGeometry? padding,
  }) {
    return FlFieldStyle(
      decoration: decoration ?? this.decoration,
      padding: padding ?? this.padding,
    );
  }
} */

class FlNodeHeaderStyle {
  final EdgeInsets padding;
  final BoxDecoration decoration;
  final TextStyle textStyle;
  final IconData? iconAvatar;
  final Color iconColor;
  final Color backgroundColorIconContainer;

  const FlNodeHeaderStyle({
    required this.padding,
    required this.decoration,
    required this.textStyle,
    required this.iconAvatar,
    required this.iconColor,
    required this.backgroundColorIconContainer,
  });

  FlNodeHeaderStyle copyWith({
    EdgeInsets? padding,
    BoxDecoration? decoration,
    TextStyle? textStyle,
    IconData? icon,
  }) {
    return FlNodeHeaderStyle(
      padding: padding ?? this.padding,
      decoration: decoration ?? this.decoration,
      textStyle: textStyle ?? this.textStyle,
      iconAvatar: icon ?? iconAvatar,
      iconColor: iconColor,
      backgroundColorIconContainer: backgroundColorIconContainer,
    );
  }
}

typedef FlNodeHeaderStyleBuilder = FlNodeHeaderStyle Function(NodeState style);

FlNodeHeaderStyle defaultNodeHeaderStyle(NodeState state) {
  return FlNodeHeaderStyle(
    iconColor: Colors.white,
    backgroundColorIconContainer: const Color.fromRGBO(255, 255, 255, 0.16),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xFF322F35),
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(7),
        topRight: Radius.circular(7),
      ),
      border: Border.all(color: const Color(0xffDDE0E1), width: 1),
    ),
    textStyle: const TextStyle(
      color: Colors.white,
      fontSize: 16,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.15,
      height: 1.4,
    ),
    iconAvatar: Icons.add,
  );
}

class FlNodeStyle {
  final BoxDecoration decoration;
  final FlNodeHeaderStyleBuilder headerStyleBuilder;

  const FlNodeStyle({
    required this.decoration,
    required this.headerStyleBuilder,
  });

  FlNodeStyle copyWith({
    BoxDecoration? decoration,
    FlNodeHeaderStyleBuilder? headerStyleBuilder,
  }) {
    return FlNodeStyle(
      decoration: decoration ?? this.decoration,
      headerStyleBuilder: headerStyleBuilder ?? this.headerStyleBuilder,
    );
  }
}

typedef FlNodeStyleBuilder = FlNodeStyle Function(NodeState style);

FlNodeStyle defaultNodeStyle(NodeState state) {
  return FlNodeStyle(
    decoration: state.isSelected
        ? const BoxDecoration(
            color: Color(0xC7616161),
            borderRadius: BorderRadius.all(Radius.circular(10)),
          )
        : const BoxDecoration(
            color: Color(0xC8424242),
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
    headerStyleBuilder: defaultNodeHeaderStyle,
  );
}

class FlNodeEditorStyle {
  final BoxDecoration decoration;
  final EdgeInsetsGeometry padding;
  final FlGridStyle gridStyle;

  const FlNodeEditorStyle({
    this.decoration = const BoxDecoration(
      color: Colors.black12,
    ),
    this.padding = const EdgeInsets.all(8.0),
    this.gridStyle = const FlGridStyle(),
  });

  FlNodeEditorStyle copyWith({
    BoxDecoration? decoration,
    EdgeInsetsGeometry? padding,
    FlGridStyle? gridStyle,
  }) {
    return FlNodeEditorStyle(
      decoration: decoration ?? this.decoration,
      padding: padding ?? this.padding,
      gridStyle: gridStyle ?? this.gridStyle,
    );
  }
}
