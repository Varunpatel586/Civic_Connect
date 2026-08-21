import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:share_plus/share_plus.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../providers/app_provider.dart';
import '../services/auth_service.dart';
import '../models/models.dart';
import '../widgets/issue_card.dart';
import '../services/comment_service.dart';
import 'issue_detail_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  bool _isEditing = false;
  bool _isLoading = false;
  
  Future<void> _pickImage() async {
    // TODO: Implement image picking
    // This would typically use image_picker to select an image from gallery/camera
    // and then upload it to the MongoDB REST backend
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Image picker will be implemented here')),
    );
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      final user = appProvider.currentUser;
      if (user != null) {
        setState(() {
          _nameController.text = user.username;
          _emailController.text = user.email;
          _phoneController.text = ''; // Default phone empty since Profile model has username & email
        });
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    
    try {
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      final user = appProvider.currentUser;
      if (user == null) throw 'User not authenticated';
      
      // Update profile on custom backend via AuthService
      await AuthService().updateProfile(
        username: _nameController.text,
      );
      
      // Refresh local AppProvider cache
      await appProvider.initialize();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
        setState(() => _isEditing = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signOut() async {
    try {
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      await appProvider.signOut();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error signing out: $e')),
        );
      }
    }
  }

  Widget _buildProfileHeader(UserProfile user, String? avatarUrl, int postCount) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            CircleAvatar(
              radius: 60,
              backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                  ? NetworkImage(avatarUrl) as ImageProvider
                  : null,
              child: (avatarUrl == null || avatarUrl.isEmpty)
                  ? const Icon(Icons.person, size: 60, color: Colors.white)
                  : null,
            ),
            if (_isEditing)
              Container(
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: IconButton(
                  icon: const Icon(Icons.camera_alt, size: 20, color: Colors.white),
                  onPressed: _pickImage,
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          user.username,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          user.email,
          style: TextStyle(color: Colors.grey[600]),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildStatColumn('Posts', postCount.toString()),
            _buildStatColumn('Following', '156'),
            _buildStatColumn('Followers', '1.2K'),
          ],
        ),
      ],
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _isEditing ? _updateProfile : () => setState(() => _isEditing = true),
              icon: Icon(_isEditing ? Icons.save : Icons.edit, size: 16),
              label: Text(_isEditing ? 'SAVE CHANGES' : 'EDIT PROFILE'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: const BorderSide(color: Colors.green),
              ),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: _isEditing 
                ? () => setState(() => _isEditing = false)
                : () => Share.share('Check out my profile on Civic Connect!'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.all(12),
              side: const BorderSide(color: Colors.green),
            ),
            child: Icon(
              _isEditing ? Icons.close : Icons.share,
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuOption(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.green),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final user = appProvider.currentUser;
    
    if (user == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final avatarUrl = user.avatarUrl;
    final joinDate = user.createdAt;
    
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green,
        title: const Text('Profile', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              // Navigate to settings
            },
          ),
        ],
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      _buildProfileHeader(user, avatarUrl, appProvider.userIssues.length),
                      const SizedBox(height: 16),
                      _buildActionButtons(),
                    ],
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextFormField(
                                controller: _nameController,
                                decoration: InputDecoration(
                                  labelText: 'Full Name',
                                  prefixIcon: const Icon(Icons.person),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                enabled: _isEditing,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your name';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _emailController,
                                decoration: InputDecoration(
                                  labelText: 'Email',
                                  prefixIcon: const Icon(Icons.email),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                enabled: false,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _phoneController,
                                decoration: InputDecoration(
                                  labelText: 'Phone Number',
                                  prefixIcon: const Icon(Icons.phone),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                enabled: _isEditing,
                                keyboardType: TextInputType.phone,
                              ),
                              if (!_isEditing) ...[
                                const SizedBox(height: 16),
                                const Text(
                                  'Member Since',
                                  style: TextStyle(color: Colors.grey, fontSize: 14),
                                ),
                                Text(
                                  timeago.format(joinDate, allowFromNow: true),
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (!_isEditing) ...[
                  const SliverToBoxAdapter(
                    child: Divider(thickness: 8, color: Color(0xFFF5F5F5)),
                  ),
                  SliverList(
                    delegate: SliverChildListDelegate([
                      _buildMenuOption(
                        Icons.history,
                        'My Activity',
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const MyActivityScreen(),
                            ),
                          );
                        },
                      ),
                      _buildMenuOption(
                        Icons.bookmark_border,
                        'Saved Posts',
                        () {
                          // Navigate to saved posts
                        },
                      ),
                      _buildMenuOption(
                        Icons.help_outline,
                        'Help & Support',
                        () {
                          launchUrlString('mailto:support@civicconnect.com');
                        },
                      ),
                      _buildMenuOption(
                        Icons.privacy_tip_outlined,
                        'Privacy Policy',
                        () {
                          launchUrlString('https://civicconnect.com/privacy');
                        },
                      ),
                      _buildMenuOption(
                        Icons.info_outline,
                        'About',
                        () {
                          showAboutDialog(
                            context: context,
                            applicationName: 'Civic Connect',
                            applicationVersion: '1.0.0',
                            children: [
                              const Text('Connecting communities and local governments.'),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: () => launchUrlString('https://civicconnect.com'),
                                child: const Text('Visit our website'),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: TextButton.icon(
                          onPressed: _signOut,
                          icon: const Icon(Icons.logout, color: Colors.red),
                          label: const Text(
                            'Sign Out',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ]),
                  ),
                ],
              ],
            ),
    );
  }
}

class MyActivityScreen extends StatefulWidget {
  const MyActivityScreen({super.key});

  @override
  State<MyActivityScreen> createState() => _MyActivityScreenState();
}

class _MyActivityScreenState extends State<MyActivityScreen> {
  final CommentService _commentService = CommentService();
  List<Map<String, dynamic>> _userComments = [];
  bool _isLoadingComments = true;

  @override
  void initState() {
    super.initState();
    _fetchUserComments();
  }

  Future<void> _fetchUserComments() async {
    try {
      final comments = await _commentService.getUserComments();
      if (mounted) {
        setState(() {
          _userComments = comments;
          _isLoadingComments = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading user comments: $e');
      if (mounted) {
        setState(() => _isLoadingComments = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final userIssues = appProvider.userIssues;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.green,
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text('My Activity', style: TextStyle(color: Colors.white)),
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: 'My Posts'),
              Tab(text: 'My Comments'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Tab 1: My Posts
            userIssues.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.post_add, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'You haven\'t reported any issues yet',
                          style: TextStyle(color: Colors.grey[600], fontSize: 16),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: userIssues.length,
                    itemBuilder: (context, index) {
                      final issue = userIssues[index];
                      return IssueCard(
                        issue: issue,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => IssueDetailScreen(issueId: issue.id),
                            ),
                          ).then((_) => appProvider.initialize());
                        },
                        onVote: () => appProvider.initialize(),
                      );
                    },
                  ),

            // Tab 2: My Comments
            _isLoadingComments
                ? const Center(child: CircularProgressIndicator())
                : _userComments.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.comment_bank_outlined, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'You haven\'t commented on any issues yet',
                              style: TextStyle(color: Colors.grey[600], fontSize: 16),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _userComments.length,
                        itemBuilder: (context, index) {
                          final comment = _userComments[index];
                          final createdAt = comment['created_at'] != null
                              ? DateTime.parse(comment['created_at'])
                              : DateTime.now();

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.grey.shade200),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'On: ${comment['issue_title']}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        timeago.format(createdAt),
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    comment['content'] ?? '',
                                    style: const TextStyle(fontSize: 15),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ],
        ),
      ),
    );
  }
}
