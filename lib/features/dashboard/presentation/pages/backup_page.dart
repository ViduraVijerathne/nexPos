import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../app_bootstrap_page.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/toast/app_toast.dart';
import '../../../backup/services/backup_service.dart';

class BackupPage extends StatefulWidget {
  const BackupPage({super.key});

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  final BackupService _backupService = BackupService.instance;

  bool _isLoading = true;
  bool _isBusy = false;
  BackupState _state = const BackupState(
    records: <BackupRecord>[],
    backupOnLogin: false,
  );

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    try {
      final state = await _backupService.loadState();
      if (!mounted) {
        return;
      }
      setState(() {
        _state = state;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoading = false);
      AppToast.error('Failed to load backups: $error');
    }
  }

  Future<void> _handleCreateBackup() async {
    setState(() => _isBusy = true);
    try {
      final backup = await _backupService.createBackup(
        type: 'Full System Backup',
      );
      await _loadState();
      AppToast.success('${backup.name} created successfully');
    } catch (error) {
      AppToast.error('Failed to create backup: $error');
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _handleToggleBackupOnLogin(bool value) async {
    try {
      await _backupService.setBackupOnLogin(value);
      setState(() {
        _state = BackupState(records: _state.records, backupOnLogin: value);
      });
      AppToast.success(
        value
            ? 'Backup on every login enabled'
            : 'Backup on every login disabled',
      );
    } catch (error) {
      AppToast.error('Failed to update backup preference: $error');
    }
  }

  Future<void> _handleExportBackup(BackupRecord record) async {
    try {
      final exportedPath = await _backupService.exportBackup(record);
      if (exportedPath == null) {
        return;
      }
      AppToast.success('Backup exported successfully');
    } catch (error) {
      AppToast.error('Failed to export backup: $error');
    }
  }

  Future<void> _handleRestoreExistingBackup() async {
    if (_state.records.isEmpty) {
      AppToast.info('No local backups available to restore');
      return;
    }

    final selectedRecord = await showDialog<BackupRecord>(
      context: context,
      builder: (context) => _RestoreBackupDialog(records: _state.records),
    );

    if (selectedRecord == null || !mounted) {
      return;
    }

    final confirmed = await _showRestoreConfirmation(
      'Restore ${selectedRecord.name}?',
      'This will replace the current local database and reload the application.',
    );
    if (!confirmed) {
      return;
    }

    await _restoreAction(() => _backupService.restoreBackup(selectedRecord));
  }

  Future<void> _handleImportRestore() async {
    final confirmed = await _showRestoreConfirmation(
      'Restore external backup?',
      'This will import a selected `.isar` backup file and replace the current local database.',
    );
    if (!confirmed) {
      return;
    }

    await _restoreAction(() async {
      final restoredPath = await _backupService.pickAndRestoreBackup();
      if (restoredPath == null) {
        throw _BackupCancelledException();
      }
    });
  }

  Future<bool> _showRestoreConfirmation(String title, String message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF334156),
          ),
        ),
        content: Text(
          message,
          style: const TextStyle(color: Color(0xFF637287), height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF36B4AE),
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    return confirmed ?? false;
  }

