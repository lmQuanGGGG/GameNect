import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
            child: ClipOval(
              child: SizedBox(
                width: 100,
                height: 100,
                child: avatarImage != null
                    ? Image.network(
                        avatarImage!.path,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.person, size: 50, color: Colors.grey),
                      )
                    : (avatarUrl != null
                        ? CachedNetworkImage(
                            imageUrl: avatarUrl!,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const Center(child: CircularProgressIndicator(color: Colors.deepOrange)),
                            errorWidget: (context, url, error) => Icon(Icons.person, size: 50, color: context.textColor.withValues(alpha: 0.5)),
                          )
                        : Container(
                            color: context.isDarkMode ? Colors.white.withValues(alpha: 0.05) : Colors.grey[200],
                            child: Icon(Icons.person, size: 50, color: context.textColor.withValues(alpha: 0.5)),
                          )),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: TextButton(
            onPressed: onPickAvatar,
            child: Text(
              'Chọn ảnh đại diện',
              style: TextStyle(
                color: Colors.deepOrange[400],
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
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: context.isDarkMode ? Colors.white.withValues(alpha: 0.08) : Colors.grey[300],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.add, color: context.isDarkMode ? Colors.white54 : Colors.white),
                  ),
                );
              }

              Widget imageWidget;
              if (index < additionalPhotoUrls.length) {
                imageWidget = CachedNetworkImage(
                  imageUrl: additionalPhotoUrls[index],
                  fit: BoxFit.cover,
                  width: 100,
                  height: 100,
                  placeholder: (context, url) => Container(color: context.isDarkMode ? Colors.white.withValues(alpha: 0.05) : Colors.grey[300]),
                  errorWidget: (context, url, error) => Container(color: context.isDarkMode ? Colors.white.withValues(alpha: 0.05) : Colors.grey[300], child: Icon(Icons.broken_image, color: context.textColor.withValues(alpha: 0.3))),
                );
              } else {
                imageWidget = Image.network(
                  additionalImages[index - additionalPhotoUrls.length].path,
                  fit: BoxFit.cover,
                  width: 100,
                  height: 100,
                  errorBuilder: (context, error, stackTrace) => Container(color: context.isDarkMode ? Colors.white.withValues(alpha: 0.05) : Colors.grey[300], child: Icon(Icons.broken_image, color: context.textColor.withValues(alpha: 0.3))),
                );
              }

              return Stack(
                children: [
                  GestureDetector(
                    onTap: () => onEditAdditionalPhoto(index),
                    child: Container(
                      width: 100,
                      height: 100,
                      margin: const EdgeInsets.only(right: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
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
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 16,
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
                        decoration: const BoxDecoration(
                          color: Colors.deepOrange,
                          shape: BoxShape.circle,
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
