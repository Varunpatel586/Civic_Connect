import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:share_plus/share_plus.dart';
import 'package:timeago/timeago.dart' as timeago;

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
  final _supabase = Supabase.instance.client;
  
  Future<void> _pickImage() async {
    // TODO: Implement image picking
    // This would typically use image_picker to select an image from gallery/camera
    // and then upload it to Supabase Storage
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Image picker will be implemented here')),
    );
  }

  @override
  void initState() {
    super.initState();
    final user = _supabase.auth.currentUser;
    _nameController = TextEditingController(text: user?.userMetadata?['full_name'] ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
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
      final user = _supabase.auth.currentUser;
      if (user == null) throw 'User not authenticated';
      
      // Update auth user metadata
      await _supabase.auth.updateUser(
        UserAttributes(
          data: {
            'full_name': _nameController.text,
            'phone': _phoneController.text,
          },
        ),
      );
      
      // Update profile in the profiles table
      await _supabase
          .from('profiles')
          .update({
            'full_name': _nameController.text,
            'phone': _phoneController.text,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', user.id);
      
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
      await _supabase.auth.signOut();
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

  Widget _buildProfileHeader(User user, String? avatarUrl) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            CircleAvatar(
              radius: 60,
              backgroundImage: avatarUrl != null
                  ? NetworkImage(avatarUrl) as ImageProvider
                  : const AssetImage('assets/images/default_avatar.png'),
              child: avatarUrl == null
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
          user.userMetadata?['full_name'] ?? 'User',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        if (user.email != null) ...[
          const SizedBox(height: 4),
          Text(
            user.email!,
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildStatColumn('Posts', '24'),
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
    final user = _supabase.auth.currentUser;
    final avatarUrl = user?.userMetadata?['avatar_url'];
    // Convert the createdAt string to DateTime if it exists
    DateTime? joinDate;
    if (user?.createdAt != null) {
      joinDate = DateTime.tryParse(user!.createdAt);
    }
    
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
                      _buildProfileHeader(user!, avatarUrl),
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
                                  joinDate != null 
                                      ? timeago.format(joinDate, allowFromNow: true)
                                      : 'Recently',
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
                          // Navigate to activity
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
