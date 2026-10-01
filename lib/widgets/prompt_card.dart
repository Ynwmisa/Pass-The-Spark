import 'package:flutter/material.dart';

import '../models/today_overview.dart';
import '../theme/app_colors.dart';

class PromptCard extends StatelessWidget {
  const PromptCard({super.key, required this.group, required this.onAnswer});
  final SparkGroup group;
  final VoidCallback onAnswer;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(17, 17, 17, 22),
    decoration: BoxDecoration(
      color: AppColors.navy,
      borderRadius: BorderRadius.circular(19),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 16,
            runSpacing: 8,
            children: [
              Text(
                group.name,
                style: const TextStyle(
                  color: AppColors.amber,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              const Text(
                'YOUR TURN',
                style: TextStyle(
                  color: Color(0xFFE0E9ED),
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  letterSpacing: 0.55,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 13),
        Text(
          group.prompt,
          style: Theme.of(context).textTheme.titleLarge!.copyWith(
            color: Colors.white,
            letterSpacing: -0.45,
          ),
        ),
        const SizedBox(height: 13),
        FilledButton(
          onPressed: onAnswer,
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(child: Text('Answer prompt')),
              SizedBox(width: 12),
              Icon(Icons.arrow_forward, size: 18),
            ],
          ),
        ),
      ],
    ),
  );
}
