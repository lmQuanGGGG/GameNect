import 'package:flutter/material.dart';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';

class AvatarPickerSection extends StatelessWidget {
  final File? avatarImage;
  final String? avatarUrl;
  final List<File> additionalImages;
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
        // Avatar picker
        Center(
          child: GestureDetector(
            onTap: onPickAvatar,
            child: CircleAvatar(
              radius: 50,
              backgroundImage: avatarImage != null
                  ? FileImage(avatarImage!)
                  : (avatarUrl != null
                        ? CachedNetworkImageProvider(avatarUrl!)
                        : null),
              child:
                  avatarImage == null && avatarUrl == null
                  ? const Icon(
                      Icons.person,
                      size: 50,
                      color: Colors.grey,
                    )
                  : null,
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
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.add, color: Colors.white),
                  ),
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
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        image: DecorationImage(
                          image: index < additionalPhotoUrls.length
                              ? CachedNetworkImageProvider(additionalPhotoUrls[index])
                              : FileImage(additionalImages[index - additionalPhotoUrls.length]) as ImageProvider,
                          fit: BoxFit.cover,
                        ),
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
