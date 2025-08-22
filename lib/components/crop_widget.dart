import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import '../models/image_model.dart'; // CropData import

class CropWidget extends StatefulWidget {
  final Uint8List imageBytes;
  final Function(CropData) onCrop;
  final double? aspectRatio;

  const CropWidget({
    Key? key,
    required this.imageBytes,
    required this.onCrop,
    this.aspectRatio,
  }) : super(key: key);

  @override
  State<CropWidget> createState() => _CropWidgetState();
}

class _CropWidgetState extends State<CropWidget> {
  late Rect _cropRect;
  late Size _imageSize;
  bool _isDragging = false;
  Offset? _dragStart;
  Corner? _resizingCorner;

  @override
  void initState() {
    super.initState();
    _initializeCropRect();
  }

  void _initializeCropRect() {
    final image = img.decodeImage(widget.imageBytes);
    if (image != null) {
      _imageSize = Size(image.width.toDouble(), image.height.toDouble());

      // Initialize crop rect to center of image
      double cropWidth = _imageSize.width * 0.8;
      double cropHeight = _imageSize.height * 0.8;

      if (widget.aspectRatio != null) {
        // Adjust for aspect ratio
        if (cropWidth / cropHeight > widget.aspectRatio!) {
          // Too wide, adjust width
          cropWidth = cropHeight * widget.aspectRatio!;
        } else {
          // Too tall, adjust height
          cropHeight = cropWidth / widget.aspectRatio!;
        }
      }

      _cropRect = Rect.fromCenter(
        center: Offset(_imageSize.width / 2, _imageSize.height / 2),
        width: cropWidth,
        height: cropHeight,
      );
    }
  }

  void _handlePanStart(DragStartDetails details) {
    final localPos = details.localPosition;

    // Check if touching a corner
    _resizingCorner = _getCornerAt(localPos);

    if (_resizingCorner != null) {
      _isDragging = false;
    } else if (_cropRect.contains(localPos)) {
      _isDragging = true;
      _dragStart = localPos - _cropRect.topLeft;
    }
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    setState(() {
      if (_isDragging && _dragStart != null) {
        // Move crop rect
        final newTopLeft = details.localPosition - _dragStart!;
        _cropRect = Rect.fromLTWH(
          newTopLeft.dx.clamp(0, _imageSize.width - _cropRect.width),
          newTopLeft.dy.clamp(0, _imageSize.height - _cropRect.height),
          _cropRect.width,
          _cropRect.height,
        );
      } else if (_resizingCorner != null) {
        // Resize crop rect
        _resizeCropRect(details.localPosition);
      }
    });
  }

  void _handlePanEnd(DragEndDetails details) {
    _isDragging = false;
    _dragStart = null;
    _resizingCorner = null;

    // Send crop data
    widget.onCrop(CropData(
      x: _cropRect.left,
      y: _cropRect.top,
      width: _cropRect.width,
      height: _cropRect.height,
    ));
  }

  Corner? _getCornerAt(Offset position) {
    const cornerSize = 30.0;

    if ((position - _cropRect.topLeft).distance < cornerSize) {
      return Corner.topLeft;
    } else if ((position - _cropRect.topRight).distance < cornerSize) {
      return Corner.topRight;
    } else if ((position - _cropRect.bottomLeft).distance < cornerSize) {
      return Corner.bottomLeft;
    } else if ((position - _cropRect.bottomRight).distance < cornerSize) {
      return Corner.bottomRight;
    }

    return null;
  }

  void _resizeCropRect(Offset position) {
    Rect newRect = _cropRect;

    switch (_resizingCorner) {
      case Corner.topLeft:
        newRect = Rect.fromLTRB(
          position.dx.clamp(0, _cropRect.right - 50),
          position.dy.clamp(0, _cropRect.bottom - 50),
          _cropRect.right,
          _cropRect.bottom,
        );
        break;
      case Corner.topRight:
        newRect = Rect.fromLTRB(
          _cropRect.left,
          position.dy.clamp(0, _cropRect.bottom - 50),
          position.dx.clamp(_cropRect.left + 50, _imageSize.width),
          _cropRect.bottom,
        );
        break;
      case Corner.bottomLeft:
        newRect = Rect.fromLTRB(
          position.dx.clamp(0, _cropRect.right - 50),
          _cropRect.top,
          _cropRect.right,
          position.dy.clamp(_cropRect.top + 50, _imageSize.height),
        );
        break;
      case Corner.bottomRight:
        newRect = Rect.fromLTRB(
          _cropRect.left,
          _cropRect.top,
          position.dx.clamp(_cropRect.left + 50, _imageSize.width),
          position.dy.clamp(_cropRect.top + 50, _imageSize.height),
        );
        break;
      default:
        break;
    }

    // Maintain aspect ratio if specified
    if (widget.aspectRatio != null && newRect != _cropRect) {
      final currentRatio = newRect.width / newRect.height;
      if ((currentRatio - widget.aspectRatio!).abs() > 0.01) {
        if (currentRatio > widget.aspectRatio!) {
          // Too wide, adjust width
          final newWidth = newRect.height * widget.aspectRatio!;
          newRect = Rect.fromLTWH(
            newRect.left,
            newRect.top,
            newWidth,
            newRect.height,
          );
        } else {
          // Too tall, adjust height
          final newHeight = newRect.width / widget.aspectRatio!;
          newRect = Rect.fromLTWH(
            newRect.left,
            newRect.top,
            newRect.width,
            newHeight,
          );
        }
      }
    }

    _cropRect = newRect;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: _handlePanStart,
      onPanUpdate: _handlePanUpdate,
      onPanEnd: _handlePanEnd,
      child: CustomPaint(
        size: _imageSize,
        painter: CropPainter(
          imageBytes: widget.imageBytes,
          cropRect: _cropRect,
        ),
      ),
    );
  }
}

