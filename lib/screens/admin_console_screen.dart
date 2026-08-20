import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/issue.dart';
import '../models/ward_stats.dart';
import '../providers/app_provider.dart';
import '../services/admin_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
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
    final jurisdiction = ComplaintReference.locality(address) ?? 'All wards';

    return Scaffold(
      appBar: AppBar(
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: Text(
                'Municipal console',
                style: Theme.of(context).appBarTheme.titleTextStyle,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 9),
            Flexible(
              child: Text(
                jurisdiction,
                style: Theme.of(context).textTheme.bodySmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 21),
              tooltip: 'Refresh',
              onPressed: _isLoading ? null : _load,
            ),
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
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          _MetricGrid(stats: _stats),
          if (_stats.byCategory.isNotEmpty) _CategoryBreakdown(stats: _stats),
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

/// Four counters on one card.
///
/// The old grid was four full-bleed cells split by 1px gaps, which read as a
/// spreadsheet. One card with generous internal spacing says the same thing,
/// and lets Overdue stand out by colour alone instead of by a filled cell.
class _MetricGrid extends StatelessWidget {
  final WardStats stats;

  const _MetricGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    final avg = stats.avgCloseDays;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        decoration: AppTheme.cardDecoration,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _Metric(value: '${stats.open}', label: 'Open'),
                ),
                Expanded(
                  child: _Metric(
                    value: '${stats.overdue}',
                    label: 'Overdue',
                    color: stats.overdue > 0
                        ? StatusColors.overdue.foreground
                        : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _Metric(
                    value: '${stats.resolved}',
                    label: 'Resolved',
                    color: StatusColors.resolved.foreground,
                  ),
                ),
                Expanded(
                  child: _Metric(
                    value: avg == null ? '—' : avg.toStringAsFixed(1),
                    unit: avg == null ? null : 'd',
                    label: 'Avg close',
                    // Says what the average is built from, so the number can be
                    // defended when someone asks.
                    footnote: avg == null
                        ? 'no closures yet'
                        : 'over ${stats.measuredClosures} closed',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String value;
  final String? unit;
  final String label;
  final String? footnote;
  final Color? color;

  const _Metric({
    required this.value,
    required this.label,
    this.unit,
    this.footnote,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final fg = color ?? AppColors.navy900;

    return Column(
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
                style: AppTypography.metric(color: fg).copyWith(fontSize: 16),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(label, style: AppTypography.meta(color: AppColors.slate600)),
        if (footnote != null) ...[
          const SizedBox(height: 2),
          Text(footnote!, style: AppTypography.meta().copyWith(fontSize: 11.5)),
        ],
      ],
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        width: double.infinity,
        decoration: AppTheme.cardDecoration,
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'By category',
              style: AppTypography.sectionLabel(color: AppColors.slate600),
            ),
            const SizedBox(height: 14),
            for (final row in rows) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    SizedBox(
                      width: 96,
                      child: Text(
                        IssueCategories.labelFor(row.category),
                        style: AppTypography.meta(color: AppColors.slate600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: max == 0 ? 0 : row.count / max,
                          minHeight: 6,
                          backgroundColor: AppColors.slate100,
                          valueColor: const AlwaysStoppedAnimation(
                            AppColors.navy700,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 32,
                      child: Text(
                        '${row.count}',
                        textAlign: TextAlign.right,
                        style: AppTypography.inlineCount(
                          color: AppColors.slate600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Queue title and the status filters.
///
/// Sits on the canvas rather than in a white strip of its own: it names the
/// list of cards below it, and a heading does not need a surface to do that.
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 26, 16, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                'Triage queue',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(width: 8),
              Text('$count', style: AppTypography.inlineCount()),
            ],
          ),
        ),
        const SizedBox(height: 3),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Overdue first, then most-supported, then oldest.',
            style: AppTypography.meta(),
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              for (final entry in _filters.entries)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _FilterChip(
                    label: entry.value,
                    selected: selected == entry.key,
                    onTap: () => onSelected(entry.key),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A status filter. Filled when chosen, a quiet tint when not — the outline
/// it used to wear was doing the same job with more lines.
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
    return Material(
      color: selected ? AppColors.navy900 : AppColors.slate100,
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Text(
            label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: selected ? Colors.white : AppColors.slate600,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

/// One complaint awaiting action.
///
/// A card like the ones the citizen sees, minus the photograph — an officer
/// triaging thirty of these needs the title, the clock, and a way in, and the
/// picture belongs on the detail screen. Overdue work tints the whole card,
/// which is the one place colour is allowed to carry across a surface.
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: DecoratedBox(
        decoration: AppTheme.cardDecoration.copyWith(
          color: sla.isOverdue
              ? StatusColors.overdue.background
              : AppColors.surface,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onOpen,
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
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
                            const SizedBox(width: 10),
                            StatusChip(
                              status: issue.status,
                              overdue: sla.isOverdue,
                              dense: true,
                            ),
                          ],
                        ),
                        const SizedBox(height: 7),
                        Row(
                          children: [
                            Text(
                              ComplaintReference.format(issue),
                              style: AppTypography.recordId(),
                            ),
                            const SizedBox(width: 10),
                            Flexible(child: SlaLabel(sla: sla)),
                            const SizedBox(width: 10),
                            const Icon(
                              Icons.arrow_upward_rounded,
                              size: 13,
                              color: AppColors.slate400,
                            ),
                            const SizedBox(width: 3),
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
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
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
              const SizedBox(height: 2),
              Text(
                ComplaintReference.format(widget.issue),
                style: AppTypography.recordId(),
              ),
              const SizedBox(height: 20),
              Text(
                'Set status',
                style: AppTypography.sectionLabel(color: AppColors.slate600),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 52, horizontal: 32),
      child: Column(
        children: [
          const Icon(Icons.inbox_outlined, size: 34, color: AppColors.slate400),
          const SizedBox(height: 12),
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
            const Icon(
              Icons.cloud_off_outlined,
              size: 36,
              color: AppColors.slate400,
            ),
            const SizedBox(height: 14),
            Text(message, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
