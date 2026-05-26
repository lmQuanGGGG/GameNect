import 'package:flutter/material.dart';
import 'package:dropdown_search/dropdown_search.dart';
import '../../../core/theme/theme_helper.dart';

class GamingSection extends StatelessWidget {
  final String? rank;
  final Function(String?) onRankChanged;
  final List<String> rankOptions;
  
  final List<String> favoriteGames;
  final Function(List<String>) onFavoriteGamesChanged;
  final List<String> hotGames;
  final Future<List<String>> Function(String) onSearchGamesAsync;
  
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
    required this.hotGames,
    required this.onSearchGamesAsync,
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
    final fieldFillColor = context.isDarkMode
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.white.withValues(alpha: 0.85);
    final fieldStyle = TextStyle(
      color: context.textColor,
      fontSize: 16,
    );
    final labelStyle = TextStyle(color: context.textSecondaryColor);
    final hintStyle = TextStyle(color: context.textTertiaryColor);
    
    final enabledBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: context.isDarkMode ? Colors.white24 : Colors.grey.shade400),
    );
    final focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Colors.deepOrange, width: 2),
    );
    final errorBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Colors.redAccent, width: 1),
    );
    final focusedErrorBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Colors.redAccent, width: 2),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Dropdown: Chọn rank game
        DropdownButtonFormField<String>(
          initialValue: rank,
          hint: Text('Chọn rank', style: hintStyle),
          style: fieldStyle,
          dropdownColor: context.dialogBgColor,
          iconEnabledColor: Colors.deepOrange,
          decoration: InputDecoration(
            labelText: 'Hạng hiện tại (Rank)',
            labelStyle: labelStyle,
            floatingLabelStyle: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold),
            enabledBorder: enabledBorder,
            focusedBorder: focusedBorder,
            errorBorder: errorBorder,
            focusedErrorBorder: focusedErrorBorder,
            filled: true,
            fillColor: fieldFillColor,
          ),
          items: rankOptions
              .map((r) => DropdownMenuItem(
                    value: r,
                    child: Text(r, style: fieldStyle),
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
        
        DropdownSearch<String>.multiSelection(
          items: (filter, props) => onSearchGamesAsync(filter),
          selectedItems: favoriteGames,
          compareFn: (i, s) => i == s,
          decoratorProps: DropDownDecoratorProps(
            decoration: InputDecoration(
              hintText: "Chọn game",
              hintStyle: hintStyle,
              enabledBorder: enabledBorder,
              focusedBorder: focusedBorder,
              errorBorder: errorBorder,
              focusedErrorBorder: focusedErrorBorder,
              filled: true,
              fillColor: fieldFillColor,
              prefixIcon: Icon(Icons.videogame_asset, color: Colors.deepOrange[400]),
            ),
          ),
          popupProps: PopupPropsMultiSelection.dialog(
            showSearchBox: true,
            searchFieldProps: TextFieldProps(
              decoration: InputDecoration(
                hintText: "Gõ tên game (ví dụ: gta...)",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            dialogProps: DialogProps(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          onChanged: (results) {
            if (results.length > 5) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Chỉ được chọn tối đa 5 game!')),
              );
              // We remove the last added item to keep it <= 5.
              results.removeLast();
              onFavoriteGamesChanged(List.from(results));
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
          style: fieldStyle,
          decoration: InputDecoration(
            labelText: 'Thời gian chơi (phút/ngày)',
            labelStyle: labelStyle,
            floatingLabelStyle: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold),
            enabledBorder: enabledBorder,
            focusedBorder: focusedBorder,
            errorBorder: errorBorder,
            focusedErrorBorder: focusedErrorBorder,
            filled: true,
            fillColor: fieldFillColor,
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
          style: fieldStyle,
          decoration: InputDecoration(
            labelText: 'Tỷ lệ thắng (%)',
            labelStyle: labelStyle,
            floatingLabelStyle: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold),
            enabledBorder: enabledBorder,
            focusedBorder: focusedBorder,
            errorBorder: errorBorder,
            focusedErrorBorder: focusedErrorBorder,
            filled: true,
            fillColor: fieldFillColor,
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
          hint: Text('Chọn mục đích', style: hintStyle),
          style: fieldStyle,
          dropdownColor: context.dialogBgColor,
          iconEnabledColor: Colors.deepOrange,
          decoration: InputDecoration(
            labelText: 'Mục đích tìm kiếm',
            labelStyle: labelStyle,
            floatingLabelStyle: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold),
            enabledBorder: enabledBorder,
            focusedBorder: focusedBorder,
            errorBorder: errorBorder,
            focusedErrorBorder: focusedErrorBorder,
            filled: true,
            fillColor: fieldFillColor,
          ),
          items: lookingForOptions
              .map((option) => DropdownMenuItem(
                    value: option,
                    child: Text(option, style: fieldStyle),
                  ))
              .toList(),
          onChanged: onLookingForChanged,
        ),
        const SizedBox(height: 14),
        
        // Dropdown: Phong cách chơi game
        DropdownButtonFormField<String>(
          initialValue: gameStyle,
          hint: Text('Chọn phong cách', style: hintStyle),
          style: fieldStyle,
          dropdownColor: context.dialogBgColor,
          iconEnabledColor: Colors.deepOrange,
          decoration: InputDecoration(
            labelText: 'Phong cách chơi game',
            labelStyle: labelStyle,
            floatingLabelStyle: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold),
            enabledBorder: enabledBorder,
            focusedBorder: focusedBorder,
            errorBorder: errorBorder,
            focusedErrorBorder: focusedErrorBorder,
            filled: true,
            fillColor: fieldFillColor,
          ),
          items: gameStyleOptions
              .map((style) => DropdownMenuItem(
                    value: style,
                    child: Text(style, style: fieldStyle),
                  ))
              .toList(),
          onChanged: onGameStyleChanged,
        ),
      ],
    );
  }
}
