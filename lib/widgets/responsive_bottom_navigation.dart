import 'package:flutter/material.dart';

class ResponsiveBottomNavigation extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final List<NavigationItem> items;
  final int? unreadCount;

  const ResponsiveBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    this.unreadCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: MediaQuery.of(context).size.width > 600 ? 24 : 16,
            vertical: MediaQuery.of(context).size.width > 600 ? 12 : 8,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isSelected = currentIndex == index;
              final isTablet = MediaQuery.of(context).size.width > 600;
              final isDesktop = MediaQuery.of(context).size.width > 1024;

              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(index),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 20 : (isTablet ? 16 : 12),
                      vertical: isDesktop ? 12 : (isTablet ? 10 : 8),
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF43A047).withOpacity(0.1) : Colors.transparent,
                      borderRadius: BorderRadius.circular(isDesktop ? 16 : (isTablet ? 14 : 12)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(
                          children: [
                            Icon(
                              item.icon,
                              color: isSelected ? const Color(0xFF43A047) : const Color(0xFF424242),
                              size: isDesktop ? 28 : (isTablet ? 26 : 24),
                            ),
                            if (item.showCounter && unreadCount != null && unreadCount! > 0)
                              Positioned(
                                right: -2,
                                top: -2,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFFB8C00),
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 16,
                                    minHeight: 16,
                                  ),
                                  child: Text(
                                    unreadCount! > 99 ? '99+' : unreadCount.toString(),
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: isDesktop ? 10 : (isTablet ? 9 : 8),
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        SizedBox(height: isDesktop ? 6 : (isTablet ? 5 : 4)),
                        Text(
                          item.label,
                          style: TextStyle(
                            color: isSelected ? const Color(0xFF43A047) : const Color(0xFF424242),
                            fontSize: isDesktop ? 14 : (isTablet ? 12 : 10),
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class NavigationItem {
  final IconData icon;
  final String label;
  final bool showCounter;

  const NavigationItem({
    required this.icon,
    required this.label,
    this.showCounter = false,
  });
}
