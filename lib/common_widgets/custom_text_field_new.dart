import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:kindura_ai/res/colors/app_color.dart';

class CustomTextFieldNew extends StatefulWidget {
  final TextEditingController controller;
  final String labelText;
  final String? Function(String?)? validator;
  final bool obscureText;
  final TextInputType keyboardType;
  final double borderRadius;
  final bool isLabel;
  final Color fontColor;
  final int maxLines;
  final int? maxLength;
  final TextAlign textAlign;

  final Function(String)? onchange;
  final FocusNode focusNode;
  final bool isHint;
  final bool readOnly;
  CustomTextFieldNew({
    Key? key,
    required this.controller,
    required this.labelText,
    this.validator = null,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.borderRadius = 8.0,
    this.isLabel = true,
    this.onchange,
    this.maxLength,
    this.textAlign = TextAlign.start,
    this.fontColor = AppColor.black,
    this.maxLines = 1,
    required this.focusNode,
    this.isHint = false,
    this.readOnly = false,
  }) : super(key: key);
  @override
  State<StatefulWidget> createState() {
    return _CustomTextFieldNewState();
  }
}

class _CustomTextFieldNewState extends State<CustomTextFieldNew> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? Colors.grey.shade600 : AppColor.black;
    final cursorColor = isDark ? Colors.white : AppColor.black;
    // Use white text in dark mode, otherwise use the provided fontColor
    final textColor = isDark ? Colors.white : widget.fontColor;
    final labelColor = isDark ? Colors.white : widget.fontColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        widget.isLabel
            ? Text(
                widget.labelText,
                style: TextStyle(
                    color: labelColor,
                    fontSize: 14.sp,
                    fontFamily: 'Inter-Medium',
                    fontWeight: FontWeight.w500),
              )
            : Container(),
        Container(
          margin: EdgeInsets.only(top: widget.isLabel ? 8.h : 0),
          child: TextFormField(
            cursorColor: cursorColor,
            textAlignVertical: TextAlignVertical.center,
            keyboardType: widget.keyboardType,
            controller: widget.controller,
            validator: widget.validator,
            maxLines: widget.maxLines,
            focusNode: widget.focusNode,
            maxLength: widget.maxLength,
            textAlign: widget.textAlign,
            onChanged: widget.onchange,
            obscureText: widget.obscureText,
            readOnly: widget.readOnly,
            style: TextStyle(
              fontSize: 16.sp,
              color: textColor,
              fontFamily: 'Inter-Regular',
              fontWeight: FontWeight.w400,
            ),
            decoration: InputDecoration(
              counterText: '',
              floatingLabelBehavior: FloatingLabelBehavior.always,
              fillColor: isDark ? const Color(0xFF1E293B) : AppColor.gray100,
              hintText: widget.isLabel
                  ? (widget.isHint ? widget.labelText : "")
                  : widget.labelText,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(widget.borderRadius.w),
                borderSide: BorderSide(
                  color: borderColor,
                  width: 1.h,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(widget.borderRadius.w),
                borderSide: BorderSide(
                  color: isDark ? AppColor.primaryColor : AppColor.black,
                  width: 1.h,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(widget.borderRadius.w),
                borderSide: BorderSide(
                  color: borderColor,
                  width: 1.h,
                ),
              ),
              contentPadding: EdgeInsets.symmetric(
                vertical: 14.h,
                horizontal: 16.w,
              ),
              hintStyle: TextStyle(
                  color: isDark ? Colors.grey.shade500 : AppColor.gray500,
                  fontFamily: 'Inter-Regular',
                  fontWeight: FontWeight.w400,
                  fontSize: 16.sp),
              errorStyle: TextStyle(
                  color: Colors.red,
                  fontFamily: 'Inter-Regular',
                  fontWeight: FontWeight.w400,
                  fontSize: 14.sp),
            ),
          ),
        ),
      ],
    );
  }
}
