import 'package:flutter/cupertino.dart';

class CustomTab extends StatelessWidget {
  final String title;
  final int count;

  const CustomTab({super.key, required this.title, int? count})
      : count = count ?? 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 12),
        ),
        Text(formatCount(count)),
      ],
    );
  }
}

String formatCount(int count) {
  if (count >= 1000000000) {
    return '${(count / 1000000000).toStringAsFixed(1)}B';
  }
  if (count >= 1000000) {
    return '${(count / 1000000).toStringAsFixed(1)}M';
  }
  if (count >= 1000) {
    return '${(count / 1000).toStringAsFixed(1)}K';
  }
  return count.toString();
}
