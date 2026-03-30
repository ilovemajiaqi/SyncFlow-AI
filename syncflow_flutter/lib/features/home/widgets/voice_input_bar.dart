import 'package:flutter/material.dart';

import '../providers/home_dashboard_provider.dart';

class VoiceInputBar extends StatefulWidget {
  const VoiceInputBar({
    super.key,
    required this.provider,
  });

  final HomeDashboardProvider provider;

  @override
  State<VoiceInputBar> createState() => _VoiceInputBarState();
}

class _VoiceInputBarState extends State<VoiceInputBar> {
  late final FocusNode _textFocusNode;

  @override
  void initState() {
    super.initState();
    _textFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _textFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF111A2B) : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF2A3751) : const Color(0xFFE5E9F2);
    final panelShadow = Colors.black.withValues(alpha: isDark ? 0.24 : 0.06);
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final helperColor = theme.colorScheme.onSurface.withValues(alpha: 0.52);

    return AnimatedPadding(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.fromLTRB(
        14,
        8,
        14,
        keyboardInset > 0 ? keyboardInset + 12 : 18,
      ),
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: panelShadow,
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!provider.isSubmittingIntent)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                  child: Text(
                    '例如：明天下午三点安排 1 小时深度工作',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      color: helperColor,
                    ),
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: TextField(
                        controller: provider.textController,
                        focusNode: _textFocusNode,
                        autofocus: true,
                        textInputAction: TextInputAction.send,
                        minLines: 1,
                        maxLines: 1,
                        onSubmitted: (_) async {
                          await provider.submitTextIntent(context);
                        },
                        decoration: const InputDecoration(
                          isDense: true,
                          hintText: '',
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 68,
                    height: 48,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: provider.isSubmittingIntent
                          ? null
                          : () async {
                              await provider.submitTextIntent(context);
                            },
                      child: provider.isSubmittingIntent
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('发送'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
