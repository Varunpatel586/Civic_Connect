import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../models/models.dart';
import '../providers/app_provider.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/comment_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/issue_card.dart';
import 'issue_detail_screen.dart';

/// The citizen's own record: who they are, what they have filed, and the
/// account controls.
///
/// Renders as content only — [HomeScreen] owns the surrounding scaffold and
/// app bar, so adding another here would stack two headers.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();

  bool _isEditing = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  void _startEditing(UserProfile user) {
    _usernameController.text = user.username;
    setState(() => _isEditing = true);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final appProvider = context.read<AppProvider>();
    final messenger = ScaffoldMessenger.of(context);

    try {
      await AuthService().updateProfile(
        username: _usernameController.text.trim(),
      );
      await appProvider.initialize();
      if (!mounted) return;
      setState(() => _isEditing = false);
      messenger.showSnackBar(const SnackBar(content: Text('Profile updated.')));
    } on AppAuthException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not update your profile.')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _signOut() async {
    final appProvider = context.read<AppProvider>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'You will need to sign in again to report or vote on issues.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Stay signed in'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Sign out',
              style: TextStyle(color: StatusColors.rejected.foreground),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await appProvider.signOut();
      navigator.pushNamedAndRemoveUntil('/', (route) => false);
    } catch (e) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not sign out.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    final user = appProvider.currentUser;

    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final issues = appProvider.userIssues;
    final resolved = issues.where((i) => i.status == 'Resolved').length;

    return ListView(
      padding: const EdgeInsets.only(bottom: 90),
      children: [
        _Header(user: user, isAdmin: appProvider.isAdmin),
        _StatStrip(
          filed: issues.length,
          resolved: resolved,
          joined: user.createdAt,
        ),
        if (_isEditing)
          _EditCard(
            formKey: _formKey,
            controller: _usernameController,
            isSaving: _isSaving,
            onCancel: () => setState(() => _isEditing = false),
            onSave: _save,
          )
        else
          _MenuGroup(
            children: [
              _MenuItem(
                icon: Icons.edit_outlined,
                label: 'Edit profile',
                onTap: () => _startEditing(user),
              ),
              _MenuItem(
                icon: Icons.history,
                label: 'My activity',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MyActivityScreen()),
                ),
              ),
            ],
          ),
        _MenuGroup(
          children: [
            _MenuItem(
              icon: Icons.help_outline,
              label: 'Help and support',
              onTap: () =>
                  launchUrlString('mailto:support@civicconnect.example'),
            ),
            _MenuItem(
              icon: Icons.info_outline,
              label: 'About Civic Connect',
              onTap: () => showAboutDialog(
                context: context,
                applicationName: 'Civic Connect',
                applicationVersion: '1.0.0',
                children: const [
                  Text(
                    'Report civic issues, track them to resolution, and see '
                    'what your neighbourhood has already raised.',
                  ),
                ],
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
          child: OutlinedButton.icon(
            onPressed: _signOut,
            icon: Icon(
              Icons.logout,
              size: 18,
              color: StatusColors.rejected.foreground,
            ),
            label: Text(
              'Sign out',
              style: TextStyle(color: StatusColors.rejected.foreground),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: StatusColors.rejected.border),
            ),
          ),
        ),
      ],
    );
  }
}

/// Identity block. Officers get a visible designation, because in a municipal
/// system who you are determines what you can do.
class _Header extends StatelessWidget {
  final UserProfile user;
  final bool isAdmin;

