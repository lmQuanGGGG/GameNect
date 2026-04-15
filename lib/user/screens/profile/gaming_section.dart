import 'package:flutter/material.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';

class GamingSection extends StatelessWidget {
  final String? rank;
  final Function(String?) onRankChanged;
  final List<String> rankOptions;
  
  final List<String> favoriteGames;
  final Function(List<String>) onFavoriteGamesChanged;
  final bool isSearching;
  final List<String> searchResultGames;
  final List<String> hotGames;
  final Function(String) onSearchGames;
  
  final int playTime;
  final Function(int) onPlayTimeChanged;
  
  final int winRate;
  final Function(int) onWinRateChanged;
  
  final String gameStyle;
  final Function(String?) onGameStyleChanged;
  final List<String> gameStyleOptions;
  
  final String lookingFor;
  final Function(String?) onLookingForChanged;
  final List<String> lookingForOptions;

  const GamingSection({
    super.key,
    required this.rank,
    required this.onRankChanged,
    required this.rankOptions,
    required this.favoriteGames,
    required this.onFavoriteGamesChanged,
    required this.isSearching,
    required this.searchResultGames,
    required this.hotGames,
    required this.onSearchGames,
    required this.playTime,
    required this.onPlayTimeChanged,
    required this.winRate,
    required this.onWinRateChanged,
    required this.gameStyle,
    required this.onGameStyleChanged,
    required this.gameStyleOptions,
    required this.lookingFor,
    required this.onLookingForChanged,
    required this.lookingForOptions,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Dropdown: Chọn rank game
        DropdownButtonFormField<String>(
          initialValue: rank,
          hint: const Text('Chọn rank'),
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.85),
          ),
          items: rankOptions
              .map((r) => DropdownMenuItem(
                    value: r,
                    child: Text(r),
                  ))
              .toList(),
          onChanged: onRankChanged,
          validator: (value) => value == null ? 'Vui lòng chọn rank' : null,
        ),
        const SizedBox(height: 16),
        
        // Section: Game yêu thích
        Text(
          "Game yêu thích (tối đa 5)",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.deepOrange[400],
          ),
        ),
        const SizedBox(height: 8),
        
        // TextField: Tìm kiếm game
        TextFormField(
          decoration: InputDecoration(
            hintText: "Tìm kiếm game...",
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.85),
          ),
          onChanged: onSearchGames,
        ),
        const SizedBox(height: 8),
        
        // MultiSelectDialogField: Chọn nhiều game
        MultiSelectDialogField<String>(
          items: (isSearching && searchResultGames.isNotEmpty
                  ? searchResultGames
                  : hotGames)
              .map((e) => MultiSelectItem(e, e))
              .toList(),
          initialValue: favoriteGames,
          title: const Text("Chọn game"),
          selectedColor: Colors.deepOrange,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.85),
            borderRadius: const BorderRadius.all(
              Radius.circular(8),
            ),
            border: Border.all(
              color: Colors.deepOrange,
              width: 2,
            ),
          ),
          buttonIcon: Icon(
            Icons.videogame_asset,
            color: Colors.deepOrange[400],
          ),
          buttonText: Text(
            "Chọn tối đa 5 game",
            style: TextStyle(
              color: Colors.deepOrange[400],
              fontSize: 16,
            ),
          ),
          onSelectionChanged: (selectedList) {
            if (selectedList.length > 5) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Chỉ được chọn tối đa 5 game!'),
                ),
              );
              selectedList.removeLast();
            }
          },
          onConfirm: (results) {
            if (results.length > 5) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Chỉ được chọn tối đa 5 game!'),
                ),
              );
              onFavoriteGamesChanged(results.sublist(0, 5));
            } else {
              onFavoriteGamesChanged(results);
            }
          },
          validator: (values) =>
              values == null || values.isEmpty ? "Chọn ít nhất 1 game" : null,
        ),
        const SizedBox(height: 16),
        
        // TextField: Thời gian chơi game/ngày
        TextFormField(
          initialValue: playTime.toString(),
          decoration: InputDecoration(
            labelText: 'Thời gian chơi (phút/ngày)',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.85),
          ),
          keyboardType: TextInputType.number,
          onChanged: (value) {
            final val = int.tryParse(value);
            if (val != null) onPlayTimeChanged(val);
          },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Vui lòng nhập thời gian chơi';
            }
            if (int.tryParse(value) == null) {
              return 'Nhập số hợp lệ';
            }
            return null;
          },
        ),
        const SizedBox(height: 14),
        
        // TextField: Tỷ lệ thắng (%)
        TextFormField(
          initialValue: winRate.toString(),
          decoration: InputDecoration(
            labelText: 'Tỷ lệ thắng (%)',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.85),
          ),
          keyboardType: TextInputType.number,
          onChanged: (value) {
            final val = int.tryParse(value);
            if (val != null) onWinRateChanged(val);
          },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Vui lòng nhập tỷ lệ thắng';
            }
            final number = int.tryParse(value);
            if (number == null) {
              return 'Nhập số hợp lệ';
            }
            if (number < 0 || number > 100) {
              return 'Tỷ lệ thắng phải từ 0 đến 100%';
            }
            return null;
          },
        ),
        const SizedBox(height: 14),
        
        // Dropdown: Mục đích tìm kiếm
        DropdownButtonFormField<String>(
          initialValue: lookingFor,
          hint: const Text('Chọn mục đích'),
          decoration: InputDecoration(
            labelText: 'Mục đích tìm kiếm',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.85),
          ),
          items: lookingForOptions
              .map((option) => DropdownMenuItem(
                    value: option,
                    child: Text(option),
                  ))
              .toList(),
          onChanged: onLookingForChanged,
        ),
        const SizedBox(height: 14),
        
        // Dropdown: Phong cách chơi game
        DropdownButtonFormField<String>(
          initialValue: gameStyle,
          hint: const Text('Chọn phong cách'),
          decoration: InputDecoration(
            labelText: 'Phong cách chơi game',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.85),
          ),
          items: gameStyleOptions
              .map((style) => DropdownMenuItem(
                    value: style,
                    child: Text(style),
                  ))
              .toList(),
          onChanged: onGameStyleChanged,
        ),
      ],
    );
  }
}
