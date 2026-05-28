import 'package:english_learning_app/l10n/spark_strings.dart';
import 'package:english_learning_app/models/offline_pack_progress.dart';
import 'package:english_learning_app/services/offline_practice_service.dart';
import 'package:flutter/material.dart';

/// Parent-facing card to download unlocked practice content for offline use.
class OfflineDownloadsCard extends StatefulWidget {
  const OfflineDownloadsCard({
    super.key,
    required this.userId,
    this.offlineService,
  });

  final String userId;
  final OfflinePracticeService? offlineService;

  @override
  State<OfflineDownloadsCard> createState() => _OfflineDownloadsCardState();
}

class _OfflineDownloadsCardState extends State<OfflineDownloadsCard> {
  late final OfflinePracticeService _service;
  OfflinePackManifest? _manifest;
  bool _loadingManifest = true;

  @override
  void initState() {
    super.initState();
    _service = widget.offlineService ?? OfflinePracticeService();
    _loadManifest();
    _service.progressStream.listen((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  Future<void> _loadManifest() async {
    final manifest = await _service.loadManifest();
    if (mounted) {
      setState(() {
        _manifest = manifest;
        _loadingManifest = false;
      });
    }
  }

  Future<void> _startDownload() async {
    await _service.downloadAllUnlocked(userId: widget.userId);
    await _loadManifest();
  }

  String _statusSubtitle(OfflinePackProgress progress) {
    switch (progress.phase) {
      case OfflinePackPhase.idle:
        if (_manifest != null) {
          return SparkStrings.offlineDownloadsLastDownload(
            _formatWhen(_manifest!.downloadedAt),
            _manifest!.levelIds.length,
          );
        }
        return SparkStrings.offlineDownloadsHint;
      case OfflinePackPhase.preparing:
      case OfflinePackPhase.downloading:
        if (progress.currentLevelName != null) {
          return progress.currentLevelName!;
        }
        return progress.message ?? SparkStrings.offlineDownloadsDownloading;
      case OfflinePackPhase.complete:
        return progress.message ?? SparkStrings.offlineDownloadsComplete;
      case OfflinePackPhase.failed:
        return progress.errorMessage ?? SparkStrings.offlineDownloadsFailed;
    }
  }

  String _formatWhen(DateTime when) {
    final day = when.day.toString().padLeft(2, '0');
    final month = when.month.toString().padLeft(2, '0');
    final year = when.year;
    final hour = when.hour.toString().padLeft(2, '0');
    final minute = when.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final progress = _service.latestProgress;
    final isBusy = progress.phase == OfflinePackPhase.preparing ||
        progress.phase == OfflinePackPhase.downloading;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.download_for_offline, color: Colors.teal.shade700),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    SparkStrings.offlineDownloadsTitle,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              SparkStrings.offlineDownloadsDescription,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
            ),
            if (!_loadingManifest) ...[
              const SizedBox(height: 8),
              Text(
                _statusSubtitle(progress),
                style: TextStyle(
                  color: isBusy ? Colors.teal.shade800 : Colors.grey.shade600,
                  fontSize: 13,
                ),
              ),
            ],
            if (isBusy) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: progress.overallFraction > 0
                    ? progress.overallFraction
                    : null,
                minHeight: 8,
                borderRadius: BorderRadius.circular(8),
                backgroundColor: Colors.grey.shade200,
                color: Colors.teal,
              ),
              if (progress.totalItems > 0) ...[
                const SizedBox(height: 6),
                Text(
                  SparkStrings.offlineDownloadsProgress(
                    progress.completedItems,
                    progress.totalItems,
                  ),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isBusy ? null : _startDownload,
                icon: isBusy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.cloud_download),
                label: Text(SparkStrings.offlineDownloadsButton),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
