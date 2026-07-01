import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';

enum FeedbackType {
  bug,
  featureRequest,
  other,
}

class FeedbackDialog extends StatefulWidget {
  const FeedbackDialog({super.key});

  @override
  State<FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends State<FeedbackDialog> {
  FeedbackType _selectedType = FeedbackType.bug;
  final TextEditingController _messageController = TextEditingController();
  bool _isSubmitting = false;

  String _getTypeLabel(FeedbackType type) {
    switch (type) {
      case FeedbackType.bug:
        return tr('feedback_type_bug');
      case FeedbackType.featureRequest:
        return tr('feedback_type_feature');
      case FeedbackType.other:
        return tr('feedback_type_other');
    }
  }

  String _getTypeValue(FeedbackType type) {
    switch (type) {
      case FeedbackType.bug:
        return 'bug';
      case FeedbackType.featureRequest:
        return 'feature_request';
      case FeedbackType.other:
        return 'other';
    }
  }

  Future<void> _submitFeedback() async {
    if (_messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('feedback_enter_message')),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await FirebaseFirestore.instance.collection('feedback').add({
        'type': _getTypeValue(_selectedType),
        'message': _messageController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'platform': Theme.of(context).platform.toString(),
      });

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('feedback_thanks')),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('フィードバック送信エラー: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('feedback_send_failed')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      backgroundColor: isDarkMode ? const Color(0xFF2D2D2D) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        // キーボード表示時や横向きの小型端末で縦にあふれないようスクロール可能にする
        child: SingleChildScrollView(
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.mail_outline, color: Color(0xFFEC407A)),
                const SizedBox(width: 8),
                Text(
                  tr('contact'),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              tr('feedback_type_label'),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDarkMode ? Colors.grey[400] : Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: FeedbackType.values.map((type) {
                final isSelected = _selectedType == type;
                return ChoiceChip(
                  label: Text(_getTypeLabel(type)),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedType = type;
                      });
                    }
                  },
                  selectedColor: const Color(0xFFEC407A),
                  labelStyle: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : (isDarkMode ? Colors.white70 : Colors.black87),
                  ),
                  backgroundColor: isDarkMode ? const Color(0xFF3D3D3D) : null,
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Text(
              tr('feedback_message_label'),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDarkMode ? Colors.grey[400] : Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _messageController,
              maxLines: 5,
              maxLength: 1000,
              style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                hintText: tr('feedback_hint'),
                hintStyle: TextStyle(color: isDarkMode ? Colors.grey[500] : null),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDarkMode ? Colors.grey[600]! : Colors.grey[400]!,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFEC407A), width: 2),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              tr('feedback_anonymous_note'),
              style: TextStyle(
                fontSize: 12,
                color: isDarkMode ? Colors.grey[400] : Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                  child: Text(
                    tr('cancel'),
                    style: TextStyle(color: isDarkMode ? Colors.grey[400] : null),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitFeedback,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEC407A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(tr('send')),
                ),
              ],
            ),
          ],
          ),
        ),
      ),
    );
  }
}
