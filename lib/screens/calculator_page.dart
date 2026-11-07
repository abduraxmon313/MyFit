import '../theme/app_theme.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'body_fat_calculator_page.dart';
import 'calorie_calculator_page.dart';
import 'water_calculator_page.dart';

class CalculatorPage extends StatelessWidget {
  const CalculatorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appColor(Color(0xFFFAFCFA), surface: true),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          context.tr('Fitness kalkulyatorlari'),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            context.tr('Maqsadingiz uchun kerakli hisob-kitobni tanlang.'),
            style: TextStyle(
              color: context.appColor(Color(0xFF697386), surface: false),
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 20),
          _CalculatorCard(
            icon: Icons.local_fire_department_rounded,
            color: Color(0xFFFF6B35),
            title: context.tr('Kunlik kaloriya va BMR'),
            description: context.tr(
              'Vazn saqlash, tashlash yoki olish uchun kaloriya miqdori.',
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const CalorieCalculatorPage(),
              ),
            ),
          ),
          _CalculatorCard(
            icon: Icons.accessibility_new_rounded,
            color: Color(0xFF9B51E0),
            title: context.tr('Tana yog‘i foizi'),
            description: context.tr(
              'Bo‘yin, qorin/bel va son o‘lchovlari orqali yog‘ foizini hisoblash.',
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const BodyFatCalculatorPage(),
              ),
            ),
          ),
          _CalculatorCard(
            icon: Icons.water_drop_rounded,
            color: Color(0xFF1597E5),
            title: context.tr('Kunlik suv ehtiyoji'),
            description: context.tr(
              'Vazn, mashq davomiyligi va ob-havoga qarab suv miqdori.',
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const WaterCalculatorPage(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CalculatorCard extends StatelessWidget {
  const _CalculatorCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(icon, color: color, size: 30),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      description,
                      style: TextStyle(
                        color: context.appColor(
                          Color(0xFF697386),
                          surface: false,
                        ),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
