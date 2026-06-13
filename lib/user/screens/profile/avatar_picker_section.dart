import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/widgets/network_image.dart';
import '../../../core/theme/theme_helper.dart';

// Dùng XFile thay File để hỗ trợ Web (dart:io File không chạy trên web)
class AvatarPickerSection extends StatelessWidget {
  final XFile? avatarImage;
  final String? avatarUrl;
  final List<XFile> additionalImages;
  final List<String> additionalPhotoUrls;
  
  final VoidCallback onPickAvatar;
  final VoidCallback onPickAdditionalPhoto;
  final Function(int) onEditAdditionalPhoto;
  final Function(int) onRemoveAdditionalPhoto;

  const AvatarPickerSection({
    super.key,
    required this.avatarImage,
    required this.avatarUrl,
    required this.additionalImages,
    required this.additionalPhotoUrls,
    required this.onPickAvatar,
    required this.onPickAdditionalPhoto,
    required this.onEditAdditionalPhoto,
    required this.onRemoveAdditionalPhoto,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Avatar picker — dùng Image.network cho web (XFile.path là blob URL)
        Center(
          child: GestureDetector(
            onTap: onPickAvatar,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey[200],
                border: Border.all(color: Colors.black, width: 3),
                boxShadow: const [
                  BoxShadow(color: Colors.black, offset: Offset(4, 4)),
                ],
              ),
              child: ClipOval(
                child: avatarImage != null
                    ? Image.network(
                        avatarImage!.path,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.person, size: 50, color: Colors.grey),
                      )
                    : (avatarUrl != null
                        ? GamenectNetworkImage(
                            imageUrl: avatarUrl!,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const Center(child: CircularProgressIndicator(color: Colors.deepOrange)),
                            errorWidget: (context, url, error) => const Icon(Icons.person, size: 50, color: Colors.black54),
                          )
                        : const Icon(Icons.person, size: 60, color: Colors.black54)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        const SizedBox(height: 12),
        Center(
          child: GestureDetector(
            onTap: onPickAvatar,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black, width: 2),
                boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(2, 2))],
              ),
              child: const Text(
                'CHỌN ẢNH ĐẠI DIỆN',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        
        // Section ảnh bổ sung
        Text(
          'Ảnh bổ sung (tối đa 4)',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.deepOrange[400],
          ),
        ),
        const SizedBox(height: 8),
        // Horizontal scroll để hiển thị và thêm ảnh bổ sung
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: additionalImages.length + additionalPhotoUrls.length + 
              (additionalImages.length + additionalPhotoUrls.length < 4 ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == additionalImages.length + additionalPhotoUrls.length &&
                  additionalImages.length + additionalPhotoUrls.length < 4) {
                return GestureDetector(
                  onTap: onPickAdditionalPhoto,
                  child: Container(
                    width: 100,
                    height: 100,
                    margin: const EdgeInsets.only(right: 12, bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black, width: 2.5),
                      boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(3, 3))],
                    ),
                    child: const Icon(Icons.add, color: Colors.black, size: 40),
                  ),
                );
              }

              Widget imageWidget;
              if (index < additionalPhotoUrls.length) {
                imageWidget = GamenectNetworkImage(
                  imageUrl: additionalPhotoUrls[index],
                  fit: BoxFit.cover,
                  width: 100,
                  height: 100,
                  placeholder: (context, url) => Container(color: Colors.grey[200]),
                  errorWidget: (context, url, error) => Container(color: Colors.grey[200], child: const Icon(Icons.broken_image, color: Colors.black54)),
                );
              } else {
                imageWidget = Image.network(
                  additionalImages[index - additionalPhotoUrls.length].path,
                  fit: BoxFit.cover,
                  width: 100,
                  height: 100,
                  errorBuilder: (context, error, stackTrace) => Container(color: Colors.grey[200], child: const Icon(Icons.broken_image, color: Colors.black54)),
                );
              }

              return Stack(
                children: [
                  GestureDetector(
                    onTap: () => onEditAdditionalPhoto(index),
                    child: Container(
                      width: 100,
                      height: 100,
                      margin: const EdgeInsets.only(right: 12, bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.black, width: 2.5),
                        boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(3, 3))],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(9),
                        child: imageWidget,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 12,
                    child: GestureDetector(
                      onTap: () => onRemoveAdditionalPhoto(index),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black, width: 2),
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.black,
                          size: 16,
                          weight: 900,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 4,
                    right: 12,
                    child: GestureDetector(
                      onTap: () => onEditAdditionalPhoto(index),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.deepOrange,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black, width: 2),
                        ),
                        child: const Icon(
                          Icons.edit,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
