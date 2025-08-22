import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import '../models/image_model.dart';

class FileManagerService {
  static const String _appFolderName = 'ImageEditor';
  static const String _editedFolderName = 'Edited';
  static const String _tempFolderName = 'Temp';

  // 앱 디렉토리 초기화
  static Future<void> initializeDirectories() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();

      // 메인 폴더 생성
      final mainFolder = Directory('${appDir.path}/$_appFolderName');
      if (!await mainFolder.exists()) {
        await mainFolder.create(recursive: true);
      }

      // 편집된 이미지 폴더 생성
      final editedFolder = Directory('${mainFolder.path}/$_editedFolderName');
      if (!await editedFolder.exists()) {
        await editedFolder.create(recursive: true);
      }

      // 임시 폴더 생성
      final tempFolder = Directory('${mainFolder.path}/$_tempFolderName');
      if (!await tempFolder.exists()) {
        await tempFolder.create(recursive: true);
      }

      debugPrint('Directories initialized successfully');
    } catch (e) {
      debugPrint('Error initializing directories: $e');
    }
  }

  // Assets에서 이미지 로드
  static Future<List<ImageModel>> loadAssetImages() async {
    final List<ImageModel> images = [];

    try {
      // AssetManifest 로드
      final manifestContent = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifestMap = {};

      // assets/images/ 경로의 이미지들 필터링
      final imagePaths = manifestMap.keys
          .where((String key) => key.startsWith('assets/images/'))
          .where((String key) =>
              key.endsWith('.jpg') ||
              key.endsWith('.jpeg') ||
              key.endsWith('.png'))
          .toList();

      // 각 이미지 로드
      for (final path in imagePaths) {
        try {
          final ByteData data = await rootBundle.load(path);
          final bytes = data.buffer.asUint8List();

          images.add(ImageModel(
            id: path.hashCode.toString(),
            bytes: bytes,
            name: path.split('/').last,
            createdAt: DateTime.now(),
          ));
        } catch (e) {
          debugPrint('Error loading asset image $path: $e');
        }
      }
    } catch (e) {
      debugPrint('Error loading asset images: $e');

      // 기본 샘플 이미지 제공 (에러 시)
      for (int i = 1; i <= 4; i++) {
        images.add(ImageModel(
          id: 'sample_$i',
          name: 'Sample $i',
          createdAt: DateTime.now(),
        ));
      }
    }

    return images;
  }

  // 편집된 이미지 저장
  static Future<SaveResult> saveEditedImage({
    required Uint8List imageBytes,
    required String fileName,
    bool saveToGallery = false,
  }) async {
    try {
      // 저장 권한 확인
      if (saveToGallery) {
        final status = await _requestStoragePermission();
        if (!status) {
          return SaveResult(
            success: false,
            message: 'Storage permission denied',
          );
        }
      }

      // 파일명 생성
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final processedFileName = fileName.isEmpty
          ? 'edited_$timestamp.jpg'
          : '${fileName.replaceAll('.jpg', '').replaceAll('.png', '')}_$timestamp.jpg';

      // 앱 내부 저장
      final appDir = await getApplicationDocumentsDirectory();
      final editedPath = '${appDir.path}/$_appFolderName/$_editedFolderName';
      final file = File('$editedPath/$processedFileName');

      await file.writeAsBytes(imageBytes);

      // 갤러리에도 저장
      String? galleryPath;
      if (saveToGallery) {
        galleryPath = await _saveToGallery(imageBytes, processedFileName);
      }

      return SaveResult(
        success: true,
        filePath: file.path,
        galleryPath: galleryPath,
        message: 'Image saved successfully',
      );
    } catch (e) {
      debugPrint('Error saving image: $e');
      return SaveResult(
        success: false,
        message: 'Failed to save image: $e',
      );
    }
  }

  // 갤러리에 저장
  static Future<String?> _saveToGallery(
    Uint8List imageBytes,
    String fileName,
  ) async {
    try {
      Directory? directory;

      if (Platform.isAndroid) {
        // Android: Pictures 폴더에 저장
        directory = Directory('/storage/emulated/0/Pictures/ImageEditor');
        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }
      } else if (Platform.isIOS) {
        // iOS: Documents 디렉토리 사용
        directory = await getApplicationDocumentsDirectory();
      }

      if (directory != null) {
        final file = File('${directory.path}/$fileName');
        await file.writeAsBytes(imageBytes);
        return file.path;
      }

      return null;
    } catch (e) {
      debugPrint('Error saving to gallery: $e');
      return null;
    }
  }

  // 저장된 이미지 목록 가져오기
  static Future<List<ImageModel>> getSavedImages() async {
    final List<ImageModel> images = [];

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final editedDir =
          Directory('${appDir.path}/$_appFolderName/$_editedFolderName');

      if (await editedDir.exists()) {
        final files = editedDir
            .listSync()
            .whereType<File>()
            .where((file) =>
                file.path.endsWith('.jpg') || file.path.endsWith('.png'))
            .toList();

        // 수정 시간 기준 정렬 (최신 순)
        files.sort(
            (a, b) => b.statSync().modified.compareTo(a.statSync().modified));

        for (final file in files) {
          try {
            final bytes = await file.readAsBytes();
            final stat = file.statSync();

            images.add(ImageModel(
              id: file.path.hashCode.toString(),
              path: file.path,
              bytes: bytes,
              name: file.path.split('/').last,
              createdAt: stat.modified,
              modifiedAt: stat.modified,
            ));
          } catch (e) {
            debugPrint('Error loading saved image: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('Error getting saved images: $e');
    }

    return images;
  }

  // 이미지 삭제
  static Future<bool> deleteImage(String imagePath) async {
    try {
      final file = File(imagePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error deleting image: $e');
      return false;
    }
  }

  // 임시 파일 저장
  static Future<String?> saveTempFile(Uint8List imageBytes) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final tempPath = '${appDir.path}/$_appFolderName/$_tempFolderName';
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('$tempPath/temp_$timestamp.jpg');

      await file.writeAsBytes(imageBytes);
      return file.path;
    } catch (e) {
      debugPrint('Error saving temp file: $e');
      return null;
    }
  }

  // 임시 파일 정리
  static Future<void> clearTempFiles() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final tempDir =
          Directory('${appDir.path}/$_appFolderName/$_tempFolderName');

      if (await tempDir.exists()) {
        final files = tempDir.listSync().whereType<File>();
        for (final file in files) {
          await file.delete();
        }
      }
    } catch (e) {
      debugPrint('Error clearing temp files: $e');
    }
  }

  // 이미지 공유
  static Future<void> shareImage(String imagePath, {String? text}) async {
    try {
      final file = File(imagePath);
      if (await file.exists()) {
        await Share.shareXFiles(
          [XFile(imagePath)],
          text: text ?? 'Check out my edited image!',
        );
      }
    } catch (e) {
      debugPrint('Error sharing image: $e');
    }
  }

  // 저장 권한 요청
  static Future<bool> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;

      if (androidInfo.version.sdkInt >= 33) {
        // Android 13 이상: 미디어 권한
        final photos = await Permission.photos.request();
        return photos.isGranted;
      } else {
        // Android 12 이하: 저장소 권한
        final storage = await Permission.storage.request();
        return storage.isGranted;
      }
    } else if (Platform.isIOS) {
      final photos = await Permission.photos.request();
      return photos.isGranted;
    }

    return true;
  }

  // 이미지 메타데이터 가져오기
  static Future<ImageMetadata?> getImageMetadata(String imagePath) async {
    try {
      final file = File(imagePath);
      if (!await file.exists()) return null;

      final stat = await file.stat();
      final bytes = await file.readAsBytes();

      // 이미지 디코딩하여 크기 정보 얻기
      final image = await decodeImageFromList(bytes);

      return ImageMetadata(
        path: imagePath,
        fileName: imagePath.split('/').last,
        fileSize: stat.size,
        width: image.width,
        height: image.height,
        createdDate: stat.modified,
        modifiedDate: stat.modified,
      );
    } catch (e) {
      debugPrint('Error getting image metadata: $e');
      return null;
    }
  }
}

// 저장 결과 클래스
class SaveResult {
  final bool success;
  final String? filePath;
  final String? galleryPath;
  final String message;

  SaveResult({
    required this.success,
    this.filePath,
    this.galleryPath,
    required this.message,
  });
}

// 이미지 메타데이터 클래스
class ImageMetadata {
  final String path;
  final String fileName;
  final int fileSize;
  final int width;
  final int height;
  final DateTime createdDate;
  final DateTime modifiedDate;

  ImageMetadata({
    required this.path,
    required this.fileName,
    required this.fileSize,
    required this.width,
    required this.height,
    required this.createdDate,
    required this.modifiedDate,
  });

  String get formattedSize {
    if (fileSize < 1024) {
      return '$fileSize B';
    } else if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }
}