  Future<void> _restoreAction(Future<void> Function() action) async {
    setState(() => _isBusy = true);
    try {
      await action();
      if (!mounted) {
        return;
      }
      AppToast.success('Backup restored successfully');
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const AppBootstrapPage()),
        (route) => false,
      );
    } on _BackupCancelledException {
      AppToast.info('Backup restore cancelled');
    } catch (error) {
      AppToast.error('Failed to restore backup: $error');
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  String _formatRelativeTime(DateTime? date) {
    if (date == null) {
      return 'No backups yet';
    }

    final difference = DateTime.now().difference(date);
    if (difference.inMinutes < 1) {
      return 'Just now';
    }
    if (difference.inHours < 1) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    }
    if (difference.inDays < 1) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    }
    return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
  }

  String _formatSize(int bytes) {
    final gigabyte = 1024 * 1024 * 1024;
    final megabyte = 1024 * 1024;
    final kilobyte = 1024;
    if (bytes >= gigabyte) {
      return '${(bytes / gigabyte).toStringAsFixed(1)} GB';
    }
    if (bytes >= megabyte) {
      return '${(bytes / megabyte).toStringAsFixed(1)} MB';
    }
    if (bytes >= kilobyte) {
      return '${(bytes / kilobyte).toStringAsFixed(1)} KB';
    }
    return '$bytes B';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.primaryTeal),
      );
    }

    final latestBackup = _state.latestBackup;

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _BackupHeader(
                onRestorePressed: _handleRestoreExistingBackup,
                onCreatePressed: _handleCreateBackup,
                onImportRestorePressed: _handleImportRestore,
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _BackupSummaryCard(
                      icon: Icons.storage_rounded,
                      iconColor: const Color(0xFF37B6B0),
                      iconBackground: const Color(0xFFE5FBF7),
                      title: 'Total Backups',
                      value: '${_state.totalBackups}',
                      subtitle: 'Stored restore points',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _BackupSummaryCard(
                      icon: Icons.schedule_rounded,
                      iconColor: const Color(0xFF4D9FFF),
                      iconBackground: const Color(0xFFEAF4FF),
                      title: 'Last Backup',
                      value: _formatRelativeTime(latestBackup?.createdAt),
                      subtitle:
                          latestBackup?.formattedDateTime ??
                          'No backup history yet',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _BackupSummaryCard(
                      icon: Icons.data_object_rounded,
                      iconColor: const Color(0xFFB74ADB),
                      iconBackground: const Color(0xFFF8EAFF),
                      title: 'Total Size',
                      value: _formatSize(_state.totalSizeBytes),
                      subtitle: 'Across all backup files',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _BackupHistoryCard(
                records: _state.records,
                onExport: _handleExportBackup,
              ),
              const SizedBox(height: 22),
              _BackupSettingsCard(
                backupOnLogin: _state.backupOnLogin,
                onToggle: _handleToggleBackupOnLogin,
              ),
            ],
          ),
        ),
        if (_isBusy)
          Positioned.fill(
            child: Container(
              color: const Color(0x660F172A),
              alignment: Alignment.center,
              child: Container(
                width: 180,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AppColors.primaryTeal),
                    SizedBox(height: 14),
                    Text(
                      'Processing backup...',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF445368),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _BackupHeader extends StatelessWidget {
  const _BackupHeader({
    required this.onRestorePressed,
    required this.onCreatePressed,
    required this.onImportRestorePressed,
  });

  final VoidCallback onRestorePressed;
  final VoidCallback onCreatePressed;
  final VoidCallback onImportRestorePressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Backups',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF334156),
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Manage your system backups and data recovery.',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF8492A6),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        OutlinedButton.icon(
          onPressed: onImportRestorePressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF36B4AE),
            side: const BorderSide(color: Color(0xFF67CBC5)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            minimumSize: const Size(116, 40),
          ),
          icon: const Icon(Icons.upload_file_outlined, size: 18),
          label: const Text(
            'Import',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 10),
        OutlinedButton.icon(
          onPressed: onRestorePressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF36B4AE),
            side: const BorderSide(color: Color(0xFF67CBC5)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            minimumSize: const Size(116, 40),
          ),
          icon: const Icon(Icons.restore_rounded, size: 18),
          label: const Text(
            'Restore',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 10),
        ElevatedButton.icon(
          onPressed: onCreatePressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF36B4AE),
            foregroundColor: Colors.white,
            elevation: 0,
            minimumSize: const Size(146, 40),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text(
            'Create Backup',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _BackupSummaryCard extends StatelessWidget {
  const _BackupSummaryCard({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.value,
    required this.subtitle,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7EDF5)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF8A98AC),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF334156),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: Color(0xFF8A98AC),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackupHistoryCard extends StatelessWidget {
  const _BackupHistoryCard({required this.records, required this.onExport});

  final List<BackupRecord> records;
  final ValueChanged<BackupRecord> onExport;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7EDF5)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Backup History',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF334156),
            ),
          ),
          const SizedBox(height: 14),
          if (records.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 36),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FBFE),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE9EFF6)),
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons.archive_outlined,
                    size: 34,
                    color: Color(0xFFB3C0D1),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'No backups available yet',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF66758B),
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Create your first backup to protect local data.',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF93A0B4),
                    ),
                  ),
                ],
              ),
            )
          else
            Column(
              children: [
                for (final record in records) ...[
                  _BackupHistoryRow(
                    record: record,
                    onExport: () => onExport(record),
                  ),
                  if (record != records.last) const SizedBox(height: 12),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _BackupHistoryRow extends StatelessWidget {
  const _BackupHistoryRow({required this.record, required this.onExport});

  final BackupRecord record;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    final exists = File(record.filePath).existsSync();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8EEF5)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFE5FBF7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.storage_rounded,
              color: Color(0xFF36B4AE),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.name,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF334156),
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    _MetaText(
                      icon: Icons.schedule_rounded,
                      text: record.formattedDateTime,
                    ),
                    _MetaText(
                      icon: Icons.data_object_rounded,
                      text: record.formattedSize,
                    ),
                    _MetaText(icon: Icons.folder_outlined, text: record.type),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: exists ? const Color(0xFFE5FBF7) : const Color(0xFFFDECEC),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              exists ? record.status : 'Missing',
              style: TextStyle(
                color: exists
                    ? const Color(0xFF36B4AE)
                    : const Color(0xFFE15B5B),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            onPressed: exists ? onExport : null,
            icon: const Icon(
              Icons.download_rounded,
              size: 20,
              color: Color(0xFF5A687D),
            ),
            tooltip: 'Export backup',
          ),
        ],
      ),
    );
  }
}

