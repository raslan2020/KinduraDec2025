import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:kindura_ai/common_widgets/custom_button.dart';
import 'package:kindura_ai/common_widgets/loading_indicator.dart';
import 'package:kindura_ai/data/response/status.dart';
import 'package:kindura_ai/res/colors/app_color.dart';
import 'package:kindura_ai/screens/pdf_upload/pdf_upload_controller.dart';

class PdfUploadScreen extends StatefulWidget {
  const PdfUploadScreen({super.key});

  @override
  State<PdfUploadScreen> createState() => _PdfUploadScreenState();
}

class _PdfUploadScreenState extends State<PdfUploadScreen> {
  final pdfUploadController = Get.put(PdfUploadController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              AppBar(
                title: Center(
                  child: Text("Kindura AI",
                      style: TextStyle(
                        color: AppColor.black,
                      )),
                ),
                backgroundColor: Colors.transparent,
                elevation: 0,
                automaticallyImplyLeading: false,
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    Padding(
                      padding: EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: "Upload your ",
                                  style: TextStyle(
                                      color: AppColor.black,
                                      fontSize: 20.sp,
                                      fontWeight: FontWeight.bold),
                                ),
                                TextSpan(
                                  text: "Course PDF",
                                  style: TextStyle(
                                      color: AppColor.primaryColor,
                                      fontSize: 20.sp,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 10.h),
                          Text(
                            "Select and upload your Course PDF document for analysis",
                            style: TextStyle(
                              color: AppColor.gray500,
                              fontSize: 14.sp,
                              fontFamily: 'Inter-Regular',
                            ),
                          ),
                          SizedBox(height: 30.h),

                          // File Selection Area
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppColor.gray100,
                              borderRadius: BorderRadius.circular(12.r),
                              border: Border.all(
                                color: AppColor.black,
                                width: 1.h,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.cloud_upload_outlined,
                                  size: 60.sp,
                                  color: AppColor.primaryColor,
                                ),
                                SizedBox(height: 20.h),
                                Text(
                                  "Choose PDF File",
                                  style: TextStyle(
                                    color: AppColor.black,
                                    fontSize: 18.sp,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Inter-Medium',
                                  ),
                                ),
                                SizedBox(height: 10.h),
                                Text(
                                  "Tap to select a PDF file from your device",
                                  style: TextStyle(
                                    color: AppColor.gray500,
                                    fontSize: 14.sp,
                                    fontFamily: 'Inter-Regular',
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: 20.h),
                                GestureDetector(
                                  onTap: pdfUploadController.pickPdfFile,
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 30.w,
                                      vertical: 12.h,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColor.buttonColor,
                                      borderRadius: BorderRadius.circular(25.r),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.file_open,
                                          color: AppColor.black,
                                          size: 20.sp,
                                        ),
                                        SizedBox(width: 8.w),
                                        Text(
                                          "Select PDF",
                                          style: TextStyle(
                                            color: AppColor.black,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14.sp,
                                            fontFamily: 'Inter-Medium',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          SizedBox(height: 25.h),

                          // Selected File Display
                          Obx(() {
                            if (pdfUploadController.fileName.value.isNotEmpty) {
                              return Container(
                                width: double.infinity,
                                padding: EdgeInsets.all(15),
                                decoration: BoxDecoration(
                                  color: AppColor.gray100,
                                  borderRadius: BorderRadius.circular(10.r),
                                  border: Border.all(
                                    color: AppColor.black,
                                    width: 1.h,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.picture_as_pdf,
                                      color: AppColor.primaryColor,
                                      size: 30.sp,
                                    ),
                                    SizedBox(width: 15.w),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Selected File:",
                                            style: TextStyle(
                                              color: AppColor.gray500,
                                              fontSize: 12.sp,
                                              fontFamily: 'Inter-Regular',
                                            ),
                                          ),
                                          Text(
                                            pdfUploadController.fileName.value,
                                            style: TextStyle(
                                              color: AppColor.black,
                                              fontSize: 14.sp,
                                              fontWeight: FontWeight.bold,
                                              fontFamily: 'Inter-Medium',
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: pdfUploadController.clearSelection,
                                      child: Container(
                                        padding: EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: AppColor.gray300,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.close,
                                          color: AppColor.black,
                                          size: 16.sp,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }
                            return SizedBox.shrink();
                          }),

                          SizedBox(height: 25.h),

                          // Upload Button
                          Obx(() => CustomButton(
                                text: pdfUploadController.isUploading.value
                                    ? "Uploading..."
                                    : "Upload PDF",
                                textColor: AppColor.black,
                                bgColor: AppColor.buttonColor,
                                onPressed: pdfUploadController.isUploading.value
                                    ? () {}
                                    : () {
                                        FocusScope.of(context).unfocus();
                                        pdfUploadController.uploadPdfFile();
                                      },
                              )),

                          SizedBox(height: 25.h),

                          // Instructions
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColor.gray100,
                              borderRadius: BorderRadius.circular(10.r),
                              border: Border.all(
                                color: AppColor.black,
                                width: 1.h,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Instructions:",
                                  style: TextStyle(
                                    color: AppColor.black,
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Inter-Medium',
                                  ),
                                ),
                                SizedBox(height: 10.h),
                                _buildInstructionItem(
                                    "Only PDF files are supported"),
                                _buildInstructionItem(
                                    "Maximum file size: 10MB"),
                                _buildInstructionItem(
                                    "Ensure your PDF is not password protected"),
                                _buildInstructionItem(
                                    "Upload may take a few moments"),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Obx(() {
            switch (pdfUploadController.requestStatus.value) {
              case Status.LOADING:
                return Container(
                  color: Colors.black.withValues(alpha: 0.3),
                  child: Center(child: LoadingIndicator()),
                );
              case Status.ERROR:
                return Container();
              case Status.COMPLETED:
                return Container();
              default:
                return Container();
            }
          }),
        ],
      ),
    );
  }

  Widget _buildInstructionItem(String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: EdgeInsets.only(top: 6.h),
            width: 6.w,
            height: 6.h,
            decoration: BoxDecoration(
              color: AppColor.primaryColor,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: AppColor.black,
                fontSize: 14.sp,
                fontFamily: 'Inter-Regular',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
