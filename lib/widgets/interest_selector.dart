import 'package:Meetcha/constants/app_colors.dart';
import 'package:Meetcha/constants/interest_options.dart';
import 'package:flutter/material.dart';

/// Grid chip untuk memilih Interest/Hobby Tags.
class InterestSelector extends StatelessWidget {
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;
  final int maxSelected;

  const InterestSelector({
    super.key,
    required this.selected,
    required this.onChanged,
    this.maxSelected = InterestOptions.maxSelected,
  });

  void _toggle(BuildContext context, String label) {
    final next = List<String>.from(selected);
    if (next.contains(label)) {
      next.remove(label);
    } else {
      if (next.length >= maxSelected) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Maksimal $maxSelected minat saja ya.')),
        );
        return;
      }
      next.add(label);
    }
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${selected.length}/$maxSelected dipilih',
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: InterestOptions.labels.map((label) {
            final isSelected = selected.contains(label);
            return FilterChip(
              selected: isSelected,
              showCheckmark: false,
              avatar: Icon(
                InterestOptions.iconFor(label),
                size: 18,
                color: isSelected ? AppColors.onPrimary : AppColors.textSecondary,
              ),
              label: Text(label),
              onSelected: (_) => _toggle(context, label),
              selectedColor: AppColors.primary,
              backgroundColor: Colors.grey.shade100,
              labelStyle: TextStyle(
                color: isSelected ? AppColors.onPrimary : AppColors.textPrimary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? AppColors.primary : Colors.grey.shade300,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}