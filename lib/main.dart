import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'firebase_options.dart';


// Global memory state for Demo Mode session persistence
String _currentDemoEmail = "";

final List<Map<String, dynamic>> _globalDemoUsers = [
  {'uid': 'demo_user_1', 'email': 'client_alpha@gmail.com', 'role': 'user', 'createdAt': '2026-07-05 10:24'},
  {'uid': 'demo_user_2', 'email': 'dev_test@legally.com', 'role': 'user', 'createdAt': '2026-07-06 09:12'},
  {'uid': 'demo_user_3', 'email': 'rohit_kumar@yahoo.com', 'role': 'user', 'createdAt': '2026-07-06 11:45'},
];

final List<Map<String, dynamic>> _globalDemoBookings = [
  {
    'id': 'booking_1',
    'userEmail': 'client_alpha@gmail.com',
    'lawyerName': 'Sarita Sharma, Esq.',
    'bookingTime': '2026-07-08 14:00',
    'status': 'scheduled',
  },
  {
    'id': 'booking_2',
    'userEmail': 'rohit_kumar@yahoo.com',
    'lawyerName': 'Elena Rostova',
    'bookingTime': '2026-07-08 16:30',
    'status': 'scheduled',
  },
];

final Map<String, List<Map<String, String>>> _globalDemoUserChats = {
  'demo_user_1': [
    {'role': 'user', 'text': 'What is Section 305 of BNS?'},
    {'role': 'ai', 'text': 'Section 305 of BNS covers theft in a dwelling house, transportation, or place of worship, carrying a maximum sentence of 7 years in prison.'},
  ],
  'demo_user_2': [
    {'role': 'user', 'text': 'How to register a trademark for my app?'},
    {'role': 'ai', 'text': 'Trademark registration requires filing a Form TM-A with the IP Office. Specialist attorneys like Elena Rostova can help file details.'},
  ],
};

const String _backendHost = 'https://legally-backend.onrender.com';

const String _systemPrompt = """
You are a legal AI specialized strictly in the NEW Indian criminal law framework effective July 2024.

CRITICAL RULES:
1. You MUST use Bharatiya Nyaya Sanhita, 2023 (BNS).
2. You MUST NOT cite IPC sections under any circumstance.
3. If IPC section numbers appear in your reasoning, you must replace them with corresponding BNS sections before answering.
4. If unsure about BNS section number, state: "Section number requires verification under BNS" instead of defaulting to IPC.
5. Always format citation as:
   Section __, Bharatiya Nyaya Sanhita, 2023.

Also reference:
- Bharatiya Nagarik Suraksha Sanhita, 2023 (BNSS)
- Bharatiya Sakshya Adhiniyam, 2023 (BSA)

Never mention IPC unless the user explicitly asks for comparison.

User Question: """;

bool _isFirebaseInitialized = false;

void _pingBackend() {
  // Fire-and-forget background ping to wake up the Render container
  http.get(Uri.parse('https://legally-backend.onrender.com')).timeout(
    const Duration(seconds: 15),
    onTimeout: () => http.Response('timeout', 408),
  ).catchError((_) => http.Response('error', 500));
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _pingBackend();
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: kIsWeb ? firebaseOptions : null,
      );
    }
    _isFirebaseInitialized = true;
  } catch (e) {
    debugPrint("Firebase initialization error: $e");
    _isFirebaseInitialized = Firebase.apps.isNotEmpty;
  }
  runApp(const LegallyApp());
}

class LegallyApp extends StatelessWidget {
  const LegallyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Legally - AI Legal Intelligence',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF090B0F),
        primaryColor: const Color(0xFFE2B755),
        focusColor: const Color(0xFFE2B755),
        hoverColor: const Color(0xFFE2B755).withValues(alpha: 0.06),
        splashColor: const Color(0xFFE2B755).withValues(alpha: 0.10),
        highlightColor: Colors.transparent,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFE2B755),
          secondary: Color(0xFF4A90E2),
          surface: Color(0xFF131720),
          onPrimary: Colors.black,
          onSecondary: Colors.white,
        ),
        cardColor: const Color(0xFF131720),
        dividerColor: const Color(0xFF2D323E),
        fontFamily: 'Roboto',
        // ── Remove the green focus border everywhere ──
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF141924),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          hintStyle: const TextStyle(color: Colors.white38),
          labelStyle: const TextStyle(color: Colors.white54),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF283042)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF283042)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2B755), width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.redAccent),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
          ),
        ),
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: Color(0xFFE2B755),
          selectionColor: Color(0x44E2B755),
          selectionHandleColor: Color(0xFFE2B755),
        ),
        // ── Smooth page transitions ──
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          },
        ),
      ),
      home: const AnimatedSplashScreen(),
    );
  }
}

// ----------------------------------------------------
// AUTH GATE: Checks if user is authenticated
// ----------------------------------------------------
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  User? _fbUser;
  bool _mockLoggedIn = false;
  String _mockEmail = "";
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (_isFirebaseInitialized) {
      FirebaseAuth.instance.authStateChanges().listen((user) {
        if (mounted) {
          setState(() {
            _fbUser = user;
            _isLoading = false;
          });
        }
      });
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _loginMock(String email) {
    setState(() {
      _mockLoggedIn = true;
      _mockEmail = email;
    });
  }

  void _logoutMock() {
    setState(() {
      _mockLoggedIn = false;
      _mockEmail = "";
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFE2B755)),
        ),
      );
    }

    if (_isFirebaseInitialized) {
      if (_fbUser != null) {
        if (_fbUser!.email == 'admin@legally.com') {
          return AdminDashboardScreen(
            isDemoMode: false,
            onLogout: () async {
              await FirebaseAuth.instance.signOut();
            },
          );
        }
        return const MainScreen();
      }
    } else {
      if (_mockLoggedIn) {
        if (_mockEmail == 'admin@legally.com') {
          return AdminDashboardScreen(
            isDemoMode: true,
            onLogout: _logoutMock,
          );
        }
        return MainScreen(
          isDemoMode: true,
          demoEmail: _mockEmail,
          onDemoLogout: _logoutMock,
        );
      }
    }

    return AuthScreen(
      isDemoMode: !_isFirebaseInitialized,
      onDemoLogin: _loginMock,
    );
  }
}

// ----------------------------------------------------
// AUTH SCREEN: Login & SignUp UI
// ----------------------------------------------------
class AuthScreen extends StatefulWidget {
  final bool isDemoMode;
  final Function(String)? onDemoLogin;
  const AuthScreen({super.key, this.isDemoMode = false, this.onDemoLogin});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLogin = true;
  bool _isLoading = false;
  String _errorMessage = "";

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitAuthForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = "";
    });

    if (widget.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        final email = _emailController.text.trim();
        if (email != 'admin@legally.com') {
          final exists = _globalDemoUsers.any((u) => u['email'] == email);
          if (!exists) {
            _globalDemoUsers.add({
              'uid': 'demo_user_${_globalDemoUsers.length + 1}',
              'email': email,
              'role': 'user',
              'createdAt': DateTime.now().toString().substring(0, 16),
            });
          }
        }
        widget.onDemoLogin?.call(email);
      }
      return;
    }

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      if (email == 'admin@legally.com' && password == 'Admin@123') {
        try {
          await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: email,
            password: password,
          );
        } catch (e) {
          try {
            await FirebaseAuth.instance.createUserWithEmailAndPassword(
              email: email,
              password: password,
            );
          } catch (_) {
            rethrow;
          }
        }
      } else {
        if (_isLogin) {
          await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: email,
            password: password,
          );
        } else {
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: email,
            password: password,
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = e.message ?? "An error occurred during authentication.";
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.2,
            colors: [
              Color(0xFF141924),
              Color(0xFF090B0F),
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450),
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: const Color(0xFF131720),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF262D3D)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    )
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2B755).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.gavel_rounded,
                          color: Color(0xFFE2B755),
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.isDemoMode ? 'Legally Portal (Demo Mode)' : 'Legally Portal',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.isDemoMode
                            ? 'Firebase Offline. You can log in using any email and password.'
                            : (_isLogin ? 'Sign in to access AI legal advisory' : 'Create an account to get started'),
                        style: const TextStyle(color: Colors.white54, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),

                      // Email input
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.email_outlined, color: Colors.white38),
                          labelText: 'Email Address',
                          labelStyle: const TextStyle(color: Colors.white54),
                          filled: true,
                          fillColor: const Color(0xFF0D1017),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFF222834)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFF222834)),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || !value.contains('@')) {
                            return 'Please enter a valid email address.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),

                      // Password input
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.lock_outline, color: Colors.white38),
                          labelText: 'Password',
                          labelStyle: const TextStyle(color: Colors.white54),
                          filled: true,
                          fillColor: const Color(0xFF0D1017),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFF222834)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFF222834)),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.length < 6) {
                            return 'Password must be at least 6 characters.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // Error message placeholder
                      if (_errorMessage.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Text(
                            _errorMessage,
                            style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                        ),

                      const SizedBox(height: 12),

                      // Submit button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submitAuthForm,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE2B755),
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                )
                              : Text(
                                  _isLogin ? 'Log In' : 'Sign Up',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Switch Login/Signup
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _isLogin = !_isLogin;
                            _errorMessage = "";
                          });
                        },
                        child: Text(
                          _isLogin ? 'Need an account? Sign Up' : 'Already have an account? Log In',
                          style: const TextStyle(color: Color(0xFFE2B755)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------
// MAIN APP SCREEN: Layout with top header and tabs
// ----------------------------------------------------
class MainScreen extends StatefulWidget {
  final bool isDemoMode;
  final String demoEmail;
  final VoidCallback? onDemoLogout;
  const MainScreen({
    super.key,
    this.isDemoMode = false,
    this.demoEmail = "",
    this.onDemoLogout,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentTab = 0;
  String _initialChatQuery = "";

  @override
  void initState() {
    super.initState();
    _syncUserProfile();
  }

  Future<void> _syncUserProfile() async {
    if (widget.isDemoMode) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final ref = FirebaseDatabase.instance.ref('users/${user.uid}');
        final snapshot = await ref.get();
        if (!snapshot.exists) {
          await ref.set({
            'email': user.email ?? 'Member',
            'role': user.email == 'admin@legally.com' ? 'admin' : 'user',
            'createdAt': ServerValue.timestamp,
          });
        }
      } catch (e) {
        debugPrint("Failed to sync user profile: $e");
      }
    }
  }

  void _navigateToTab(int index, {String query = ""}) {
    setState(() {
      _currentTab = index;
      if (query.isNotEmpty) {
        _initialChatQuery = query;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final bool isMobile = width < 850;
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0D1017),
            border: Border(
              bottom: BorderSide(color: Color(0xFF222834), width: 1),
            ),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 16 : 24,
            vertical: isMobile ? 8 : 10,
          ),
          child: SafeArea(
            child: Row(
              children: [
                // Logo — always shown
                GestureDetector(
                  onTap: () => _navigateToTab(0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2B755).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.gavel_rounded,
                          color: Color(0xFFE2B755),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Legally',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Desktop: nav links
                if (!isMobile)
                  Row(
                    children: [
                      _NavBarItem(
                        title: 'Home',
                        isActive: _currentTab == 0,
                        onTap: () => _navigateToTab(0),
                      ),
                      _NavBarItem(
                        title: 'Ask AI Chat',
                        isActive: _currentTab == 1,
                        onTap: () => _navigateToTab(1),
                      ),
                      _NavBarItem(
                        title: 'Browse Laws',
                        isActive: _currentTab == 2,
                        onTap: () => _navigateToTab(2),
                      ),
                      _NavBarItem(
                        title: 'Find Lawyers',
                        isActive: _currentTab == 3,
                        onTap: () => _navigateToTab(3),
                      ),
                      const SizedBox(width: 16),
                    ],
                  ),

                // Desktop: email + logout + consult AI button
                if (!isMobile) ...[
                  Text(
                    widget.isDemoMode ? widget.demoEmail : (user?.email ?? 'Member'),
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: () async {
                      if (widget.isDemoMode) {
                        widget.onDemoLogout?.call();
                      } else {
                        await FirebaseAuth.instance.signOut();
                      }
                    },
                    child: const Text('Logout', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _navigateToTab(1),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE2B755),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bolt, size: 15),
                        SizedBox(width: 4),
                        Text('Consult AI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                  ),
                ],

                // Mobile: compact logout icon only (navigation is in bottom bar)
                if (isMobile)
                  IconButton(
                    onPressed: () async {
                      if (widget.isDemoMode) {
                        widget.onDemoLogout?.call();
                      } else {
                        await FirebaseAuth.instance.signOut();
                      }
                    },
                    icon: const Icon(Icons.logout_rounded, color: Colors.white54, size: 20),
                    tooltip: 'Logout',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),
        ),
      ),

      bottomNavigationBar: isMobile
          ? BottomNavigationBar(
              currentIndex: _currentTab,
              onTap: (index) => _navigateToTab(index),
              backgroundColor: const Color(0xFF0D1017),
              selectedItemColor: const Color(0xFFE2B755),
              unselectedItemColor: Colors.white60,
              type: BottomNavigationBarType.fixed,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home_outlined),
                  activeIcon: Icon(Icons.home),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.chat_bubble_outline_rounded),
                  activeIcon: Icon(Icons.chat_bubble_rounded),
                  label: 'Ask AI',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.library_books_outlined),
                  activeIcon: Icon(Icons.library_books),
                  label: 'Laws',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.people_outline_rounded),
                  activeIcon: Icon(Icons.people_rounded),
                  label: 'Lawyers',
                ),
              ],
            )
          : null,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.03),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOut,
              )),
              child: child,
            ),
          );
        },
        child: KeyedSubtree(
          key: ValueKey<int>(_currentTab),
          child: _buildCurrentScreen(),
        ),
      ),
    );
  }

  Widget _buildCurrentScreen() {
    switch (_currentTab) {
      case 0:
        return HomeScreen(
          onNavigate: (index, {String query = ""}) => _navigateToTab(index, query: query),
        );
      case 1:
        final query = _initialChatQuery;
        _initialChatQuery = "";
        return ChatScreen(initialQuery: query, isDemoMode: widget.isDemoMode);
      case 2:
        return const BrowseLawsScreen();
      case 3:
        return LawyerDirectoryScreen(isDemoMode: widget.isDemoMode);
      default:
        return HomeScreen(
          onNavigate: (index, {String query = ""}) => _navigateToTab(index, query: query),
        );
    }
  }
}

