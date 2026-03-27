import 'package:flutter/material.dart';

import 'controllers/app_controller.dart';
import 'pages/home_page.dart';
import 'pages/settings_page.dart';
import 'services/ai_service.dart';
import 'services/excel_service.dart';
import 'services/history_service.dart';
import 'services/pdf_service.dart';
import 'services/scanner_service.dart';
import 'services/settings_service.dart';
import 'services/task_queue_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final controller = AppController(
    settingsService: SettingsService(),
    excelService: ExcelService(),
    scannerService: ScannerService(),
    pdfService: PdfService(),
    aiService: AiService(),
    historyService: HistoryService(),
    taskQueueService: TaskQueueService(),
  );

  runApp(ScanAiExcelApp(controller: controller));
}

class ScanAiExcelApp extends StatefulWidget {
  const ScanAiExcelApp({super.key, required this.controller});

  final AppController controller;

  @override
  State<ScanAiExcelApp> createState() => _ScanAiExcelAppState();
}

class _ScanAiExcelAppState extends State<ScanAiExcelApp> {
  late final Future<void> _initializeFuture;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _initializeFuture = widget.controller.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ScanExcel',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: FutureBuilder<void>(
        future: _initializeFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          return Scaffold(
            body: IndexedStack(
              index: _currentIndex,
              children: [
                HomePage(controller: widget.controller),
                SettingsPage(controller: widget.controller),
              ],
            ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: _currentIndex,
              onDestinationSelected: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: '首页',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: '我的',
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
