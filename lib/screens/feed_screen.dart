import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/issue.dart';
import '../providers/app_provider.dart';
import '../services/issue_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/issue_categories.dart';
import '../widgets/issue_card.dart';
import 'issue_detail_screen.dart';

/// How much of the city the feed is showing.
enum FeedScope {
  /// Complaints within [FeedScreen._nearRadiusKm] of the citizen.
  nearMe,

  /// Everything on the books, wherever it was filed.
  allWards,
}

/// The citizen feed: what has been reported, newest first.
class FeedScreen extends StatefulWidget {
  final int refreshToken;

  const FeedScreen({super.key, this.refreshToken = 0});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  static const double _nearRadiusKm = 5;

  /// Wide enough to be effectively unbounded, so "All wards" is one code path
  /// with "Near me" rather than a second endpoint.
  static const double _allRadiusKm = 20000;

  final IssueService _issueService = IssueService();

  List<Issue> _issues = [];
  bool _isLoading = true;
  String? _error;

  /// Starts wide: a citizen opening the app for the first time should see the
  /// service working, not an empty radius.
  FeedScope _scope = FeedScope.allWards;
  String? _category;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant FeedScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final position = context.read<AppProvider>().currentPosition;
    final nearMe = _scope == FeedScope.nearMe && position != null;

    try {
      final issues = await _issueService.getNearbyIssues(
        latitude: nearMe ? position.latitude : 0,
        longitude: nearMe ? position.longitude : 0,
        radiusKm: nearMe ? _nearRadiusKm : _allRadiusKm,
        limit: 100,
      );

      if (!mounted) return;
      setState(() {
        _issues = issues;
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

  Future<void> _setScope(FeedScope scope) async {
    if (scope == _scope) return;

    if (scope == FeedScope.nearMe &&
        context.read<AppProvider>().currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Location is off, so nearby complaints cannot be found.',
          ),
        ),
      );
      return;
    }

    setState(() => _scope = scope);
    await _load();
  }

  Future<void> _refreshIssue(String issueId) async {
    final updatedIssue = await _issueService.getIssueById(issueId);
    if (!mounted || updatedIssue == null) return;

    final index = _issues.indexWhere((issue) => issue.id == issueId);
    if (index == -1) return;
    setState(() => _issues[index] = updatedIssue);
  }

  List<Issue> get _visible {
    if (_category == null) return _issues;
    return _issues.where((issue) => issue.category == _category).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _FeedFilters(
          scope: _scope,
          category: _category,
          onScopeChanged: _setScope,
          onCategoryChanged: (value) => setState(() => _category = value),
        ),
        Expanded(child: _buildList()),
      ],
    );
  }

  Widget _buildList() {
    if (_isLoading && _issues.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _FeedMessage(
        icon: Icons.cloud_off_outlined,
        title: _error!,
        body: 'Check that the backend is running, then try again.',
        action: OutlinedButton(
          onPressed: _load,
          child: const Text('Try again'),
        ),
      );
    }

    final visible = _visible;

    if (visible.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.12),
            _FeedMessage(
              icon: Icons.inbox_outlined,
              title: _category != null
                  ? 'No ${IssueCategories.labelFor(_category!).toLowerCase()} complaints'
                  : _scope == FeedScope.nearMe
                  ? 'Nothing reported within ${_nearRadiusKm.toInt()} km'
                  : 'No complaints filed yet',
              body: _category != null
                  ? 'Clear the filter to see everything else.'
                  : 'Be the first — tap the + button to report an issue.',
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
        itemCount: visible.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final issue = visible[index];
          return IssueCard(
            issue: issue,
            onTap: () => Navigator.of(context)
                .push(
                  MaterialPageRoute(
                    builder: (_) => IssueDetailScreen(issueId: issue.id),
                  ),
                )
                .then((_) => _load()),
            onVote: _refreshIssue,
          );
        },
      ),
    );
  }
}

/// Scope on top, category beneath.
///
/// Two axes rather than one combined list: scope answers "where", category
/// answers "what", and collapsing them would make it impossible to ask for
/// nearby potholes specifically. Different controls for different jobs — a
/// segmented switch for the binary, an underlined row for the many.
class _FeedFilters extends StatelessWidget {
  final FeedScope scope;
  final String? category;
  final ValueChanged<FeedScope> onScopeChanged;
  final ValueChanged<String?> onCategoryChanged;

  const _FeedFilters({
    required this.scope,
    required this.category,
    required this.onScopeChanged,
    required this.onCategoryChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _ScopeSwitch(scope: scope, onChanged: onScopeChanged),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _CategoryTab(
                  label: 'All',
                  selected: category == null,
                  onTap: () => onCategoryChanged(null),
                ),
                for (final c in IssueCategories.all)
                  _CategoryTab(
                    label: c.label,
                    selected: category == c.value,
                    onTap: () => onCategoryChanged(c.value),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// All wards / Near me, as one control rather than two buttons.
///
/// A segmented switch states that these are the only two choices and that one
/// is always active — which two outlined buttons never quite manage to say.
class _ScopeSwitch extends StatelessWidget {
  final FeedScope scope;
  final ValueChanged<FeedScope> onChanged;

  const _ScopeSwitch({required this.scope, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.slate100,
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ScopeSegment(
              label: 'All wards',
              selected: scope == FeedScope.allWards,
              onTap: () => onChanged(FeedScope.allWards),
            ),
          ),
          Expanded(
            child: _ScopeSegment(
              label: 'Near me',
              icon: Icons.near_me_rounded,
              selected: scope == FeedScope.nearMe,
              onTap: () => onChanged(FeedScope.nearMe),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScopeSegment extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  const _ScopeSegment({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radius - 3),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: Color(0x120F1F35),
                    blurRadius: 3,
                    offset: Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: selected ? AppColors.navy900 : AppColors.slate400,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: selected ? AppColors.navy900 : AppColors.slate400,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A category, marked by a rule under the active one rather than a filled pill.
class _CategoryTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(right: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: selected ? AppColors.navy900 : AppColors.slate400,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            const SizedBox(height: 7),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 2,
              width: selected ? 22 : 0,
              decoration: BoxDecoration(
                color: AppColors.navy900,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Empty and error states. Both say what happened and what to do next.
class _FeedMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  const _FeedMessage({
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 38, color: AppColors.slate400),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 7),
            Text(
              body,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}