class CropPainter extends CustomPainter {
  final Uint8List imageBytes;
  final Rect cropRect;

  CropPainter({
    required this.imageBytes,
    required this.cropRect,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw darkened overlay outside crop area
    final overlayPaint = Paint()..color = Colors.black.withOpacity(0.5);

    // Top
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, cropRect.top),
      overlayPaint,
    );

    // Bottom
    canvas.drawRect(
      Rect.fromLTWH(
          0, cropRect.bottom, size.width, size.height - cropRect.bottom),
      overlayPaint,
    );

    // Left
    canvas.drawRect(
      Rect.fromLTWH(0, cropRect.top, cropRect.left, cropRect.height),
      overlayPaint,
    );

    // Right
    canvas.drawRect(
      Rect.fromLTWH(cropRect.right, cropRect.top, size.width - cropRect.right,
          cropRect.height),
      overlayPaint,
    );

    // Draw crop border
    final borderPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    canvas.drawRect(cropRect, borderPaint);

    // Draw corner handles
    final cornerPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    const cornerLength = 20.0;

    // Top-left corner
    canvas.drawLine(
      cropRect.topLeft,
      cropRect.topLeft + const Offset(cornerLength, 0),
      cornerPaint,
    );
    canvas.drawLine(
      cropRect.topLeft,
      cropRect.topLeft + const Offset(0, cornerLength),
      cornerPaint,
    );

    // Top-right corner
    canvas.drawLine(
      cropRect.topRight,
      cropRect.topRight + const Offset(-cornerLength, 0),
      cornerPaint,
    );
    canvas.drawLine(
      cropRect.topRight,
      cropRect.topRight + const Offset(0, cornerLength),
      cornerPaint,
    );

    // Bottom-left corner
    canvas.drawLine(
      cropRect.bottomLeft,
      cropRect.bottomLeft + const Offset(cornerLength, 0),
      cornerPaint,
    );
    canvas.drawLine(
      cropRect.bottomLeft,
      cropRect.bottomLeft + const Offset(0, -cornerLength),
      cornerPaint,
    );

    // Bottom-right corner
    canvas.drawLine(
      cropRect.bottomRight,
      cropRect.bottomRight + const Offset(-cornerLength, 0),
      cornerPaint,
    );
    canvas.drawLine(
      cropRect.bottomRight,
      cropRect.bottomRight + const Offset(0, -cornerLength),
      cornerPaint,
    );

    // Draw grid lines
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    // Vertical lines
    final thirdWidth = cropRect.width / 3;
    canvas.drawLine(
      Offset(cropRect.left + thirdWidth, cropRect.top),
      Offset(cropRect.left + thirdWidth, cropRect.bottom),
      gridPaint,
    );
    canvas.drawLine(
      Offset(cropRect.left + thirdWidth * 2, cropRect.top),
      Offset(cropRect.left + thirdWidth * 2, cropRect.bottom),
      gridPaint,
    );

    // Horizontal lines
    final thirdHeight = cropRect.height / 3;
    canvas.drawLine(
      Offset(cropRect.left, cropRect.top + thirdHeight),
      Offset(cropRect.right, cropRect.top + thirdHeight),
      gridPaint,
    );
    canvas.drawLine(
      Offset(cropRect.left, cropRect.top + thirdHeight * 2),
      Offset(cropRect.right, cropRect.top + thirdHeight * 2),
      gridPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

enum Corner {
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
}

// CropData 클래스는 image_model.dart에서 import하므로 여기서는 정의하지 않음
