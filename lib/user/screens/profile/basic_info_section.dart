import 'package:flutter/material.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';
import '../../../core/theme/theme_helper.dart';
import '../../../core/utils/icon_helper.dart';

class BasicInfoSection extends StatelessWidget {
  final TextEditingController usernameController;
  final TextEditingController birthDateController;
  final TextEditingController heightController;
  final TextEditingController bioController;
  
  final String gender;
  final Function(String?) onGenderChanged;
  final List<String> genderOptions;
  
  final List<String> interests;
  final Function(List<String>) onInterestsChanged;
  final List<String> interestOptions;
  
  final Function(String)? onBirthDateChanged;

  const BasicInfoSection({
    super.key,
    required this.usernameController,
    required this.birthDateController,
    required this.heightController,
    required this.bioController,
    required this.gender,
    required this.onGenderChanged,
    required this.genderOptions,
    required this.interests,
    required this.onInterestsChanged,
    required this.interestOptions,
    this.onBirthDateChanged,
  });

  bool _isValidDate(String input) {
    if (input.isEmpty) return false;
    final RegExp dateRegex = RegExp(r'^\d{2}/\d{2}/\d{4}$');
    if (!dateRegex.hasMatch(input)) return false;

    final parts = input.split('/');
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);

    if (day == null || month == null || year == null) return false;
    if (month < 1 || month > 12) return false;
    if (day < 1 || day > 31) return false;

    final now = DateTime.now();
    const minYear = 1950;
    final maxYear = now.year - 18;
    if (year < minYear || year > maxYear) return false;

