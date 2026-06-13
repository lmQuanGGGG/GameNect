import 'package:flutter/material.dart';
import 'package:dropdown_search/dropdown_search.dart';
import '../../../core/theme/theme_helper.dart';
import '../../../core/widgets/game_tag_widget.dart';

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
    final fieldFillColor = Colors.white;
    final fieldStyle = const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold);
    final labelStyle = const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold);
    final hintStyle = const TextStyle(color: Colors.black54, fontWeight: FontWeight.w500);
    
    final enabledBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.black, width: 2.5),
    );
    final focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.deepOrange, width: 3),
    );
    final errorBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.redAccent, width: 2.5),
    );
    final focusedErrorBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.redAccent, width: 3),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Dropdown: Chọn rank game
        DropdownButtonFormField<String>(
          initialValue: rank,
          hint: Text('Chọn rank', style: hintStyle),
          style: fieldStyle,
          dropdownColor: Colors.white,
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
        
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black, width: 2.5),
            boxShadow: const [
              BoxShadow(
                color: Colors.black,
                offset: Offset(4, 4),
              )
            ],
          ),
          child: DropdownSearch<String>.multiSelection(
            items: (filter, props) => onSearchGamesAsync(filter),
            selectedItems: favoriteGames,
            compareFn: (i, s) => i == s,
            dropdownBuilder: (context, selectedItems) {
              if (selectedItems.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text("Chọn game (tối đa 5)", style: TextStyle(color: Colors.black54, fontSize: 16, fontWeight: FontWeight.bold)),
                );
              }
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: selectedItems.map((game) => GameTagWidget(gameName: game)).toList(),
                ),
              );
            },
            decoratorProps: DropDownDecoratorProps(
              decoration: InputDecoration(
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
                prefixIcon: const Icon(Icons.videogame_asset, color: Colors.deepOrange, size: 28),
              ),
            ),
            popupProps: PopupPropsMultiSelection.dialog(
              showSearchBox: true,
              itemBuilder: (context, item, isDisabled, isSelected) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.deepOrange.withValues(alpha: 0.1) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: isSelected ? Border.all(color: Colors.deepOrange, width: 2) : Border.all(color: Colors.transparent, width: 2),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    title: GameTagWidget(gameName: item),
                    selected: isSelected,
                  ),
                );
              },
              searchFieldProps: TextFieldProps(
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                decoration: InputDecoration(
                  hintText: "Gõ tên game (ví dụ: gta...)",
                  prefixIcon: const Icon(Icons.search, color: Colors.black),
                  filled: true,
                  fillColor: Colors.grey.shade200,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.black, width: 2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.deepOrange, width: 2.5),
                  ),
                ),
              ),
              dialogProps: DialogProps(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: Colors.black, width: 3),
                ),
                elevation: 0,
              ),
            ),
            onChanged: (results) {
              if (results.length > 5) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Chỉ được chọn tối đa 5 game!', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    backgroundColor: Colors.deepOrange,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.black, width: 2)),
                  ),
                );
                results.removeLast();
                onFavoriteGamesChanged(List.from(results));
              } else {
                onFavoriteGamesChanged(results);
              }
            },
            validator: (values) =>
                values == null || values.isEmpty ? "Chọn ít nhất 1 game" : null,
          ),
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
          dropdownColor: Colors.white,
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
          dropdownColor: Colors.white,
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
