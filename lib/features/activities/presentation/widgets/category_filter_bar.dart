import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../domain/entities/activity_category.dart';

/// Mirrors the web list page's category tabs — an "All" tab plus one per
/// `ActivityListData.categories`. Free-plan users never see this (the web
/// hides the whole tab row for them too, since they only ever see the
/// fixed Free-plan catalogue regardless of category).
class CategoryFilterBar extends StatelessWidget {
  const CategoryFilterBar({
    required this.categories,
    required this.selectedCategory,
    required this.onSelected,
    super.key,
  });

  final List<ActivityCategory> categories;
  final String selectedCategory;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        itemCount: categories.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _Chip(label: 'All', selected: selectedCategory.isEmpty, onTap: () => onSelected(''));
          }
          final category = categories[index - 1];
          return _Chip(
            label: category.label,
            selected: selectedCategory == category.value,
            onTap: () => onSelected(category.value),
          );
        },
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.action,
      labelStyle: TextStyle(color: selected ? AppColors.textOnDark : AppColors.textPrimary),
      backgroundColor: AppColors.surface,
      side: BorderSide(color: selected ? AppColors.action : AppColors.border),
    );
  }
}
