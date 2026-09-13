// lib/widgets/upvote_button.dart
import 'package:flutter/material.dart';

import '../services/upvote_service.dart';

class UpvoteButton extends StatefulWidget {
  final String issueId;
  final int initialCount;
  final bool initialHasUpvoted;
  final VoidCallback? onUpvoteChanged;

  const UpvoteButton({
    Key? key,
    required this.issueId,
    required this.initialCount,
    required this.initialHasUpvoted,
    this.onUpvoteChanged,
  }) : super(key: key);

  @override
  _UpvoteButtonState createState() => _UpvoteButtonState();
}

class _UpvoteButtonState extends State<UpvoteButton> {
  late bool _hasUpvoted;
  late int _upvoteCount;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _hasUpvoted = widget.initialHasUpvoted;
    _upvoteCount = widget.initialCount;
  }

  Future<void> _toggleUpvote() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _hasUpvoted = !_hasUpvoted;
      _upvoteCount += _hasUpvoted ? 1 : -1;
    });

    try {
      final upvoteService = UpvoteService();
      await upvoteService.toggleUpvote(widget.issueId);
      widget.onUpvoteChanged?.call();
    } catch (e) {
      // Revert on error
      setState(() {
        _hasUpvoted = !_hasUpvoted;
        _upvoteCount += _hasUpvoted ? 1 : -1;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update vote: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(
            _hasUpvoted ? Icons.thumb_up : Icons.thumb_up_outlined,
            color: _hasUpvoted ? Colors.blue : null,
          ),
          onPressed: _toggleUpvote,
          tooltip: _hasUpvoted ? 'Remove upvote' : 'Upvote',
        ),
        Text('$_upvoteCount'),
      ],
    );
  }
}
