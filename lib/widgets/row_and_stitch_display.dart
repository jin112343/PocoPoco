import 'package:flutter/material.dart';

class RowAndStitchDisplay extends StatelessWidget {
  const RowAndStitchDisplay({
    super.key,
    required this.rowNumber,
    required this.stitchCount,
    this.onRowTap,
  });

  final int rowNumber;
  final int stitchCount;
  final Function(int)? onRowTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.pink.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () {
              if (onRowTap != null) {
                onRowTap!(rowNumber);
              }
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$rowNumber',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFAD1457),
                  ),
                ),
                Text(
                  '段目',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFAD1457),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 32),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$stitchCount目',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1976D2),
                ),
              ),
              Text(
                '編み目数',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
