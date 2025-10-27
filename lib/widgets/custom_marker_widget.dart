import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';

class CustomMarkerWidget {
  static Future<BitmapDescriptor> createCustomMarker({
    required String text,
    required Color color,
    required bool isOnline,
    required double rating,
  }) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    
    // Marker size
    const double size = 60.0;
    
    // Draw outer circle (online indicator)
    if (isOnline) {
      final Paint onlinePaint = Paint()
        ..color = Colors.green.withOpacity(0.3)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(size / 2, size / 2), size / 2 + 5, onlinePaint);
    }
    
    // Draw main marker circle
    final Paint mainPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size / 2, size / 2), size / 2, mainPaint);
    
    // Draw border
    final Paint borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    canvas.drawCircle(Offset(size / 2, size / 2), size / 2, borderPaint);
    
    // Draw icon (donor icon)
    final TextPainter iconPainter = TextPainter(
      text: TextSpan(
        text: '🍽️',
        style: TextStyle(
          fontSize: 24,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    iconPainter.layout();
    iconPainter.paint(
      canvas,
      Offset(
        (size - iconPainter.width) / 2,
        (size - iconPainter.height) / 2 - 5,
      ),
    );
    
    // Draw rating stars
    if (rating > 0) {
      final double starSize = 8.0;
      final double starSpacing = 2.0;
      final double totalStarsWidth = (starSize + starSpacing) * 5 - starSpacing;
      final double startX = (size - totalStarsWidth) / 2;
      
      for (int i = 0; i < 5; i++) {
        final Paint starPaint = Paint()
          ..color = i < rating.round() ? Colors.amber : Colors.grey[300]!
          ..style = PaintingStyle.fill;
        
        final double starX = startX + i * (starSize + starSpacing);
        final double starY = size - 15;
        
        // Draw star shape
        final Path starPath = Path();
        starPath.moveTo(starX + starSize / 2, starY);
        starPath.lineTo(starX + starSize * 0.4, starY + starSize * 0.3);
        starPath.lineTo(starX, starY + starSize * 0.3);
        starPath.lineTo(starX + starSize * 0.2, starY + starSize * 0.6);
        starPath.lineTo(starX + starSize * 0.1, starY + starSize);
        starPath.lineTo(starX + starSize / 2, starY + starSize * 0.7);
        starPath.lineTo(starX + starSize * 0.9, starY + starSize);
        starPath.lineTo(starX + starSize * 0.8, starY + starSize * 0.6);
        starPath.lineTo(starX + starSize, starY + starSize * 0.3);
        starPath.lineTo(starX + starSize * 0.6, starY + starSize * 0.3);
        starPath.close();
        
        canvas.drawPath(starPath, starPaint);
      }
    }
    
    // Convert to image
    final ui.Image image = pictureRecorder.endRecording().toImageSync(
      (size * 2).toInt(),
      (size * 2).toInt(),
    );
    
    final ByteData? byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    
    return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
  }
  
  static Future<BitmapDescriptor> createUserLocationMarker() async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    
    const double size = 40.0;
    
    // Draw pulsing circle
    final Paint pulsePaint = Paint()
      ..color = Colors.blue.withOpacity(0.3)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size / 2, size / 2), size / 2 + 8, pulsePaint);
    
    // Draw main circle
    final Paint mainPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size / 2, size / 2), size / 2, mainPaint);
    
    // Draw border
    final Paint borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    canvas.drawCircle(Offset(size / 2, size / 2), size / 2, borderPaint);
    
    // Draw person icon
    final TextPainter iconPainter = TextPainter(
      text: TextSpan(
        text: '👤',
        style: TextStyle(
          fontSize: 20,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    iconPainter.layout();
    iconPainter.paint(
      canvas,
      Offset(
        (size - iconPainter.width) / 2,
        (size - iconPainter.height) / 2,
      ),
    );
    
    final ui.Image image = pictureRecorder.endRecording().toImageSync(
      (size * 2).toInt(),
      (size * 2).toInt(),
    );
    
    final ByteData? byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    
    return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
  }
}
