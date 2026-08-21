import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:url_launcher/url_launcher_string.dart';

import '../models/models.dart';
import '../providers/app_provider.dart';
import '../widgets/comment_tile.dart';
import '../services/api_client.dart';

class IssueDetailScreen extends StatefulWidget {
  final String issueId;

  const IssueDetailScreen({super.key, required this.issueId});

  @override
  State<IssueDetailScreen> createState() => _IssueDetailScreenState();
}

class _IssueDetailScreenState extends State<IssueDetailScreen> {
  final _commentController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isLoading = true;
  bool _isSubmitting = false;
  Issue? _issue;
  List<Comment> _comments = [];
  late AppProvider _appProvider;

  @override
  void initState() {
    super.initState();
    _appProvider = context.read<AppProvider>();
    _loadIssue();
    
    // Add a post-frame callback to load comments after the first build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadComments();
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadIssue() async {
    setState(() => _isLoading = true);
    try {
      final appProvider = context.read<AppProvider>();

      // Try to find the issue in the provider first
      _issue = appProvider.nearbyIssues.firstWhere(
        (issue) => issue.id == widget.issueId,
        orElse: () => appProvider.userIssues.firstWhere(
          (issue) => issue.id == widget.issueId,
          orElse: () => Issue(
            id: widget.issueId,
            userId: '',
            title: 'Loading...',
            description: '',
            imageUrl: '',
            latitude: 0,
            longitude: 0,
            timestamp: DateTime.now(),
            status: 'Pending',
            createdAt: DateTime.now(),
          ),
        ),
      );

      // If issue not found in provider, fetch it from the server
      if (_issue?.title == 'Loading...') {
        _issue = await appProvider.getIssueById(widget.issueId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to load issue details'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadComments() async {
    if (!mounted) return;
    
    try {
      await _appProvider.loadCommentsForIssue(widget.issueId);
      if (mounted) {
        setState(() {
          _comments = _appProvider.getCommentsForIssue(widget.issueId);
        });
      }
    } catch (e) {
      debugPrint('Error loading comments: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load comments: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _submitComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;

    if (!mounted) return;
    
    setState(() => _isSubmitting = true);
    
    try {
      await _appProvider.addComment(widget.issueId, content);
      
      _commentController.clear();
      
      // Scroll to bottom to show the new comment
      if (_scrollController.hasClients) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to post comment: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _shareIssue() {
    if (_issue == null) return;

    final text = 'Check out this issue on Civic Connect: ${_issue!.title}';
    final url = 'https://yourapp.com/issues/${_issue!.id}';

    Share.share('$text\n$url');
  }

  void _openInMaps() async {
    if (_issue == null) return;

    final url =
        'https://www.google.com/maps/search/?api=1&query=${_issue!.latitude},${_issue!.longitude}';

    if (await canLaunchUrlString(url)) {
      await launchUrlString(url);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open maps'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appProvider = context.watch<AppProvider>();
    
    // Listen to comments changes
    _comments = appProvider.getCommentsForIssue(widget.issueId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Issue Details'),
        actions: [
          IconButton(icon: const Icon(Icons.share), onPressed: _shareIssue),
          if (appProvider.isAdmin) ...[
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'resolve' && _issue != null) {
                  _updateIssueStatus('Resolved');
                } else if (value == 'reject' && _issue != null) {
                  _updateIssueStatus('Rejected');
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'resolve',
                  child: Text('Mark as Resolved'),
                ),
                const PopupMenuItem(
                  value: 'reject',
                  child: Text('Reject Issue'),
                ),
              ],
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _issue == null
          ? const Center(child: Text('Issue not found'))
          : Column(
              children: [
                // Issue Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Issue Image
                        AspectRatio(
                          aspectRatio: 16 / 9,
                          child: CachedNetworkImage(
                            imageUrl: ApiClient().normalizeUrl(_issue!.imageUrl),
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: Colors.grey[200],
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey[200],
                              child: const Icon(Icons.error),
                            ),
                          ),
                        ),

                        // Issue Details
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Title and Status
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _issue!.title,
                                      style: theme.textTheme.headlineSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ),
                                  _buildStatusChip(theme, _issue!.status),
                                ],
                              ),

                              const SizedBox(height: 16),

                              // Description
                              if (_issue!.description?.isNotEmpty ?? false) ...[
                                Text(
                                  _issue!.description!,
                                  style: theme.textTheme.bodyLarge,
                                ),
                                const SizedBox(height: 16),
                              ],

                              // Location and Time
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_on_outlined,
                                    size: 20,
                                    color: theme.hintColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: _openInMaps,
                                      child: Text(
                                        _issue!.address ?? 'Unknown location',
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              color: theme.primaryColor,
                                              decoration:
                                                  TextDecoration.underline,
                                            ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 8),

                              Row(
                                children: [
                                  Icon(
                                    Icons.access_time,
                                    size: 20,
                                    color: theme.hintColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Reported ${timeago.format(_issue!.timestamp)}',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.hintColor,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 24),

                              // Votes
                              _buildVotingSection(theme, appProvider),

                              const SizedBox(height: 24),
                              const Divider(),
                              const SizedBox(height: 8),

                              // Comments Header
                              Row(
                                children: [
                                  Text(
                                    'Comments',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.primaryColor.withOpacity(
                                        0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      _comments.length.toString(),
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme.primaryColor,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Comments List
                        if (_comments.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 32),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.comment_outlined,
                                  size: 48,
                                  color: theme.hintColor.withOpacity(0.5),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'No comments yet',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.hintColor,
                                  ),
                                ),
                                const Text('Be the first to comment!'),
                              ],
                            ),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _comments.length,
                            itemBuilder: (context, index) {
                              return CommentTile(comment: _comments[index]);
                            },
                          ),
                      ],
                    ),
                  ),
                ),

                // Comment Input
                if (appProvider.isAuthenticated)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _commentController,
                            decoration: InputDecoration(
                              hintText: 'Add a comment...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: theme.inputDecorationTheme.fillColor,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                            maxLines: null,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _submitComment(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (_isSubmitting)
                          const CircularProgressIndicator()
                        else
                          IconButton(
                            icon: const Icon(Icons.send),
                            onPressed: _submitComment,
                            color: theme.primaryColor,
                          ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildVotingSection(ThemeData theme, AppProvider appProvider) {
    // Get the current user's vote for this issue
    final userVote = _issue?.userVote;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Is this issue still relevant?',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _handleVote(appProvider, true),
                icon: Icon(
                  Icons.thumb_up,
                  color: userVote == 'agree'
                      ? theme.primaryColor
                      : theme.hintColor,
                ),
                label: Text(
                  'Agree (${_issue?.agreeCount ?? 0})',
                  style: TextStyle(
                    color: userVote == 'agree'
                        ? theme.primaryColor
                        : theme.hintColor,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: userVote == 'agree'
                        ? theme.primaryColor
                        : theme.dividerColor,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _handleVote(appProvider, false),
                icon: Icon(
                  Icons.thumb_down,
                  color: userVote == 'disagree' ? Colors.red : theme.hintColor,
                ),
                label: Text(
                  'Disagree (${_issue?.disagreeCount ?? 0})',
                  style: TextStyle(
                    color: userVote == 'disagree'
                        ? Colors.red
                        : theme.hintColor,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: userVote == 'disagree'
                        ? Colors.red
                        : theme.dividerColor,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusChip(ThemeData theme, String status) {
    Color statusColor;
    switch (status.toLowerCase()) {
      case 'resolved':
        statusColor = Colors.green;
        break;
      case 'in progress':
        statusColor = Colors.orange;
        break;
      case 'rejected':
        statusColor = Colors.red;
        break;
      default: // pending
        statusColor = Colors.blue;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Text(
        status.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: statusColor,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Future<void> _handleVote(AppProvider appProvider, bool isAgree) async {
    if (!appProvider.isAuthenticated) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please sign in to vote'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    try {
      setState(() => _isLoading = true);
      await appProvider.voteOnIssue(widget.issueId, isAgree);

      // Refresh the issue data
      await _loadIssue();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Your vote has been recorded!'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to submit vote. Please try again.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateIssueStatus(String status) async {
    try {
      final appProvider = context.read<AppProvider>();
      await appProvider.updateIssueStatus(
        issueId: widget.issueId,
        status: status,
      );

      if (mounted) {
        await _loadIssue(); // Refresh the issue to update the status
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Issue marked as $status'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update issue status'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
