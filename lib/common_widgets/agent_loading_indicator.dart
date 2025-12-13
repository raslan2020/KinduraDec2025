import 'package:flutter/material.dart';
import 'package:kindura_ai/res/colors/app_color.dart';

class AgentLoadingIndicator extends StatefulWidget {
  const AgentLoadingIndicator({
    super.key,
  });

  @override
  State<AgentLoadingIndicator> createState() => _AgentLoadingIndicatorState();
}

class _AgentLoadingIndicatorState extends State<AgentLoadingIndicator>
    with TickerProviderStateMixin {
  late AnimationController _textAnimationController;
  late AnimationController _dotAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _textAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _dotAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat();

    _fadeAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _textAnimationController,
      curve: Curves.easeInOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.95,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _textAnimationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _textAnimationController.dispose();
    _dotAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(
            color: AppColor.primaryColor,
            strokeWidth: 3,
          ),
          const SizedBox(height: 20),
          AnimatedBuilder(
            animation: _textAnimationController,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Opacity(
                  opacity: _fadeAnimation.value,
                  child: const Text(
                    'Please wait',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'the agent is loading',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(width: 4),
              AnimatedBuilder(
                animation: _dotAnimationController,
                builder: (context, child) {
                  return Row(
                    children: List.generate(3, (index) {
                      return AnimatedBuilder(
                        animation: _dotAnimationController,
                        builder: (context, child) {
                          final delay = index * 0.2;
                          final animationValue =
                              (_dotAnimationController.value + delay) % 1.0;
                          final opacity = (animationValue * 2).clamp(0.0, 1.0);

                          return Opacity(
                            opacity: opacity,
                            child: const Text(
                              '.',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColor.primaryColor,
                              ),
                            ),
                          );
                        },
                      );
                    }),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
