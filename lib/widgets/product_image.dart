import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/api_base_url.dart';

class ProductImage extends StatelessWidget {
  const ProductImage({
    super.key,
    this.url,
    this.bytes,
    this.title = '',
    this.width = 64,
    this.height = 64,
  });
  final String? url;
  final Uint8List? bytes;
  final String title;
  final double width, height;

  String? get resolvedUrl {
    final value = url?.trim();
    if (value == null || value.isEmpty) return null;
    final normalized = value.replaceAll('\\', '/');
    final path = normalized.startsWith('UPLOAD/IMAGES/')
        ? '/uploads/images/${normalized.split('/').last}'
        : normalized;
    return Uri.parse(getBaseUrl()).resolve(path).toString();
  }

  Widget _image(BoxFit fit) {
    Widget failure(BuildContext context, Object error, StackTrace? stack) =>
        const Center(
          child: Icon(Icons.broken_image_outlined, color: Colors.grey),
        );
    if (bytes != null)
      return Image.memory(bytes!, fit: fit, errorBuilder: failure);
    if (resolvedUrl != null)
      return Image.network(resolvedUrl!, fit: fit, errorBuilder: failure);
    return const Center(
      child: Icon(Icons.inventory_2_outlined, color: Colors.grey),
    );
  }

  @override
  Widget build(BuildContext context) => Tooltip(
    message: resolvedUrl != null || bytes != null
        ? '点击放大 / Enlarge image'
        : '暂无图片',
    child: InkWell(
      onTap: resolvedUrl == null && bytes == null
          ? null
          : () => showDialog<void>(
              context: context,
              builder: (context) => Dialog(
                child: SizedBox(
                  width: 900,
                  height: MediaQuery.sizeOf(context).height * .85,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              tooltip: '关闭 / Close',
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: InteractiveViewer(
                          minScale: .5,
                          maxScale: 6,
                          child: SizedBox.expand(child: _image(BoxFit.contain)),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.all(10),
                        child: Text('滚轮或双指缩放，拖动查看 / Zoom and drag'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: width,
          height: height,
          color: Colors.grey.shade100,
          child: _image(BoxFit.contain),
        ),
      ),
    ),
  );
}
