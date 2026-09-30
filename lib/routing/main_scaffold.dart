import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_colors.dart';

class MainScaffold extends StatelessWidget {
  const MainScaffold({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  static const _destinations = [
    (label: 'Today', icon: Icons.home_outlined),
    (label: 'Groups', icon: Icons.adjust_outlined),
    (label: 'Journey', icon: Icons.north_east),
    (label: 'Profile', icon: Icons.account_circle_outlined),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    body: navigationShell,
    bottomNavigationBar: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(13, 0, 13, 10),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(17),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Row(
              children: List.generate(_destinations.length, (index) {
                final destination = _destinations[index];
                final selected = navigationShell.currentIndex == index;
                final color = selected ? AppColors.teal : AppColors.muted;
                return Expanded(
                  child: Semantics(
                    selected: selected,
                    button: true,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(13),
                      onTap: () => navigationShell.goBranch(index),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 60),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ExcludeSemantics(
                                child: Icon(
                                  destination.icon,
                                  color: color,
                                  size: 23,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                destination.label,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: color,
                                  fontWeight: selected
                                      ? FontWeight.w800
                                      : FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    ),
  );
}