class _NavBarItem extends StatelessWidget {
  final String title;
  final bool isActive;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.title,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: isActive ? const Color(0xFFE2B755) : Colors.white70,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 2,
              width: isActive ? 24 : 0,
              color: const Color(0xFFE2B755),
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------
// HOVER CARD (Reusable Wrapper for Interactive Glow/Scale)
// ----------------------------------------------------
class HoverCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color glowColor;
  final double scaleFactor;

  const HoverCard({
    super.key,
    required this.child,
    this.onTap,
    this.glowColor = const Color(0xFFE2B755),
    this.scaleFactor = 1.02,
  });

  @override
  State<HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<HoverCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: widget.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          transform: Matrix4.diagonal3Values(
            _isHovered ? widget.scaleFactor : 1.0,
            _isHovered ? widget.scaleFactor : 1.0,
            1.0,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: widget.glowColor.withOpacity(0.12),
                      blurRadius: 20,
                      spreadRadius: 2,
                      offset: const Offset(0, 8),
                    )
                  ]
                : [],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

// ====================================================
// REUSABLE FADE + SLIDE ENTRANCE ANIMATION WIDGET
// ====================================================
class _FadeSlideIn extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  const _FadeSlideIn({
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 500),
  });
  @override
  State<_FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<_FadeSlideIn> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

// ====================================================
// SCREEN 1: HOME DASHBOARD
// ====================================================
class HomeScreen extends StatefulWidget {
  final Function(int, {String query}) onNavigate;

  const HomeScreen({super.key, required this.onNavigate});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _askController = TextEditingController();

  @override
  void dispose() {
    _askController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final bool isMobile = width < 850;

    return SingleChildScrollView(
      child: Column(
        children: [
          // 1. HERO SECTION WITH GRADIENT GLOW
          _FadeSlideIn(
            delay: const Duration(milliseconds: 50),
            child: _buildHeroSection(isMobile),
          ),

          // 2. KEY STATS SECTION
          _FadeSlideIn(
            delay: const Duration(milliseconds: 180),
            child: _buildStatsSection(isMobile),
          ),

          // 3. CAPABILITIES GRID
          _FadeSlideIn(
            delay: const Duration(milliseconds: 280),
            child: _buildCapabilitiesSection(isMobile),
          ),

          // 4. PRECEDENT SCANNER & MOCK TOOLS SECTION
          _FadeSlideIn(
            delay: const Duration(milliseconds: 360),
            child: _buildSpecialHighlightSection(isMobile),
          ),

          // 5. FAQ SECTION
          _FadeSlideIn(
            delay: const Duration(milliseconds: 420),
            child: _buildFAQSection(isMobile),
          ),

          // 6. ATTORNEY CALLOUT
          _FadeSlideIn(
            delay: const Duration(milliseconds: 480),
            child: _buildLawyerCallout(isMobile),
          ),

          // 7. FOOTER
          _FadeSlideIn(
            delay: const Duration(milliseconds: 520),
            child: const PremiumFooter(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection(bool isMobile) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF0D1017),
            Color(0xFF090B0F),
          ],
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 60,
        vertical: isMobile ? 50 : 90,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Glow Shield / Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFE2B755).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFE2B755).withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      color: Color(0xFFE2B755),
                      size: 14,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'SECURE • AI-POWERED • 24/7 LEGAL INTELLIGENCE',
                      style: TextStyle(
                        color: Color(0xFFE2B755),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Title with Glowing Glow Effect
              Stack(
                alignment: Alignment.center,
                children: [
                  // Behind glow
                  Text(
                    'AI-Powered Legal Intelligence',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: isMobile ? 32 : 56,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      foreground: Paint()
                        ..style = PaintingStyle.stroke
                        ..strokeWidth = 8
                        ..color = const Color(0xFFE2B755).withOpacity(0.15),
                      shadows: [
                        Shadow(
                          color: const Color(0xFFE2B755).withOpacity(0.6),
                          blurRadius: 40,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'AI-Powered Legal Intelligence',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: isMobile ? 32 : 56,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Subheading
              Text(
                'Understand laws, regulations, and applicable sections — instantly and accurately.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: isMobile ? 15 : 18,
                  color: Colors.white70,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 40),

              // Interactive Search / Question bar
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 650),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF141924),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF283042)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      )
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.search_rounded, color: Colors.white38),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _askController,
                          onSubmitted: (value) {
                            if (value.trim().isNotEmpty) {
                              widget.onNavigate(1, query: value);
                            }
                          },
                          decoration: const InputDecoration(
                            hintText: 'Describe your legal question (e.g. rent agreement clauses, NDA template)...',
                            hintStyle: TextStyle(color: Colors.white38, fontSize: 14),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          if (_askController.text.trim().isNotEmpty) {
                            widget.onNavigate(1, query: _askController.text);
                          } else {
                            widget.onNavigate(1);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE2B755),
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        child: const Row(
                          children: [
                            Text('Ask AI', style: TextStyle(fontWeight: FontWeight.bold)),
                            SizedBox(width: 4),
                            Icon(Icons.arrow_forward_rounded, size: 16),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Hero CTAs
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  HoverCard(
                    onTap: () => widget.onNavigate(1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.balance, color: Colors.black, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Ask Legally',
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  HoverCard(
                    onTap: () => widget.onNavigate(2),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF2D323E)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.collections_bookmark_outlined, color: Colors.white, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Browse Laws',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsSection(bool isMobile) {
    final List<Map<String, String>> stats = [
      {'val': '99.4%', 'lbl': 'Accuracy Benchmark'},
      {'val': 'Instant', 'lbl': 'Response Speed'},
      {'val': '384', 'lbl': 'BNS Codified Sections'},
      {'val': '100%', 'lbl': 'Confidential & Encrypted'},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      color: const Color(0xFF0B0D13),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (isMobile) {
                return Column(
                  children: stats
                      .map((s) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12.0),
                            child: _buildStatItem(s['val']!, s['lbl']!),
                          ))
                      .toList(),
                );
              }
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: stats
                    .map((s) => Expanded(
                          child: _buildStatItem(s['val']!, s['lbl']!),
                        ))
                    .toList(),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String val, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          val,
          style: const TextStyle(
            color: Color(0xFFE2B755),
            fontSize: 32,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 13,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildCapabilitiesSection(bool isMobile) {
    final double paddingVal = isMobile ? 20.0 : 60.0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: paddingVal, vertical: 80),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'Key Capabilities',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFFE2B755),
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Advanced Legal Tools at Your Fingertips',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Leverage models fine-tuned on code libraries, constitution, and state laws.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.white54,
                ),
              ),
              const SizedBox(height: 48),

              // 2x2 Grid of capabilities (responsive)
              LayoutBuilder(
                builder: (context, constraints) {
                  int cols = isMobile ? 1 : 2;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      crossAxisSpacing: 24,
                      mainAxisSpacing: 24,
                      childAspectRatio: isMobile ? 1.5 : 1.8,
                    ),
                    itemCount: 4,
                    itemBuilder: (context, idx) {
                      return _buildCapabilityCard(idx);
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCapabilityCard(int index) {
    final List<Map<String, dynamic>> items = [
      {
        'title': 'AI Advisory Consultation',
        'desc': 'Ask complex hypothetical questions. Our LLMs cite regulatory code references to justify logic.',
        'icon': Icons.smart_toy_outlined,
        'color': const Color(0xFFE2B755),
        'tab': 1,
      },
      {
        'title': 'Intelligent Document Review',
        'desc': 'Scan employment agreements, leases, or NDAs to spot hidden indemnity, renewal clauses, and liabilities.',
        'icon': Icons.document_scanner_outlined,
        'color': const Color(0xFF4A90E2),
        'tab': 1,
      },
      {
        'title': 'Precedent BNS Search',
        'desc': 'Search BNS penal codes, labor guides, and historical federal judgments instantly.',
        'icon': Icons.menu_book_outlined,
        'color': const Color(0xFF4AE2A0),
        'tab': 2,
      },
      {
        'title': 'Smart Legal Form Constructor',
        'desc': 'Answer a dynamic questionnaire to build ready-to-sign legal agreements, contracts, and dispute notices.',
        'icon': Icons.border_color_outlined,
        'color': const Color(0xFFE24AE2),
        'tab': 1,
      },
    ];

    final item = items[index];

    return HoverCard(
      onTap: () => widget.onNavigate(item['tab'] as int),
      glowColor: item['color'] as Color,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF131720),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF252B3A)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (item['color'] as Color).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                item['icon'] as IconData,
                color: item['color'] as Color,
                size: 24,
              ),
            ),
            const Spacer(),
            Text(
              item['title'] as String,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              item['desc'] as String,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.white60,
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            Row(
              children: [
                Text(
                  'Launch Feature',
                  style: TextStyle(
                    color: item['color'] as Color,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_right_alt_rounded,
                  color: item['color'] as Color,
                  size: 16,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpecialHighlightSection(bool isMobile) {
    return Container(
      width: double.infinity,
      color: const Color(0xFF0C0E14),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 60,
        vertical: 70,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Flex(
            direction: isMobile ? Axis.vertical : Axis.horizontal,
            children: [
              // Text Content
              Expanded(
                flex: isMobile ? 0 : 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'NEW BNS PRECEDENT INDEX',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Search Codified Sections & Judgments',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Legally connects dynamically to active database codes to fetch sections. Instantly find case briefs, decisions, and punishments relevant to your query.',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.white70,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => widget.onNavigate(2),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1B2333),
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFF333E56)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Try Precedent Explorer'),
                    ),
                  ],
                ),
              ),
              if (!isMobile) const SizedBox(width: 60),
              if (isMobile) const SizedBox(height: 40),

              // Visual Sandbox Simulation Window
              Expanded(
                flex: isMobile ? 0 : 1,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF131720),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF262D3D)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Simulated Header bar
                      Row(
                        children: [
                          Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.red)),
                          const SizedBox(width: 6),
                          Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.amber)),
                          const SizedBox(width: 6),
                          Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.green)),
                          const SizedBox(width: 20),
                          const Text(
                            'bns_engine_v1.bin',
                            style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.white30),
                          ),
                        ],
                      ),
                      const Divider(height: 24, color: Color(0xFF202634)),
                      const Text(
                        '>> query --context="theft in dwelling house" --region="BNS"',
                        style: TextStyle(fontFamily: 'monospace', color: Color(0xFFE2B755), fontSize: 12),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Searching Bharatiya Nyaya Sanhita, 2023 database...',
                        style: TextStyle(fontFamily: 'monospace', color: Colors.white70, fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C222E),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF2E374A)),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'IDENTIFIED SECTION:',
                              style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 11, color: Colors.lightBlueAccent),
                            ),
                            SizedBox(height: 6),
                            Text(
                              '• Section 305: Theft in dwelling house, means of transportation or place of worship.\n• Punishment: Imprisonment up to 7 years and fine.',
                              style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.white60, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Row(
                        children: [
                          Icon(Icons.check_circle_outline, color: Colors.green, size: 14),
                          SizedBox(width: 6),
                          Text(
                            'Confidence Index: 99.1%',
                            style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.green),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFAQSection(bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 60,
        vertical: 80,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'FAQ',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFFE2B755),
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Frequently Asked Questions',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 36),

              _FAQTile(
                question: 'Is AI-generated legal advice legally binding?',
                answer: 'No. Legally provides automated information and document synthesis tools based on raw legislative guides. It does not replace formal legal counsel. For binding disputes or formal court representation, you should consult a licensed lawyer.',
              ),
              _FAQTile(
                question: 'How secure and confidential is my uploaded document data?',
                answer: 'Completely secure. All contracts, files, and queries are encrypted in transit and at rest. Your documents are never shared or used to train public models.',
              ),
              _FAQTile(
                question: 'Does Legally support state-specific regulations?',
                answer: 'Currently, the integrated database contains the complete codified structures of the new Bharatiya Nyaya Sanhita (BNS), 2023, along with categories for penal codes and judicial acts.',
              ),
              _FAQTile(
                question: 'How do I speak to a real lawyer using the app?',
                answer: 'Navigate to the "Find Lawyers" tab, filter by specialization and location, and schedule a consultation. Connected attorneys will review your Legally AI summary to speed up onboarding.',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLawyerCallout(bool isMobile) {
    return Container(
      margin: const EdgeInsets.only(bottom: 60, left: 24, right: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2A1F11), Color(0xFF131720)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF5E4924), width: 1),
            ),
            padding: const EdgeInsets.all(28),
            child: Flex(
              direction: isMobile ? Axis.vertical : Axis.horizontal,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: isMobile ? 0 : 2,
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.gavel_rounded, color: Color(0xFFE2B755), size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Need Binding Counsel / Court Representation?',
                            style: TextStyle(
                              color: Color(0xFFE2B755),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Connected attorneys are ready to review your case dashboard, contracts, and AI draft responses to provide licensed, formal legal support.',
                        style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                      ),
                    ],
                  ),
                ),
                if (isMobile) const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => widget.onNavigate(3),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE2B755),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Browse Attorney Directory',
                    style: TextStyle(fontWeight: FontWeight.bold),
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

