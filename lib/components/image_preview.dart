import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'dart:math' as math;
import '../models/image_model.dart';

class ImagePreview extends StatefulWidget {
  final ImageModel imageModel;
  final bool enableZoom;
  final bool showGrid;
  final Function(Offset)? onTap;

  const ImagePreview({
    Key? key,
    required this.imageModel,
    this.enableZoom = true,
    this.showGrid = false,
    this.onTap,
  }) : super(key: key);

  @override
  State<ImagePreview> createState() => _ImagePreviewState();
}

class _ImagePreviewState extends State<ImagePreview> {
  late PhotoViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PhotoViewController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageModel.bytes == null) {
      return const Center(
        child: Text('No image selected'),
      );
    }

    return Stack(
      children: [
        // 이미지 뷰어
        GestureDetector(
          onTapUp: (details) {
            if (widget.onTap != null) {
              widget.onTap!(details.localPosition);
            }
          },
          child: Transform.rotate(
            angle: widget.imageModel.rotation * math.pi / 180,
            child: widget.enableZoom
                ? PhotoView(
                    controller: _controller,
                    imageProvider: MemoryImage(widget.imageModel.bytes!),
                    minScale: PhotoViewComputedScale.contained,
                    maxScale: PhotoViewComputedScale.covered * 3,
                    backgroundDecoration: const BoxDecoration(
                      color: Colors.black87,
                    ),
                  )
                : Image.memory(
                    widget.imageModel.bytes!,
                    fit: BoxFit.contain,
                  ),
          ),
        ),

        // 그리드 오버레이
        if (widget.showGrid)
          IgnorePointer(
            child: CustomPaint(
              size: Size.infinite,
              painter: GridPainter(),
            ),
          ),

        // 텍스트 오버레이
        ...widget.imageModel.textOverlays.map((overlay) {
          return Positioned(
            left: overlay.x,
            top: overlay.y,
            child: Transform.rotate(
              angle: overlay.rotation * math.pi / 180,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  overlay.text,
                  style: TextStyle(
                    color: Color(overlay.color),
                    fontSize: overlay.fontSize,
                    fontFamily: overlay.fontFamily,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        offset: const Offset(1, 1),
                        blurRadius: 3,
                        color: Colors.black.withOpacity(0.8),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),

        // 필터 오버레이 표시
        if (widget.imageModel.appliedFilters.isNotEmpty)
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.auto_awesome, size: 16, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    '${widget.imageModel.appliedFilters.length} filters',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// 그리드 페인터
class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    // 3x3 그리드 그리기
    final horizontalSpacing = size.height / 3;
    final verticalSpacing = size.width / 3;

    for (int i = 1; i < 3; i++) {
      // 수평선
      canvas.drawLine(
        Offset(0, horizontalSpacing * i),
        Offset(size.width, horizontalSpacing * i),
        paint,
      );
      // 수직선
      canvas.drawLine(
        Offset(verticalSpacing * i, 0),
        Offset(verticalSpacing * i, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