class _BackupSettingsCard extends StatelessWidget {
  const _BackupSettingsCard({
    required this.backupOnLogin,
    required this.onToggle,
  });

  final bool backupOnLogin;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFEAFBFD),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF77D7D3)),
      ),
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.schedule_rounded,
              color: Color(0xFF36B4AE),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Automated Backup Schedule',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF334156),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Enable an automatic local backup every time the cashier successfully logs in. This is useful for debugging and frequent workstation recovery.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF6A7A8F),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFD8EFF0)),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Backup Every Login',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF334156),
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Run a new backup after each successful login.',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF8391A5),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        value: backupOnLogin,
                        activeColor: const Color(0xFF36B4AE),
                        onChanged: onToggle,
                      ),
                    ],
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

class _MetaText extends StatelessWidget {
  const _MetaText({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: const Color(0xFF8D9BB0)),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: Color(0xFF8A98AC),
          ),
        ),
      ],
    );
  }
}

class _RestoreBackupDialog extends StatelessWidget {
  const _RestoreBackupDialog({required this.records});

  final List<BackupRecord> records;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 660),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Backup to Restore',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF334156),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Choose a local backup file to restore your current workstation data.',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF7E8C9F),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 18),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (final record in records) ...[
                        _RestoreBackupOption(record: record),
                        if (record != records.last) const SizedBox(height: 10),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RestoreBackupOption extends StatelessWidget {
  const _RestoreBackupOption({required this.record});

  final BackupRecord record;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => Navigator.of(context).pop(record),
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE4EAF2)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFE5FBF7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.restore_page_outlined,
                size: 20,
                color: Color(0xFF36B4AE),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF334156),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${record.formattedDateTime}  •  ${record.formattedSize}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF8A98AC),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF90A0B5)),
          ],
        ),
      ),
    );
  }
}

class _BackupCancelledException implements Exception {}
