import 'package:flutter_starter/app/utils/constants/app_fonts.dart';
import 'package:flutter/material.dart';

class ThinkingDots extends StatefulWidget {
  final String? title;

  const ThinkingDots({super.key, this.title});

  @override
  State<ThinkingDots> createState() => _ThinkingDotsState();
}

class _ThinkingDotsState extends State<ThinkingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();

    _animations = List.generate(
      3,
      (index) => Tween<double>(begin: 0.3, end: 1.0).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(
            index * 0.2,
            (index * 0.2) + 0.6,
            curve: Curves.easeInOut,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.title ?? 'Thinking', style: CustomTextStyles.medium12),
        const SizedBox(width: 4),
        Row(
          children: List.generate(
            3,
            (index) => AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Opacity(
                    opacity: _animations[index].value,
                    child: const CircleAvatar(
                      radius: 4,
                      backgroundColor: Color(0xFF004D4D),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
