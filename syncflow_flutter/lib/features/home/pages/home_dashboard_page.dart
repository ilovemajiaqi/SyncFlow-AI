import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/home_dashboard_provider.dart';
import '../widgets/calendar_header.dart';
import '../widgets/timeline_view.dart';
import '../widgets/voice_input_bar.dart';

class HomeDashboardPage extends StatelessWidget {
  const HomeDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<HomeDashboardProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          resizeToAvoidBottomInset: false,
          body: SafeArea(
            child: Column(
              children: [
                CalendarHeader(provider: provider),
                Expanded(child: TimelineView(provider: provider)),
              ],
            ),
          ),
          bottomNavigationBar: VoiceInputBar(provider: provider),
        );
      },
    );
  }
}
