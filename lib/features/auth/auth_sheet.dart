import '../../app_services.dart';
import '../../core/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui.dart';
import '../../data/errors.dart';
import '../../shared/widgets/feedback.dart';

/// Opens the login / register sheet; on success continues to the dashboard
/// (the web app's `#authModal` + redirect to `dashboard.html`).
Future<void> showAuthSheet(
  BuildContext context, {
  bool register = false,
}) async {
  final navigator = Navigator.of(context);
  final signedIn = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => AuthSheet(initialRegister: register),
  );
  if (signedIn == true) {
    await navigator.pushNamed(AppRoutes.dashboard);
  }
}

class AuthSheet extends StatefulWidget {
  const AuthSheet({super.key, this.initialRegister = false});

  final bool initialRegister;

  @override
  State<AuthSheet> createState() => _AuthSheetState();
}

class _AuthSheetState extends State<AuthSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  late bool _register = widget.initialRegister;
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = AppScope.of(context).auth;
    try {
      if (_register) {
        await auth.register(
          fullName: _name.text,
          email: _email.text,
          password: _password.text,
        );
      } else {
        await auth.signIn(email: _email.text, password: _password.text);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = friendlyAuthError(e);
      });
    }
  }

  void _switchMode(bool register) {
    setState(() {
      _register = register;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(22, 4, 22, 24 + inset),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _register ? 'Create your account' : 'Welcome back',
              style: AppText.heading(size: 24),
            ),
            const SizedBox(height: 4),
            Text(
              _register
                  ? 'Join Boundary to manage your club and score matches.'
                  : 'Sign in to open your club workspace.',
              style: AppText.muted(size: 13),
            ),
            const SizedBox(height: 18),
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: false, label: Text('Log in')),
                ButtonSegment(value: true, label: Text('Register')),
              ],
              selected: {_register},
              onSelectionChanged: (s) => _switchMode(s.first),
            ),
            const SizedBox(height: 18),
            if (_register) ...[
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                decoration: const InputDecoration(labelText: 'Full name'),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Enter your full name.' : null,
              ),
              const SizedBox(height: 12),
            ],
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(labelText: 'Email address'),
              validator: (v) {
                final value = (v ?? '').trim();
                if (value.isEmpty ||
                    !value.contains('@') ||
                    !value.contains('.')) {
                  return 'Enter a valid email address.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _password,
              obscureText: _obscure,
              textInputAction: TextInputAction.done,
              autofillHints: [
                _register ? AutofillHints.newPassword : AutofillHints.password,
              ],
              onFieldSubmitted: (_) => _busy ? null : _submit(),
              decoration: InputDecoration(
                labelText: 'Password',
                helperText: _register ? 'At least 6 characters.' : null,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure ? Icons.visibility_off : Icons.visibility,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) {
                final value = v ?? '';
                if (value.isEmpty) return 'Enter your password.';
                if (_register && value.length < 6) {
                  return 'Use at least 6 characters.';
                }
                return null;
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              NoticeBanner(_error!),
            ],
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: AppColors.onMint,
                      ),
                    )
                  : Text(_register ? 'Create account' : 'Log in'),
            ),
          ],
        ),
      ),
    );
  }
}