class _FAQTile extends StatefulWidget {
  final String question;
  final String answer;

  const _FAQTile({required this.question, required this.answer});

  @override
  State<_FAQTile> createState() => _FAQTileState();
}

class _FAQTileState extends State<_FAQTile> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF131720),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF262C3A)),
      ),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: ListTile(
              title: Text(
                widget.question,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              trailing: Icon(
                _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                color: const Color(0xFFE2B755),
              ),
              onTap: () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              },
            ),
          ),
          AnimatedCrossFade(
            firstChild: Container(),
            secondChild: Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 20, top: 4),
              child: Text(
                widget.answer,
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
            crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}

// ====================================================
// SCREEN 2: LIVE AI CHAT ASSISTANT
// ====================================================
class ChatScreen extends StatefulWidget {
  final String initialQuery;
  final bool isDemoMode;
  const ChatScreen({super.key, this.initialQuery = "", this.isDemoMode = false});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _msgController = TextEditingController();
  final List<Map<String, String>> _messages = [];
  bool _isTyping = false;
  bool _isLoadingHistory = true;

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
  }

  Future<void> _loadChatHistory() async {
    if (widget.isDemoMode) {
      final userIndex = _globalDemoUsers.indexWhere((u) => u['email'] == _currentDemoEmail);
      final String userUid = userIndex != -1 ? _globalDemoUsers[userIndex]['uid'] : 'demo_user_temp';
      
      final history = _globalDemoUserChats[userUid];
      if (history != null && history.isNotEmpty) {
        _messages.addAll(history);
      } else {
        _messages.add({
          'role': 'ai',
          'text': 'Hello! I am Legally AI (Demo Mode). Ask me any questions regarding the Bharatiya Nyaya Sanhita (BNS), 2023. What legal context can I assist you with today?',
        });
      }
      setState(() {
        _isLoadingHistory = false;
      });
      if (widget.initialQuery.isNotEmpty) {
        _sendMessage(widget.initialQuery);
      }
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final chatRef = FirebaseDatabase.instance.ref('chats/${user.uid}');
      final chatSnapshot = await chatRef.orderByChild('timestamp').get();

      // Firebase can return a Map (push-ID keys) or a List (integer keys).
      Iterable<dynamic> historyValues = [];
      if (chatSnapshot.exists) {
        if (chatSnapshot.value is Map) {
          final rawMap = chatSnapshot.value as Map<dynamic, dynamic>;
          final sortedEntries = rawMap.entries.toList()
            ..sort((a, b) {
              final t1 = (a.value is Map ? (a.value as Map)['timestamp'] : null) ?? 0;
              final t2 = (b.value is Map ? (b.value as Map)['timestamp'] : null) ?? 0;
              return (t1 as Comparable).compareTo(t2);
            });
          historyValues = sortedEntries.map((e) => e.value);
        } else if (chatSnapshot.value is List) {
          historyValues = (chatSnapshot.value as List).whereType<Object>();
        }
      }

      bool hasHistory = false;
      for (final data in historyValues) {
        if (data is Map) {
          final userText = (data['query'] ?? data['message'] ?? data['text'] ?? data['userQuery'] ?? data['question'] ?? '').toString().trim();
          final aiText = (data['reply'] ?? data['response'] ?? data['aiResponse'] ?? data['answer'] ?? '').toString().trim();
          if (userText.isNotEmpty && aiText.isNotEmpty) {
            _messages.add({'role': 'user', 'text': userText});
            _messages.add({'role': 'ai', 'text': aiText});
            hasHistory = true;
          }
        }
      }

      if (!hasHistory) {
        // Default greeting if no history
        _messages.add({
          'role': 'ai',
          'text': 'Hello! I am Legally AI. Ask me any questions regarding the Bharatiya Nyaya Sanhita (BNS), 2023. What legal context can I assist you with today?',
        });
      }
    } catch (e) {
      debugPrint("Failed to load chat history: $e");
      _messages.add({
        'role': 'ai',
        'text': 'Hello! I am Legally AI. Ask me any questions regarding the Bharatiya Nyaya Sanhita (BNS), 2023. What legal context can I assist you with today?',
      });
    } finally {
      setState(() {
        _isLoadingHistory = false;
      });

      if (widget.initialQuery.isNotEmpty) {
        _sendMessage(widget.initialQuery);
      }
    }
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _isTyping = true;
    });

    _msgController.clear();

    String reply = "";

    try {
      final response = await http.post(
        Uri.parse('$_backendHost/api/legal-advice'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'message': '$_systemPrompt$text'}),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        reply = data['response'] ?? data['reply'] ?? "Sorry, the AI could not formulate a response.";
      } else {
        try {
          final Map<String, dynamic> errData = jsonDecode(response.body);
          reply = errData['detail'] ?? "Error: Backend server responded with status code ${response.statusCode}.";
        } catch (_) {
          reply = "Error: Backend server responded with status code ${response.statusCode}.";
        }
      }
    } catch (e) {
      reply = "Failed to connect to Legally API backend. Please check your network connection.";
    }

    if (!mounted) return;

    setState(() {
      _isTyping = false;
      _messages.add({'role': 'ai', 'text': reply});
    });

    // Save to Firestore history
    if (!widget.isDemoMode) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && reply.isNotEmpty) {
        try {
          await FirebaseDatabase.instance
              .ref('chats/${user.uid}')
              .push()
              .set({
            'query': text,
            'message': text,
            'text': text,
            'userQuery': text,
            'reply': reply,
            'response': reply,
            'aiResponse': reply,
            'category': 'General',
            'timestamp': ServerValue.timestamp,
          });
        } catch (e) {
          debugPrint("Failed to save message to history: $e");
        }
      }
    } else {
      if (reply.isNotEmpty) {
        final userIndex = _globalDemoUsers.indexWhere((u) => u['email'] == _currentDemoEmail);
        final String userUid = userIndex != -1 ? _globalDemoUsers[userIndex]['uid'] : 'demo_user_temp';
        
        _globalDemoUserChats.putIfAbsent(userUid, () => []);
        _globalDemoUserChats[userUid]!.add({'role': 'user', 'text': text});
        _globalDemoUserChats[userUid]!.add({'role': 'ai', 'text': reply});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF131720),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF262D3D)),
            ),
            child: Column(
              children: [
                // Chat Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: const BoxDecoration(
                    color: Color(0xFF0D1017),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                    border: Border(bottom: BorderSide(color: Color(0xFF222834))),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Legally BNS AI Assistant',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          Text(
                            'Trained on Bharatiya Nyaya Sanhita, 2023',
                            style: TextStyle(color: Colors.white54, fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Chat Message List
                Expanded(
                  child: _isLoadingHistory
                      ? const Center(
                          child: CircularProgressIndicator(color: Color(0xFFE2B755)),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _messages.length,
                          itemBuilder: (context, idx) {
                            final msg = _messages[idx];
                            final isUser = msg['role'] == 'user';
                            return Align(
                              alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                constraints: const BoxConstraints(maxWidth: 650),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isUser ? const Color(0xFF1B2A4A) : const Color(0xFF1D222E),
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(12),
                                    topRight: const Radius.circular(12),
                                    bottomLeft: isUser ? const Radius.circular(12) : Radius.zero,
                                    bottomRight: isUser ? Radius.zero : const Radius.circular(12),
                                  ),
                                  border: Border.all(
                                    color: isUser ? const Color(0xFF2B447A) : const Color(0xFF2D3547),
                                  ),
                                ),
                                child: _renderMessageContent(msg['text']!, isUser),
                              ),
                            );
                          },
                        ),
                ),

                if (_isTyping)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFE2B755)),
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Legally AI is formulating response citing BNS clauses...',
                          style: TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                      ],
                    ),
                  ),

                // Preset suggestion chips
                if (_messages.length == 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _PresetChip(
                          text: 'What is Section 305?',
                          onTap: () => _sendMessage('What does Section 305 of BNS cover and what is the punishment?'),
                        ),
                        _PresetChip(
                          text: 'Punishment for defamation?',
                          onTap: () => _sendMessage('What is the punishment for defamation under BNS?'),
                        ),
                        _PresetChip(
                          text: 'Punishment for cheating?',
                          onTap: () => _sendMessage('Explain the cheating provisions and punishments in BNS.'),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 10),

                // Chat Input
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D1017),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF222834)),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: TextField(
                            controller: _msgController,
                            onSubmitted: _sendMessage,
                            decoration: const InputDecoration(
                              hintText: 'Ask your BNS legal query...',
                              hintStyle: TextStyle(color: Colors.white38),
                              border: InputBorder.none,
                            ),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: const Icon(Icons.send_rounded, color: Color(0xFFE2B755)),
                        onPressed: () => _sendMessage(_msgController.text),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _renderMessageContent(String text, bool isUser) {
    if (isUser) {
      return Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 14),
      );
    }

    // Process bold-styled text and bullets
    List<Widget> children = [];
    final lines = text.split('\n');

    for (var line in lines) {
      if (line.trim().isEmpty) {
        children.add(const SizedBox(height: 6));
        continue;
      }
      
      if (line.startsWith('**') && line.endsWith('**')) {
        final titleText = line.replaceAll('**', '');
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 6.0, top: 4.0),
            child: Text(
              titleText,
              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE2B755), fontSize: 15),
            ),
          ),
        );
      } else if (line.startsWith('*') && line.endsWith('*')) {
        final italicText = line.replaceAll('*', '');
        children.add(
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              italicText,
              style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.white38, fontSize: 12),
            ),
          ),
        );
      } else {
        // Handle bold fragments in inline text
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: Text(
              line,
              style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.45),
            ),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

