import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/issue.dart';
import '../models/ward_stats.dart';
import '../providers/app_provider.dart';
import '../services/admin_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../utils/complaint_reference.dart';
import '../utils/issue_categories.dart';
import '../utils/sla.dart';
import '../widgets/status_chip.dart';
import 'issue_detail_screen.dart';

/// The municipal officer's view: what the ward's position is, then what to do
/// about it.
///
/// Opens on counters rather than the queue because the first question an
/// officer is asked is "where are we", not "what is next". The queue sits
/// directly beneath, already ranked by the server.
class AdminConsoleScreen extends StatefulWidget {
  const AdminConsoleScreen({super.key});

  @override
  State<AdminConsoleScreen> createState() => _AdminConsoleScreenState();
}

class _AdminConsoleScreenState extends State<AdminConsoleScreen> {
  final AdminService _adminService = AdminService();

  WardStats _stats = WardStats.empty;
  List<Issue> _queue = [];
  bool _isLoading = true;
  String? _error;

  /// Null means "everything"; otherwise a status from the server's enum.
  String? _statusFilter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _adminService.getStats(),
        _adminService.getQueue(status: _statusFilter),
      ]);

      if (!mounted) return;
      setState(() {
        _stats = results[0] as WardStats;
        _queue = results[1] as List<Issue>;
        _isLoading = false;
      });
    } on AdminException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not reach the server.';
        _isLoading = false;
      });
    }
  }

  Future<void> _applyFilter(String? status) async {
    setState(() => _statusFilter = status);
    await _load();
  }

  Future<void> _openStatusSheet(Issue issue) async {
    final result = await showModalBottomSheet<_StatusChange>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      isScrollControlled: true,
      builder: (_) => _StatusSheet(issue: issue),
    );

    if (result == null || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await _adminService.updateStatus(
        issueId: issue.id,
        status: result.status,
        note: result.note,
      );
      messenger.showSnackBar(
        SnackBar(content: Text('${issue.title} marked ${result.status}.')),
      );
      await _load();
    } on AdminException catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: StatusColors.rejected.foreground,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final address = context.select<AppProvider, String?>(
      (p) => p.currentAddress,
    );
    final jurisdiction =
        ComplaintReference.locality(address)?.toUpperCase() ?? 'ALL WARDS';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Municipal console',
              style: Theme.of(context).appBarTheme.titleTextStyle,
            ),
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Text(
                jurisdiction,
                style: AppTypography.badge(color: AppColors.navy200),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _load,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _queue.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _ConsoleError(message: _error!, onRetry: _load);
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _MetricGrid(stats: _stats),
          if (_stats.byCategory.isNotEmpty)
            _CategoryBreakdown(stats: _stats),
          _QueueHeader(
            count: _queue.length,
            selected: _statusFilter,
            onSelected: _applyFilter,
          ),
          if (_queue.isEmpty)
            const _QueueEmpty()
          else
            ..._queue.map(
              (issue) => _QueueRow(
                issue: issue,
                onChangeStatus: () => _openStatusSheet(issue),
                onOpen: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => IssueDetailScreen(issueId: issue.id),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Four counters, two across. Overdue carries the alert palette because it is
/// the only one that demands action rather than reporting a position.
class _MetricGrid extends StatelessWidget {
  final WardStats stats;

  const _MetricGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    final avg = stats.avgCloseDays;

    return Container(
      color: AppColors.slate100,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _Metric(
                  value: '${stats.open}',
                  label: 'OPEN',
                ),
              ),
              Expanded(
                child: _Metric(
                  value: '${stats.overdue}',
                  label: 'OVERDUE',
                  palette: stats.overdue > 0 ? StatusColors.overdue : null,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  value: '${stats.resolved}',
                  label: 'RESOLVED',
                  valueColor: StatusColors.resolved.foreground,
                ),
              ),
              Expanded(
                child: _Metric(
                  value: avg == null ? '—' : avg.toStringAsFixed(1),
                  unit: avg == null ? null : 'd',
                  label: 'AVG CLOSE',
                  // Says what the average is actually built from, so the number
                  // can be defended when someone asks.
                  footnote: avg == null
                      ? 'no closures yet'
                      : 'over ${stats.measuredClosures} closed',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String value;
  final String? unit;
  final String label;
  final String? footnote;
  final Color? valueColor;
  final StatusPalette? palette;

  const _Metric({
    required this.value,
    required this.label,
    this.unit,
    this.footnote,
    this.valueColor,
    this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final fg = palette?.foreground ?? valueColor ?? AppColors.navy900;

    return Container(
      color: palette?.background ?? AppColors.surface,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value, style: AppTypography.metric(color: fg)),
              if (unit != null)
                Text(
                  unit!,
                  style: AppTypography.metric(color: fg).copyWith(fontSize: 15),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTypography.badge(
              color: palette?.foreground ?? AppColors.slate600,
            ),
          ),
          if (footnote != null) ...[
            const SizedBox(height: 3),
            Text(
              footnote!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontSize: 10),
            ),
          ],
        ],
      ),
    );
  }
}

/// Where the ward's complaints are concentrated.
///
/// Horizontal bars rather than vertical: category names are words, and words
/// need width. A vertical chart on a phone would truncate every label.
class _CategoryBreakdown extends StatelessWidget {
  final WardStats stats;

  const _CategoryBreakdown({required this.stats});

  @override
  Widget build(BuildContext context) {
    final rows = stats.byCategory.take(5).toList();
    final max = rows.fold<int>(0, (m, r) => r.count > m ? r.count : m);

    return Container(
      width: double.infinity,
      color: AppColors.surface,
      margin: const EdgeInsets.only(top: 1),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('BY CATEGORY', style: AppTypography.sectionLabel()),
          const SizedBox(height: 12),
          for (final row in rows) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                children: [
                  SizedBox(
                    width: 92,
                    child: Text(
                      IssueCategories.labelFor(row.category),
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: max == 0 ? 0 : row.count / max,
                        minHeight: 7,
                        backgroundColor: AppColors.slate100,
                        valueColor: const AlwaysStoppedAnimation(
                          AppColors.navy700,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 30,
                    child: Text(
                      '${row.count}',
                      textAlign: TextAlign.right,
                      style: AppTypography.inlineCount(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Queue title and the status filters.
class _QueueHeader extends StatelessWidget {
  final int count;
  final String? selected;
  final ValueChanged<String?> onSelected;

  const _QueueHeader({
    required this.count,
    required this.selected,
    required this.onSelected,
  });

  static const _filters = <String?, String>{
    null: 'All',
    'Pending': 'Pending',
    'In Progress': 'In progress',
    'Resolved': 'Resolved',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      margin: const EdgeInsets.only(top: 1),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('TRIAGE QUEUE', style: AppTypography.sectionLabel()),
              const Spacer(),
              Text('$count', style: AppTypography.inlineCount()),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final entry in _filters.entries)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _FilterChip(
                      label: entry.value,
                      selected: selected == entry.key,
                      onTap: () => onSelected(entry.key),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Ranked by urgency: overdue first, then most-supported, then oldest.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(3),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.navy900 : AppColors.surface,
          border: Border.all(
            color: selected ? AppColors.navy900 : AppColors.slate200,
          ),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontSize: 12,
            color: selected ? Colors.white : AppColors.slate600,
          ),
        ),
      ),
    );
  }
}

/// One complaint awaiting action.
class _QueueRow extends StatelessWidget {
  final Issue issue;
  final VoidCallback onChangeStatus;
  final VoidCallback onOpen;

  const _QueueRow({
    required this.issue,
    required this.onChangeStatus,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final sla = SlaPolicy.evaluate(issue);

    return Container(
      color: sla.isOverdue
          ? StatusColors.overdue.background
          : AppColors.surface,
      margin: const EdgeInsets.only(top: 1),
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 11, 8, 11),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            issue.title,
                            style: Theme.of(context).textTheme.titleSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        StatusChip(
                          status: issue.status,
                          overdue: sla.isOverdue,
                          dense: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Text(
                          ComplaintReference.format(issue),
                          style: AppTypography.recordId(),
                        ),
                        const SizedBox(width: 8),
                        Flexible(child: SlaLabel(sla: sla)),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.arrow_drop_up,
                          size: 15,
                          color: AppColors.slate600,
                        ),
                        Text(
                          '${issue.agreeCount}',
                          style: AppTypography.inlineCount(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 19),
                color: AppColors.navy700,
                tooltip: 'Change status',
                onPressed: onChangeStatus,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What the officer chose in the status sheet.
class _StatusChange {
  final String status;
  final String note;

  const _StatusChange(this.status, this.note);
}

/// Move a complaint to a new state, with an optional note for the record.
class _StatusSheet extends StatefulWidget {
  final Issue issue;

  const _StatusSheet({required this.issue});

  @override
  State<_StatusSheet> createState() => _StatusSheetState();
}

class _StatusSheetState extends State<_StatusSheet> {
  static const _statuses = ['Pending', 'In Progress', 'Resolved', 'Rejected'];

  final _noteController = TextEditingController();
  late String _selected = widget.issue.status;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.issue.title,
                style: Theme.of(context).textTheme.titleMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                ComplaintReference.format(widget.issue),
                style: AppTypography.recordId(),
              ),
              const SizedBox(height: 16),
              Text('SET STATUS', style: AppTypography.sectionLabel()),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final status in _statuses)
                    _FilterChip(
                      label: status,
                      selected: _selected == status,
                      onTap: () => setState(() => _selected = status),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _noteController,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Note for the record (optional)',
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _selected == widget.issue.status
                          ? null
                          : () => Navigator.of(context).pop(
                              _StatusChange(_selected, _noteController.text),
                            ),
                      child: const Text('Update'),
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

class _QueueEmpty extends StatelessWidget {
  const _QueueEmpty();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      margin: const EdgeInsets.only(top: 1),
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        children: [
          const Icon(
            Icons.inbox_outlined,
            size: 36,
            color: AppColors.slate200,
          ),
          const SizedBox(height: 10),
          Text(
            'Nothing in this filter',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(
            'Clear the filter to see the rest of the ward.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _ConsoleError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ConsoleError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 38,
              color: AppColors.slate200,
            ),
            const SizedBox(height: 12),
            Text(message, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
