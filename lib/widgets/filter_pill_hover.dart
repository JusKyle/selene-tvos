import 'package:flutter/material.dart';
import '../utils/font_utils.dart';

class SelectorOption {
  final String label;
  final String value;

  const SelectorOption({required this.label, required this.value});
}

// 筛选条件按钮（tvOS）
class FilterPillHover extends StatelessWidget {
  final bool isDefault;
  final String title;
  final SelectorOption selectedOption;
  final VoidCallback onTap;

  const FilterPillHover({
    super.key,
    required this.isDefault,
    required this.title,
    required this.selectedOption,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // isDefault 时显示默认灰色，否则显示绿色
    final Color textColor = isDefault
        ? (Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey)
        : const Color(0xFF27AE60);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Text(
              isDefault ? title : selectedOption.label,
              style: FontUtils.poppins(
                fontSize: 13,
                color: textColor,
                fontWeight:
                    isDefault ? FontWeight.normal : FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              size: 18,
              color: textColor,
            ),
          ],
        ),
      ),
    );
  }
}

// 筛选选项（tvOS）
class FilterOptionHover extends StatelessWidget {
  final bool isSelected;
  final String label;
  final VoidCallback onTap;

  const FilterOptionHover({
    super.key,
    required this.isSelected,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // 选中时文字白色，否则默认
    final Color textColor = isSelected
        ? Colors.white
        : (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF27AE60)
              : Theme.of(context).chipTheme.backgroundColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(color: textColor),
        ),
      ),
    );
  }
}
