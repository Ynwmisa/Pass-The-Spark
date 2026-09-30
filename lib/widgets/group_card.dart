import 'package:flutter/material.dart';

import '../models/today_overview.dart';
import '../theme/app_colors.dart';

class GroupCard extends StatelessWidget {
  const GroupCard({
    super.key,
    required this.group,
    required this.isYourTurn,
    required this.onTap,
    this.highlighted = false,
  });

  final SparkGroup group;
  final bool isYourTurn;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: highlighted ? AppColors.mint : Colors.white,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                group.name,
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                '${group.memberCount} members',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 14),
              Text(
                isYourTurn
                    ? 'Your spark'
                    : '${group.holderName} holds the spark',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkTeal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
