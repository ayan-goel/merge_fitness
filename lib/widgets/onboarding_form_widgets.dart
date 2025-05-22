import 'package:flutter/material.dart';
import '../theme/app_styles.dart';

class FormSectionTitle extends StatelessWidget {
  final String title;
  final IconData? icon;

  const FormSectionTitle({
    super.key,
    required this.title,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24.0, bottom: 8.0),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: AppStyles.primarySage),
            const SizedBox(width: 8),
          ],
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppStyles.textDark,
            ),
          ),
        ],
      ),
    );
  }
}

class FormDivider extends StatelessWidget {
  const FormDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16.0),
      child: Divider(height: 1, thickness: 1),
    );
  }
}

class YesNoQuestion extends StatelessWidget {
  final String question;
  final bool? value;
  final Function(bool?) onChanged;

  const YesNoQuestion({
    super.key,
    required this.question,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 5,
            child: Text(
              question,
              style: const TextStyle(fontSize: 14),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Radio<bool>(
                value: true,
                groupValue: value,
                onChanged: onChanged,
                activeColor: AppStyles.primarySage,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              const Text('Yes', style: TextStyle(fontSize: 12)),
            ],
          ),
          const SizedBox(width: 10),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Radio<bool>(
                value: false,
                groupValue: value,
                onChanged: onChanged,
                activeColor: AppStyles.primarySage,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              const Text('No', style: TextStyle(fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

class SliderRatingInput extends StatelessWidget {
  final String label;
  final int value;
  final Function(double) onChanged;

  const SliderRatingInput({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 16),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppStyles.primarySage,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  value.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          Slider(
            value: value.toDouble(),
            min: 1,
            max: 10,
            divisions: 9,
            activeColor: AppStyles.primarySage,
            inactiveColor: AppStyles.primarySage.withOpacity(0.3),
            label: value.toString(),
            onChanged: onChanged,
          ),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Poor', style: TextStyle(fontSize: 12, color: Colors.grey)),
              Text('Average', style: TextStyle(fontSize: 12, color: Colors.grey)),
              Text('Excellent', style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }
}

class CheckboxFormField extends StatelessWidget {
  final String title;
  final bool value;
  final ValueChanged<bool?> onChanged;

  const CheckboxFormField({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      title: Text(title),
      value: value,
      onChanged: onChanged,
      activeColor: AppStyles.primarySage,
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
    );
  }
}

class InfoCard extends StatelessWidget {
  final String message;
  final Color? backgroundColor;
  final Color? textColor;

  const InfoCard({
    super.key,
    required this.message,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: backgroundColor ?? AppStyles.primarySage.withOpacity(0.1),
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline,
              color: textColor ?? AppStyles.primarySage,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: textColor ?? AppStyles.primarySage,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SignatureBox extends StatelessWidget {
  final Function() onSign;
  final String? signatureTimestamp;

  const SignatureBox({
    super.key,
    required this.onSign,
    this.signatureTimestamp,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: signatureTimestamp != null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Signed:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Form signed on $signatureTimestamp',
                      ),
                    ),
                  ],
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Please sign to acknowledge that you have read and agreed to the terms above.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: onSign,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppStyles.primarySage,
                  ),
                  child: const Text('Sign Now'),
                ),
              ],
            ),
    );
  }
} 