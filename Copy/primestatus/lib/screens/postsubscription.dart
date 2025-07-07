import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import '../services/subscription_service.dart';
import '../widgets/fullscreen_post_viewer.dart';
import '../services/user_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

class PostSubscriptionScreen extends StatefulWidget {
  final Map<String, dynamic> post;
  final String userUsageType;
  final String userName;
  final String? userProfilePhotoUrl;
  final String userAddress;
  final String userPhoneNumber;
  final String userCity;
  final String userEmail;

  const PostSubscriptionScreen({
    Key? key,
    required this.post,
    required this.userUsageType,
    required this.userName,
    this.userProfilePhotoUrl,
    required this.userAddress,
    required this.userPhoneNumber,
    required this.userCity,
    required this.userEmail,
  }) : super(key: key);

  @override
  State<PostSubscriptionScreen> createState() => _PostSubscriptionScreenState();
}

class _PostSubscriptionScreenState extends State<PostSubscriptionScreen> {
  List<SubscriptionPlan> _plans = [];
  bool _loadingPlans = true;
  bool _processing = false;
  final UserService _userService = UserService();

  @override
  void initState() {
    super.initState();
    _fetchPlans();
  }

  Future<void> _fetchPlans() async {
    setState(() { _loadingPlans = true; });
    final plans = await SubscriptionService().getAllActivePlans();
    setState(() {
      _plans = plans;
      _loadingPlans = false;
    });
  }

  // Helper function to request storage permissions based on Android version
  Future<bool> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      // Check Android version
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final sdkInt = androidInfo.version.sdkInt;
      
