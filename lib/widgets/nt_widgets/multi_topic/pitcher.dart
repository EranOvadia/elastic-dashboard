import 'dart:math' as math;
import 'package:dot_cast/dot_cast.dart';
import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class Pitcher extends NTWidget {
  static const String widgetType = "Pitcher";

  const Pitcher({super.key});

  @override
  Widget build(BuildContext context) {
    // Use read instead of watch at the top level
    PitcherModel model = cast(context.watch<NTWidgetModel>());
    return ListenableBuilder(
      listenable: model.subscription!,
      builder: (context, _) {
            double angleDeg = model.pitcherAngle * 180 / math.pi;

        return LayoutBuilder(
          builder: (context, constraints) {
            // Use the full available space
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;

            // Calculate size for the visualization (left side)
            final visualSize = width * 0.5;

            return Center(
              child: SizedBox(
                width: width,
                height: height,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Visualization on the left
                    SizedBox(
                      width: visualSize,
                      height: visualSize,
                      child: CustomPaint(
                        size: Size(visualSize, visualSize),
                        painter: LinePainter(model: model),
                      ),
                    ),

                    // Text on the right
                    Expanded(
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '${angleDeg.toStringAsFixed(1)}°' ,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: math.min(height * 0.5, 48),
                              fontWeight: FontWeight.bold,
                            ),
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

class PitcherModel extends SingleTopicNTWidgetModel {
  @override
  String type = Pitcher.widgetType;

  double get pitcherAngle {
    final value = subscription?.value;
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
    required String topic,
    super.dataType,
    super.period,
    super.ntStructMeta,
  }) : super.createDefault(type: Pitcher.widgetType, topic: topic);

  PitcherModel.fromJson({
    required super.ntConnection,
    required super.preferences,
    required Map<String, dynamic> jsonData,
  }) : super.fromJson(jsonData: jsonData);

  @override
  List<Widget> getEditProperties(BuildContext context) => [];
}
class LinePainter extends CustomPainter {
  final PitcherModel model;

  LinePainter({required this.model});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 1 ;

    canvas.save();
    canvas.translate(center.dx, center.dy);

    final strokeWidth = math.max(2.0, radius * 0.08);
    final arcStrokeWidth = math.max(1.5, radius * 0.06);

    final paint = Paint()
      ..color = Colors.yellow
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final paint1 = Paint()
      ..color = Colors.blue
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Input is in radians, adjust by 90 degrees (π/2 radians) to make 0° horizontal
    final double angleRad = model.pitcherAngle - (math.pi / 2);

    final startPoint = Offset(size.width * 0.35, size.height * 0.25);
    final endPoint = Offset(
      -radius * math.cos(angleRad) + startPoint.dx,
      radius * math.sin(angleRad) + startPoint.dy,
    );
    final horizontalEnd = Offset(-radius + startPoint.dx, startPoint.dy);

    // Draw pitcher arm (angled line)
    canvas.drawLine(startPoint, endPoint, paint1);

    // Draw horizontal reference line
    canvas.drawLine(startPoint, horizontalEnd, paint);

    final arcRect = Rect.fromCircle(
      center: Offset(startPoint.dx, startPoint.dy),
      radius: radius,
    );

    // Arc from horizontal upward to the pitcher angle
    canvas.drawArc(
      arcRect,
      math.pi,      // Start at horizontal left (π radians = 180°)
      -angleRad,    // Negative sweep to flip arc upward
      false,
      paint,
    );

    // Draw center point
    canvas.drawCircle(startPoint, strokeWidth, paint1);

    // Draw end point
    canvas.drawCircle(endPoint, strokeWidth, paint1);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant LinePainter oldDelegate) {
    return oldDelegate.model.pitcherAngle != model.pitcherAngle;
  }
}