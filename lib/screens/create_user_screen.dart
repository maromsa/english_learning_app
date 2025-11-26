import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:provider/provider.dart';

import '../services/local_user_service.dart';
import '../providers/auth_provider.dart';

class CreateUserScreen extends StatefulWidget {
  const CreateUserScreen({super.key});

  @override
  State<CreateUserScreen> createState() => _CreateUserScreenState();
}

class _CreateUserScreenState extends State<CreateUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final LocalUserService _userService = LocalUserService();
  final ImagePicker _picker = ImagePicker();

  File? _selectedImage;
  bool _isCreating = false;
  bool _isLinkingGoogle = false;
  String? _googleUid;
  String? _googleEmail;
  String? _googleDisplayName;
  String? _googlePhotoUrl;

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 400,
        maxHeight: 400,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה בבחירת תמונה: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<String?> _uploadImage(File imageFile) async {
    try {
      final storage = FirebaseStorage.instance;
      final extension = imageFile.path.split('.').last;
      final fileName =
          'user_${DateTime.now().millisecondsSinceEpoch}.$extension';
      final ref = storage.ref().child('user_profiles/$fileName');

      await ref.putFile(imageFile);
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading image: $e');
      // Return null if upload fails - user can continue without photo
      return null;
    }
  }

  Future<void> _linkToGoogle() async {
    setState(() => _isLinkingGoogle = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.signInWithGoogle();

      if (authProvider.isAuthenticated && authProvider.firebaseUser != null) {
        final user = authProvider.firebaseUser!;
        setState(() {
          _googleUid = user.uid;
          _googleEmail = user.email;
          _googleDisplayName = user.displayName;
          _googlePhotoUrl = user.photoURL;
          // Use Google photo if available
          if (_googlePhotoUrl != null && _selectedImage == null) {
            // Photo will be set from Google
          }
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('התחברת בהצלחה לחשבון Google!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה בהתחברות ל-Google: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLinkingGoogle = false);
      }
    }
  }

  Future<void> _createUser() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isCreating = true);

    try {
      String? photoUrl;
      if (_selectedImage != null) {
        photoUrl = await _uploadImage(_selectedImage!);
      } else if (_googlePhotoUrl != null) {
        // Use Google photo if no image selected
        photoUrl = _googlePhotoUrl;
      }

      final user = await _userService.createUser(
        name: _nameController.text.trim(),
        age: int.parse(_ageController.text),
        photoUrl: photoUrl,
        googleUid: _googleUid,
        googleEmail: _googleEmail,
        googleDisplayName: _googleDisplayName,
      );

      await _userService.setActiveUser(user.id);

      if (mounted) {
        Navigator.of(context).pop(user);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה ביצירת משתמש: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isCreating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('יצירת משתמש'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // 1. Hero Photo Picker
                GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey.shade100,
                          border: Border.all(
                            color: _selectedImage != null
                                ? primaryColor
                                : Colors.grey.shade300,
                            width: 4,
                          ),
                          image: _selectedImage != null
                              ? DecorationImage(
                                  image: FileImage(_selectedImage!),
                                  fit: BoxFit.cover)
                              : null,
                        ),
                        child: _selectedImage == null
                            ? Icon(Icons.camera_alt_rounded,
                                size: 50, color: Colors.grey.shade400)
                            : null,
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: primaryColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.edit,
                            color: Colors.white, size: 20),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "הוסיפו תמונה כדי שיהיה קל לזהות אתכם",
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),

                const SizedBox(height: 40),

                // 2. Form Fields
                TextFormField(
                  controller: _nameController,
                  textDirection: TextDirection.rtl,
                  decoration: InputDecoration(
                    labelText: 'שם הילד/ה',
                    hintText: 'איך קוראים לך?',
                    prefixIcon: const Icon(Icons.face),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'אנא הזינו שם';
                    }
                    if (value.trim().length < 2) {
                      return 'השם חייב להכיל לפחות 2 תווים';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _ageController,
                  keyboardType: TextInputType.number,
                  textDirection: TextDirection.rtl,
                  decoration: InputDecoration(
                    labelText: 'גיל',
                    hintText: 'בן/בת כמה את/ה?',
                    prefixIcon: const Icon(Icons.cake),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'אנא הזינו גיל';
                    }
                    final age = int.tryParse(value);
                    if (age == null) {
                      return 'אנא הזינו מספר תקין';
                    }
                    if (age < 3 || age > 18) {
                      return 'הגיל חייב להיות בין 3 ל-18';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 32),

                // 3. Google Link Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _googleUid != null
                        ? Colors.green.shade50
                        : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _googleUid != null
                          ? Colors.green.shade200
                          : Colors.blue.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: _isLinkingGoogle
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Icon(
                                _googleUid != null
                                    ? Icons.check
                                    : Icons.cloud_upload,
                                color: _googleUid != null
                                    ? Colors.green
                                    : Colors.blue,
                              ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _googleUid != null
                                  ? 'מחובר ל-Google'
                                  : 'חיבור לחשבון Google',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              _googleUid != null
                                  ? (_googleEmail ?? '')
                                  : 'לשמירת ההתקדמות בענן',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_googleUid == null)
                        TextButton(
                          onPressed: _isLinkingGoogle || _isCreating
                              ? null
                              : _linkToGoogle,
                          child: const Text('התחבר'),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // 4. Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton(
                    onPressed: _isCreating ? null : _createUser,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      backgroundColor: const Color(0xFF4A90E2),
                    ),
                    child: _isCreating
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'יצירת משתמש',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
