import 'dart:async'; // For TimeoutException
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:app_links/app_links.dart';
import '../services/auth_flow_service.dart';
import '../services/account_linking_service.dart';
import '../services/otp_auth_service.dart';
import 'role_based_signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  bool _isLogin = true;
  bool _isLoading = false;
  bool _otpSent = false;
  bool _isPhoneLogin = true; // Toggle between Phone and Email
  bool _emailLinkSent = false; // Track if email link was sent
  String _selectedRole = 'Customer';
  final List<String> _roles = [
    'Customer',
    'Vendor',
    'Delivery Partner',
    'Real Estate Agent',
    'Plumber',        // ← add
    'Electrician',    // ← add
    'Doctor',         // ← add
    'Carpenter',      // ← add
    'Cleaner',        // ← add
  ];


  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final AuthFlowService _authFlowService = AuthFlowService();
  final AccountLinkingService _accountLinkingService = AccountLinkingService();
  final OtpAuthService _otpAuthService = OtpAuthService();
  
  // OTP State
  int _otpRetriesLeft = 3;
  bool _isSendingLink = false; // Prevent double-click on send link button
  
  // Deep Linking
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _initDeepLinking();
  }

  void _initDeepLinking() {
    _appLinks = AppLinks();

    // Check for initial link when app starts
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) {
        debugPrint('🔗 [DeepLink] Initial link: $uri');
        _processDeepLink(uri);
      }
    });

    // Listen for incoming links while app is running
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      debugPrint('🔗 [DeepLink] Stream link: $uri');
      _processDeepLink(uri);
    });
  }

  void _processDeepLink(Uri uri) {
    final link = uri.toString();
    if (_auth.isSignInWithEmailLink(link)) {
      debugPrint('📧 [PasswordlessAuth] Valid email sign-in link detected');
      _handleEmailLinkSignIn(providedLink: link);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    _phoneController.dispose();
    _otpController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _toggleMode() {
    setState(() {
      _isLogin = !_isLogin;
      _otpSent = false;
      _isLoading = false;
      _phoneController.clear();
      _nameController.clear();
      _otpController.clear();
      _emailController.clear();
      _passwordController.clear();
    });
  }

  void _switchLoginMethod() {
    setState(() {
      _isPhoneLogin = !_isPhoneLogin;
      _otpSent = false;
      _emailLinkSent = false;
      _isLoading = false;
      _phoneController.clear();
      _emailController.clear();
      _passwordController.clear();
    });
  }

  // ========== PASSWORDLESS EMAIL AUTHENTICATION ==========
  
  /// Send passwordless login link via email
  /// Fixed: Added timeout, double-click prevention, and better error handling
  Future<void> _sendPasswordlessEmailLink() async {
    // Prevent double-click
    if (_isSendingLink || _isLoading) {
      debugPrint('⚠️ [PasswordlessAuth] Request already in progress');
      return;
    }

    final email = _emailController.text.trim().toLowerCase();
    
    // Validate email
    if (email.isEmpty) {
      _showError('Please enter your email address');
      return;
    }
    
    if (!email.contains('@') || !email.contains('.')) {
      _showError('Please enter a valid email address');
      return;
    }

    // Set loading states
    setState(() {
      _isLoading = true;
      _isSendingLink = true;
    });

    try {
      debugPrint('📧 [PasswordlessAuth] Starting email link authentication');
      debugPrint('📧 [PasswordlessAuth] Email: $email');
      
      // Store email temporarily for later use
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pending_email_link', email);
      debugPrint('✅ [PasswordlessAuth] Email stored in SharedPreferences');

      // Configure action code settings for the email link
      // Using authorized domain from Firebase Hosting
       final actionCodeSettings = ActionCodeSettings(
         // URL must be whitelisted in Firebase Console > Authentication > Authorized domains
         // Using Firebase Hosting domain instead of deprecated page.link
         url: 'https://multiverses-8d207.web.app/login',
         handleCodeInApp: true, // Required for email link sign-in
         // Update with your actual iOS bundle ID
         iOSBundleId: 'com.ayush.multiverse.multiverses',
         // Android package name from AndroidManifest.xml
         androidPackageName: 'com.ayush.multiverse.multiverses',
         androidInstallApp: true,
         androidMinimumVersion: '1',
       );

      debugPrint('🔧 [PasswordlessAuth] ActionCodeSettings configured');
      debugPrint('🔧 [PasswordlessAuth] URL: ${actionCodeSettings.url}');
      debugPrint('🔧 [PasswordlessAuth] Android Package: ${actionCodeSettings.androidPackageName}');
      
      // Send email with sign-in link with timeout
      debugPrint('📤 [PasswordlessAuth] Calling sendSignInLinkToEmail...');
      
       await _auth.sendSignInLinkToEmail(
         email: email,
         actionCodeSettings: actionCodeSettings,
       ).timeout(
         const Duration(seconds: 30), // 30 second timeout to prevent ANR
         onTimeout: () {
           throw Exception('Request timed out. Please check your internet connection and try again.');
         },
       );

      debugPrint('✅ [PasswordlessAuth] Login link sent successfully to $email');

      if (!mounted) return;

      setState(() {
        _emailLinkSent = true;
        _isLoading = false;
        _isSendingLink = false;
      });

      _showSuccess('Login lb ink sent! Check your email (including spam folder) and click the link to login.');
      
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ [PasswordlessAuth] FirebaseAuthException: ${e.code}');
      debugPrint('❌ [PasswordlessAuth] Message: ${e.message}');
      
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isSendingLink = false;
      });
      
      String message = 'Failed to send login link';
      
      switch (e.code) {
        case 'invalid-email':
          message = 'Invalid email address format';
          break;
        case 'user-not-found':
          message = 'No account found with this email. Please sign up first.';
          break;
        case 'too-many-requests':
          message = 'Too many requests. Please wait a few minutes and try again.';
          break;
        case 'internal-error':
          message = 'Internal error. Please try again later.';
          break;
        case 'network-request-failed':
          message = 'Network error. Please check your internet connection.';
          break;
        case 'missing-android-pkgname':
          message = 'Configuration error: Android package name not set. Contact support.';
          debugPrint('⚠️ [PasswordlessAuth] Missing androidPackageName in ActionCodeSettings');
          break;
        case 'missing-ios-bundleid':
          message = 'Configuration error: iOS bundle ID not set. Contact support.';
          debugPrint('⚠️ [PasswordlessAuth] Missing iOSBundleId in ActionCodeSettings');
          break;
        case 'unauthorized-continue-uri':
          message = 'Configuration error: Domain not authorized in Firebase Console.';
          debugPrint('⚠️ [PasswordlessAuth] URL domain not whitelisted in Firebase Console');
          break;
        default:
          message = 'Error: ${e.message ?? "Unknown error occurred"}';
      }
      
      _showError(message);
      
    } on TimeoutException catch (e) {
      debugPrint('⏱️ [PasswordlessAuth] Timeout: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isSendingLink = false;
      });
      _showError('Request timed out. Please check your internet connection and try again.');
      
    } catch (e) {
      debugPrint('❌ [PasswordlessAuth] Unexpected error: $e');
      debugPrint('❌ [PasswordlessAuth] Stack trace: ${StackTrace.current}');
      
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isSendingLink = false;
      });
      _showError('Failed to send login link: ${e.toString()}');
    }
  }

  /// Check if app was opened from email link and complete sign-in
  Future<void> _handleEmailLinkSignIn({String? providedLink}) async {
    try {
      String? link = providedLink;
      
      // Fallback for Web or manual check
      if (link == null && kIsWeb) {
        link = Uri.base.toString();
        debugPrint('🌐 [PasswordlessAuth] Checking Web URL: $link');
      } 
      
      if (link == null || !_auth.isSignInWithEmailLink(link)) {
        return;
      }

      debugPrint('🔗 [PasswordlessAuth] Processing email link...');
      
      final prefs = await SharedPreferences.getInstance();
      String? pendingEmail = prefs.getString('pending_email_link');

      if (pendingEmail == null) {
        debugPrint('⚠️ [PasswordlessAuth] No pending email in storage, prompting user');
        if (mounted) {
          _showEmailPromptForLink(link);
        }
        return;
      }

      await _completeEmailLinkSignIn(pendingEmail, link);
      
    } catch (e) {
      debugPrint('❌ [PasswordlessAuth] Error handling email link: $e');
    }
  }

  /// Helper to complete the sign-in with email and link
  Future<void> _completeEmailLinkSignIn(String email, String link) async {
    setState(() => _isLoading = true);
    try {
      debugPrint('📧 [PasswordlessAuth] Signing in with email: $email');
      
       final userCredential = await _auth.signInWithEmailLink(
         email: email,
         emailLink: link,
       ).timeout(
         const Duration(seconds: 30),
         onTimeout: () => throw TimeoutException('Sign-in timed out'),
       );

      debugPrint('✅ [PasswordlessAuth] Sign-in successful');

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('pending_email_link');

       if (mounted) {
         await _completeSignIn(
           userCredential.user!.uid,
           email: userCredential.user!.email,
         );
       }
    } catch (e) {
      debugPrint('❌ [PasswordlessAuth] Sign-in error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('Failed to sign in. The link may be expired or already used.');
      }
    }
  }

  /// Show dialog to enter email if missing from SharedPreferences
  Future<void> _showEmailPromptForLink(String link) async {
    final TextEditingController emailConfirmController = TextEditingController();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Confirm Email', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'To complete sign-in, please enter the email address where you received the link:',
              style: TextStyle(color: Color(0xFFBBBBBB), fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailConfirmController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Email address',
                hintStyle: TextStyle(color: Color(0xFF666666)),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFFF4D4F))),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              final email = emailConfirmController.text.trim();
              if (email.isNotEmpty) {
                Navigator.pop(context);
                _completeEmailLinkSignIn(email, link);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF4D4F)),
            child: const Text('Sign In'),
          ),
         ],
       ),
     );
   }

  Future<void> _sendOTP() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty || phone.length < 10) {
      _showError('Please enter a valid phone number');
      return;
    }

    if (!_isLogin && _nameController.text.trim().isEmpty) {
      _showError('Please enter your full name');
      return;
    }

    // Check if can request OTP (cooldown check)
    if (!_otpAuthService.canRequestOtp()) {
      final remaining = _otpAuthService.remainingCooldownSeconds;
      _showError('Please wait $remaining seconds before requesting another OTP');
      return;
    }

    setState(() => _isLoading = true);

    final formattedPhone = phone.startsWith('+') ? phone : '+91$phone';
    
    final result = await _otpAuthService.sendPhoneOtp(
      phoneNumber: formattedPhone,
      codeSent: (String verificationId, int? resendToken) {
        setState(() {
          _otpSent = true;
          _isLoading = false;
          _otpRetriesLeft = 3;
        });
        debugPrint('✅ [Login] OTP sent, waiting for verification');
      },
      verificationCompleted: (PhoneAuthCredential credential) async {
        debugPrint('✅ [Login] Auto-verification completed');
        await _auth.signInWithCredential(credential).then((userCredential) {
          _completeSignIn(userCredential.user!.uid, phoneNumber: phone);
        });
      },
      verificationFailed: (FirebaseAuthException e) {
        setState(() => _isLoading = false);
        _showError(e.message ?? 'Verification failed');
      },
       codeAutoRetrievalTimeout: (String verificationId) {
         debugPrint('⏱️ [Login] Auto-retrieval timeout');
       },
     );

    // Handle immediate errors
    if (!result['success']) {
      setState(() => _isLoading = false);
      
      if (result['error'] == 'cooldown') {
        // Cooldown handled by service
      }
      
      _showError(result['message']);
    }
  }

  Future<void> _verifyOTP() async {
    final otp = _otpController.text.trim();
    if (otp.isEmpty || otp.length < 6) {
      _showError('Please enter 6-digit OTP');
      return;
    }

    // Check retry limit
    if (!_otpAuthService.canRetryOtp()) {
      _showError('Maximum OTP attempts exceeded. Please request a new OTP');
      setState(() {
        _otpSent = false;
      });
      return;
    }

    setState(() => _isLoading = true);

    final phone = _phoneController.text.trim();
    final formattedPhone = phone.startsWith('+') ? phone : '+91$phone';
    
     final result = await _otpAuthService.verifyPhoneOtp(
       verificationId: _otpAuthService.verificationId!,
       smsCode: otp,
       phoneNumber: formattedPhone,
     );

    if (result['success']) {
      // OTP verified successfully
      debugPrint('✅ [Login] OTP verification successful');
      
      final userCredential = result['userCredential'] as UserCredential;
      
      // Check if user already exists with this phone
      debugPrint('🔍 [Login] Checking for existing user with phone: $phone');
      final existingUserByPhone = await _accountLinkingService.findUserByPhone(phone);
      
      if (existingUserByPhone != null && !_isLogin) {
        // Signup but user already exists
        debugPrint('⚠️ [Login] User already exists with this phone');
        setState(() => _isLoading = false);
        _showError('Phone number already registered. Please login instead.');
        return;
      }
      
       await _completeSignIn(
         userCredential.user!.uid,
         phoneNumber: phone,
         name: _isLogin ? null : _nameController.text.trim(),
       );
    } else {
      // OTP verification failed
      setState(() => _isLoading = false);
      
      // Update retry count display
      setState(() {
        _otpRetriesLeft = result['retriesLeft'] ?? 0;
      });
      
      // Show appropriate error message
       if (result['error'] == 'max_retries') {
         _showError('Maximum OTP attempts exceeded. Please request a new OTP');
         // Reset OTP flow
         setState(() {
           _otpSent = false;
         });
      } else {
        // Show error with retries left
        final message = result['message'];
        if (_otpRetriesLeft > 0) {
          _showError('$message ($_otpRetriesLeft attempts left)');
        } else {
          _showError(message);
        }
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      await _googleSignIn.signOut();
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }
       final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
       final AuthCredential credential = GoogleAuthProvider.credential(
         accessToken: googleAuth.accessToken,
         idToken: googleAuth.idToken,
       );
       UserCredential userCredential = await _auth.signInWithCredential(credential);
       await _completeSignIn(
         userCredential.user!.uid,
         email: userCredential.user!.email,
         phoneNumber: userCredential.user!.phoneNumber,
         name: googleUser.displayName,
       );
    } catch (e) {
      setState(() => _isLoading = false);
      _showError("Google Sign-In failed");
    }
  }

  Future<void> _handleEmailLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      _showError('Please enter a valid email address');
      return;
    }

    if (password.isEmpty || password.length < 6) {
      _showError('Password must be at least 6 characters');
      return;
    }

    if (!_isLogin && _nameController.text.trim().isEmpty) {
      _showError('Please enter your full name');
      return;
    }

    setState(() => _isLoading = true);

    try {
      UserCredential userCredential;
      
      if (_isLogin) {
        // LOGIN: Check if user exists with this email
        debugPrint('🔍 [Login] Checking for existing user with email: $email');
        
         // Try to login with email
         userCredential = await _auth.signInWithEmailAndPassword(
           email: email,
           password: password,
         );

        debugPrint('✅ [Login] Email login successful: ${userCredential.user!.uid}');
        
        // Check if this email user has a corresponding phone user that needs linking
        final currentUser = userCredential.user;
        if (currentUser != null && !_accountLinkingService.hasPhoneProvider(currentUser)) {
          // User logged in with email but doesn't have phone linked
          // Check if there's a phone user with same details
          debugPrint('🔗 [Login] Checking if phone needs to be linked...');
          // This will be handled in _completeSignIn
        }
        
      } else {
        // SIGN UP: Check if user already exists with email or phone
        debugPrint('🔍 [Login] Checking for duplicate users before signup...');
        
        final existingUserByEmail = await _accountLinkingService.findUserByEmail(email);
        
        if (existingUserByEmail != null) {
          debugPrint('⚠️ [Login] User already exists with this email');
          setState(() => _isLoading = false);
          _showError('Email already registered. Please login instead.');
          return;
        }
        
         // Create new user
         userCredential = await _auth.createUserWithEmailAndPassword(
           email: email,
           password: password,
         );

        debugPrint('✅ [Login] Email signup successful: ${userCredential.user!.uid}');
      }

       await _completeSignIn(
         userCredential.user!.uid,
         email: email,
         name: _isLogin ? null : _nameController.text.trim(),
       );
    } on FirebaseAuthException catch (e) {
      setState(() => _isLoading = false);
      String message = 'Login failed';
      if (e.code == 'user-not-found') {
        message = 'No user found with this email';
      } else if (e.code == 'wrong-password') {
        message = 'Incorrect password';
      } else if (e.code == 'email-already-in-use') {
        message = 'Email already registered';
      } else if (e.code == 'weak-password') {
        message = 'Password is too weak';
      } else if (e.code == 'invalid-email') {
        message = 'Invalid email address';
      }
      _showError(message);
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Error: ${e.toString()}');
    }
  }

  Future<void> _completeSignIn(
    String uid, {
    String? email,
    String? phoneNumber,
    String? name,
  }) async {
    try {
      // Check for blocked users
      final userData = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final isBlocked = userData.data()?['isBlocked'] ?? false;

      if (isBlocked) {
        if (mounted) {
          setState(() => _isLoading = false);
          _showError("Account blocked. Contact support.");
          await _auth.signOut();
        }
        return;
      }

      // Check if we need to link accounts
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        // If user logged in with phone but has email in Firestore
        if (currentUser.providerData.any((p) => p.providerId == 'phone') && 
            email != null && 
            email.isNotEmpty) {
          final existingEmailUser = await _accountLinkingService.findUserByEmail(email);
          if (existingEmailUser != null && existingEmailUser['uid'] != uid) {
            debugPrint('🔗 [Login] Found email user that needs linking...');
            // Show dialog to user asking if they want to link accounts
            final shouldLink = await _showLinkAccountDialog(email, phoneNumber);
            if (shouldLink) {
              // User wants to link - they need to verify email password
              await _linkAccountWithEmail(email, uid);
              return; // Will navigate after linking
            }
          }
        }
        
        // If user logged in with email but has phone in Firestore
        if (currentUser.providerData.any((p) => p.providerId == 'password') && 
            phoneNumber != null && 
            phoneNumber.isNotEmpty) {
          final existingPhoneUser = await _accountLinkingService.findUserByPhone(phoneNumber);
          if (existingPhoneUser != null && existingPhoneUser['uid'] != uid) {
            debugPrint('🔗 [Login] Found phone user that needs linking...');
            // Show dialog to user asking if they want to link accounts
            final shouldLink = await _showLinkAccountDialog(email, phoneNumber);
            if (shouldLink) {
              // User wants to link - they need to verify phone OTP
              await _linkAccountWithPhone(phoneNumber, uid);
              return; // Will navigate after linking
            }
          }
        }
      }

       // Create/update user profile
       final role = await _authFlowService.ensureUserProfile(
         uid: uid,
         email: email,
         phoneNumber: phoneNumber,
         name: name,
         defaultRole: _selectedRole,
       );

      if (!mounted) return;
      
      // Save user session to avoid repeated login
      await _otpAuthService.saveUserSession(uid);
      
      if (!mounted) return;
      
      // Print user linking status for debugging
      _accountLinkingService.printUserLinkingStatus();
      _otpAuthService.printOtpState();
      
       // Navigate to appropriate screen
       Navigator.of(context).pushAndRemoveUntil(
         MaterialPageRoute(builder: (_) => _authFlowService.destinationForRole(role)),
         (route) => false,
       );
    } catch (e) {
      debugPrint('❌ [Login] Error completing sign in: $e');
      setState(() => _isLoading = false);
      _showError("Error completing sign in: $e");
    }
  }

  // ========== ACCOUNT LINKING METHODS ==========

  /// Show dialog asking user if they want to link accounts
  Future<bool> _showLinkAccountDialog(String? email, String? phone) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Link Accounts?'),
        content: Text(
          'We found an existing account'
          '${email != null ? ' with email: $email' : ''}'
          '${phone != null ? ' with phone: $phone' : ''}'
          '\n\nWould you like to link them together? ' 
          'This will allow you to login with either method.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No, Continue'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4D4F),
            ),
            child: const Text('Yes, Link'),
          ),
        ],
      ),
    ) ?? false;
  }

  /// Link account by verifying email password
  Future<void> _linkAccountWithEmail(String email, String currentUid) async {
    // Show password input dialog
    final passwordController = TextEditingController();
    
    final password = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Verify Email'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter your email password to link accounts:'),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                hintText: 'Password',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, passwordController.text),
            child: const Text('Verify & Link'),
          ),
         ],
       ),
     );

     if (password == null || password.isEmpty) {
      debugPrint('❌ [Linking] User cancelled email linking');
      // Continue without linking
      await _completeSignInWithoutLinking(currentUid);
      return;
    }
    
    try {
      // Try to sign in with email to verify password
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      
      // If successful, link the credential
      final success = await _accountLinkingService.linkEmailToCurrentUser(email, password);
      
      if (success) {
        debugPrint('✅ [Linking] Email linked successfully');
        _showSuccess('Accounts linked successfully!');
        
         // Now complete sign in with original phone user
         final currentUser = _auth.currentUser;
         if (currentUser != null) {
           await _completeSignIn(
             currentUser.uid,
             email: email,
             phoneNumber: currentUser.phoneNumber,
           );
        }
      } else {
        debugPrint('❌ [Linking] Failed to link email');
        _showError('Failed to link accounts. Please try again.');
        await _completeSignInWithoutLinking(currentUid);
      }
    } catch (e) {
      debugPrint('❌ [Linking] Email verification failed: $e');
      _showError('Incorrect password. Accounts not linked.');
      await _completeSignInWithoutLinking(currentUid);
    }
  }

  /// Link account by verifying phone OTP
  Future<void> _linkAccountWithPhone(String phone, String currentUid) async {
    // Show OTP input dialog
    final otpController = TextEditingController();
    String? verificationId;
    
    // First, send OTP to phone
    setState(() => _isLoading = true);
    
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phone.startsWith('+') ? phone : '+91$phone',
        verificationCompleted: (PhoneAuthCredential credential) async {
           // Auto-verification
           final success = await _accountLinkingService.linkPhoneToCurrentUser(
             verificationId!,
             credential.smsCode ?? '',
           );

           if (success) {
             _showSuccess('Accounts linked successfully!');
             final currentUser = _auth.currentUser;
             if (currentUser != null) {
               await _completeSignIn(
                 currentUser.uid,
                 email: currentUser.email,
                 phoneNumber: phone,
               );
            }
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() => _isLoading = false);
          _showError('Failed to send OTP: ${e.message}');
        },
        codeSent: (String vId, int? resendToken) {
          verificationId = vId;
          setState(() => _isLoading = false);
          
          // Show OTP dialog
          _showOtpLinkDialog(otpController, verificationId!, phone, currentUid);
        },
         codeAutoRetrievalTimeout: (String vId) {
           verificationId = vId;
         },
       );
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Failed to send OTP: $e');
      await _completeSignInWithoutLinking(currentUid);
    }
  }

  /// Show OTP dialog for phone linking
  Future<void> _showOtpLinkDialog(
    TextEditingController otpController,
    String verificationId,
    String phone,
    String currentUid,
  ) async {
    final otp = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Verify Phone'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Enter OTP sent to $phone'),
            const SizedBox(height: 16),
            TextField(
              controller: otpController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: '6-digit OTP',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, otpController.text),
            child: const Text('Verify & Link'),
          ),
        ],
      ),
    );
    
    if (otp == null || otp.isEmpty) {
      debugPrint('❌ [Linking] User cancelled phone linking');
      await _completeSignInWithoutLinking(currentUid);
      return;
    }
    
    try {
      final success = await _accountLinkingService.linkPhoneToCurrentUser(
        verificationId,
        otp,
      );
      
      if (success) {
        debugPrint('✅ [Linking] Phone linked successfully');
        _showSuccess('Accounts linked successfully!');
        
        final currentUser = _auth.currentUser;
        if (currentUser != null) {
          await _completeSignIn(
            currentUser.uid,
            email: currentUser.email,
            phoneNumber: phone,
          );
        }
      } else {
        debugPrint('❌ [Linking] Failed to link phone');
        _showError('Failed to link accounts. Please try again.');
        await _completeSignInWithoutLinking(currentUid);
      }
    } catch (e) {
      debugPrint('❌ [Linking] Phone verification failed: $e');
      _showError('Invalid OTP. Accounts not linked.');
      await _completeSignInWithoutLinking(currentUid);
    }
  }

  /// Complete sign in without linking (fallback)
  Future<void> _completeSignInWithoutLinking(String uid) async {
    final role = await _authFlowService.ensureUserProfile(
      uid: uid,
      defaultRole: _selectedRole,
    );
    
    if (!mounted) return;
    
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => _authFlowService.destinationForRole(role)),
      (route) => false,
    );
  }

  /// Show success message
  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Container(
        height: MediaQuery.of(context).size.height,
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1A1A1A),
              Color(0xFF0D0D0D),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Hero(
                    tag: 'app_logo',
                    child: Image.asset(
                      'assets/logo.png', 
                      width: 100, 
                      height: 100, 
                      errorBuilder: (_, __, ___) => const Icon(Icons.flash_on, size: 80, color: Color(0xFFFF4D4F))
                    ),
                  ),
                ),
              const SizedBox(height: 28),
              Text(
                _otpSent ? 'Verify OTP' : (_isLogin ? 'Login to\nMULTIVERSE' : 'Create\nAccount'),
                style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 1.5)
              ),
              const SizedBox(height: 36),
              
              // Login Method Toggle (Phone/Email)
              if (!_otpSent) ...[
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _switchLoginMethod,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            gradient: _isPhoneLogin
                                ? const LinearGradient(
                                    colors: [Color(0xFFFF4D4F), Color(0xFFD32F2F)],
                                  )
                                : const LinearGradient(
                                    colors: [Color(0xFF2A2A2A), Color(0xFF252525)],
                                  ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: _isPhoneLogin
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFFFF4D4F).withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.phone_android_rounded,
                                  color: _isPhoneLogin ? Colors.white : const Color(0xFF888888),
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Phone',
                                  style: TextStyle(
                                    color: _isPhoneLogin ? Colors.white : const Color(0xFF888888),
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: _switchLoginMethod,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            gradient: !_isPhoneLogin
                                ? const LinearGradient(
                                    colors: [Color(0xFFFF4D4F), Color(0xFFD32F2F)],
                                  )
                                : const LinearGradient(
                                    colors: [Color(0xFF2A2A2A), Color(0xFF252525)],
                                  ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: !_isPhoneLogin
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFFFF4D4F).withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.email_rounded,
                                  color: !_isPhoneLogin ? Colors.white : const Color(0xFF888888),
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Email',
                                  style: TextStyle(
                                    color: !_isPhoneLogin ? Colors.white : const Color(0xFF888888),
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
              ],
              
              // Conditional UI based on login method
              if (!_otpSent) ...[
                _isPhoneLogin
                    ? _buildPhoneLoginWidget()
                    : _buildEmailLoginWidget(),
              ] else ...[
                _buildTextField(_otpController, 'Enter 6-digit OTP', Icons.lock_outline, keyboardType: TextInputType.number),
                const SizedBox(height: 32),
                _buildButton('Verify & Continue', _verifyOTP),
                Center(
                  child: TextButton(
                    onPressed: () => setState(() => _otpSent = false),
                    child: const Text('Change Phone Number', style: TextStyle(color: Color(0xFFFF4D4F))),
                  ),
                ),
              ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, IconData icon, {TextInputType keyboardType = TextInputType.text}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF777777)),
        prefixIcon: Icon(icon, color: const Color(0xFFFF4D4F)),
        filled: true,
        fillColor: const Color(0xFF1E1E1E),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF2D2D2D))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFFF4D4F))),
      ),
    );
  }

  Widget _buildRoleChip(String role) {
    bool isSelected = _selectedRole == role;
    return GestureDetector(
      onTap: () => setState(() => _selectedRole = role),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF4D4F) : const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? const Color(0xFFFF4D4F) : const Color(0xFF333333)),
        ),
        child: Text(
          role,
          style: TextStyle(color: isSelected ? Colors.white : Colors.grey, fontSize: 13, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildButton(String label, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF4D4F),
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: _isLoading
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Text(label, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildGoogleButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: _isLoading ? null : _handleGoogleSignIn,
        style: OutlinedButton.styleFrom(
          backgroundColor: const Color(0xFFF5F5F5),
          foregroundColor: const Color(0xFF111111),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.g_mobiledata, size: 30, color: Color(0xFF4285F4)),
            SizedBox(width: 12),
            Text('Continue with Google', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  // Phone Login Widget
  Widget _buildPhoneLoginWidget() {
    return Column(
      children: [
        if (!_isLogin) ...[
          _buildTextField(_nameController, 'Full Name', Icons.person_outline),
          const SizedBox(height: 16),
        ],
        _buildTextField(_phoneController, 'Phone Number', Icons.phone_android_rounded, keyboardType: TextInputType.phone),
        
        if (!_isLogin) ...[
          const SizedBox(height: 24),
          const Text('Select your role:', style: TextStyle(color: Colors.white, fontSize: 14)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _roles.map((role) => _buildRoleChip(role)).toList(),
          ),
        ],
        
        const SizedBox(height: 32),
        _buildButton(_isLogin ? 'Send OTP' : 'Sign Up', _sendOTP),
        
        if (_isLogin) ...[
          const SizedBox(height: 24),
          const Row(
            children: [
              Expanded(child: Divider(color: Color(0xFF333333))),
              Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('OR', style: TextStyle(color: Color(0xFF444444)))),
              Expanded(child: Divider(color: Color(0xFF333333))),
            ],
          ),
          const SizedBox(height: 24),
          _buildGoogleButton(),
        ],
        
        const SizedBox(height: 24),
        Center(
          child: TextButton(
            onPressed: _toggleMode,
            child: RichText(
              text: TextSpan(
                text: _isLogin ? "New user? " : "Already have account? ",
                style: const TextStyle(color: Colors.grey),
                children: [
                  TextSpan(
                    text: _isLogin ? "Sign Up" : "Login",
                    style: const TextStyle(color: Color(0xFFFF4D4F), fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Email Login Widget (Passwordless)
  Widget _buildEmailLoginWidget() {
    return Column(
      children: [
        if (!_isLogin) ...[
          _buildTextField(_nameController, 'Full Name', Icons.person_outline),
          const SizedBox(height: 16),
        ],
        _buildTextField(_emailController, 'Email Address', Icons.email_rounded, keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 16),
        
        if (!_emailLinkSent) ...[
          // Show send login link button (login only)
          if (_isLogin) ...[
            _buildButton('Send Login Link', _sendPasswordlessEmailLink),
            const SizedBox(height: 16),
            const Center(
              child: Text(
                'We\'ll send you a magic link to login without password',
                style: TextStyle(
                  color: Color(0xFF888888),
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ] else ...[
            // For signup, keep password
            _buildTextField(_passwordController, 'Password', Icons.lock_outline, keyboardType: TextInputType.visiblePassword),
            const SizedBox(height: 32),
            _buildButton('Sign Up', _handleEmailLogin),
          ],
        ] else ...[
          // Email link sent success UI
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFF4D4F)),
            ),
            child: Column(
              children: [
                const Icon(Icons.mark_email_read, size: 64, color: Color(0xFFFF4D4F)),
                const SizedBox(height: 16),
                const Text(
                  'Login Link Sent!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Check your email and click the login link to continue',
                  style: TextStyle(
                    color: Color(0xFF888888),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                _buildButton('Resend Link', _sendPasswordlessEmailLink),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _emailLinkSent = false;
                    });
                  },
                  child: const Text(
                    'Change Email',
                    style: TextStyle(color: Color(0xFFFF4D4F)),
                  ),
                ),
              ],
            ),
          ),
        ],
        
        if (_isLogin && !_emailLinkSent) ...[
          const SizedBox(height: 24),
          const Row(
            children: [
              Expanded(child: Divider(color: Color(0xFF333333))),
              Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('OR', style: TextStyle(color: Color(0xFF444444)))),
              Expanded(child: Divider(color: Color(0xFF333333))),
            ],
          ),
          const SizedBox(height: 24),
          _buildGoogleButton(),
        ],
        
        const SizedBox(height: 24),
        Center(
          child: TextButton(
            onPressed: () {
              // Navigate to new role-based signup screen
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RoleBasedSignupScreen()),
              );
            },
            child: RichText(
              text: TextSpan(
                text: _isLogin ? "New user? " : "Already have account? ",
                style: const TextStyle(color: Colors.grey),
                children: [
                  TextSpan(
                    text: _isLogin ? "Sign Up" : "Login",
                    style: const TextStyle(color: Color(0xFFFF4D4F), fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
