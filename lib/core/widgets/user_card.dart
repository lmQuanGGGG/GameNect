import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/user_model.dart';

class UserCard extends StatelessWidget {
  final UserModel user;
  final VoidCallback? onLike;
  final VoidCallback? onDislike;

  const UserCard({
    super.key,
    required this.user,
    this.onLike,
    this.onDislike,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 8,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ảnh đại diện
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: CachedNetworkImage(
              imageUrl: user.avatarUrl ?? '',
              height: 260,
              width: double.infinity,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                height: 260,
                color: Colors.grey[200],
                child: const Center(child: CircularProgressIndicator()),
              ),
              errorWidget: (context, url, error) => Container(
                height: 260,
                color: Colors.grey[200],
                child: const Icon(Icons.person, size: 80, color: Colors.grey),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.username,
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text('${user.age} tuổi • ${user.gender} • ${user.rank}',
                    style: TextStyle(fontSize: 16, color: Colors.grey[700])),
                const SizedBox(height: 10),
                Text(user.bio, style: const TextStyle(fontSize: 15, color: Colors.black87)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: user.favoriteGames.map((g) => Chip(label: Text(g))).toList(),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: user.interests.map((i) => Chip(label: Text(i), backgroundColor: Colors.blue[50])).toList(),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red, size: 32),
                      onPressed: onDislike,
                    ),
                    IconButton(
                      icon: const Icon(Icons.favorite, color: Colors.deepOrange, size: 32),
                      onPressed: onLike,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}