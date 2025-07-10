import 'package:flutter/material.dart';

class ControlButtons extends StatelessWidget {
  const ControlButtons({
    super.key,
    required this.onRemoveStitch,
    required this.onCompleteRow,
    required this.onReset,
    required this.canRemoveStitch,
    required this.canCompleteRow,
  });

  final VoidCallback onRemoveStitch;
  final VoidCallback onCompleteRow;
  final VoidCallback onReset;
  final bool canRemoveStitch;
  final bool canCompleteRow;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ControlButton(
            icon: Icons.undo,
            label: '1つ戻す',
            onPressed: canRemoveStitch ? onRemoveStitch : null,
            color: Colors.orange,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ControlButton(
            icon: Icons.check_circle,
            label: '段完成',
            onPressed: canCompleteRow ? onCompleteRow : null,
            color: Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ControlButton(
            icon: Icons.refresh,
            label: 'リセット',
            onPressed: onReset,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}

class ControlButton extends StatelessWidget {
  const ControlButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: onPressed != null ? color : const Color(0xFFE0E0E0),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: onPressed != null
                  ? color.withOpacity(0.3)
                  : Colors.grey.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: onPressed != null ? Colors.white : Colors.grey,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: onPressed != null ? Colors.white : Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
