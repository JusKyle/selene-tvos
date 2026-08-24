import 'package:flutter/material.dart';
import 'filter_pill_hover.dart';

/// 显示筛选选项的公共方法
/// 在 tvOS 端显示底部弹出
void showFilterOptionsSelector({
  required BuildContext context,
  required String title,
  required List<SelectorOption> options,
  required String selectedValue,
  required ValueChanged<String> onSelected,
}) {
  // 计算需要的行数
  final rowCount = (options.length / 4).ceil();
  // 计算GridView的高度：行数 * (item高度 + 间距) + padding
  final gridHeight = rowCount * (40.0 + 10.0) - 10.0 + 32.0; // 32.0是上下padding

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) {
      return Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child:
                  Text(title, style: Theme.of(context).textTheme.titleLarge),
            ),
            Container(
              height: gridHeight,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  childAspectRatio: 2.5,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options[index];
                  final isSelected = option.value == selectedValue;
                  return FilterOptionHover(
                    isSelected: isSelected,
                    label: option.label,
                    onTap: () {
                      onSelected(option.value);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16), // 底部间距
          ],
        ),
      );
    },
  );
}
