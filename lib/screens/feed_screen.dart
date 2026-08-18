import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _posts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchApprovedPosts();
  }

  // Helper function to generate a consistent UUID v5 from a string
  String _generateUUIDv5(String input) {
    // This is a simple implementation for demo purposes
    // In production, use a proper UUID v5 generator
    const namespace =
        '1b671a64-40d5-491e-99b0-da01ff1f3341'; // Randomly generated namespace
    final bytes = utf8.encode('$namespace$input');
    final digest = sha1.convert(bytes);
    final hex = digest.toString();

    // Format as UUID
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-4${hex.substring(13, 16)}-a${hex.substring(17, 20)}-${hex.substring(20, 32)}';
  }

  Future<void> _fetchApprovedPosts() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      final response = await _supabase
          .from(
            'issues',
          ) // Changed from 'posts' to 'issues' to match your database
          .select('*')
          .eq('status', 'approved')
          .order('created_at', ascending: false);

      List<Map<String, dynamic>> posts = [];

      if (response != null && response.isNotEmpty) {
        posts = List<Map<String, dynamic>>.from(response);
      } else {
        // Add placeholder posts if no posts found
        // Using consistent UUIDs based on the post title for demo purposes
        posts = [
          {
            'id': _generateUUIDv5('Pothole on Main Street'),
            'title': 'Pothole on Main Street',
            'description':
                'Large pothole causing traffic issues near the intersection of Main and 5th. Needs urgent attention.',
            'image_url':
                'https://storage.googleapis.com/kagglesdsdata/datasets/116400/628563/Pothole_Image_Data/1.jpg?X-Goog-Algorithm=GOOG4-RSA-SHA256&X-Goog-Credential=databundle-worker-v2%40kaggle-161607.iam.gserviceaccount.com%2F20250919%2Fauto%2Fstorage%2Fgoog4_request&X-Goog-Date=20250919T053603Z&X-Goog-Expires=345600&X-Goog-SignedHeaders=host&X-Goog-Signature=5140c0693cdc9ab9dca62680835f673a2b10a2838788626a9a59ed011c83e6da07b92f993bfca654a99f274e42ec57dc04c4a0d6fafb67276d7845745dd34cb257c665b81925ed5cf5385efccc4efbe5cb2bfcac8d21f386443fcb7b4891c2981bf723f48c71ff651e04e47018f60c595c93b554ecf20e8a1bd4d782665f532432a50c2ae0924dfbea2b98b7db1e71601b38ebe7511a5ba250117c10588481fc3c33c955bb0b8a616254c37225ad1c892f5d82e131558c742659f1af2c355529283e452071a64b196e4e4085cf1e21276c1e31627bcc73c314bcd98280e4cb69da2b3739f779a01617e7d54077ae95ca49e453701e6c136024ed9f2fdfb28de1',
            'status': 'approved',
            'created_at': DateTime.now()
                .subtract(const Duration(days: 2))
                .toIso8601String(),
            'location': 'Main Street, City',
            'upvotes': 15,
            'profiles': {'username': 'JohnDoe'},
            'is_placeholder': true, // Mark as placeholder to handle differently
          },
          {
            'id': _generateUUIDv5('Broken Street Light'),
            'title': 'Broken Street Light',
            'description':
                'Street light not working on Park Avenue. It has been 3 days now.',
            'image_url':
                'https://images.unsplash.com/photo-1508514177221-188b1cf16e9d?w=800&auto=format&fit=crop',
            'status': 'approved',
            'created_at': DateTime.now()
                .subtract(const Duration(days: 1))
                .toIso8601String(),
            'location': 'Park Avenue, City',
            'upvotes': 8,
            'profiles': {'username': 'JaneSmith'},
            'is_placeholder': true,
          },
          {
            'id': _generateUUIDv5('Garbage Pile-up'),
            'title': 'Garbage Pile-up',
            'description':
                'Garbage not being collected in the downtown area for over a week.',
            'image_url':
                'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcRyvTN25milJJwSf-8nqAE-VfbkFD2XO--CuA&s',
            'status': 'approved',
            'created_at': DateTime.now().toIso8601String(),
            'location': 'Downtown Area',
            'upvotes': 23,
            'profiles': {'username': 'MikeJohnson'},
            'is_placeholder': true,
          },
          {
            'id': _generateUUIDv5('Damaged Sidewalk'),
            'title': 'Damaged Sidewalk',
            'description':
                'Cracked and uneven sidewalk near the school. Safety hazard for children.',
            'image_url':
                'https://images.indianexpress.com/2024/08/pune-footpath.jpeg',
            'status': 'approved',
            'created_at': DateTime.now()
                .subtract(const Duration(hours: 12))
                .toIso8601String(),
            'location': 'Near City Elementary School',
            'upvotes': 12,
            'profiles': {'username': 'SarahWilliams'},
            'is_placeholder': true,
          },
        ];
      }

      if (mounted) {
        setState(() {
          _posts = posts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _posts = [
            {
              'id': '1',
              'title': 'Pothole on Main Street',
              'description':
                  'Large pothole causing traffic issues near the intersection of Main and 5th. Needs urgent attention.',
              'image_url':
                  'https://images.unsplash.com/photo-1564053489984-317bbd824340?w=800&auto=format&fit=crop',
              'status': 'approved',
              'created_at': DateTime.now()
                  .subtract(const Duration(days: 2))
                  .toIso8601String(),
              'location': 'Main Street, City',
              'upvotes': 15,
              'profiles': {'username': 'JohnDoe'},
            },
            {
              'id': '2',
              'title': 'Broken Street Light',
              'description':
                  'Street light not working on Park Avenue. It has been 3 days now.',
              'image_url':
                  'https://images.unsplash.com/photo-1508514177221-188b1cf16e9d?w=800&auto=format&fit=crop',
              'status': 'approved',
              'created_at': DateTime.now()
                  .subtract(const Duration(days: 1))
                  .toIso8601String(),
              'location': 'Park Avenue, City',
              'upvotes': 8,
              'profiles': {'username': 'JaneSmith'},
            },
            {
              'id': '3',
              'title': 'Garbage Pile-up',
              'description':
                  'Garbage not being collected in the downtown area for over a week.',
              'image_url':
                  'https://images.unsplash.com/photo-1559123692-5d4d4c9536e9?w=800&auto=format&fit=crop',
              'status': 'approved',
              'created_at': DateTime.now().toIso8601String(),
              'location': 'Downtown Area',
              'upvotes': 23,
              'profiles': {'username': 'MikeJohnson'},
            },
            {
              'id': '4',
              'title': 'Damaged Sidewalk',
              'description':
                  'Cracked and uneven sidewalk near the school. Safety hazard for children.',
              'image_url':
                  'https://images.unsplash.com/photo-1601531452914-51acd275e30d?w=800&auto=format&fit=crop',
              'status': 'approved',
              'created_at': DateTime.now()
                  .subtract(const Duration(hours: 12))
                  .toIso8601String(),
              'location': 'Near City Elementary School',
              'upvotes': 12,
              'profiles': {'username': 'SarahWilliams'},
            },
          ];
          _isLoading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Showing sample posts')));
      }
    }
  }

  void _showPostDetails(Map<String, dynamic> post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => PostDetailsBottomSheet(post: post),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_posts.isEmpty) {
      return Center(
        child: Text(
          'No approved posts yet',
          style: GoogleFonts.poppins(fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      itemCount: _posts.length,
      itemBuilder: (context, index) {
        final post = _posts[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16.0),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: () => _showPostDetails(post),
            borderRadius: BorderRadius.circular(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Image
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  child: post['image_url'] != null
                      ? AspectRatio(
                          aspectRatio: 16 / 9,
                          child: Image.network(
                            post['image_url'],
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                                  color: Colors.grey[200],
                                  child: const Center(
                                    child: Icon(Icons.broken_image, size: 48),
                                  ),
                                ),
                          ),
                        )
                      : Container(
                          height: 200,
                          color: Colors.grey[200],
                          child: const Center(
                            child: Icon(Icons.image_not_supported, size: 48),
                          ),
                        ),
                ),

                // Post content
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title and upvotes
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              post['title'] ?? 'No Title',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Row(
                            children: [
                              const Icon(
                                Icons.thumb_up,
                                size: 16,
                                color: Colors.green,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${post['upvotes'] ?? 0}',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // Location
                      if (post['location'] != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 16,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                post['location'],
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Description
                      Text(
                        post['description'] ?? '',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          color: Colors.grey[800],
                          height: 1.4,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),

                      // Author and date
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.green[100],
                            child: Text(
                              post['profiles']?['username']
                                      ?.substring(0, 1)
                                      .toUpperCase() ??
                                  '?',
                              style: const TextStyle(color: Colors.green),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                post['profiles']?['username'] ?? 'Anonymous',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (post['created_at'] != null)
                                Text(
                                  _formatDate(post['created_at']),
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return '';
    try {
      final date = DateTime.parse(dateString);
      return '${_getMonth(date.month)} ${date.day}, ${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  String _getMonth(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }
}

class PostDetailsBottomSheet extends StatefulWidget {
  final Map<String, dynamic> post;

  const PostDetailsBottomSheet({super.key, required this.post});

  @override
  State<PostDetailsBottomSheet> createState() => _PostDetailsBottomSheetState();
}

class _PostDetailsBottomSheetState extends State<PostDetailsBottomSheet> {
  final TextEditingController _commentController = TextEditingController();
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _comments = [];
  bool _isLoadingComments = true;

  late SharedPreferences _prefs;
  static const String _commentsKey = 'placeholder_comments';

  @override
  void initState() {
    super.initState();
    _initPrefs();
  }

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadComments();
  }

  Future<void> _loadComments() async {
    if (widget.post['is_placeholder'] != true) {
      await _fetchComments();
      return;
    }

    final commentsJson = _prefs.getString(
      '${_commentsKey}_${widget.post['id']}',
    );
    if (commentsJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(commentsJson);
        if (mounted) {
          setState(() {
            _comments = List<Map<String, dynamic>>.from(
              decoded.map((x) => Map<String, dynamic>.from(x)),
            );
            _isLoadingComments = false;
          });
        }
      } catch (e) {
        debugPrint('Error loading comments from SharedPreferences: $e');
        _fetchComments();
      }
    } else {
      _fetchComments();
    }
  }

  Future<void> _saveComments() async {
    if (widget.post['is_placeholder'] != true) return;

    try {
      await _prefs.setString(
        '${_commentsKey}_${widget.post['id']}',
        jsonEncode(_comments),
      );
    } catch (e) {
      debugPrint('Error saving comments: $e');
    }
  }

  Future<void> _fetchComments() async {
    try {
      final response = await _supabase
          .from('comments')
          .select('''
            *,
            profiles!inner (
              id,
              username,
              avatar_url
            )
          ''')
          .eq('issue_id', widget.post['id'])
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _comments = List<Map<String, dynamic>>.from(response);
          _isLoadingComments = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching comments: $e');
      if (mounted) {
        setState(() => _isLoadingComments = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Error loading comments')));
      }
    }
  }

  Future<void> _addComment() async {
    final commentText = _commentController.text.trim();
    if (commentText.isEmpty) return;

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please sign in to comment')),
          );
        }
        return;
      }

      // Check if this is a placeholder post
      final isPlaceholder = widget.post['is_placeholder'] == true;

      if (isPlaceholder) {
        // For placeholder posts, save to SharedPreferences
        final newComment = {
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
          'issue_id': widget.post['id'],
          'user_id': user.id,
          'content': commentText,
          'created_at': DateTime.now().toIso8601String(),
          'profiles': {
            'username': user.email?.split('@').first ?? 'User',
            'avatar_url': null,
          },
        };

        if (mounted) {
          setState(() {
            _comments.insert(0, newComment);
          });
          _commentController.clear();

          // Save the updated comments to SharedPreferences
          await _saveComments();

          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Comment added'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      // For real posts, save to the database
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 12),
                Text('Posting comment...'),
              ],
            ),
            duration: Duration(seconds: 5),
          ),
        );
      }

      await _supabase.from('comments').insert({
        'issue_id': widget.post['id'],
        'user_id': user.id,
        'content': commentText,
      });

      _commentController.clear();

      if (mounted) {
        await _fetchComments();

        // Show success message
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Comment posted successfully'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error adding comment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to add comment: ${e.toString().split(':').last.trim()}',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  String _timeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return '$years year${years > 1 ? 's' : ''} ago';
    } else if (difference.inDays >= 30) {
      final months = (difference.inDays / 30).floor();
      return '$months month${months > 1 ? 's' : ''} ago';
    } else if (difference.inDays >= 1) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours >= 1) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes >= 1) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  // Clear all placeholder comments (for testing)
  Future<void> _clearPlaceholderComments() async {
    if (widget.post['is_placeholder'] == true) {
      await _prefs.remove('${_commentsKey}_${widget.post['id']}');
      if (mounted) {
        setState(() {
          _comments = [];
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                widget.post['title'] ?? 'No Title',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              if (widget.post['image_url'] != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    widget.post['image_url'],
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 200,
                      color: Colors.grey[200],
                      child: const Center(child: Icon(Icons.broken_image)),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                widget.post['description'] ?? '',
                style: GoogleFonts.poppins(fontSize: 16),
              ),
              const SizedBox(height: 16),
              const Divider(height: 32, thickness: 1.5),
              Row(
                children: [
                  Text(
                    'Comments',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _comments.length.toString(),
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.green,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _isLoadingComments
                    ? const Center(child: CircularProgressIndicator())
                    : _comments.isEmpty
                    ? Center(
                        child: Text(
                          'No comments yet',
                          style: GoogleFonts.poppins(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: _comments.length,
                        itemBuilder: (context, index) {
                          final comment = _comments[index];
                          final profile = comment['profiles'] ?? {};
                          final createdAt = comment['created_at'] != null
                              ? DateTime.parse(comment['created_at'])
                              : null;
                          final timeAgo = createdAt != null
                              ? _timeAgo(createdAt)
                              : 'Just now';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: Colors.grey.shade200,
                                width: 1,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 18,
                                        backgroundColor: Colors.green,
                                        child: Text(
                                          profile['username']
                                                  ?.substring(0, 1)
                                                  .toUpperCase() ??
                                              '?',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              profile['username'] ??
                                                  'Anonymous',
                                              style: GoogleFonts.poppins(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                              ),
                                            ),
                                            Text(
                                              timeAgo,
                                              style: GoogleFonts.poppins(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    comment['content'] ?? '',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 16),
              Container(
                margin: const EdgeInsets.only(bottom: 16, top: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.grey.shade300, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        maxLines: 4,
                        minLines: 1,
                        style: GoogleFonts.poppins(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Add a comment...',
                          hintStyle: GoogleFonts.poppins(
                            color: Colors.grey[500],
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 12,
                          ),
                        ),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _addComment(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.send,
                          color: Colors.white,
                          size: 20,
                        ),
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          FocusScope.of(context).unfocus(); // Dismiss keyboard
                          _addComment();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
