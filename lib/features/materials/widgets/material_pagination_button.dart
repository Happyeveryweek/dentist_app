import 'package:flutter/material.dart';
import '../../../widgets/dental_icons.dart';

class MaterialPaginationButton extends StatelessWidget {
  final IconData? icon;
  final int? pageNumber;
  final VoidCallback? onPressed;
  final bool isActive;

  const MaterialPaginationButton({
    Key? key,
    this.icon,
    this.pageNumber,
    required this.onPressed,
    required this.isActive,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: isActive ? DentalColors.primary : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive ? DentalColors.primary : Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Center(
            child: icon != null
                ? Icon(
                    icon,
                    size: 18,
                    color: isActive ? Colors.white : Colors.grey.shade600,
                  )
                : Text(
                    pageNumber.toString(),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isActive ? Colors.white : Colors.grey.shade700,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
