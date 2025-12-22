import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:kindura_ai/common_widgets/home_app_bar.dart';
import 'package:kindura_ai/common_widgets/toogle_botton.dart';
import 'package:kindura_ai/res/routes/routes_name.dart';
import 'package:kindura_ai/screens/conservation/conservation_controller.dart';
import 'package:shimmer/shimmer.dart';
import 'package:kindura_ai/data/response/status.dart';
import 'package:intl/intl.dart';

class ConservationScreen extends StatefulWidget {
  const ConservationScreen({super.key});

  @override
  State<ConservationScreen> createState() => _ConservationScreenState();
}

class _ConservationScreenState extends State<ConservationScreen> {
  /// Format timestamp to HH:MM:SS & DD/MM/YY
  String _formatTimestamp(String isoTimestamp) {
    try {
      final dateTime = DateTime.parse(isoTimestamp).toLocal();
      final timeFormat = DateFormat('HH:mm:ss');
      final dateFormat = DateFormat('dd/MM/yy');
      return '${timeFormat.format(dateTime)} • ${dateFormat.format(dateTime)}';
    } catch (e) {
      return '';
    }
  }

  Widget _shimmerCard() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8.w),
        ),
        height: 100.h,
        width: double.infinity,
      ),
    );
  }

  final controller = Get.put(ConservationController());
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: "Kindura AI",
        showBackButton: true,
      ),
      body: RefreshIndicator(
        onRefresh: () {
          return controller.getConservation();
        },
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text("AI Conversation Logs",
                          style: TextStyle(
                              fontSize: 24, fontWeight: FontWeight.bold)),
                      Spacer(),
                      IconButton(
                        icon: Icon(Icons.refresh, color: Colors.black),
                        onPressed: () {
                          controller.getConservation();
                        },
                      )
                    ],
                  ),
                  Text("Look Your AI Conversation Logs",
                      style: TextStyle(fontSize: 16, color: Colors.grey)),
                  SizedBox(height: 20.h),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    padding: EdgeInsets.all(5),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CustomToggle(
                          isSelected: true,
                          onTap: () {},
                          child: Text(
                            'All Conversation Logs',
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20.h),
                  Obx(() {
                    if (controller.requestStatus.value == Status.LOADING) {
                      return Column(
                        children: List.generate(2, (index) => _shimmerCard()),
                      );
                    }

                    return Column(
                      children: [
                        if (controller.conservationRepository.value.result?.isNotEmpty == true)
                          Column(
                            children: [
                              for (var conservation in controller
                                  .conservationRepository.value.result ?? [])
                                InkWell(
                                  onTap: () {
                                    Get.toNamed(
                                      RoutesName.conservationDetailScreen,
                                      arguments: conservation,
                                    );
                                  },
                                  child: Container(
                                      margin: EdgeInsets.symmetric(vertical: 6),
                                      padding: EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF5F6FF),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                            color: Colors.grey.shade300),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Timestamp at the top
                                          if (conservation.uploadedAt != null)
                                            Padding(
                                              padding: EdgeInsets.only(bottom: 8.h),
                                              child: Row(
                                                children: [
                                                  Icon(Icons.access_time,
                                                    size: 14,
                                                    color: Colors.grey.shade600),
                                                  SizedBox(width: 4.w),
                                                  Text(
                                                    _formatTimestamp(conservation.uploadedAt!),
                                                    style: TextStyle(
                                                      fontSize: 11.sp,
                                                      color: Colors.grey.shade600,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                child: RichText(
                                                  text: TextSpan(
                                                    style: TextStyle(
                                                      color: Colors.black87,
                                                      fontSize: 14.sp,
                                                      fontWeight: FontWeight.w400,
                                                      height: 1.4,
                                                    ),
                                                    children: [
                                                      TextSpan(
                                                        text: "AI: ",
                                                        style: TextStyle(
                                                            fontWeight:
                                                                FontWeight
                                                                    .w500),
                                                      ),
                                                      TextSpan(
                                                        text: conservation
                                                                .conservation
                                                                ?.conversation
                                                                ?.messages
                                                                .isNotEmpty == true
                                                            ? (conservation
                                                                    .conservation!
                                                                    .conversation!
                                                                    .messages[0]
                                                                    .ai ??
                                                                '')
                                                            : 'No messages',
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (conservation.conservation?.conversation?.messages != null &&
                                              conservation
                                                      .conservation!
                                                      .conversation!
                                                      .messages
                                                      .length >
                                                  1 &&
                                              conservation
                                                      .conservation!
                                                      .conversation!
                                                      .messages[1]
                                                      .human !=
                                                  null)
                                            Padding(
                                              padding:
                                                  const EdgeInsets.only(top: 8),
                                              child: Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Expanded(
                                                    child: RichText(
                                                      text: TextSpan(
                                                        style: TextStyle(
                                                          color: Colors.black87,
                                                          fontSize: 14.sp,
                                                          fontWeight: FontWeight.w400,
                                                          height: 1.4,
                                                        ),
                                                        children: [
                                                          TextSpan(
                                                            text: "Human: ",
                                                            style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500),
                                                          ),
                                                          TextSpan(
                                                            text: conservation
                                                                .conservation!
                                                                .conversation!
                                                                .messages[1]
                                                                .human!,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      )),
                                ),
                            ],
                          )
                        else
                          Center(
                            child: Text("No Conversation Found"),
                          )
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
