import 'dart:math' as math;
import 'package:dot_cast/dot_cast.dart';
import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:typed_data';

class Pitcher extends NTWidget {
  static const String widgetType = "Pitcher";

  const Pitcher({super.key});

  @override
  Widget build(BuildContext context) {
    PitcherModel model = cast(context.watch<NTWidgetModel>());
    return ListenableBuilder(
      listenable: Listenable.merge(model.subscriptions),
      builder: (context, _) {
        double angleDeg = model.pitcherAngle * 180 / math.pi;
        double wantedAngleDeg = model.wantedAngle * 180 / math.pi;

        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;
            final visualSize = width * 0.5;

            return Center(
              child: SizedBox(
                width: width,
                height: height,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: visualSize,
                      height: visualSize,
                      child: CustomPaint(
                        size: Size(visualSize, visualSize),
                        painter: LinePainter(model: model),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${angleDeg.toStringAsFixed(1)}°',
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontSize: math.min(height * 0.3, 36),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${wantedAngleDeg.toStringAsFixed(1)}°',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: math.min(height * 0.25, 28),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class PitcherModel extends MultiTopicNTWidgetModel {
  @override
  String type = Pitcher.widgetType;

  late NT4Subscription _positionSubscription;
  late NT4Subscription _wantedPositionSubscription;

  @override
  List<NT4Subscription> get subscriptions => [
    _positionSubscription,
    _wantedPositionSubscription,
  ];

  double get pitcherAngle => _getValue(_positionSubscription);
  double get wantedAngle => _getValue(_wantedPositionSubscription);

  double _getValue(NT4Subscription sub) {
    final value = sub.value;

    if (value is Uint8List || value is List<int>) {
      final bytes = value is Uint8List
          ? value
          : Uint8List.fromList(value as List<int>);
      if (bytes.length >= 8) {
        // Rotation2d is a single double (radians) in little-endian
        return ByteData.sublistView(bytes).getFloat64(0, Endian.little);
      }
    }

    return switch (value) {
      double v => v,
      int v => v.toDouble(),
      String v => double.tryParse(v) ?? 0.0,
      _ => 0.0,
    };
  }

  PitcherModel({
    required super.ntConnection,
    required super.preferences,
    required super.topic,
    super.period,
  }) : super();

  // ✅ KEY FIX: pass jsonData to super
  PitcherModel.fromJson({
    required super.ntConnection,
    required super.preferences,
    required Map<String, dynamic> jsonData,
  }) : super.fromJson(jsonData: jsonData);

  @override
  void initializeSubscriptions() {
    final base = topic.contains('/')
        ? topic.substring(0, topic.lastIndexOf('/'))
        : topic;

    // Try subscribing to the struct topic directly, not the /value subkey
    _positionSubscription = ntConnection.subscribe(
      '$base/position',
      super.period,
    );
    _wantedPositionSubscription = ntConnection.subscribe(
      '$base/wantedPosition',
      super.period,
    );
  }

  @override
  List<Widget> getEditProperties(BuildContext context) => [];
}

class LinePainter extends CustomPainter {
  final PitcherModel model;

  LinePainter({required this.model});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 1;

    canvas.save();
    canvas.translate(center.dx, center.dy);

    final strokeWidth = math.max(2.0, radius * 0.08);

    final actualPaint = Paint()
      ..color = Colors.blue
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final wantedPaint = Paint()
      ..color = Colors.red
      ..strokeWidth = strokeWidth * 0.7
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final refPaint = Paint()
      ..color = Colors.yellow
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final startPoint = Offset(size.width * 0.35, size.height * 0.25);

    // Draw actual angle (blue)
    final double angleRad = model.pitcherAngle - (math.pi / 2);
    final endPoint = Offset(
      -radius * math.cos(angleRad) + startPoint.dx,
      radius * math.sin(angleRad) + startPoint.dy,
    );
    canvas.drawLine(startPoint, endPoint, actualPaint);

    // Draw wanted angle (orange, dashed feel via thinner line)
    final double wantedRad = model.wantedAngle - (math.pi / 2);
    final wantedEnd = Offset(
      -radius * math.cos(wantedRad) + startPoint.dx,
      radius * math.sin(wantedRad) + startPoint.dy,
    );
    canvas.drawLine(startPoint, wantedEnd, wantedPaint);

    // Draw horizontal reference line (yellow)
    final horizontalEnd = Offset(-radius + startPoint.dx, startPoint.dy);
    canvas.drawLine(startPoint, horizontalEnd, refPaint);

    // Arc for actual angle
    final arcRect = Rect.fromCircle(
      center: Offset(startPoint.dx, startPoint.dy),
      radius: radius,
    );
    canvas.drawArc(arcRect, math.pi, -wantedRad, false, wantedPaint);
    canvas.drawArc(arcRect, math.pi, -angleRad, false, refPaint);

    // Pivot and end dots
    canvas.drawCircle(startPoint, strokeWidth, actualPaint);
    canvas.drawCircle(endPoint, strokeWidth, actualPaint);
    canvas.drawCircle(wantedEnd, strokeWidth * 0.6, wantedPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant LinePainter oldDelegate) {
    return oldDelegate.model.pitcherAngle != model.pitcherAngle ||
        oldDelegate.model.wantedAngle != model.wantedAngle;
  }
}