  const _Header({required this.user, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.navy900,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      child: Row(
        children: [
          _Avatar(user: user),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.username,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontSize: 19,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  user.email,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.navy200),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (isAdmin) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.amber700,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      'MUNICIPAL OFFICER',
                      style: AppTypography.badge(color: Colors.white),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final UserProfile user;

  const _Avatar({required this.user});

  @override
  Widget build(BuildContext context) {
    final url = user.avatarUrl;
    final initial = user.username.isNotEmpty
        ? user.username[0].toUpperCase()
        : '?';

    return Container(
      width: 58,
      height: 58,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.navy700,
        border: Border.all(color: AppColors.navy200),
        borderRadius: BorderRadius.circular(4),
      ),
      child: url == null || url.isEmpty
          ? Center(
              child: Text(
                initial,
                style: AppTypography.metric(
                  color: Colors.white,
                ).copyWith(fontSize: 24),
              ),
            )
          : CachedNetworkImage(
              imageUrl: ApiClient().normalizeUrl(url),
              fit: BoxFit.cover,
              errorWidget: (context, u, e) => Center(
                child: Text(
                  initial,
                  style: AppTypography.metric(
                    color: Colors.white,
                  ).copyWith(fontSize: 24),
                ),
              ),
            ),
    );
  }
}

class _StatStrip extends StatelessWidget {
  final int filed;
  final int resolved;
  final DateTime joined;

  const _StatStrip({
    required this.filed,
    required this.resolved,
    required this.joined,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Expanded(child: _Stat(value: '$filed', label: 'FILED')),
          Container(width: 1, height: 34, color: AppColors.slate100),
          Expanded(
            child: _Stat(
              value: '$resolved',
              label: 'RESOLVED',
              color: StatusColors.resolved.foreground,
            ),
          ),
          Container(width: 1, height: 34, color: AppColors.slate100),
          Expanded(
            child: _Stat(
              value: DateFormat('MMM yyyy').format(joined),
              label: 'MEMBER SINCE',
              small: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  final Color? color;
  final bool small;

  const _Stat({
    required this.value,
    required this.label,
    this.color,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: AppTypography.metric(
            color: color ?? AppColors.navy900,
          ).copyWith(fontSize: small ? 15 : 22),
        ),
        const SizedBox(height: 4),
        Text(label, style: AppTypography.badge(color: AppColors.slate600)),
      ],
    );
  }
}

class _EditCard extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController controller;
  final bool isSaving;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  const _EditCard({
    required this.formKey,
    required this.controller,
    required this.isSaving,
    required this.onCancel,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      margin: const EdgeInsets.only(top: 1),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('USERNAME', style: AppTypography.sectionLabel()),
            const SizedBox(height: 6),
            TextFormField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'How you appear on complaints',
              ),
              validator: (value) {
                final v = value?.trim() ?? '';
                if (v.isEmpty) return 'Username cannot be empty';
                if (v.length < 3) return 'Use at least 3 characters';
                return null;
              },
            ),
            const SizedBox(height: 6),
            Text(
              'Your email address cannot be changed here.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontSize: 11),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: isSaving ? null : onCancel,
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: isSaving ? null : onSave,
                    child: isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Save'),
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

class _MenuGroup extends StatelessWidget {
  final List<Widget> children;

  const _MenuGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      margin: const EdgeInsets.only(top: 10),
      child: Column(children: children),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 19, color: AppColors.navy700),
            const SizedBox(width: 13),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 18,
              color: AppColors.slate600,
            ),
          ],
        ),
      ),
    );
  }
}

/// Everything this citizen has contributed: complaints filed, and comments left
/// on other people's.
class MyActivityScreen extends StatefulWidget {
  const MyActivityScreen({super.key});

  @override
  State<MyActivityScreen> createState() => _MyActivityScreenState();
}

class _MyActivityScreenState extends State<MyActivityScreen> {
  final CommentService _commentService = CommentService();

  List<Map<String, dynamic>> _comments = [];
  bool _isLoadingComments = true;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  Future<void> _loadComments() async {
    try {
      final comments = await _commentService.getUserComments();
      if (!mounted) return;
      setState(() {
        _comments = comments;
        _isLoadingComments = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingComments = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    final issues = appProvider.userIssues;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My activity'),
          bottom: TabBar(
            tabs: [
              Tab(text: 'Complaints (${issues.length})'),
              Tab(text: 'Comments (${_comments.length})'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _ComplaintsTab(issues: issues, onChanged: appProvider.initialize),
            _CommentsTab(
              comments: _comments,
              isLoading: _isLoadingComments,
            ),
          ],
        ),
      ),
    );
  }
}

class _ComplaintsTab extends StatelessWidget {
  final List<Issue> issues;
  final Future<void> Function() onChanged;

  const _ComplaintsTab({required this.issues, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    if (issues.isEmpty) {
      return const _ActivityEmpty(
        icon: Icons.post_add_outlined,
        title: 'You have not filed anything yet',
        body: 'Complaints you report will be listed here with their status.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: issues.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final issue = issues[index];
        return IssueCard(
          issue: issue,
          showActions: false,
          onTap: () => Navigator.of(context)
              .push(
                MaterialPageRoute(
                  builder: (_) => IssueDetailScreen(issueId: issue.id),
                ),
              )
              .then((_) => onChanged()),
        );
      },
    );
  }
}

class _CommentsTab extends StatelessWidget {
  final List<Map<String, dynamic>> comments;
  final bool isLoading;

  const _CommentsTab({required this.comments, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (comments.isEmpty) {
      return const _ActivityEmpty(
        icon: Icons.mode_comment_outlined,
        title: 'No comments yet',
        body: 'Anything you add to a discussion will show up here.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: comments.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final comment = comments[index];
        final issueId = comment['issue_id']?.toString() ?? '';

        return Card(
          child: InkWell(
            onTap: issueId.isEmpty
                ? null
                : () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => IssueDetailScreen(issueId: issueId),
                    ),
                  ),
            child: Padding(
              padding: const EdgeInsets.all(13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    comment['issue_title']?.toString() ?? 'Deleted complaint',
                    style: Theme.of(context).textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    comment['content']?.toString() ?? '',
                    style: Theme.of(context).textTheme.bodyMedium,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 7),
                  Text(
                    _filedOn(comment['created_at']),
                    style: AppTypography.recordId().copyWith(fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _filedOn(Object? raw) {
    final parsed = DateTime.tryParse(raw?.toString() ?? '');
    if (parsed == null) return '';
    return DateFormat('d MMM yyyy, HH:mm').format(parsed.toLocal());
  }
}

class _ActivityEmpty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _ActivityEmpty({
    required this.icon,
    required this.title,
    required this.body,
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
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              body,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
