import '../controllers/app_controller.dart';
import '../models/scan_task.dart';

class TaskQueueService {
  bool _running = false;

  bool get running => _running;

  Future<void> processPending(AppController controller) async {
    if (_running) return;
    _running = true;
    controller.notifyQueueStateChanged();
    try {
      while (true) {
        final task = controller.tasks.firstWhere(
          (item) => item.status == TaskStatus.queued,
          orElse: () => const ScanTask(
            rowIndex: -1,
            taskName: '',
            pdfFileNameStem: '',
            rowData: {},
            status: TaskStatus.pending,
          ),
        );
        if (task.rowIndex == -1) {
          break;
        }
        await controller.processQueuedTask(task);
      }
    } finally {
      _running = false;
      controller.notifyQueueStateChanged();
    }
  }
}