      if (sdkInt >= 33) {
        // Android 13+ - use media permissions
        var status = await Permission.photos.status;
        if (!status.isGranted) {
          status = await Permission.photos.request();
        }
        return status.isGranted;
      } else if (sdkInt >= 30) {
        // Android 11+ - use manage external storage
        var status = await Permission.manageExternalStorage.status;
        if (!status.isGranted) {
          status = await Permission.manageExternalStorage.request();
        }
        return status.isGranted;
      } else {
        // Android 10 and below - use storage permission
        var status = await Permission.storage.status;
        if (!status.isGranted) {
          status = await Permission.storage.request();
        }
        return status.isGranted;
      }
    } else {
      // iOS - no special permission needed for app documents
      return true;
    }
  }

  // Helper function to get downloads directory
  Future<Directory?> _getDownloadsDirectory() async {
    if (Platform.isAndroid) {
      // For Android, try to use the Downloads directory
      final List<String> possiblePaths = [
        '/storage/emulated/0/Download',
        '/storage/emulated/0/Downloads',
        '/sdcard/Download',
        '/sdcard/Downloads',
      ];
      
      for (String path in possiblePaths) {
        final dir = Directory(path);
        if (dir.existsSync()) {
          return dir;
        }
      }
      
      // If no download directory found, use external storage
      return await getExternalStorageDirectory();
    } else {
      // For iOS, use app documents directory
      return await getApplicationDocumentsDirectory();
    }
  }

  Future<void> _downloadFreeMedia() async {
    setState(() { _processing = true; });
    try {
      final String imageUrl = widget.post['mainImage'] ?? widget.post['imageUrl'] ?? '';
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        // Request appropriate storage permission
        final hasPermission = await _requestStoragePermission();
        
        if (hasPermission) {
          final downloadsDir = await _getDownloadsDirectory();
          
          if (downloadsDir != null) {
            String fileExtension = 'jpg';
            if (imageUrl.contains('.png')) fileExtension = 'png';
            else if (imageUrl.contains('.gif')) fileExtension = 'gif';
            else if (imageUrl.contains('.webp')) fileExtension = 'webp';
            final String fileName = 'PrimeStatus_Free_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
            final String filePath = '${downloadsDir.path}/$fileName';
            final File imageFile = File(filePath);
            await imageFile.writeAsBytes(response.bodyBytes);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Image saved to gallery!'),
                action: SnackBarAction(
                  label: 'Share',
                  onPressed: () async {
                    await Share.shareXFiles([XFile(filePath)]);
                  },
                ),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Could not access downloads directory')),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Storage permission required to download images')),
          );
        }
      } else {
        throw Exception('Failed to download image: HTTP ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to download: $e')),
      );
    } finally {
      setState(() { _processing = false; });
    }
  }

  Future<void> _shareFreeMedia() async {
    setState(() { _processing = true; });
    try {
      final String imageUrl = widget.post['mainImage'] ?? widget.post['imageUrl'] ?? '';
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        final Directory tempDir = await getTemporaryDirectory();
        final String fileName = 'PrimeStatus_FreeShare_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final String filePath = '${tempDir.path}/$fileName';
        final File imageFile = File(filePath);
        await imageFile.writeAsBytes(response.bodyBytes);
        await Share.shareXFiles([XFile(filePath)]);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to share: $e')),
      );
    } finally {
      setState(() { _processing = false; });
    }
  }

  Future<void> _goPremium(SubscriptionPlan plan) async {
    setState(() { _processing = true; });
    try {
      final user = _userService.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('User not authenticated.')),
        );
        setState(() { _processing = false; });
        return;
      }
      final userName = user.displayName ?? widget.userName;
      final userEmail = user.email ?? '';
      final userPhone = user.phoneNumber ?? widget.userPhoneNumber;
      final result = await SubscriptionService().createPaymentLink(
        userId: user.uid,
        userName: userName,
        userEmail: userEmail,
        userPhone: userPhone,
        plan: plan,
      );
      if (result != null && result['success'] == true && result['paymentLink'] != null) {
        final paymentLink = result['paymentLink'];
        if (await canLaunchUrl(Uri.parse(paymentLink))) {
          await launchUrl(Uri.parse(paymentLink), mode: LaunchMode.externalApplication);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open payment link')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create payment link.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start payment: $e')),
      );
    } finally {
      setState(() { _processing = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Unlock Premium'),
        backgroundColor: Colors.deepPurple,
      ),
      body: _loadingPlans
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Free Option
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.lock_open, color: Colors.green, size: 28),
                                SizedBox(width: 8),
                                Text('Free Option', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            SizedBox(height: 12),
                            AspectRatio(
                              aspectRatio: 9 / 16,
                              child: _PlainMediaPreview(imageUrl: widget.post['mainImage'] ?? widget.post['imageUrl'] ?? ''),
                            ),
                            SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _processing ? null : _shareFreeMedia,
                                    icon: Icon(Icons.share),
                                    label: Text('Share'),
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _processing ? null : _downloadFreeMedia,
                                    icon: Icon(Icons.download),
                                    label: Text('Download'),
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 24),
                    // Premium Options
                    Text('Go Premium', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    SizedBox(height: 12),
                    ..._plans.map((plan) => Card(
                          elevation: 6,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.star, color: Colors.amber, size: 28),
                                    SizedBox(width: 8),
                                    Text(plan.title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                    Spacer(),
                                    Text('₹${plan.price}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                                  ],
                                ),
                                if (plan.subtitle.isNotEmpty) ...[
                                  SizedBox(height: 4),
                                  Text(plan.subtitle, style: TextStyle(color: Colors.grey[700])),
                                ],
                                SizedBox(height: 8),
                                Text('Duration: ${plan.duration} days', style: TextStyle(color: Colors.grey[600])),
                                SizedBox(height: 12),
                                AspectRatio(
                                  aspectRatio: 9 / 16,
                                  child: AdminPostFullScreenCard(
                                    post: widget.post,
                                    userUsageType: widget.userUsageType,
                                    userName: widget.userName,
                                    userProfilePhotoUrl: widget.userProfilePhotoUrl,
                                    userAddress: widget.userAddress,
                                    userPhoneNumber: widget.userPhoneNumber,
                                    userCity: widget.userCity,
                                    onShare: () {},
                                    onDownload: () {},
                                    onEdit: () {},
                                    onPremium: () {},
                                    userEmail: widget.userEmail,
                                  ),
                                ),
                                SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _processing ? null : () => _goPremium(plan),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.deepPurple,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    child: Text('Go Premium'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )),
                  ],
                ),
                if (_processing)
                  Container(
                    color: Colors.black.withOpacity(0.3),
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
    );
  }
}

class _PlainMediaPreview extends StatelessWidget {
  final String imageUrl;
  const _PlainMediaPreview({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    if (imageUrl.endsWith('.mp4') || imageUrl.endsWith('.mov')) {
      // TODO: Add video preview if needed
      return Center(child: Icon(Icons.videocam, size: 48, color: Colors.grey));
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) => Container(
          color: Colors.grey[200],
          child: Icon(Icons.broken_image, color: Colors.grey, size: 48),
        ),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Center(child: CircularProgressIndicator());
        },
      ),
    );
  }
} 