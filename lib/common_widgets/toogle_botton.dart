import 'package:flutter/material.dart';

class CustomToggle extends StatelessWidget {
  final Widget child;
  final bool isSelected;
  final VoidCallback onTap;

  const CustomToggle({
    super.key,
    required this.child,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(5),
        ),
        child: child,
      ),
    );
  }
}
