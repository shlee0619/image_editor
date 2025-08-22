import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart'
    hide ImageFilter; // 'ImageFilter' 이름 충돌을 피하기 위해 숨김 처리
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../models/image_model.dart';

class ImageService extends ChangeNotifier {
  ImageModel? _currentImage;
  List<ImageModel> _savedImages = [];
  final ImagePicker _picker = ImagePicker();

  ImageModel? get currentImage => _currentImage;
  List<ImageModel> get savedImages => _savedImages;

  // 갤러리에서 이미지 선택
  Future<bool> pickImageFromGallery() async {
    return _pickImage(ImageSource.gallery);
  }

  // 카메라로 사진 촬영
  Future<bool> pickImageFromCamera() async {
    return _pickImage(ImageSource.camera);
  }

  // 이미지 선택 로직 (갤러리/카메라 공통)
  Future<bool> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 2000,
        maxHeight: 2000,
        imageQuality: 100,
      );

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        final imageName = source == ImageSource.camera
            ? 'camera_${DateTime.now().millisecondsSinceEpoch}.jpg'
            : pickedFile.name;

        _currentImage = ImageModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          path: pickedFile.path,
          bytes: bytes,
          name: imageName,
          createdAt: DateTime.now(),
        );
        notifyListeners();
        return true;
      }
      return false;
    } catch (e, stackTrace) {
      // 오류 발생 시 스택 트레이스와 함께 로그를 남겨 디버깅을 용이하게 합니다.
      debugPrint('Error picking image from $source: $e');
      debugPrint(stackTrace.toString());
      return false;
    }
  }

  // Assets에서 이미지 로드
  Future<bool> loadImageFromAssets(String assetPath) async {
    try {
      final ByteData data = await rootBundle.load(assetPath);
      final bytes = data.buffer.asUint8List();

      _currentImage = ImageModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        bytes: bytes,
        name: assetPath.split('/').last,
        createdAt: DateTime.now(),
      );
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error loading asset image: $e');
      return false;
    }
  }

  // 이미지 회전
  void rotateImage(double angle) {
    if (_currentImage != null) {
      _currentImage = _currentImage!.copyWith(
        rotation: (_currentImage!.rotation + angle) % 360,
        modifiedAt: DateTime.now(),
      );
      notifyListeners();
    }
  }

  // 필터 적용
  void applyFilter(ImageFilter filter) {
    if (_currentImage != null) {
      final filters = List<ImageFilter>.from(_currentImage!.appliedFilters);
      filters.add(filter);
      _currentImage = _currentImage!.copyWith(
        appliedFilters: filters,
        modifiedAt: DateTime.now(),
      );
      notifyListeners();
    }
  }

  // 텍스트 추가
  void addTextOverlay(TextOverlay textOverlay) {
    if (_currentImage != null) {
      final overlays = List<TextOverlay>.from(_currentImage!.textOverlays);
      overlays.add(textOverlay);
      _currentImage = _currentImage!.copyWith(
        textOverlays: overlays,
        modifiedAt: DateTime.now(),
      );
      notifyListeners();
    }
  }

  // 크롭 데이터 설정
  void setCropData(CropData cropData) {
    if (_currentImage != null) {
      _currentImage = _currentImage!.copyWith(
        cropData: cropData,
        modifiedAt: DateTime.now(),
      );
      notifyListeners();
    }
  }

  // 편집된 이미지 처리 및 바이트 생성
  Future<Uint8List?> processImage() async {
    if (_currentImage == null || _currentImage!.bytes == null) return null;

    try {
      // 원본 이미지 디코딩
      img.Image? image = img.decodeImage(_currentImage!.bytes!);
      if (image == null) return null;

      // 회전 적용
      if (_currentImage!.rotation != 0) {
        image = img.copyRotate(image, angle: _currentImage!.rotation);
      }

      // 크롭 적용
      if (_currentImage!.cropData != null) {
        final crop = _currentImage!.cropData!;
        image = img.copyCrop(
          image,
          x: crop.x.toInt(),
          y: crop.y.toInt(),
          width: crop.width.toInt(),
          height: crop.height.toInt(),
        );
      }

      // 필터 적용
      for (final filter in _currentImage!.appliedFilters) {
        image = _applyImageFilter(image, filter);
      }

      // 처리된 이미지를 바이트로 변환
      return Uint8List.fromList(img.encodeJpg(image, quality: 95));
    } catch (e) {
      debugPrint('Error processing image: $e');
      return null;
    }
  }

  // 필터 적용 헬퍼 메서드
  img.Image _applyImageFilter(img.Image image, ImageFilter filter) {
    switch (filter.type) {
      case FilterType.brightness:
        return img.adjustColor(image, brightness: filter.intensity);
      case FilterType.contrast:
        return img.adjustColor(image, contrast: filter.intensity);
      case FilterType.saturation:
        return img.adjustColor(image, saturation: filter.intensity);
      case FilterType.sepia:
        return img.sepia(image);
      case FilterType.grayscale:
        return img.grayscale(image);
      case FilterType.vintage:
        // 빈티지 효과: 세피아 + 대비 감소
        image = img.sepia(image);
        return img.adjustColor(image, contrast: 0.8);
    }
  }

  // 이미지 저장
  Future<bool> saveImage() async {
    if (_currentImage == null) return false;

    try {
      // 처리된 이미지 바이트 가져오기
      final processedBytes = await processImage();
      if (processedBytes == null) return false;

      // 저장 경로 설정
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'edited_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = '${directory.path}/$fileName';

      // 파일 저장
      final file = File(filePath);
      await file.writeAsBytes(processedBytes);

      // 저장된 이미지 목록에 추가
      final savedImage = _currentImage!.copyWith(
        path: filePath,
        bytes: processedBytes,
        name: fileName,
        modifiedAt: DateTime.now(),
      );
      _savedImages.add(savedImage);

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error saving image: $e');
      return false;
    }
  }

  // 현재 이미지 초기화
  void clearCurrentImage() {
    _currentImage = null;
    notifyListeners();
  }

  // 저장된 이미지 목록 로드
  Future<void> loadSavedImages() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final files = directory
          .listSync()
          .whereType<File>()
          .where((file) =>
              file.path.endsWith('.jpg') || file.path.endsWith('.png'))
          .toList();

      _savedImages = [];
      for (final file in files) {
        final bytes = await file.readAsBytes();
        _savedImages.add(ImageModel(
          id: file.path.split('/').last.split('.').first,
          path: file.path,
          bytes: bytes,
          name: file.path.split('/').last,
          createdAt: file.statSync().modified,
        ));
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading saved images: $e');
    }
  }
}