    final daysInMonth = DateTime(year, month + 1, 0).day;
    if (day > daysInMonth) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final fieldFillColor = Colors.white;
    final fieldStyle = const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold);
    final labelStyle = const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold);
    final hintStyle = const TextStyle(color: Colors.black54, fontWeight: FontWeight.w500);
    final helperStyle = const TextStyle(color: Colors.black54, fontWeight: FontWeight.w500);
    
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
        // TextField: Tên người dùng
        TextFormField(
          controller: usernameController,
          style: fieldStyle,
          decoration: InputDecoration(
            labelText: 'Tên người dùng',
            labelStyle: labelStyle,
            floatingLabelStyle: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold),
            enabledBorder: enabledBorder,
            focusedBorder: focusedBorder,
            errorBorder: errorBorder,
            focusedErrorBorder: focusedErrorBorder,
            filled: true,
            fillColor: fieldFillColor,
          ),
          validator: (value) =>
              value!.isEmpty ? 'Vui lòng nhập tên người dùng' : null,
        ),
        const SizedBox(height: 14),
        
        // Dropdown: Giới tính
        DropdownButtonFormField<String>(
          initialValue: gender,
          hint: Text('Chọn giới tính', style: hintStyle),
          style: fieldStyle,
          dropdownColor: Colors.white,
          iconEnabledColor: Colors.deepOrange,
          decoration: InputDecoration(
            labelText: 'Giới tính',
            labelStyle: labelStyle,
            floatingLabelStyle: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold),
            enabledBorder: enabledBorder,
            focusedBorder: focusedBorder,
            errorBorder: errorBorder,
            focusedErrorBorder: focusedErrorBorder,
            filled: true,
            fillColor: fieldFillColor,
          ),
          items: genderOptions
              .map((g) => DropdownMenuItem(
                    value: g,
                    child: Text(g, style: fieldStyle),
                  ))
              .toList(),
          onChanged: onGenderChanged,
        ),
        const SizedBox(height: 14),
        
        // TextField: Ngày sinh với format dd/MM/yyyy
        TextFormField(
          controller: birthDateController,
          style: fieldStyle,
          decoration: InputDecoration(
            labelText: 'Ngày sinh (dd/MM/yyyy)',
            labelStyle: labelStyle,
            floatingLabelStyle: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold),
            hintText: 'VD: 25/12/1990',
            hintStyle: hintStyle,
            enabledBorder: enabledBorder,
            focusedBorder: focusedBorder,
            errorBorder: errorBorder,
            focusedErrorBorder: focusedErrorBorder,
            filled: true,
            fillColor: fieldFillColor,
            suffixIcon: const Icon(
              Icons.calendar_today,
              color: Colors.deepOrange,
            ),
            helperText: 'Nhập theo định dạng: ngày/tháng/năm',
            helperStyle: helperStyle,
          ),
          keyboardType: TextInputType.datetime,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Vui lòng nhập ngày sinh';
            }
            if (!_isValidDate(value)) {
              return 'Ngày sinh không hợp lệ (phải đủ 18 tuổi)';
            }
            return null;
          },
          onChanged: onBirthDateChanged ?? (value) {
            if (value.length == 2 && !value.contains('/')) {
              birthDateController.text = '$value/';
              birthDateController.selection = TextSelection.fromPosition(
                TextPosition(offset: birthDateController.text.length),
              );
            } else if (value.length == 5 && value.split('/').length == 2) {
              birthDateController.text = '$value/';
              birthDateController.selection = TextSelection.fromPosition(
                TextPosition(offset: birthDateController.text.length),
              );
            }
          },
        ),
        const SizedBox(height: 14),
        
        // TextField: Chiều cao
        TextFormField(
          controller: heightController,
          style: fieldStyle,
          decoration: InputDecoration(
            labelText: 'Chiều cao (cm)',
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
          validator: (value) {
            if (value == null || value.isEmpty) return 'Vui lòng nhập chiều cao';
            final height = int.tryParse(value);
            if (height == null || height < 140 || height > 220) {
              return 'Chiều cao phải từ 140-220cm';
            }
            return null;
          },
        ),
        const SizedBox(height: 14),
        
        // TextField: Bio
        TextFormField(
          controller: bioController,
          style: fieldStyle,
          decoration: InputDecoration(
            labelText: 'Giới thiệu bản thân',
            labelStyle: labelStyle,
            floatingLabelStyle: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold),
            counterStyle: helperStyle,
            enabledBorder: enabledBorder,
            focusedBorder: focusedBorder,
            errorBorder: errorBorder,
            focusedErrorBorder: focusedErrorBorder,
            filled: true,
            fillColor: fieldFillColor,
          ),
          maxLines: 3,
          maxLength: 200,
        ),
        const SizedBox(height: 14),
        
        // MultiSelectDialogField: Chọn sở thích khác
        MultiSelectDialogField<String>(
          items: interestOptions.map((e) => MultiSelectItem(e, e)).toList(),
          initialValue: interests,
          title: const Text("Sở thích khác", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 22)),
          selectedColor: Colors.deepOrange,
          backgroundColor: Colors.white,
          itemsTextStyle: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w600),
          selectedItemsTextStyle: const TextStyle(color: Colors.deepOrange, fontSize: 16, fontWeight: FontWeight.bold),
          searchTextStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          searchHintStyle: const TextStyle(color: Colors.black54),
          cancelText: const Text("HỦY", style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold, fontSize: 16)),
          confirmText: const Text("CHỌN", style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold, fontSize: 16)),
          decoration: BoxDecoration(
            color: fieldFillColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black, width: 2.5),
            boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(3, 3))],
          ),
          buttonIcon: const Icon(
            Icons.interests,
            color: Colors.deepOrange,
          ),
          buttonText: const Text(
            "Chọn sở thích",
            style: TextStyle(
              color: Colors.black,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          chipDisplay: MultiSelectChipDisplay.none(),
          onConfirm: onInterestsChanged,
        ),
        if (interests.isNotEmpty) const SizedBox(height: 12),
        if (interests.isNotEmpty)
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: interests.map((interest) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black, width: 2.5),
                  boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(3, 3))],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(IconHelper.getInterestIcon(interest), size: 20, color: Colors.deepOrange),
                    const SizedBox(width: 8),
                    Text(
                      interest,
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}
