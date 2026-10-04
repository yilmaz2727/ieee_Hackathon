import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final _age = TextEditingController();

  List<Map<String, dynamic>> _savedUsers = [];

  String? _gender;
  String? _selectedUserId;

  bool _saving = false;
  bool _loadingUsers = true;

  bool get _isTr => AppLocalizations.instance.isTurkish;

  @override
  void initState() {
    super.initState();
    _loadSavedUsers();
  }

  Future<void> _loadSavedUsers() async {
    try {
      final users = await LocalDatabaseService.getAllUsers();

      if (!mounted) return;

      setState(() {
        _savedUsers = users;
        _loadingUsers = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() => _loadingUsers = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isTr
                ? 'Kayıtlı oyuncular yüklenemedi.'
                : 'Could not load saved players.',
          ),
        ),
      );
    }
  }

  void _selectSavedUser(String? userId) {
    if (userId == null) return;

    final user = _savedUsers.firstWhere((item) => item['id'] == userId);

    final age = (user['age'] as num?)?.toInt();
    final gender = user['gender'] as String?;

    const validGenders = {'female', 'male', 'other', 'prefer_not_to_say'};

    setState(() {
      _selectedUserId = userId;
      _nickname.text = user['nickname'] as String? ?? '';
      _age.text = age != null && age >= 4 ? '$age' : '';
      _gender = validGenders.contains(gender) ? gender : null;
    });
  }

  void _newPlayer() {
    FocusScope.of(context).unfocus();
    _formKey.currentState?.reset();

    setState(() {
      _selectedUserId = null;
      _nickname.clear();
      _age.clear();
      _gender = null;
    });
  }

  Future<void> _login() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() => _saving = true);

    try {
      await LocalDatabaseService.signInWithNickname(
        _nickname.text,
        age: int.parse(_age.text.trim()),
        gender: _gender!,
      );

      final prefs = widget.prefs ?? await SharedPreferences.getInstance();
      await prefs.reload();

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => StoryScreen(prefs: prefs)),
        (_) => false,
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isTr
                ? 'Hesabın kaydedilemedi. Lütfen tekrar dene.'
                : 'Could not save your account. Please try again.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  InputDecoration _decoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: ink),
      filled: true,
      fillColor: Colors.white70,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
    );
  }

  @override
  void dispose() {
    _nickname.dispose();
    _age.dispose();
    super.dispose();
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
              Image.asset('assets/images/samlar.png', fit: BoxFit.cover),
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
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      Text(
                        tr('home.title'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'StorySerif',
                          fontSize: 34,
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
                      const SizedBox(height: 16),
                      Image.asset(
                        'assets/images/esma.png',
                        height: 120,
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
                                    ? 'Maceradaki yerini al!'
                                    : 'Join the adventure!',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontFamily: 'StorySerif',
                                  fontSize: 23,
                                  fontWeight: FontWeight.bold,
                                  color: ink,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                _isTr
                                    ? 'Oyuncu adın, yaşın ve cinsiyet seçimin '
                                          'profilinde saklanır.'
                                    : 'Your nickname, age and gender choice '
                                          'are saved in your profile.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: ink,
                                  height: 1.5,
                                  fontSize: 12,
                                ),
                              ),
                              if (_loadingUsers) ...[
                                const SizedBox(height: 16),
                                const LinearProgressIndicator(),
                              ],
                              if (_savedUsers.isNotEmpty) ...[
                                const SizedBox(height: 20),
                                DropdownButtonFormField<String>(
                                  key: ValueKey('account_$_selectedUserId'),
                                  initialValue: _selectedUserId,
                                  isExpanded: true,
                                  decoration: _decoration(
                                    _isTr
                                        ? 'Kayıtlı oyuncunu seç'
                                        : 'Choose a saved player',
                                    Icons.manage_accounts_outlined,
                                  ),
                                  items: _savedUsers.map((user) {
                                    return DropdownMenuItem<String>(
                                      value: user['id'] as String,
                                      child: Text(
                                        user['nickname'] as String,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: _saving ? null : _selectSavedUser,
                                ),
                                TextButton.icon(
                                  onPressed: _saving ? null : _newPlayer,
                                  icon: const Icon(Icons.person_add_alt_1),
                                  label: Text(
                                    _isTr
                                        ? 'Yeni oyuncu oluştur'
                                        : 'Create a new player',
                                  ),
                                ),
                              ],
                              const SizedBox(height: 18),
                              TextFormField(
                                controller: _nickname,
                                enabled: !_saving,
                                // Kayıtlı hesap seçiliyken kimliğini değiştirme.
                                readOnly: _selectedUserId != null,
                                maxLength: 24,
                                autocorrect: false,
                                textInputAction: TextInputAction.next,
                                decoration: _decoration(
                                  _isTr ? 'Oyuncu adın' : 'Your nickname',
                                  Icons.person_outline,
                                ),
                                validator: (value) {
                                  final nick = value?.trim() ?? '';

                                  if (nick.length < 2 || nick.length > 24) {
                                    return _isTr
                                        ? '2–24 karakter arasında bir ad yaz.'
                                        : 'Use 2–24 characters.';
                                  }

                                  // Yeni hesap açarken mevcut nick'i ezme.
                                  if (_selectedUserId == null) {
                                    final taken = _savedUsers.any(
                                      (user) =>
                                          (user['nickname'] as String)
                                              .trim()
                                              .toLowerCase() ==
                                          nick.toLowerCase(),
                                    );

                                    if (taken) {
                                      return _isTr
                                          ? 'Bu ad kayıtlı. Yukarıdan hesabını seç.'
                                          : 'Already saved. Select this account above.';
                                    }
                                  }

                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _age,
                                enabled: !_saving,
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.done,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(3),
                                ],
                                decoration: _decoration(
                                  _isTr ? 'Yaşın' : 'Your age',
                                  Icons.cake_outlined,
                                ),
                                validator: (value) {
                                  final age = int.tryParse(value?.trim() ?? '');

                                  if (age == null || age < 4 || age > 120) {
                                    return _isTr
                                        ? '4–120 arasında geçerli bir yaş yaz.'
                                        : 'Enter a valid age from 4 to 120.';
                                  }

                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              DropdownButtonFormField<String>(
                                key: ValueKey(
                                  'gender_${_selectedUserId}_$_gender',
                                ),
                                initialValue: _gender,
                                isExpanded: true,
                                decoration: _decoration(
                                  _isTr ? 'Cinsiyet' : 'Gender',
                                  Icons.badge_outlined,
                                ),
                                items: [
                                  DropdownMenuItem(
                                    value: 'female',
                                    child: Text(
                                      _isTr ? 'Kız / Kadın' : 'Female',
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 'male',
                                    child: Text(_isTr ? 'Erkek' : 'Male'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'other',
                                    child: Text(_isTr ? 'Diğer' : 'Other'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'prefer_not_to_say',
                                    child: Text(
                                      _isTr
                                          ? 'Belirtmek istemiyorum'
                                          : 'Prefer not to say',
                                    ),
                                  ),
                                ],
                                onChanged: _saving
                                    ? null
                                    : (value) {
                                        setState(() => _gender = value);
                                      },
                                validator: (value) {
                                  if (value == null) {
                                    return _isTr
                                        ? 'Bir seçenek seç.'
                                        : 'Choose an option.';
                                  }

                                  return null;
                                },
                              ),
                              const SizedBox(height: 22),
                              StoryButton(
                                _selectedUserId != null
                                    ? (_isTr ? 'Hesabıma gir' : 'Sign in')
                                    : (_isTr
                                          ? 'Maceraya katıl'
                                          : 'Join the adventure'),
                                onPressed: _saving || _loadingUsers
                                    ? null
                                    : _login,
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
                        icon: const Icon(Icons.language, color: cream),
                        label: Text(
                          _isTr ? 'English' : 'Türkçe',
                          style: const TextStyle(color: cream),
                        ),
                      ),
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
}
