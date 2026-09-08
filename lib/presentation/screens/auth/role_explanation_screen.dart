import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/background_pattern.dart';

class RoleExplanationScreen extends StatelessWidget {
  const RoleExplanationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          const BackgroundPattern(),
          SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white70 : Colors.black54, size: 20),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Understanding Cofiz',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Cofiz ማንነቱ እና ምንድነው',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 24),
                          _Section(
                            titleEn: 'Getting started',
                            titleAm: 'መጀመር',
                            bodyEn: 'Register with your name, company and phone number. The developer reviews and approves your account, then you log in with a code sent to your phone and set a 6-digit PIN.',
                            bodyAm: 'በስምዎ፣ በኩባንያዎ እና በስልክ ቁጥርዎ ይመዝገቡ። ገንቢው መለያዎን ካጸደቀ በኋላ በስልክዎ በሚደርስ ኮድ ይግቡ እና ባለ 6-አሃዝ PIN ያዘጋጁ።',
                            isDark: isDark,
                          ),
                          const SizedBox(height: 20),
                          _Section(
                            titleEn: 'Cash flow',
                            titleAm: 'የገንዘብ እንቅስቃሴ',
                            bodyEn: 'Admins give cash to collectors with Distribute. Collectors record coffee purchases and return cash with Return. Balances update instantly, and everything works offline and syncs later.',
                            bodyAm: 'አድሚኖች ገንዘብ ለሰብሳቢዎች ያከፋፍላሉ። ሰብሳቢዎች የቡና ግዢ ይመዝገባሉ እና ገንዘብ ይመልሳሉ። ሂሳቦች ወዲያውኑ ይዘምናሉ፤ ከመስመር ውጭ ሲሆኑም ይሰራል እና በኋላ ይመሳሰላል።',
                            isDark: isDark,
                          ),
                          const SizedBox(height: 20),
                          _Section(
                            titleEn: 'Debts',
                            titleAm: 'ዕዳዎች',
                            bodyEn: 'If a purchase costs more than the collector\u2019s balance, the extra amount is recorded as a debt. Debts stay open until they are marked as paid.',
                            bodyAm: 'ግዢው ካለው ሂሳብ በላይ ከሆነ ልዩነቱ እንደ ዕዳ ይመዘገባል። ዕዳዎች እስከሚከፈሉ ድረስ ክፍት ሆነው ይቆያሉ።',
                            isDark: isDark,
                          ),
                          const SizedBox(height: 20),
                          _Section(
                            titleEn: 'Income & expenses',
                            titleAm: 'ገቢ እና ወጪ',
                            bodyEn: 'Investor money and sales are recorded as income, running costs as expenses. The dashboard compares Cash In against Cash Out.',
                            bodyAm: 'የኢንቨስተሮች ገንዘብ እና ሽያጮች እንደ ገቢ ይመዘገባሉ፤ የስራ ማስኬጃ ወጪዎች ደግሞ እንደ ወጪ። ዳሽቦርዱ ገቢን (Cash In) ከወጪ (Cash Out) ጋር ያነጻጽራል።',
                            isDark: isDark,
                          ),
                          const SizedBox(height: 20),
                          _Section(
                            titleEn: 'Reports',
                            titleAm: 'ሪፖርቶች',
                            bodyEn: 'Filter by today, last 7 days, this month or any date, and export a PDF. Dates can follow the Ethiopian or Gregorian calendar.',
                            bodyAm: 'በዛሬ፣ ባለፉት 7 ቀናት፣ በዚህ ወር ወይም በማንኛውም ቀን ያጣሩ እና PDF ሪፖርት ያውጡ። ቀናት በኢትዮጵያ ወይም በግሪጎሪያን አቆጣጠር ሊታዩ ይችላሉ።',
                            isDark: isDark,
                          ),
                          const SizedBox(height: 20),
                          _Section(
                            titleEn: 'Notifications',
                            titleAm: 'ማሳወቂያዎች',
                            bodyEn: 'The bell shows every event and collectors can ping admins. Turn push alerts on in Settings, and verify your email to also receive email updates.',
                            bodyAm: 'የደወል ምልክቱ እያንዳንዱን ክስተት ያሳያል፤ ሰብሳቢዎች ለአድሚኖች መልእክት መላክ ይችላሉ። በቅንብሮች (Settings) የስልክ ማሳወቂያዎችን ያብሩ፤ ኢሜይልዎ ከተረጋገጠ በኢሜይልም ማሳወቂያ ይደርስዎታል።',
                            isDark: isDark,
                          ),
                          const SizedBox(height: 20),
                          _Section(
                            titleEn: 'Security & settings',
                            titleAm: 'ደህንነት እና ቅንብሮች',
                            bodyEn: 'A PIN locks the app with auto-lock and fingerprint unlock. Switch language, theme and calendar, back up data, and admins can review the audit log of every change.',
                            bodyAm: 'PIN መተግበሪያውን ይቆልፋል፤ ከቆይታ በኋላ በራስ-ሰር ይቆለፋል እና በጣት አሻራ ይከፈታል። ቋንቋ፣ ገጽታ እና አቆጣጠር ይቀይሩ፤ ምትኬ ያስቀምጡ፤ አድሚኖች የሁሉንም ለውጥ መዝገብ ማየት ይችላሉ።',
                            isDark: isDark,
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String titleEn;
  final String titleAm;
  final String bodyEn;
  final String bodyAm;
  final bool isDark;

  const _Section({
    required this.titleEn,
    required this.titleAm,
    required this.bodyEn,
    required this.bodyAm,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              titleEn,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              titleAm,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          bodyEn,
          style: TextStyle(
            fontSize: 13,
            height: 1.6,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          bodyAm,
          style: TextStyle(
            fontSize: 12.5,
            height: 1.6,
            color: isDark ? Colors.white38 : Colors.black38,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}
