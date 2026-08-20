import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/issue.dart';
import '../providers/app_provider.dart';
import '../services/issue_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
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
  const FeedScreen({super.key});

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
          content: Text('Location is off, so nearby complaints cannot be found.'),
        ),
      );
      return;
    }

    setState(() => _scope = scope);
    await _load();
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
        action: OutlinedButton(onPressed: _load, child: const Text('Try again')),
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
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 92),
        itemCount: visible.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
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
            onVote: _load,
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
/// nearby potholes specifically.
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
      padding: const EdgeInsets.only(top: 10, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                _ScopeButton(
                  label: 'All wards',
                  selected: scope == FeedScope.allWards,
                  onTap: () => onScopeChanged(FeedScope.allWards),
                ),
                const SizedBox(width: 6),
                _ScopeButton(
                  label: 'Near me',
                  icon: Icons.my_location,
                  selected: scope == FeedScope.nearMe,
                  onTap: () => onScopeChanged(FeedScope.nearMe),
                ),
              ],
            ),
          ),
          const SizedBox(height: 9),
          SizedBox(
            height: 30,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _CategoryChip(
                  label: 'All',
                  selected: category == null,
                  onTap: () => onCategoryChanged(null),
                ),
                for (final c in IssueCategories.all)
                  _CategoryChip(
                    label: c.label,
                    icon: c.icon,
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

class _ScopeButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  const _ScopeButton({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(3),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.navy900 : AppColors.surface,
          border: Border.all(
            color: selected ? AppColors.navy900 : AppColors.slate200,
          ),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 13,
                color: selected ? Colors.white : AppColors.slate600,
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontSize: 12.5,
                color: selected ? Colors.white : AppColors.slate600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(3),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.navy700 : AppColors.canvas,
            border: Border.all(
              color: selected ? AppColors.navy700 : AppColors.slate200,
            ),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 12,
                  color: selected ? Colors.white : AppColors.slate600,
                ),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: AppTypography.badge(
                  color: selected ? Colors.white : AppColors.slate600,
                ).copyWith(letterSpacing: 0.2, fontSize: 11),
              ),
            ],
          ),
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
            Icon(icon, size: 40, color: AppColors.slate200),
            const SizedBox(height: 13),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              body,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (action != null) ...[const SizedBox(height: 18), action!],
          ],
        ),
      ),
    );
  }
}
