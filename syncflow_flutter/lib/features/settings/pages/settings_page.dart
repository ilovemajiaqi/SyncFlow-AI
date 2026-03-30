import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/settings/app_settings_controller.dart';
import '../../../core/settings/user_api_settings.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _apiKeyController;
  late final TextEditingController _baseUrlController;
  late final TextEditingController _modelController;
  late final TextEditingController _defaultDurationController;
  late final TextEditingController _notificationCenterLeadController;
  late final TextEditingController _bannerLeadController;
  late final TextEditingController _bannerIntervalController;
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    final settings = context.read<AppSettingsController>().settings;
    _apiKeyController = TextEditingController(text: settings.apiKey);
    _baseUrlController = TextEditingController(text: settings.baseUrl);
    _modelController = TextEditingController(text: settings.modelName);
    _defaultDurationController =
        TextEditingController(text: settings.defaultDurationMinutes.toString());
    _notificationCenterLeadController = TextEditingController(
      text: settings.notificationCenterLeadMinutes.toString(),
    );
    _bannerLeadController =
        TextEditingController(text: settings.bannerLeadMinutes.toString());
    _bannerIntervalController = TextEditingController(
      text: settings.bannerRepeatIntervalMinutes.toString(),
    );
    _themeMode = settings.themeMode;
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _baseUrlController.dispose();
    _modelController.dispose();
    _defaultDurationController.dispose();
    _notificationCenterLeadController.dispose();
    _bannerLeadController.dispose();
    _bannerIntervalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppSettingsController>(
      builder: (context, controller, _) {
        return DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('设置'),
              bottom: const TabBar(
                tabs: [
                  Tab(text: '模型'),
                  Tab(text: '提醒'),
                  Tab(text: '偏好'),
                ],
              ),
            ),
            bottomNavigationBar: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: FilledButton(
                  onPressed: controller.isSaving
                      ? null
                      : () => _save(context, controller),
                  child: controller.isSaving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('保存设置'),
                ),
              ),
            ),
            body: TabBarView(
              children: [
                ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
                  children: [
                    _SectionCard(
                      title: '本地模型配置',
                      subtitle:
                          '这些配置只保存在当前设备。SyncFlow AI 会直接从本机请求你填写的 OpenAI 兼容模型服务，不经过中转后端。',
                      child: Column(
                        children: [
                          TextField(
                            controller: _apiKeyController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'API Key',
                              hintText: '输入你的模型服务密钥',
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _baseUrlController,
                            decoration: const InputDecoration(
                              labelText: 'Base URL',
                              hintText: 'https://api.deepseek.com/v1',
                              helperText:
                                  '只填根地址，别手动加 /chat/completions；如果误填了完整接口，应用也会自动纠正。',
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _modelController,
                            decoration: const InputDecoration(
                              labelText: 'Model Name',
                              hintText: 'deepseek-chat',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
                  children: [
                    _SectionCard(
                      title: '通知中心提醒',
                      subtitle: '事件开始前多久先进入系统通知中心。',
                      child: TextField(
                        controller: _notificationCenterLeadController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '提前多久进入通知中心（分钟）',
                          hintText: '120',
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _SectionCard(
                      title: '横幅提醒',
                      subtitle: '事件快到时开始弹横幅，并按你设定的间隔重复提醒。',
                      child: Column(
                        children: [
                          TextField(
                            controller: _bannerLeadController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: '提前多久开始横幅提醒（分钟）',
                              hintText: '15',
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _bannerIntervalController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: '横幅提醒间隔（分钟）',
                              hintText: '5',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
                  children: [
                    _SectionCard(
                      title: '本地解析偏好',
                      subtitle: '默认时长会在模型没有给出明确结束时间时，作为本地兜底时长使用。',
                      child: Column(
                        children: [
                          TextField(
                            controller: _defaultDurationController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: '默认任务时长（分钟）',
                              hintText: '60',
                            ),
                          ),
                          const SizedBox(height: 14),
                          SegmentedButton<ThemeMode>(
                            segments: const [
                              ButtonSegment<ThemeMode>(
                                value: ThemeMode.system,
                                label: Text('跟随系统'),
                              ),
                              ButtonSegment<ThemeMode>(
                                value: ThemeMode.light,
                                label: Text('浅色模式'),
                              ),
                              ButtonSegment<ThemeMode>(
                                value: ThemeMode.dark,
                                label: Text('深色模式'),
                              ),
                            ],
                            selected: {_themeMode},
                            onSelectionChanged: (selection) {
                              setState(() {
                                _themeMode = selection.first;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _save(
    BuildContext context,
    AppSettingsController controller,
  ) async {
    final parsedDuration = int.tryParse(_defaultDurationController.text.trim());
    final parsedCenterLead =
        int.tryParse(_notificationCenterLeadController.text.trim());
    final parsedBannerLead = int.tryParse(_bannerLeadController.text.trim());
    final parsedBannerInterval =
        int.tryParse(_bannerIntervalController.text.trim());
    final baseUrl = _baseUrlController.text.trim();

    if (parsedDuration == null || parsedDuration <= 0) {
      _showMessage(context, '默认任务时长请输入大于 0 的整数。');
      return;
    }
    if (parsedCenterLead == null || parsedCenterLead < 0) {
      _showMessage(context, '通知中心提前时间请输入大于等于 0 的整数。');
      return;
    }
    if (parsedBannerLead == null || parsedBannerLead < 0) {
      _showMessage(context, '横幅提前时间请输入大于等于 0 的整数。');
      return;
    }
    if (parsedBannerInterval == null || parsedBannerInterval <= 0) {
      _showMessage(context, '横幅提醒间隔请输入大于 0 的整数。');
      return;
    }
    if (baseUrl.isNotEmpty) {
      final parsedBaseUrl = Uri.tryParse(baseUrl);
      final isValidBaseUrl = parsedBaseUrl != null &&
          parsedBaseUrl.hasScheme &&
          (parsedBaseUrl.scheme == 'http' || parsedBaseUrl.scheme == 'https');
      if (!isValidBaseUrl) {
        _showMessage(context, 'Base URL 必须是完整的 http/https 地址。');
        return;
      }
    }

    final settings = UserApiSettings(
      apiKey: _apiKeyController.text.trim(),
      baseUrl: baseUrl,
      modelName: _modelController.text.trim(),
      defaultDurationMinutes: parsedDuration,
      themeMode: _themeMode,
      notificationCenterLeadMinutes: parsedCenterLead,
      bannerLeadMinutes: parsedBannerLead,
      bannerRepeatIntervalMinutes: parsedBannerInterval,
    );

    await controller.saveSettings(settings);
    if (!context.mounted) return;
    _showMessage(context, '设置已保存，新的本地模型配置会在下一次解析时立即生效。');
    Navigator.of(context).pop();
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.68),
                  ),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}
