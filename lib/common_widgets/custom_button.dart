// custom_button.dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final Color textColor;
  final Color bgColor;
  final VoidCallback onPressed;
  final Color? borderColor;
  final String? imageLogo;

  const CustomButton(
      {super.key,
      required this.text,
      required this.textColor,
      required this.bgColor,
      required this.onPressed,
      this.borderColor,
      this.imageLogo});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50.h,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15.0),
            side: borderColor != null
                ? BorderSide(
                    color: borderColor!) // Apply border if color is provided
                : BorderSide.none, // No border if color is not provided
          ),
        ),
        onPressed: onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              text,
              style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 16.sp),
            ),
            if (imageLogo != null)
              Padding(
                padding: EdgeInsets.only(left: 10.w),
                child: SvgPicture.asset(
                  imageLogo!,
                  height: 20.h,
                  width: 20.w,
                  color: Colors.black,
                ),
              )
          ],
        ),
      ),
    );
  }
}
