import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/image_service.dart';
import '../models/image_model.dart';
import 'edit_screen.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({Key? key}) : super(key: key);

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  final List<String> _sampleImages = [
    'assets/images/sample1.jpg',
    'assets/images/sample2.jpg',
    'assets/images/sample3.jpg',
    'assets/images/sample4.jpg',
  ];

  @override
  void initState() {
    super.initState();
    // 저장된 이미지 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ImageService>().loadSavedImages();
    });
  }

  void _navigateToEditor() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const EditScreen(),
      ),
    );
  }

  void _selectImage(ImageSource source) async {
    final imageService = context.read<ImageService>();
    bool success = false;

    if (source == ImageSource.gallery) {
      success = await imageService.pickImageFromGallery();
    } else if (source == ImageSource.camera) {
      success = await imageService.pickImageFromCamera();
    }

    if (success && mounted) {
      _navigateToEditor();
    }
  }

  void _selectAssetImage(String assetPath) async {
    final imageService = context.read<ImageService>();
    final success = await imageService.loadImageFromAssets(assetPath);

    if (success && mounted) {
      _navigateToEditor();
    }
  }

  void _openSavedImage(ImageModel image) {
    context.read<ImageService>().clearCurrentImage();
    final imageService = context.read<ImageService>();
    imageService._currentImage = image;
    imageService.notifyListeners();
    _navigateToEditor();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Image Editor',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: Consumer<ImageService>(
        builder: (context, imageService, child) {
          return CustomScrollView(
            slivers: [
              // 이미지 소스 선택 섹션
              SliverToBoxAdapter(
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Choose Image Source',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _SourceCard(
                              icon: Icons.photo_library,
                              label: 'Gallery',
                              color: Colors.blue,
                              onTap: () => _selectImage(ImageSource.gallery),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _SourceCard(
                              icon: Icons.camera_alt,
                              label: 'Camera',
                              color: Colors.orange,
                              onTap: () => _selectImage(ImageSource.camera),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // 샘플 이미지 섹션
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.only(top: 8),
                  color: Colors.white,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Sample Images',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 120,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _sampleImages.length,
                          itemBuilder: (context, index) {
                            return GestureDetector(
                              onTap: () =>
                                  _selectAssetImage(_sampleImages[index]),
                              child: Container(
                                width: 120,
                                margin: const EdgeInsets.only(right: 12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color: Colors.grey[300],
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Stack(
                                    children: [
                                      // Placeholder for asset image
                                      Container(
                                        color: Colors.grey[300],
                                        child: Center(
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.image,
                                                size: 40,
                                                color: Colors.grey[600],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Sample ${index + 1}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      Positioned.fill(
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: () => _selectAssetImage(
                                                _sampleImages[index]),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 저장된 이미지 섹션
              if (imageService.savedImages.isNotEmpty)
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.only(top: 8),
                    color: Colors.white,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Edited Images',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${imageService.savedImages.length} images',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),

              // 저장된 이미지 그리드
              if (imageService.savedImages.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final image = imageService.savedImages[index];
                        return GestureDetector(
                          onTap: () => _openSavedImage(image),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  if (image.bytes != null)
                                    Image.memory(
                                      image.bytes!,
                                      fit: BoxFit.cover,
                                    )
                                  else
                                    Container(
                                      color: Colors.grey[300],
                                      child: const Icon(
                                        Icons.image,
                                        size: 50,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  Positioned(
                                    bottom: 0,
                                    left: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.bottomCenter,
                                          end: Alignment.topCenter,
                                          colors: [
                                            Colors.black.withOpacity(0.7),
                                            Colors.transparent,
                                          ],
                                        ),
                                      ),
                                      child: Text(
                                        image.name,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                      childCount: imageService.savedImages.length,
                    ),
                  ),
                ),

              const SliverPadding(padding: EdgeInsets.only(bottom: 20)),
            ],
          );
        },
      ),
    );
  }
}

// 이미지 소스 카드 위젯
class _SourceCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SourceCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [
                color.withOpacity(0.1),
                color.withOpacity(0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: color.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 40,
                color: color,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum ImageSource {
  gallery,
  camera,
}
