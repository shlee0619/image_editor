import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/image_service.dart';
import '../services/file_manager_service.dart';
import '../components/image_preview.dart';
import '../components/edit_tool_button.dart';
import '../components/save_button.dart';
import '../components/save_dialog.dart';
import '../components/filter_selector.dart';
import '../components/text_editor.dart';
import '../components/crop_widget.dart';
import '../models/image_model.dart';

class EditScreen extends StatefulWidget {
  const EditScreen({Key? key}) : super(key: key);

  @override
  State<EditScreen> createState() => _EditScreenState();
}

class _EditScreenState extends State<EditScreen> with TickerProviderStateMixin {
  EditTool? _selectedTool;
  bool _isSaving = false;
  bool _showGrid = false;

  // 애니메이션 컨트롤러
  late AnimationController _toolbarAnimationController;
  late Animation<Offset> _toolbarAnimation;

  // Undo/Redo 스택
  final List<ImageModel> _historyStack = [];
  int _historyIndex = -1;

  @override
  void initState() {
    super.initState();

    _toolbarAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _toolbarAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _toolbarAnimationController,
      curve: Curves.easeOut,
    ));

    _toolbarAnimationController.forward();

    // 초기 상태 저장
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final imageService = context.read<ImageService>();
      if (imageService.currentImage != null) {
        _addToHistory(imageService.currentImage!);
      }
    });
  }

  @override
  void dispose() {
    _toolbarAnimationController.dispose();
    super.dispose();
  }

  void _addToHistory(ImageModel image) {
    // 현재 인덱스 이후의 히스토리 제거
    if (_historyIndex < _historyStack.length - 1) {
      _historyStack.removeRange(_historyIndex + 1, _historyStack.length);
    }

    _historyStack.add(image);
    _historyIndex++;

    // 히스토리 크기 제한 (메모리 관리)
    if (_historyStack.length > 20) {
      _historyStack.removeAt(0);
      _historyIndex--;
    }
  }

  void _undo() {
    if (_historyIndex > 0) {
      _historyIndex--;
      final imageService = context.read<ImageService>();
      imageService._currentImage = _historyStack[_historyIndex];
      imageService.notifyListeners();
    }
  }

  void _redo() {
    if (_historyIndex < _historyStack.length - 1) {
      _historyIndex++;
      final imageService = context.read<ImageService>();
      imageService._currentImage = _historyStack[_historyIndex];
      imageService.notifyListeners();
    }
  }

  void _handleToolSelection(EditTool tool) {
    setState(() {
      _selectedTool = _selectedTool == tool ? null : tool;
      _showGrid = tool == EditTool.crop;
    });

    // 도구별 처리
    _showToolInterface(tool);
  }

  void _showToolInterface(EditTool tool) {
    switch (tool) {
      case EditTool.rotate:
        _showRotateOptions();
        break;
      case EditTool.crop:
        _showCropInterface();
        break;
      case EditTool.filter:
        _showFilterSelector();
        break;
      case EditTool.text:
        _showTextEditor();
        break;
      default:
        break;
    }
  }

  void _showRotateOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _RotateOptionsSheet(
        onRotate: (angle) {
          final imageService = context.read<ImageService>();
          imageService.rotateImage(angle);
          _addToHistory(imageService.currentImage!);
        },
      ),
    );
  }

  void _showCropInterface() {
    final imageService = context.read<ImageService>();
    if (imageService.currentImage?.bytes == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            AppBar(
              title: const Text('Crop Image'),
              backgroundColor: Colors.transparent,
              elevation: 0,
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Done'),
                ),
              ],
            ),
            Expanded(
              child: CropWidget(
                imageBytes: imageService.currentImage!.bytes!,
                onCrop: (cropData) {
                  imageService.setCropData(cropData);
                  _addToHistory(imageService.currentImage!);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterSelector() {
    final imageService = context.read<ImageService>();
    if (imageService.currentImage?.bytes == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => FilterSelector(
        originalImage: imageService.currentImage!.bytes!,
        onFilterSelected: (filter) {
          imageService.applyFilter(filter);
          _addToHistory(imageService.currentImage!);
        },
      ),
    );
  }

  void _showTextEditor() {
    final imageService = context.read<ImageService>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: TextEditor(
          imageSize: const Size(300, 400), // Default size
          onTextAdded: (textOverlay) {
            imageService.addTextOverlay(textOverlay);
            _addToHistory(imageService.currentImage!);
          },
        ),
      ),
    );
  }

  Future<void> _saveImage() async {
    showDialog(
      context: context,
      builder: (context) => SaveDialog(
        onSave: (fileName, saveToGallery) async {
          setState(() {
            _isSaving = true;
          });

          final imageService = context.read<ImageService>();
          final processedBytes = await imageService.processImage();

          if (processedBytes != null) {
            final result = await FileManagerService.saveEditedImage(
              imageBytes: processedBytes,
              fileName: fileName,
              saveToGallery: saveToGallery,
            );

            setState(() {
              _isSaving = false;
            });

            if (result.success && mounted) {
              _showSaveSuccessDialog(result);
            } else if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(result.message),
                  backgroundColor: Colors.red,
                ),
              );
            }
          } else {
            setState(() {
              _isSaving = false;
            });
          }
        },
      ),
    );
  }

  void _showSaveSuccessDialog(SaveResult result) {
    showDialog(
      context: context,
      builder: (context) => SaveSuccessDialog(
        imagePath: result.filePath ?? '',
        onClose: () {
          Navigator.pop(context);
          Navigator.pop(context);
        },
        onShare: () {
          if (result.filePath != null) {
            FileManagerService.shareImage(result.filePath!);
          }
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // 편집 내용이 있으면 확인 다이얼로그 표시
        if (_historyStack.length > 1) {
          final shouldPop = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Discard Changes?'),
              content: const Text(
                  'You have unsaved changes. Do you want to discard them?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Discard'),
                ),
              ],
            ),
          );
          return shouldPop ?? false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: const Text('Edit Image'),
          actions: [
            // Undo button
            IconButton(
              icon: Icon(
                Icons.undo,
                color: _historyIndex > 0 ? Colors.white : Colors.grey,
              ),
              onPressed: _historyIndex > 0 ? _undo : null,
            ),
            // Redo button
            IconButton(
              icon: Icon(
                Icons.redo,
                color: _historyIndex < _historyStack.length - 1
                    ? Colors.white
                    : Colors.grey,
              ),
              onPressed:
                  _historyIndex < _historyStack.length - 1 ? _redo : null,
            ),
            // Settings button
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                _showSettingsDialog();
              },
            ),
          ],
        ),
        body: Consumer<ImageService>(
          builder: (context, imageService, child) {
            if (imageService.currentImage == null) {
              return const Center(
                child: Text(
                  'No image selected',
                  style: TextStyle(color: Colors.white),
                ),
              );
            }

            return Stack(
              children: [
                // Image preview
                Positioned.fill(
                  child: ImagePreview(
                    imageModel: imageService.currentImage!,
                    showGrid: _showGrid,
                    onTap: _selectedTool == EditTool.text
                        ? (offset) {
                            // Handle text placement
                          }
                        : null,
                  ),
                ),

                // Bottom toolbar
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: SlideTransition(
                    position: _toolbarAnimation,
                    child: EditToolBar(
                      selectedTool: _selectedTool,
                      onToolSelected: _handleToolSelection,
                    ),
                  ),
                ),

                // Save button
                Positioned(
                  top: 20,
                  right: 20,
                  child: SaveButton(
                    onSave: _saveImage,
                    isLoading: _isSaving,
                    icon: Icons.save,
                  ),
                ),

                // Loading overlay
                if (_isSaving)
                  Container(
                    color: Colors.black54,
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.high_quality),
              title: const Text('Export Quality'),
              subtitle: const Text('High'),
              onTap: () {
                // Implement quality settings
              },
            ),
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text('About'),
              onTap: () {
                Navigator.pop(context);
                _showAboutDialog();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'Image Editor Pro',
      applicationVersion: '1.0.0',
      applicationIcon: const Icon(Icons.photo_camera_back, size: 48),
      children: const [
        Text('A powerful image editing app built with Flutter.'),
        SizedBox(height: 8),
        Text('© 2024 Image Editor Pro'),
      ],
    );
  }
}

// 회전 옵션 시트
class _RotateOptionsSheet extends StatelessWidget {
  final Function(double) onRotate;

  const _RotateOptionsSheet({required this.onRotate});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Rotate Image',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _RotateButton(
                label: '90°',
                icon: Icons.rotate_right,
                onTap: () {
                  onRotate(90);
                  Navigator.pop(context);
                },
              ),
              _RotateButton(
                label: '-90°',
                icon: Icons.rotate_left,
                onTap: () {
                  onRotate(-90);
                  Navigator.pop(context);
                },
              ),
              _RotateButton(
                label: '180°',
                icon: Icons.flip,
                onTap: () {
                  onRotate(180);
                  Navigator.pop(context);
                },
              ),
              _RotateButton(
                label: 'Reset',
                icon: Icons.refresh,
                onTap: () {
                  onRotate(0);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _RotateButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _RotateButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 28),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