class _PresetChip extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _PresetChip({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(text, style: const TextStyle(fontSize: 12, color: Colors.white70)),
      backgroundColor: const Color(0xFF1D222E),
      side: const BorderSide(color: Color(0xFF2D3547)),
      onPressed: onTap,
    );
  }
}

// ====================================================
// SCREEN 3: LIVE BROWSE LAWS (BNS SECTIONS)
// ====================================================
class BrowseLawsScreen extends StatefulWidget {
  const BrowseLawsScreen({super.key});

  @override
  State<BrowseLawsScreen> createState() => _BrowseLawsScreenState();
}

class _BrowseLawsScreenState extends State<BrowseLawsScreen> {
  String _searchQuery = "";
  String _selectedCategory = "";
  List<dynamic> _sections = [];
  List<dynamic> _categories = [];
  bool _isLoadingSections = false;
  bool _isLoadingCategories = false;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
    _fetchSections();
  }

  final List<String> _localCategories = [
    'General Exceptions',
    'Offences against Body',
    'Offences against Property',
    'Offences against State',
    'Public Tranquility',
  ];

  final List<Map<String, dynamic>> _localSections = [
    {
      'number': 'Section 103',
      'title': 'Punishment for Murder',
      'category': 'Offences against Body',
      'punishment': 'Death or Imprisonment for life, and shall also be liable to fine.',
      'description': 'Whoever commits murder shall be punished with death or imprisonment for life, and shall also be liable to fine.',
    },
    {
      'number': 'Section 115',
      'title': 'Voluntary Causing Hurt',
      'category': 'Offences against Body',
      'punishment': 'Imprisonment up to one year, or fine up to ten thousand rupees, or both.',
      'description': 'Whoever voluntarily causes hurt to any person shall be punished with imprisonment or fine or both.',
    },
    {
      'number': 'Section 303',
      'title': 'Theft',
      'category': 'Offences against Property',
      'punishment': 'Imprisonment up to three years, or fine, or both.',
      'description': 'Whoever commits theft shall be punished with imprisonment for a term which may extend to three years, or with fine, or with both.',
    },
    {
      'number': 'Section 309',
      'title': 'Robbery',
      'category': 'Offences against Property',
      'punishment': 'Rigorous imprisonment up to ten years, and fine.',
      'description': 'In all robbery there is either theft or extortion.',
    },
    {
      'number': 'Section 189',
      'title': 'Unlawful Assembly',
      'category': 'Public Tranquility',
      'punishment': 'Imprisonment up to six months, or fine, or both.',
      'description': 'An assembly of five or more persons is designated an unlawful assembly if the common object is to overawe by criminal force.',
    },
  ];

  Future<void> _fetchCategories() async {
    setState(() {
      _isLoadingCategories = true;
    });

    try {
      final response = await http.get(Uri.parse('$_backendHost/api/categories'));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        setState(() {
          _categories = List<String>.from(data['categories'] ?? []);
        });
      } else {
        setState(() {
          _categories = _localCategories;
        });
      }
    } catch (e) {
      debugPrint("Failed to fetch categories: $e");
      setState(() {
        _categories = _localCategories;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingCategories = false;
        });
      }
    }
  }

  Future<void> _fetchSections() async {
    setState(() {
      _isLoadingSections = true;
    });

    try {
      String url = '$_backendHost/api/sections?limit=50';
      if (_searchQuery.trim().isNotEmpty) {
        url += '&search=${Uri.encodeComponent(_searchQuery)}';
      }
      if (_selectedCategory.isNotEmpty) {
        url += '&category=${Uri.encodeComponent(_selectedCategory)}';
      }

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        setState(() {
          _sections = data['sections'] ?? [];
        });
      } else {
        _loadLocalSectionsFallback();
      }
    } catch (e) {
      debugPrint("Failed to fetch sections: $e");
      _loadLocalSectionsFallback();
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingSections = false;
        });
      }
    }
  }

  void _loadLocalSectionsFallback() {
    List<Map<String, dynamic>> filtered = _localSections;
    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((s) {
        final title = s['title']?.toString().toLowerCase() ?? '';
        final number = s['number']?.toString().toLowerCase() ?? '';
        final desc = s['description']?.toString().toLowerCase() ?? '';
        return title.contains(query) || number.contains(query) || desc.contains(query);
      }).toList();
    }
    if (_selectedCategory.isNotEmpty) {
      filtered = filtered.where((s) => s['category'] == _selectedCategory).toList();
    }
    setState(() {
      _sections = filtered;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Precedent BNS Directory',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Search codified statutes and BNS categories referenced by our AI model.',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 24),

              // Search input
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF131720),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF262C3A)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  onSubmitted: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                    _fetchSections();
                  },
                  decoration: InputDecoration(
                    icon: const Icon(Icons.search, color: Colors.white38),
                    hintText: 'Type keyword and press Enter (e.g. theft, murder, cheating)...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    border: InputBorder.none,
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.white54, size: 18),
                            onPressed: () {
                              setState(() {
                                _searchQuery = "";
                              });
                              _fetchSections();
                            },
                          )
                        : null,
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // Category selector chips
              if (_isLoadingCategories)
                const SizedBox(
                  height: 35,
                  child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFE2B755)))),
                )
              else if (_categories.isNotEmpty)
                SizedBox(
                  height: 40,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length + 1,
                    itemBuilder: (context, idx) {
                      if (idx == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: const Text('All Categories'),
                            selected: _selectedCategory.isEmpty,
                            selectedColor: const Color(0xFFE2B755),
                            labelStyle: TextStyle(
                              color: _selectedCategory.isEmpty ? Colors.black : Colors.white,
                              fontSize: 12,
                            ),
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _selectedCategory = "";
                                });
                                _fetchSections();
                              }
                            },
                          ),
                        );
                      }
                      final cat = _categories[idx - 1];
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text(cat),
                          selected: _selectedCategory == cat,
                          selectedColor: const Color(0xFFE2B755),
                          labelStyle: TextStyle(
                            color: _selectedCategory == cat ? Colors.black : Colors.white,
                            fontSize: 12,
                          ),
                          onSelected: (selected) {
                            setState(() {
                              _selectedCategory = selected ? cat : "";
                            });
                            _fetchSections();
                          },
                        ),
                      );
                    },
                  ),
                ),

              const SizedBox(height: 24),

              // Law items list
              Expanded(
                child: _isLoadingSections
                    ? const Center(
                        child: CircularProgressIndicator(color: Color(0xFFE2B755)),
                      )
                    : _sections.isEmpty
                        ? const Center(
                            child: Text(
                              'No sections found matching your query.',
                              style: TextStyle(color: Colors.white38),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _sections.length,
                            itemBuilder: (context, idx) {
                              final item = _sections[idx];
                              return FadeInSlide(
                                delay: Duration(milliseconds: idx * 30),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF131720),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFF262C3A)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFE2B755).withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              item['category'] ?? 'BNS Code',
                                              style: const TextStyle(
                                                color: Color(0xFFE2B755),
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            item['act'] ?? 'BNS, 2023',
                                            style: const TextStyle(
                                              color: Colors.white38,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Section ${item['section']}: ${item['title']}',
                                        style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        item['description'] ?? '',
                                        style: const TextStyle(
                                          color: Colors.white60,
                                          fontSize: 13,
                                          height: 1.45,
                                        ),
                                      ),
                                      if (item['punishment'] != null && item['punishment'].toString().isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 14.0),
                                          child: Container(
                                            padding: const EdgeInsets.all(12),
                                            width: double.infinity,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF0F1219),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: const Color(0xFF1E2433)),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  '⚖️ STATUTORY PUNISHMENT:',
                                                  style: TextStyle(
                                                    color: Color(0xFF4A90E2),
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  item['punishment'],
                                                  style: const TextStyle(
                                                    color: Colors.white70,
                                                    fontSize: 12,
                                                    height: 1.4,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ====================================================
// SCREEN 4: LIVE LAWYER DIRECTORY & BOOKINGS
// ====================================================
class LawyerDirectoryScreen extends StatefulWidget {
  final bool isDemoMode;
  const LawyerDirectoryScreen({super.key, this.isDemoMode = false});

  @override
  State<LawyerDirectoryScreen> createState() => _LawyerDirectoryScreenState();
}

class _LawyerDirectoryScreenState extends State<LawyerDirectoryScreen> {
  String _lawyerFilter = "";
  List<dynamic> _lawyers = [];
  List<dynamic> _userBookings = [];
  bool _isLoadingLawyers = true;
  bool _isLoadingBookings = true;

  final List<Map<String, dynamic>> _mockLawyers = [
    {
      'name': 'Sarita Sharma, Esq.',
      'specialty': 'Criminal Penal Code Defense',
      'location': 'New Delhi, DL',
      'rate': '₹3500/hr',
      'rating': 4.9,
      'consults': 142,
    },
    {
      'name': 'Rahul Vance',
      'specialty': 'Corporate Formations & LLCs',
      'location': 'Mumbai, MH',
      'rate': '₹4000/hr',
      'rating': 4.8,
      'consults': 98,
    },
    {
      'name': 'Elena Rostova',
      'specialty': 'Intellectual Property Patents',
      'location': 'Bengaluru, KA',
      'rate': '₹3800/hr',
      'rating': 5.0,
      'consults': 210,
    },
    {
      'name': 'David Kim',
      'specialty': 'Real Estate & Property Dispute',
      'location': 'Kolkata, WB',
      'rate': '₹3000/hr',
      'rating': 4.7,
      'consults': 85,
    },
  ];

  @override
  void initState() {
    super.initState();
    _fetchLawyersAndSeedIfNeeded();
    _fetchUserBookings();
  }

  Future<void> _fetchLawyersAndSeedIfNeeded() async {
    setState(() {
      _isLoadingLawyers = true;
    });

    if (widget.isDemoMode) {
      setState(() {
        _lawyers = _mockLawyers;
        _isLoadingLawyers = false;
      });
      return;
    }

    try {
      final ref = FirebaseDatabase.instance.ref('lawyers');
      final snapshot = await ref.get();
      if (!snapshot.exists) {
        // Seed mock lawyers database
        for (var mock in _mockLawyers) {
          await ref.push().set(mock);
        }
        final reSnapshot = await ref.get();
        final List<Map<String, dynamic>> lawyers = [];
        if (reSnapshot.exists && reSnapshot.value is Map) {
          final Map<dynamic, dynamic> values = reSnapshot.value as Map;
          for (var key in values.keys) {
            lawyers.add({'id': key, ...Map<String, dynamic>.from(values[key] as Map)});
          }
        }
        setState(() {
          _lawyers = lawyers;
        });
      } else {
        final List<Map<String, dynamic>> lawyers = [];
        if (snapshot.value is Map) {
          final Map<dynamic, dynamic> values = snapshot.value as Map;
          for (var key in values.keys) {
            lawyers.add({'id': key, ...Map<String, dynamic>.from(values[key] as Map)});
          }
        }
        setState(() {
          _lawyers = lawyers;
        });
      }
    } catch (e) {
      debugPrint("Failed to fetch lawyers from Realtime DB: $e");
      setState(() {
        _lawyers = _mockLawyers;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingLawyers = false;
        });
      }
    }
  }

  Future<void> _fetchUserBookings() async {
    if (widget.isDemoMode) {
      setState(() {
        _userBookings = _globalDemoBookings.where((b) => b['userEmail'] == _currentDemoEmail).toList();
        _isLoadingBookings = false;
      });
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _isLoadingBookings = true;
    });

    try {
      final ref = FirebaseDatabase.instance.ref('bookings');
      final snapshot = await ref.orderByChild('uid').equalTo(user.uid).get();

      final List<Map<String, dynamic>> bookings = [];
      if (snapshot.exists && snapshot.value is Map) {
        final Map<dynamic, dynamic> values = snapshot.value as Map;
        for (var key in values.keys) {
          bookings.add({'id': key, ...Map<String, dynamic>.from(values[key] as Map)});
        }
        // Sort by createdAt descending
        bookings.sort((a, b) {
          final t1 = a['createdAt'] ?? 0;
          final t2 = b['createdAt'] ?? 0;
          return t2.compareTo(t1);
        });
      }

      setState(() {
        _userBookings = bookings;
      });
    } catch (e) {
      debugPrint("Failed to load user bookings: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingBookings = false;
        });
      }
    }
  }

  Future<void> _bookConsultation(String lawyerName) async {
    if (widget.isDemoMode) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF131720),
          title: const Text('Confirm Consultation Booking'),
          content: Text('Would you like to book a 30-minute introductory phone consultation with $lawyerName? (Demo Mode)'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE2B755)),
              onPressed: () {
                Navigator.pop(ctx);
                final newBooking = {
                  'id': 'booking_${_globalDemoBookings.length + 1}',
                  'userEmail': _currentDemoEmail,
                  'lawyerName': lawyerName,
                  'bookingTime': DateTime.now().add(const Duration(days: 2)).toLocal().toString().substring(0, 16),
                  'status': 'scheduled',
                };
                setState(() {
                  _globalDemoBookings.insert(0, newBooking);
                  _userBookings.insert(0, newBooking);
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Booking scheduled (Demo Mode) with $lawyerName!'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              child: const Text('Confirm', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131720),
        title: const Text('Confirm Consultation Booking'),
        content: Text('Would you like to book a 30-minute introductory phone consultation with $lawyerName? Details will be logged to the database.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE2B755)),
            onPressed: () async {
              Navigator.pop(ctx);
              
              try {
                await FirebaseDatabase.instance.ref('bookings').push().set({
                  'uid': user.uid,
                  'userEmail': user.email ?? 'Unknown',
                  'lawyerName': lawyerName,
                  'bookingTime': DateTime.now().add(const Duration(days: 2)).toLocal().toString().substring(0, 16),
                  'status': 'scheduled',
                  'createdAt': ServerValue.timestamp,
                });

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Booking scheduled successfully with $lawyerName!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }

                _fetchUserBookings(); // Reload list
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Booking failed: $e'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              }
            },
            child: const Text('Confirm', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _lawyers.where((lay) {
      final search = _lawyerFilter.toLowerCase();
      final name = (lay['name'] ?? '').toString().toLowerCase();
      final specialty = (lay['specialty'] ?? '').toString().toLowerCase();
      final location = (lay['location'] ?? '').toString().toLowerCase();
      return name.contains(search) || specialty.contains(search) || location.contains(search);
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Licensed Attorney Directory',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Connect with verified attorneys to evaluate your case or sign documents.',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 24),

              // Search bar
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF131720),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF262C3A)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  onChanged: (val) {
                    setState(() {
                      _lawyerFilter = val;
                    });
                  },
                  decoration: const InputDecoration(
                    icon: Icon(Icons.search, color: Colors.white38),
                    hintText: 'Search by specialty, name, or city location...',
                    hintStyle: TextStyle(color: Colors.white38),
                    border: InputBorder.none,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Bookings panel (Horizontal row)
              if (!_isLoadingBookings && _userBookings.isNotEmpty) ...[
                const Text(
                  'My Active Bookings',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFE2B755)),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _userBookings.length,
                    itemBuilder: (context, idx) {
                      final bk = _userBookings[idx];
                      return Container(
                        width: 250,
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF19202E),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF2B364D)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              bk['lawyerName'] ?? '',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Time: ${bk['bookingTime']}',
                              style: const TextStyle(color: Colors.white54, fontSize: 11),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.check_circle_outline, color: Colors.green, size: 12),
                                const SizedBox(width: 4),
                                Text(
                                  bk['status'].toString().toUpperCase(),
                                  style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 10),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // List of lawyers
              Expanded(
                child: _isLoadingLawyers
                    ? const Center(
                        child: CircularProgressIndicator(color: Color(0xFFE2B755)),
                      )
                    : filtered.isEmpty
                        ? const Center(
                            child: Text(
                              'No attorneys found matching your filter.',
                              style: TextStyle(color: Colors.white38),
                            ),
                          )
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (context, idx) {
                              final item = filtered[idx];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF131720),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFF262C3A)),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    CircleAvatar(
                                      radius: 30,
                                      backgroundColor: const Color(0xFF262C3A),
                                      child: Text(
                                        item['name']!.substring(0, 2),
                                        style: const TextStyle(
                                          color: Color(0xFFE2B755),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 20),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item['name']!,
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            item['specialty']!,
                                            style: const TextStyle(
                                              color: Color(0xFFE2B755),
                                              fontSize: 13,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Location: ${item['location']}',
                                            style: const TextStyle(
                                              color: Colors.white54,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.star, color: Color(0xFFE2B755), size: 16),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${item['rating']} (${item['consults']})',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          item['rate']!,
                                          style: const TextStyle(
                                            color: Colors.white54,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF1B2333),
                                            foregroundColor: Colors.white,
                                            side: const BorderSide(color: Color(0xFF333E56)),
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                          ),
                                          onPressed: () => _bookConsultation(item['name']!),
                                          child: const Text('Book Intro', style: TextStyle(fontSize: 12)),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ====================================================
// COMPONENT: PREMIUM FOOTER
// ====================================================
class PremiumFooter extends StatelessWidget {
  const PremiumFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final bool isMobile = width < 850;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF07090C),
        border: Border(top: BorderSide(color: Color(0xFF191F2B))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            children: [
              Flex(
                direction: isMobile ? Axis.vertical : Axis.horizontal,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: isMobile ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                children: [
                  // Logo / Pitch
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE2B755).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(
                              Icons.gavel_rounded,
                              color: Color(0xFFE2B755),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Legally',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Secure, AI-powered BNS regulatory insights.',
                        style: TextStyle(color: Colors.white38, fontSize: 13),
                      ),
                    ],
                  ),
                  if (isMobile) const SizedBox(height: 32),

                  // Links
                  Row(
                    children: [
                      _FooterLink(text: 'Privacy Policy', onTap: () {}),
                      const SizedBox(width: 24),
                      _FooterLink(text: 'Terms of Use', onTap: () {}),
                      const SizedBox(width: 24),
                      _FooterLink(text: 'Security Audits', onTap: () {}),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 40),
              const Divider(color: Color(0xFF191F2B)),
              const SizedBox(height: 24),

              // Disclaimer
              const Text(
                'Disclaimer: Legally is an automated artificial intelligence advisory platform trained on Bharatiya Nyaya Sanhita, 2023. It does not issue formal binding legal counsel, certification, or representation. All templates and data are provided for informational and drafting assistance purposes only. For binding disputes or court representation, please consult a certified attorney or legal professional in your jurisdiction.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white24,
                  fontSize: 11,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),

              // Copyright
              const Text(
                '© 2026 Legally Inc. All rights reserved.',
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FooterLink extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _FooterLink({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 13,
        ),
      ),
    );
  }
}

// ====================================================
// ANIMATION HELPERS & DYNAMIC SPLASH SCREEN
// ====================================================

class AnimatedSplashScreen extends StatefulWidget {
  const AnimatedSplashScreen({super.key});

  @override
  State<AnimatedSplashScreen> createState() => _AnimatedSplashScreenState();
}

class _AnimatedSplashScreenState extends State<AnimatedSplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<double> _textOpacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    _scaleAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutBack),
      ),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    _textOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 1.0, curve: Curves.easeIn),
      ),
    );

    _controller.forward();

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const AuthGate(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 600),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.2,
            colors: [
              Color(0xFF141924),
              Color(0xFF090B0F),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Opacity(
                    opacity: _opacityAnimation.value,
                    child: Transform.scale(
                      scale: _scaleAnimation.value,
                      child: child,
                    ),
                  );
                },
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE2B755).withOpacity(0.3),
                        blurRadius: 40,
                        spreadRadius: 5,
                      )
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(70),
                    child: Image.asset(
                      'assets/logo.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Opacity(
                    opacity: _textOpacityAnimation.value,
                    child: child,
                  );
                },
                child: const Column(
                  children: [
                    Text(
                      'LEGALLY',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4.0,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'AI-Powered Legal Intelligence',
                      style: TextStyle(
                        fontSize: 12,
                        letterSpacing: 1.5,
                        color: Color(0xFFE2B755),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FadeInSlide extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  const FadeInSlide({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 600),
    this.delay = Duration.zero,
  });

  @override
  State<FadeInSlide> createState() => _FadeInSlideState();
}

class _FadeInSlideState extends State<FadeInSlide> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<double> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _slide = Tween<double>(begin: 15.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutQuad),
    );

    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacity.value,
          child: Transform.translate(
            offset: Offset(0, _slide.value),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

class AnimatedCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  const AnimatedCard({super.key, required this.child, this.onTap});

  @override
  State<AnimatedCard> createState() => _AnimatedCardState();
}

class _AnimatedCardState extends State<AnimatedCard> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isPressed ? 0.97 : (_isHovered ? 1.02 : 1.0),
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeInOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              boxShadow: _isHovered
                  ? [
                      BoxShadow(
                        color: const Color(0xFFE2B755).withOpacity(0.12),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      )
                    ]
                  : [],
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

// ====================================================
// ADMIN PORTAL SCREEN: Users, Chats, and Bookings
// ====================================================

class AdminDashboardScreen extends StatefulWidget {
  final bool isDemoMode;
  final VoidCallback onLogout;
  const AdminDashboardScreen({
    super.key,
    required this.isDemoMode,
    required this.onLogout,
  });

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _currentTab = 0;
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _allBookings = [];
  bool _isLoadingUsers = true;
  bool _isLoadingBookings = true;
  String? _usersError;
  String? _bookingsError;

  // Real-time dynamic stats
  int _totalUsers = 0;
  int _totalQueries = 0;
  final int _activeTodayCount = 1;
  int _todaysQueriesCount = 0;
  Map<String, int> _categoryCounts = {};

  // Selection state for User Details
  Map<String, dynamic>? _selectedUser;
  List<Map<String, String>> _selectedUserChats = [];
  List<Map<String, dynamic>> _selectedUserBookings = [];
  bool _isLoadingUserDetails = false;

  // Chat Logs tab state
  // Each entry: {uid, email, query, reply, timestamp}
  List<Map<String, dynamic>> _allChatLogs = [];
  bool _isLoadingChatLogs = true;
  String _chatLogSearch = '';

  // References to global memory state for Demo Mode session persistence
  List<Map<String, dynamic>> get _mockUsers => _globalDemoUsers;
  List<Map<String, dynamic>> get _mockBookings => _globalDemoBookings;
  Map<String, List<Map<String, String>>> get _mockUserChats => _globalDemoUserChats;

  @override
  void initState() {
    super.initState();
    _syncAdminProfile();
    _fetchUsers();
    _fetchBookings();
    _fetchStats();
    _fetchAllChatLogs();
  }

  Future<void> _fetchAllChatLogs() async {
    setState(() => _isLoadingChatLogs = true);

    if (widget.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 300));
      final List<Map<String, dynamic>> logs = [];
      _globalDemoUserChats.forEach((uid, messages) {
        final user = _globalDemoUsers.firstWhere(
          (u) => u['uid'] == uid,
          orElse: () => {'email': uid},
        );
        // Pair messages: user message followed by ai message
        for (int i = 0; i + 1 < messages.length; i += 2) {
          logs.add({
            'uid': uid,
            'email': user['email'] ?? uid,
            'query': messages[i]['text'] ?? '',
            'reply': messages[i + 1]['text'] ?? '',
            'timestamp': '',
          });
        }
      });
      setState(() {
        _allChatLogs = logs;
        _isLoadingChatLogs = false;
      });
      return;
    }

    try {
      final chatsSnapshot = await FirebaseDatabase.instance.ref('chats').get();
      final List<Map<String, dynamic>> logs = [];

      if (chatsSnapshot.exists && chatsSnapshot.value is Map) {
        final Map<dynamic, dynamic> userChatsMap = chatsSnapshot.value as Map;
        for (final userKey in userChatsMap.keys) {
          final uid = userKey.toString();
          // Look up email from already-loaded users list
          final matchedUser = _users.firstWhere(
            (u) => u['uid'] == uid,
            orElse: () => {'email': uid},
          );
          final String email = matchedUser['email']?.toString() ?? uid;

          final userChatData = userChatsMap[userKey];
          Iterable<dynamic> msgValues = [];
          if (userChatData is Map) {
            final entries = (userChatData as Map<dynamic, dynamic>).entries.toList()
              ..sort((a, b) {
                final t1 = (a.value is Map ? (a.value as Map)['timestamp'] : null) ?? 0;
                final t2 = (b.value is Map ? (b.value as Map)['timestamp'] : null) ?? 0;
                return (t1 as Comparable).compareTo(t2);
              });
            msgValues = entries.map((e) => e.value);
          } else if (userChatData is List) {
            msgValues = (userChatData as List).whereType<Object>();
          }

          for (final msg in msgValues) {
            if (msg is Map) {
              final query = (msg['query'] ?? msg['message'] ?? msg['text'] ?? msg['userQuery'] ?? '').toString().trim();
              final reply = (msg['reply'] ?? msg['response'] ?? msg['aiResponse'] ?? '').toString().trim();
              if (query.isNotEmpty && reply.isNotEmpty) {
                // Format timestamp
                String tsStr = '';
                final dynamic rawTs = msg['timestamp'];
                if (rawTs != null) {
                  final ts = int.tryParse(rawTs.toString());
                  if (ts != null) {
                    final dt = DateTime.fromMillisecondsSinceEpoch(ts);
                    tsStr = '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                  }
                }
                logs.add({
                  'uid': uid,
                  'email': email,
                  'query': query,
                  'reply': reply,
                  'timestamp': tsStr,
                });
              }
            }
          }
        }
      }

      setState(() {
        _allChatLogs = logs;
        _isLoadingChatLogs = false;
      });
    } catch (e) {
      debugPrint('Failed to load all chat logs: $e');
      setState(() => _isLoadingChatLogs = false);
    }
  }

  Future<void> _syncAdminProfile() async {
    if (widget.isDemoMode) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseDatabase.instance.ref('users/${user.uid}').update({
          'email': user.email ?? 'admin@legally.com',
          'role': 'admin',
          'createdAt': ServerValue.timestamp,
        });
      } catch (e) {
        debugPrint("Failed to sync admin profile: $e");
      }
    }
  }

  Future<void> _fetchUsers() async {
    setState(() {
      _isLoadingUsers = true;
      _usersError = null;
    });

    if (widget.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 500));
      setState(() {
        _users = _mockUsers;
        _isLoadingUsers = false;
      });
      return;
    }

    try {
      final snapshot = await FirebaseDatabase.instance.ref('users').get();
      final List<Map<String, dynamic>> users = [];
      if (snapshot.exists && snapshot.value is Map) {
        final Map<dynamic, dynamic> values = snapshot.value as Map;
        for (var key in values.keys) {
          final data = values[key];
          if (data is Map) {
            users.add({'uid': key, ...Map<String, dynamic>.from(data)});
          }
        }
      }
      setState(() {
        _users = users;
        _isLoadingUsers = false;
      });
    } catch (e) {
      debugPrint("Failed to fetch users: $e");
      setState(() {
        _usersError = e.toString();
        _isLoadingUsers = false;
      });
    }
  }

  Future<void> _fetchBookings() async {
    setState(() {
      _isLoadingBookings = true;
      _bookingsError = null;
    });

    if (widget.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 400));
      setState(() {
        _allBookings = _mockBookings;
        _isLoadingBookings = false;
      });
      return;
    }

    try {
      final snapshot = await FirebaseDatabase.instance.ref('bookings').get();
      final List<Map<String, dynamic>> bookings = [];
      if (snapshot.exists && snapshot.value is Map) {
        final Map<dynamic, dynamic> values = snapshot.value as Map;
        for (var key in values.keys) {
          bookings.add({'id': key, ...Map<String, dynamic>.from(values[key] as Map)});
        }
        bookings.sort((a, b) {
          final t1 = a['createdAt'] ?? 0;
          final t2 = b['createdAt'] ?? 0;
          return t2.compareTo(t1);
        });
      }
      setState(() {
        _allBookings = bookings;
        _isLoadingBookings = false;
      });
    } catch (e) {
      debugPrint("Failed to fetch all bookings: $e");
      setState(() {
        _bookingsError = e.toString();
        _isLoadingBookings = false;
      });
    }
  }

  Future<void> _fetchStats() async {
    if (widget.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 300));
      setState(() {
        _totalUsers = _mockUsers.length;
        _totalQueries = 15;
        _todaysQueriesCount = 2;
        _categoryCounts = {'General': 10, 'Criminal': 3, 'Corporate': 2};
      });
      return;
    }

    try {
      final usersSnapshot = await FirebaseDatabase.instance.ref('users').get();
      int userCount = 0;
      if (usersSnapshot.exists && usersSnapshot.value is Map) {
        userCount = (usersSnapshot.value as Map).length;
      }

      final chatsSnapshot = await FirebaseDatabase.instance.ref('chats').get();
      int queryCount = 0;
      int todaysQueries = 0;
      final Map<String, int> categories = {};
      final nowStr = DateTime.now().toString().substring(0, 10);

      if (chatsSnapshot.exists && chatsSnapshot.value is Map) {
        final Map<dynamic, dynamic> userChatsMap = chatsSnapshot.value as Map;
        for (var userKey in userChatsMap.keys) {
          final userChatData = userChatsMap[userKey];
          if (userChatData is Map) {
            for (var msgKey in userChatData.keys) {
              queryCount++;
              final msg = userChatData[msgKey];
              if (msg is Map) {
                final String cat = msg['category']?.toString() ?? 'General';
                categories[cat] = (categories[cat] ?? 0) + 1;

                final dynamic rawTs = msg['timestamp'];
                if (rawTs != null) {
                  final double? ts = double.tryParse(rawTs.toString());
                  if (ts != null) {
                    final date = DateTime.fromMillisecondsSinceEpoch(ts.toInt());
                    if (date.toString().substring(0, 10) == nowStr) {
                      todaysQueries++;
                    }
                  }
                }
              }
            }
          }
        }
      }

      setState(() {
        _totalUsers = userCount;
        _totalQueries = queryCount;
        _todaysQueriesCount = todaysQueries;
        _categoryCounts = categories;
      });
    } catch (e) {
      debugPrint("Failed to fetch stats: $e");
    }
  }

  Future<void> _selectUser(Map<String, dynamic> user) async {
    setState(() {
      _selectedUser = user;
      _isLoadingUserDetails = true;
      _selectedUserChats = [];
      _selectedUserBookings = [];
    });

    final String uid = user['uid'] ?? '';

    if (widget.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 300));
      setState(() {
        _selectedUserChats = _mockUserChats[uid] ?? [];
        _selectedUserBookings = _mockBookings.where((b) => b['userEmail'] == user['email']).toList();
        _isLoadingUserDetails = false;
      });
      return;
    }

    try {
      final chatRef = FirebaseDatabase.instance.ref('chats/$uid');
      final chatSnapshot = await chatRef.get();

      final List<Map<String, String>> chats = [];

      // Firebase can return a Map (keyed by push ID) or a List (integer keys).
      Iterable<dynamic> chatValues = [];
      if (chatSnapshot.exists) {
        if (chatSnapshot.value is Map) {
          final rawMap = chatSnapshot.value as Map<dynamic, dynamic>;
          // Sort by timestamp ascending
          final sortedEntries = rawMap.entries.toList()
            ..sort((a, b) {
              final t1 = (a.value is Map ? (a.value as Map)['timestamp'] : null) ?? 0;
              final t2 = (b.value is Map ? (b.value as Map)['timestamp'] : null) ?? 0;
              return (t1 as Comparable).compareTo(t2);
            });
          chatValues = sortedEntries.map((e) => e.value);
        } else if (chatSnapshot.value is List) {
          chatValues = (chatSnapshot.value as List).whereType<Object>();
        }
      }

      for (final data in chatValues) {
        if (data is Map) {
          final userText = (data['query'] ?? data['message'] ?? data['text'] ?? data['userQuery'] ?? data['question'] ?? '').toString().trim();
          final aiText = (data['reply'] ?? data['response'] ?? data['aiResponse'] ?? data['answer'] ?? '').toString().trim();
          // Only add if both sides have content
          if (userText.isNotEmpty && aiText.isNotEmpty) {
            chats.add({'role': 'user', 'text': userText});
            chats.add({'role': 'ai', 'text': aiText});
          }
        }
      }

      // Fallback: if direct path was empty, try data already loaded in _allChatLogs
      // (handles Firebase Security Rules that block per-uid reads but allow full chats node reads)
      if (chats.isEmpty && _allChatLogs.isNotEmpty) {
        final fallbackLogs = _allChatLogs.where((log) => log['uid'] == uid).toList();
        for (final log in fallbackLogs) {
          final query = (log['query'] as String).trim();
          final reply = (log['reply'] as String).trim();
          if (query.isNotEmpty && reply.isNotEmpty) {
            chats.add({'role': 'user', 'text': query});
            chats.add({'role': 'ai', 'text': reply});
          }
        }
      }

      final bookingRef = FirebaseDatabase.instance.ref('bookings');
      final bookingSnapshot = await bookingRef.orderByChild('uid').equalTo(uid).get();

      final List<Map<String, dynamic>> userBookings = [];
      if (bookingSnapshot.exists && bookingSnapshot.value is Map) {
        final Map<dynamic, dynamic> values = bookingSnapshot.value as Map;
        for (var key in values.keys) {
          userBookings.add({'id': key, ...Map<String, dynamic>.from(values[key] as Map)});
        }
      }

      setState(() {
        _selectedUserChats = chats;
        _selectedUserBookings = userBookings;
        _isLoadingUserDetails = false;
      });
    } catch (e) {
      debugPrint("Failed to load details for user $uid: $e");
      // Even on error, try to show data from the already-loaded global chat logs
      final fallbackChats = <Map<String, String>>[];
      for (final log in _allChatLogs.where((l) => l['uid'] == uid)) {
        final query = (log['query'] as String).trim();
        final reply = (log['reply'] as String).trim();
        if (query.isNotEmpty && reply.isNotEmpty) {
          fallbackChats.add({'role': 'user', 'text': query});
          fallbackChats.add({'role': 'ai', 'text': reply});
        }
      }
      setState(() {
        _selectedUserChats = fallbackChats;
        _isLoadingUserDetails = false;
      });
    }
  }

  Future<void> _deleteUser(String uid, String email) async {
    final bool confirm = await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF131720),
            title: const Text('Confirm User Deletion'),
            content: Text('Are you sure you want to delete user $email? This action will permanently remove all profile records, advisory chats, and scheduled bookings.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete Permanently', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

    if (widget.isDemoMode) {
      setState(() {
        _globalDemoUsers.removeWhere((u) => u['uid'] == uid);
        _globalDemoUserChats.remove(uid);
        _globalDemoBookings.removeWhere((b) => b['userEmail'] == email);
        _selectedUser = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User $email deleted successfully (Demo Mode)')),
      );
      _fetchUsers();
      _fetchStats();
      return;
    }

    try {
      await FirebaseDatabase.instance.ref('users/$uid').remove();
      await FirebaseDatabase.instance.ref('chats/$uid').remove();
      final bookingsRef = FirebaseDatabase.instance.ref('bookings');
      final bookingsSnapshot = await bookingsRef.orderByChild('uid').equalTo(uid).get();
      if (bookingsSnapshot.exists && bookingsSnapshot.value is Map) {
        final Map<dynamic, dynamic> values = bookingsSnapshot.value as Map;
        for (var bookingId in values.keys) {
          await bookingsRef.child(bookingId).remove();
        }
      }

      setState(() {
        _selectedUser = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User $email deleted successfully from database!')),
      );

      _fetchUsers();
      _fetchStats();
      _fetchBookings();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete user: $e')),
      );
    }
  }

  Future<void> _editUserProfile(String uid, String currentName, String currentPhone) async {
    final nameController = TextEditingController(text: currentName);
    final phoneController = TextEditingController(text: currentPhone);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131720),
        title: const Text('Edit User Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Display Name',
                labelStyle: TextStyle(color: Colors.white54),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF222834))),
              ),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                labelStyle: TextStyle(color: Colors.white54),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF222834))),
              ),
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE2B755)),
            onPressed: () async {
              Navigator.pop(ctx);
              final newName = nameController.text.trim();
              final newPhone = phoneController.text.trim();

              if (widget.isDemoMode) {
                final idx = _globalDemoUsers.indexWhere((u) => u['uid'] == uid);
                if (idx != -1) {
                  setState(() {
                    _globalDemoUsers[idx]['displayName'] = newName;
                    _globalDemoUsers[idx]['phoneNumber'] = newPhone;
                    if (_selectedUser != null && _selectedUser!['uid'] == uid) {
                      _selectedUser!['displayName'] = newName;
                      _selectedUser!['phoneNumber'] = newPhone;
                    }
                  });
                }
                _fetchUsers();
                return;
              }

              try {
                await FirebaseDatabase.instance.ref('users/$uid').update({
                  'displayName': newName,
                  'phoneNumber': newPhone,
                });
                _fetchUsers();
                if (_selectedUser != null) {
                  setState(() {
                    _selectedUser!['displayName'] = newName;
                    _selectedUser!['phoneNumber'] = newPhone;
                  });
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Profile updated successfully!')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to update profile: $e')),
                );
              }
            },
            child: const Text('Save', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final bool isMobile = width < 850;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0D1017),
            border: Border(
              bottom: BorderSide(color: Color(0xFF222834), width: 1),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2B755).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.shield_rounded,
                      color: Color(0xFFE2B755),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Legally Admin',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        widget.isDemoMode ? 'Database: Offline Demo' : 'Database: Shared Realtime DB Live',
                        style: const TextStyle(fontSize: 10, color: Colors.white54),
                      )
                    ],
                  ),
                ],
              ),
              Row(
                children: [
                  TextButton(
                    onPressed: () {
                      _fetchUsers();
                      _fetchBookings();
                      _fetchStats();
                      if (_selectedUser != null) {
                        _selectUser(_selectedUser!);
                      }
                    },
                    child: const Row(
                      children: [
                        Icon(Icons.refresh, size: 16, color: Color(0xFFE2B755)),
                        SizedBox(width: 4),
                        Text('Sync', style: TextStyle(color: Color(0xFFE2B755))),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: widget.onLogout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B2333),
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFF333E56)),
                    ),
                    child: const Text('Log Out'),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
      bottomNavigationBar: isMobile
          ? BottomNavigationBar(
              currentIndex: _currentTab,
              onTap: (idx) => setState(() => _currentTab = idx),
              backgroundColor: const Color(0xFF0D1017),
              selectedItemColor: const Color(0xFFE2B755),
              unselectedItemColor: Colors.white60,
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Overview'),
                BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Users'),
                BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'Chat Logs'),
                BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: 'Bookings'),
              ],
            )
          : null,
      body: Row(
        children: [
          if (!isMobile)
            Container(
              width: 220,
              decoration: const BoxDecoration(
                color: Color(0xFF0D1017),
                border: Border(right: BorderSide(color: Color(0xFF222834))),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  _buildSidebarItem(0, 'Overview Dashboard', Icons.dashboard_outlined),
                  _buildSidebarItem(1, 'Users & Activity', Icons.people_outline),
                  _buildSidebarItem(2, 'Chat Logs', Icons.chat_bubble_outline_rounded),
                  _buildSidebarItem(3, 'Global Bookings', Icons.calendar_today_outlined),
                ],
              ),
            ),
          Expanded(
            child: switch (_currentTab) {
              0 => _buildOverviewTab(),
              1 => _buildUsersTab(isMobile),
              2 => _buildChatLogsTab(),
              3 => _buildBookingsTab(),
              _ => _buildOverviewTab(),
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(int index, String title, IconData icon) {
    final bool isActive = _currentTab == index;
    return InkWell(
      onTap: () => setState(() => _currentTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF181F2E) : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: isActive ? const Color(0xFFE2B755) : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isActive ? const Color(0xFFE2B755) : Colors.white60, size: 20),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.white70,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Admin Overview',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 6),
          const Text(
            'Summary stats and legal advisory queries aggregate.',
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 24),

          LayoutBuilder(
            builder: (context, constraints) {
              final double cardWidth = (constraints.maxWidth - 48) / (constraints.maxWidth > 750 ? 4 : 2);
              final bool useRow = constraints.maxWidth > 700;
              
              if (useRow) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatCard('Total Users', '$_totalUsers', '+1 active today', Icons.people_outline, cardWidth),
                    _buildStatCard('Total Queries', '$_totalQueries', '+0 today', Icons.chat_bubble_outline, cardWidth),
                    _buildStatCard('Active Today', '$_activeTodayCount', 'Users online', Icons.trending_up, cardWidth),
                    _buildStatCard("Today's Queries", '$_todaysQueriesCount', 'Questions asked', Icons.query_stats, cardWidth),
                  ],
                );
              } else {
                return Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildStatCard('Total Users', '$_totalUsers', '+1 active today', Icons.people_outline, (constraints.maxWidth - 12) / 2),
                        _buildStatCard('Total Queries', '$_totalQueries', '+0 today', Icons.chat_bubble_outline, (constraints.maxWidth - 12) / 2),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildStatCard('Active Today', '$_activeTodayCount', 'Users online', Icons.trending_up, (constraints.maxWidth - 12) / 2),
                        _buildStatCard("Today's Queries", '$_todaysQueriesCount', 'Questions asked', Icons.query_stats, (constraints.maxWidth - 12) / 2),
                      ],
                    ),
                  ],
                );
              }
            },
          ),

          const SizedBox(height: 32),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF131720),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF222834)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.bar_chart, color: Color(0xFFE2B755), size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Top Legal Categories',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Most queried legal topics in Realtime Database',
                  style: TextStyle(fontSize: 12, color: Colors.white54),
                ),
                const SizedBox(height: 24),
                _categoryCounts.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24.0),
                        child: Center(
                          child: Text('No categories recorded in database', style: TextStyle(color: Colors.white38)),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _categoryCounts.length,
                        itemBuilder: (context, index) {
                          final key = _categoryCounts.keys.elementAt(index);
                          final val = _categoryCounts[key] ?? 0;
                          final double percent = _totalQueries > 0 ? val / _totalQueries : 0.0;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.description_outlined, size: 14, color: Colors.white30),
                                        const SizedBox(width: 8),
                                        Text(key, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white70)),
                                      ],
                                    ),
                                    Text('$val', style: const TextStyle(color: Color(0xFFE2B755), fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: percent,
                                    minHeight: 8,
                                    backgroundColor: const Color(0xFF1F2533),
                                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFE2B755)),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String count, String subText, IconData icon, double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF131720),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF222834)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(title, style: const TextStyle(color: Colors.white54, fontSize: 13), overflow: TextOverflow.ellipsis)),
              Icon(icon, color: const Color(0xFFE2B755), size: 18),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            count,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 6),
          Text(subText, style: const TextStyle(color: Colors.white30, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildUsersTab(bool isMobile) {
    return Flex(
      direction: isMobile ? Axis.vertical : Axis.horizontal,
      children: [
        Expanded(
          flex: isMobile ? 1 : 2,
          child: Container(
            decoration: BoxDecoration(
              border: isMobile ? null : const Border(right: BorderSide(color: Color(0xFF222834))),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Registered Users',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _isLoadingUsers
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFFE2B755)))
                      : _usersError != null
                          ? Center(
                              child: SingleChildScrollView(
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Database Error:\n$_usersError',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                          : _users.isEmpty
                              ? const Center(child: Text('No users registered in database', style: TextStyle(color: Colors.white38)))
                              : ListView.builder(
                                  itemCount: _users.length,
                                  itemBuilder: (context, idx) {
                                    final user = _users[idx];
                                    final bool isSelected = _selectedUser != null && _selectedUser!['uid'] == user['uid'];
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 10.0),
                                      child: ListTile(
                                        tileColor: isSelected ? const Color(0xFF1B2333) : const Color(0xFF131720),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          side: BorderSide(color: isSelected ? const Color(0xFFE2B755) : const Color(0xFF222834)),
                                        ),
                                        title: Text(user['email'] ?? 'No Email', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                                        subtitle: Text(
                                          user['displayName'] != null ? 'Name: ${user['displayName']}' : 'UID: ${user['uid']?.toString().substring(0, 10)}...',
                                          style: const TextStyle(fontSize: 11, color: Colors.white38),
                                        ),
                                        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white30),
                                        onTap: () => _selectUser(user),
                                      ),
                                    );
                                  },
                                ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          flex: isMobile ? 1 : 3,
          child: Container(
            padding: const EdgeInsets.all(20),
            color: const Color(0xFF0A0D14),
            child: _selectedUser == null
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_pin_rounded, size: 64, color: Colors.white12),
                        SizedBox(height: 12),
                        Text('Select a user to view active database logs', style: TextStyle(color: Colors.white30)),
                      ],
                    ),
                  )
                : _isLoadingUserDetails
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFFE2B755)))
                    : SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'User Details',
                                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                                Row(
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: () => _editUserProfile(
                                        _selectedUser!['uid'] ?? '',
                                        _selectedUser!['displayName'] ?? '',
                                        _selectedUser!['phoneNumber'] ?? '',
                                      ),
                                      icon: const Icon(Icons.edit, size: 14, color: Color(0xFFE2B755)),
                                      label: const Text('Edit', style: TextStyle(color: Color(0xFFE2B755), fontSize: 12)),
                                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFE2B755))),
                                    ),
                                    const SizedBox(width: 8),
                                    OutlinedButton.icon(
                                      onPressed: () => _deleteUser(_selectedUser!['uid'] ?? '', _selectedUser!['email'] ?? ''),
                                      icon: const Icon(Icons.delete, size: 14, color: Colors.redAccent),
                                      label: const Text('Delete', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.redAccent)),
                                    ),
                                  ],
                                )
                              ],
                            ),
                            const SizedBox(height: 20),

                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF131720),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFF222834)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'User Information',
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFE2B755)),
                                  ),
                                  const Divider(color: Color(0xFF222834), height: 24),
                                  _buildUserDetailRow(Icons.email_outlined, 'Email Address', _selectedUser!['email'] ?? 'Not provided'),
                                  const SizedBox(height: 12),
                                  _buildUserDetailRow(Icons.person_outline, 'Display Name', _selectedUser!['displayName'] ?? 'Not provided'),
                                  const SizedBox(height: 12),
                                  _buildUserDetailRow(Icons.phone_outlined, 'Phone Number', _selectedUser!['phoneNumber'] ?? 'Not provided'),
                                  const SizedBox(height: 12),
                                  _buildUserDetailRow(
                                    Icons.calendar_today_outlined,
                                    'Account Created',
                                    _selectedUser!['createdAt'] != null ? _formatTimestamp(_selectedUser!['createdAt']) : 'Not provided',
                                  ),
                                ],
                              ),
                            ),

                            const Divider(color: Color(0xFF2D323E), height: 40),

                            Row(
                              children: [
                                const Text(
                                  'AI Advisory Chat Logs',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE2B755).withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${_selectedUserChats.length ~/ 2} sessions',
                                    style: const TextStyle(color: Color(0xFFE2B755), fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                )
                              ],
                            ),
                            const SizedBox(height: 16),
                            _selectedUserChats.isEmpty
                                ? Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'No chat logs found for this user via direct lookup.',
                                        style: TextStyle(color: Colors.white30, fontSize: 13),
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          OutlinedButton.icon(
                                            onPressed: () => _selectUser(_selectedUser!),
                                            icon: const Icon(Icons.refresh, size: 13, color: Color(0xFFE2B755)),
                                            label: const Text('Retry', style: TextStyle(color: Color(0xFFE2B755), fontSize: 12)),
                                            style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFE2B755))),
                                          ),
                                          const SizedBox(width: 8),
                                          OutlinedButton.icon(
                                            onPressed: () => setState(() => _currentTab = 2),
                                            icon: const Icon(Icons.open_in_new, size: 13, color: Colors.white38),
                                            label: const Text('View in Chat Logs tab', style: TextStyle(color: Colors.white54, fontSize: 12)),
                                            style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF333E56))),
                                          ),
                                        ],
                                      ),
                                    ],
                                  )
                                : ListView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: _selectedUserChats.length,
                                    itemBuilder: (context, idx) {
                                      final chat = _selectedUserChats[idx];
                                      final bool isUser = chat['role'] == 'user';
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                                        child: Column(
                                          crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              isUser ? 'Client Query:' : 'Legally AI Response:',
                                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isUser ? Colors.lightBlueAccent : const Color(0xFFE2B755)),
                                            ),
                                            const SizedBox(height: 4),
                                            Container(
                                              padding: const EdgeInsets.all(12),
                                              width: double.infinity,
                                              decoration: BoxDecoration(
                                                color: isUser ? const Color(0xFF182238) : const Color(0xFF141924),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: const Color(0xFF222B3E)),
                                              ),
                                              child: Text(chat['text'] ?? '', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                            ),
                                            const SizedBox(height: 8),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                          ],
                        ),
                      ),
          ),
        ),
      ],
    );
  }

  Widget _buildUserDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.white38),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
          ],
        )
      ],
    );
  }

  String _formatTimestamp(dynamic ts) {
    if (ts == null) return 'Not provided';
    try {
      final double? ms = double.tryParse(ts.toString());
      if (ms != null) {
        final date = DateTime.fromMillisecondsSinceEpoch(ms.toInt());
        return date.toString().substring(0, 16);
      }
    } catch (_) {}
    return ts.toString();
  }

  Widget _buildChatLogsTab() {
    final filtered = _chatLogSearch.trim().isEmpty
        ? _allChatLogs
        : _allChatLogs.where((log) {
            final q = _chatLogSearch.toLowerCase();
            return (log['email'] as String).toLowerCase().contains(q) ||
                (log['query'] as String).toLowerCase().contains(q) ||
                (log['reply'] as String).toLowerCase().contains(q);
          }).toList();

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'All Chat Logs',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFE2B755).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${filtered.length} conversations',
                  style: const TextStyle(color: Color(0xFFE2B755), fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () async {
                  await _fetchUsers();
                  await _fetchAllChatLogs();
                },
                icon: const Icon(Icons.refresh, size: 16, color: Color(0xFFE2B755)),
                label: const Text('Refresh', style: TextStyle(color: Color(0xFFE2B755))),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Search bar
          TextField(
            onChanged: (val) => setState(() => _chatLogSearch = val),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search by user email, question, or answer...',
              hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
              prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 18),
              filled: true,
              fillColor: const Color(0xFF131720),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF222834)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF222834)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoadingChatLogs
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFE2B755)))
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.chat_bubble_outline, color: Colors.white12, size: 56),
                            const SizedBox(height: 12),
                            Text(
                              _chatLogSearch.isEmpty
                                  ? 'No chat logs recorded in database yet.'
                                  : 'No results match "${_chatLogSearch}".',
                              style: const TextStyle(color: Colors.white30, fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, idx) {
                          final log = filtered[idx];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF131720),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF222834)),
                            ),
                            child: ExpansionTile(
                              tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              iconColor: const Color(0xFFE2B755),
                              collapsedIconColor: Colors.white38,
                              title: Row(
                                children: [
                                  const Icon(Icons.person_outline, size: 14, color: Color(0xFFE2B755)),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      log['email'] as String,
                                      style: const TextStyle(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w500),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(
                                  log['query'] as String,
                                  style: const TextStyle(fontSize: 12, color: Colors.white38),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if ((log['timestamp'] as String).isNotEmpty)
                                    Text(
                                      log['timestamp'] as String,
                                      style: const TextStyle(fontSize: 10, color: Colors.white30),
                                    ),
                                  const SizedBox(width: 8),
                                ],
                              ),
                              children: [
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF182238),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('CLIENT QUERY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.lightBlueAccent)),
                                      const SizedBox(height: 6),
                                      Text(log['query'] as String, style: const TextStyle(color: Colors.white, fontSize: 13)),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF141924),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFF222B3E)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('LEGALLY AI RESPONSE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFE2B755))),
                                      const SizedBox(height: 6),
                                      Text(log['reply'] as String, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingsTab() {

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Timeline of Global Consultations',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 6),
          const Text(
            'Monitor all booked lawyer appointments in real-time.',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _isLoadingBookings
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFE2B755)))
                : _bookingsError != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
                              const SizedBox(height: 12),
                              Text(
                                'Database Error:\n$_bookingsError',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _allBookings.isEmpty
                        ? const Center(child: Text('No bookings exist in database.', style: TextStyle(color: Colors.white38)))
                        : ListView.builder(
                            itemCount: _allBookings.length,
                            itemBuilder: (context, idx) {
                              final booking = _allBookings[idx];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF131720),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFF222834)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const CircleAvatar(
                                          backgroundColor: Color(0xFFE2B755),
                                          foregroundColor: Colors.black,
                                          child: Icon(Icons.gavel),
                                        ),
                                        const SizedBox(width: 16),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('Client: ${booking['userEmail'] ?? 'Unknown'}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Attorney: ${booking['lawyerName']} | Scheduled: ${booking['bookingTime']}',
                                              style: const TextStyle(fontSize: 12, color: Colors.white60),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'scheduled',
                                        style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
