import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../cleanup_verification/services/local_database_service.dart';
import '../../../../localization/app_localizations.dart';
import '../../../../main.dart';
import '../../../../ui/widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.prefs});

  final SharedPreferences? prefs;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nickname = TextEditingController();

  bool _saving = false;

  bool get _isTr => AppLocalizations.instance.isTurkish;

  @override
  void dispose() {
    _nickname.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;

    FocusScope.of(context).unfocus();
    setState(() => _saving = true);

    try {
      await LocalDatabaseService.signInWithNickname(_nickname.text);

      final prefs = widget.prefs ?? await SharedPreferences.getInstance();
      await prefs.reload();

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => StoryScreen(prefs: prefs),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isTr
                ? 'Giriş kaydedilemedi. Lütfen tekrar dene.'
                : 'Could not save your session. Please try again.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffe6eddf),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Oyunun ana menüsündeki görselle aynı.
              Image.asset(
                'assets/images/samlar.png',
                fit: BoxFit.cover,
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x55234331),
                      Color(0x11234331),
                      Color(0xBB234331),
                    ],
                  ),
                ),
              ),
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight:
                              (constraints.maxHeight - 48).clamp(0.0, double.infinity),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              tr('home.title'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: 'StorySerif',
                                fontSize: 36,
                                height: 1.15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xfffff4d6),
                                shadows: [
                                  Shadow(
                                    color: Colors.black54,
                                    blurRadius: 10,
                                    offset: Offset(0, 3),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            Image.asset(
                              'assets/images/esma.png',
                              height: 155,
                              fit: BoxFit.contain,
                            ),
                            const SizedBox(height: 12),
                            Paper(
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      _isTr
                                          ? 'Suyun koruyucusu olmaya hazır mısın?'
                                          : 'Ready to become a guardian of water?',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontFamily: 'StorySerif',
                                        fontSize: 21,
                                        fontWeight: FontWeight.bold,
                                        color: ink,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      _isTr
                                          ? 'Bir oyuncu adı seç. Maceran ve kazandığın rozet bu adla hatırlansın.'
                                          : 'Choose a nickname for your adventure and the badge you earn.',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: ink,
                                        height: 1.5,
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    TextFormField(
                                      controller: _nickname,
                                      enabled: !_saving,
                                      maxLength: 24,
                                      autocorrect: false,
                                      textInputAction: TextInputAction.done,
                                      onFieldSubmitted: (_) => _login(),
                                      style: const TextStyle(
                                        fontFamily: 'StorySans',
                                        color: ink,
                                      ),
                                      decoration: InputDecoration(
                                        labelText:
                                            _isTr ? 'Oyuncu adın' : 'Your nickname',
                                        prefixIcon:
                                            const Icon(Icons.person_outline),
                                        filled: true,
                                        fillColor: Colors.white70,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                      ),
                                      validator: (value) {
                                        final nick = value?.trim() ?? '';

                                        if (nick.length < 2 || nick.length > 24) {
                                          return _isTr
                                              ? '2–24 karakter arasında bir ad yaz.'
                                              : 'Use 2–24 characters.';
                                        }

                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 12),
                                    StoryButton(
                                      _isTr ? 'Maceraya katıl' : 'Join the adventure',
                                      onPressed: _saving ? null : _login,
                                      loading: _saving,
                                      icon: Icons.eco_outlined,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      _isTr
                                          ? 'Şifre gerekmez. Bu cihazda oturumun açık kalır.'
                                          : 'No password needed. You stay signed in on this device.',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: ink,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextButton.icon(
                              onPressed: _saving
                                  ? null
                                  : () async {
                                      await AppLocalizations.instance.setLanguage(
                                        _isTr ? 'en' : 'tr',
                                        prefs: widget.prefs,
                                      );

                                      if (mounted) setState(() {});
                                    },
                              icon: const Icon(
                                Icons.language,
                                color: cream,
                              ),
                              label: Text(
                                _isTr ? 'English' : 'Türkçe',
                                style: const TextStyle(color: cream),
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