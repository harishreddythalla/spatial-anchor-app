import 'package:flutter/material.dart';

class TopBarWidget extends StatelessWidget {
  final VoidCallback onOpenMenu;
  final bool villagesEnabled;
  final bool villagesOn;
  final VoidCallback onToggleVillages;

  const TopBarWidget({
    super.key,
    required this.onOpenMenu,
    required this.villagesEnabled,
    required this.villagesOn,
    required this.onToggleVillages,
  });

  @override
  Widget build(BuildContext context) {
    final pillColor = villagesOn
        ? const Color(0xFF00695C).withValues(alpha: 0.90)
        : Colors.black.withValues(alpha: 0.55);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              onPressed: onOpenMenu,
              icon: const Icon(Icons.menu, color: Colors.white70),
              tooltip: 'Menu',
            ),
            const Text(
              'Village',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            GestureDetector(
              onTap: villagesEnabled ? onToggleVillages : null,
              child: Opacity(
                opacity: villagesEnabled ? 1 : 0.45,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: pillColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: villagesOn
                          ? const Color(0xFF00695C)
                          : Colors.white24,
                    ),
                  ),
                  child: const Text(
                    'Villages',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

