import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';

Future<List<String>> pickAttachmentPaths(BuildContext context) async {
  final source = await showCupertinoModalPopup<ImageSource>(
    context: context,
    builder: (ctx) => CupertinoActionSheet(
      title: const Text('添加图片'),
      actions: [
        CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx, ImageSource.camera),
          child: const Text('拍照'),
        ),
        CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx, ImageSource.gallery),
          child: const Text('相册'),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.pop(ctx),
        child: const Text('取消'),
      ),
    ),
  );
  if (source == null) {
    return const [];
  }
  final picker = ImagePicker();
  if (source == ImageSource.gallery) {
    final files = await picker.pickMultiImage();
    return files.map((f) => f.path).toList(growable: false);
  }
  final file = await picker.pickImage(source: source);
  if (file == null) {
    return const [];
  }
  return [file.path];
}
