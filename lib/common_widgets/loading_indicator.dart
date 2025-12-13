import 'package:flutter/material.dart';
import 'package:kindura_ai/res/colors/app_color.dart';

class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return const CircularProgressIndicator(
      color: AppColor.primaryColor,
    );
  }
}
