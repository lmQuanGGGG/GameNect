import 'package:flutter/material.dart';

class IconHelper {
  static IconData getInterestIcon(String interest) {
    switch (interest) {
      case 'Anime/Manga': return Icons.auto_awesome;
      case 'Thể thao': return Icons.sports_basketball;
      case 'Du lịch': return Icons.flight;
      case 'Âm nhạc': return Icons.music_note;
      case 'Phim ảnh': return Icons.movie;
      case 'Nấu ăn': return Icons.restaurant;
      case 'Sách': return Icons.menu_book;
      case 'Công nghệ': return Icons.computer;
      case 'Thời trang': return Icons.checkroom;
      case 'Nhiếp ảnh': return Icons.camera_alt;
      case 'Gym/Thể hình': return Icons.fitness_center;
      case 'Yoga': return Icons.self_improvement;
      case 'Thiền': return Icons.spa;
      case 'Chạy bộ': return Icons.directions_run;
      case 'Leo núi': return Icons.terrain;
      case 'Podcast': return Icons.podcasts;
      case 'Game online': return Icons.videogame_asset;
      case 'Boardgame': return Icons.casino;
      case 'Karaoke': return Icons.mic;
      case 'Viết lách': return Icons.edit;
      case 'Vẽ tranh': return Icons.palette;
      default: return Icons.star;
    }
  }
}
