import 'package:get/route_manager.dart';
import 'package:kindura_ai/res/routes/routes_name.dart';
import 'package:kindura_ai/screens/bottom_navigation/bottom_navigation_screen.dart';
import 'package:kindura_ai/screens/conservation/conservation_screen.dart';
import 'package:kindura_ai/screens/conservation_detail/conservation_detail_screen.dart';
import 'package:kindura_ai/screens/course_detail/course_detail_screen.dart';
import 'package:kindura_ai/screens/health/health_screen.dart';
import 'package:kindura_ai/screens/home/home_screen.dart';
import 'package:kindura_ai/screens/login/login_screen.dart';
import 'package:kindura_ai/screens/signup/signup_screen.dart';
import 'package:kindura_ai/screens/forgot_password/forgot_password_screen.dart';
import 'package:kindura_ai/screens/kindura_reports/kindura_reports_screen.dart';
import 'package:kindura_ai/screens/meds_vitamin/meds_vitamin_screen.dart';
import 'package:kindura_ai/screens/monitor/monitor_screen.dart';
import 'package:kindura_ai/screens/pdf_upload/pdf_upload_screen.dart';
import 'package:kindura_ai/screens/profile/profile_screen.dart';
import 'package:kindura_ai/screens/report_checkup/report_checkup_screen.dart';
import 'package:kindura_ai/screens/scan/scan_screen.dart';
import 'package:kindura_ai/screens/splash_screen/splash_screen.dart';
import 'package:kindura_ai/screens/lifestyle_habits/lifestyle_habits_screen.dart';
import 'package:kindura_ai/screens/physical_activity/physical_activity_screen.dart';
import 'package:kindura_ai/screens/dietary_habits/dietary_habits_screen.dart';
import 'package:kindura_ai/screens/labs/labs_screen.dart';
import 'package:kindura_ai/screens/labs/biomarker_detail_screen.dart';
import 'package:kindura_ai/screens/vitals_history/vitals_history_screen.dart';
import 'package:kindura_ai/screens/contacts/contacts_screen.dart';
import 'package:kindura_ai/screens/adherence_analysis/adherence_analysis_screen.dart';

class AppRoutes {
  static appRoutes() => [
        GetPage(
          name: RoutesName.splashScreen,
          page: () => SplashScreen(),
        ),
        GetPage(
          name: RoutesName.loginScreen,
          page: () => Login_Screen(),
        ),
        GetPage(
          name: RoutesName.signupScreen,
          page: () => Signup_Screen(),
        ),
        GetPage(
          name: RoutesName.forgotPasswordScreen,
          page: () => ForgotPasswordScreen(),
        ),
        GetPage(
          name: RoutesName.homeScreen,
          page: () => Home(),
        ),
        GetPage(
          name: RoutesName.healthScreen,
          page: () => HealthScreen(),
        ),
        GetPage(
          name: RoutesName.medsVitaminScreen,
          page: () => MedsVitaminScreen(),
        ),
        GetPage(
          name: RoutesName.monitorScreen,
          page: () => MonitorScreen(),
        ),
        GetPage(
          name: RoutesName.profileScreen,
          page: () => ProfileScreen(),
        ),
        GetPage(
          name: RoutesName.reportCheckupScreen,
          page: () => ReportCheckupScreen(),
        ),
        GetPage(
          name: RoutesName.scanScreen,
          page: () => ScanScreen(),
        ),
        GetPage(
          name: RoutesName.pdfUploadScreen,
          page: () => PdfUploadScreen(),
        ),
        GetPage(
          name: RoutesName.lifestyleHabitsScreen,
          page: () => LifestyleHabitsScreen(),
        ),
        GetPage(
          name: RoutesName.physicalActivityScreen,
          page: () => PhysicalActivityScreen(),
        ),
        GetPage(
          name: RoutesName.dietaryHabitsScreen,
          page: () => DietaryHabitsScreen(),
        ),
        GetPage(
          name: RoutesName.conservationScreen,
          page: () => ConservationScreen(),
        ),
        GetPage(
          name: RoutesName.conservationDetailScreen,
          page: () => ConservationDetailScreen(),
        ),
        GetPage(
          name: RoutesName.courseDetailScreen,
          page: () => CourseDetailScreen(),
        ),
        GetPage(
          name: RoutesName.mainScreen,
          page: () {
            final int initialIndex =
                int.parse(Get.parameters['initialIndex'] ?? '0');
            return MainPage(initialIndex: initialIndex);
          },
        ),
        GetPage(
          name: '/labs',
          page: () => LabsScreen(),
        ),
        GetPage(
          name: '/biomarker-detail',
          page: () => BiomarkerDetailScreen(),
        ),
        GetPage(
          name: '/kindura_reports',
          page: () => KinduraReportsScreen(),
        ),
        GetPage(
          name: RoutesName.vitalsHistoryScreen,
          page: () => VitalsHistoryScreen(),
        ),
        GetPage(
          name: '/contacts',
          page: () => ContactsScreen(),
        ),
        GetPage(
          name: RoutesName.adherenceAnalysisScreen,
          page: () => AdherenceAnalysisScreen(),
        ),
      ];
}
