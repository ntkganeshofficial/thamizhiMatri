import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/l10n.dart';
import '../widgets/language_toggle.dart';
import 'email_auth_screen.dart';
import 'phone_auth_screen.dart';

const _bg = Color(0xFFFAF5EF);
const _wine = Color(0xFF671B30);
const _gold = Color(0xFFC9A66B);
const _welcomePhoto = 'assets/images/hands_together.jpg';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) {
            // On very short screens fall back to scrolling instead of squeezing the photo away.
            final compact = c.maxHeight < 600;
            final column = Column(
              mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: _children(context, compact),
            );
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                  child: compact ? SingleChildScrollView(child: column) : column,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _children(BuildContext context, bool compact) {
    final ta = context.isTamil;
    return [
      const Align(alignment: Alignment.centerRight, child: LanguageToggle()),
      const SizedBox(height: 8),
      if (compact)
        const SizedBox(height: 230, child: _ArchPhoto())
      else
        const Expanded(child: _ArchPhoto()),
      const SizedBox(height: 8),
      Text(
        AppStrings.nameTamil,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: TamilFonts.display,
          fontSize: 32,
          color: _wine,
        ),
      ),
      Text(
        AppStrings.nameEnglish,
        textAlign: TextAlign.center,
        style: Fx.latin(TamilFonts.latinHeading, fontSize: 24, color: _wine),
      ),
      const SizedBox(height: 12),
      const _GoldDivider(),
      const SizedBox(height: 12),
      Text(
        AppStrings.taglineTamil,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: TamilFonts.accent,
          fontSize: 17,
          height: 1.4,
          color: Color(0xFF3A2A2E),
        ),
      ),
      if (!ta) ...[
        const SizedBox(height: 6),
        Text(
          AppStrings.taglineEnglish,
          textAlign: TextAlign.center,
          style: Fx.latin(
            TamilFonts.latinBody,
            fontSize: 13,
            height: 1.4,
            color: Colors.black54,
          ),
        ),
      ],
      const SizedBox(height: 18),
      FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: _wine,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PhoneAuthScreen()),
        ),
        icon: const Icon(Icons.smartphone_outlined),
        label: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            context.tr('Register / Login with Mobile OTP'),
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: _wine,
          backgroundColor: _bg,
          side: BorderSide(color: _gold.withValues(alpha: 0.6)),
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const EmailAuthScreen()),
        ),
        icon: const Icon(Icons.mail_outline),
        label: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            context.tr('Continue with Email'),
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ),
      const SizedBox(height: 12),
      const _Terms(),
    ];
  }
}

class _ArchPhoto extends StatelessWidget {
  const _ArchPhoto();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        const inset = 14.0;
        const heartSpace = 44.0; // the heart badge hangs below the arch
        final h = math.min(c.maxHeight - heartSpace, c.maxWidth / 1.19);
        if (h < 90) return const SizedBox.shrink();
        final w = h * 1.19;
        final gold = _gold.withValues(alpha: 0.8);
        final arch = SizedBox(
          width: w,
          height: h,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: gold),
                      left: BorderSide(color: gold),
                      right: BorderSide(color: gold),
                    ),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(w / 2),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: inset,
                right: inset,
                top: inset,
                bottom: 16,
                child: ClipRRect(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular((w - inset * 2) / 2),
                    bottom: const Radius.circular(10),
                  ),
                  child: Image.asset(
                    _welcomePhoto,
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    errorBuilder: (_, _, _) => Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFFF1E3CC), Color(0xFFD9B98A)],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -40,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: const BoxDecoration(
                      color: _bg,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: const BoxDecoration(
                        color: _wine,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.favorite_border,
                        color: _gold,
                        size: 34,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
        return Center(
          child: SizedBox(
            width: w,
            height: h + heartSpace,
            child: Align(alignment: Alignment.topCenter, child: arch),
          ),
        );
      },
    );
  }
}

class _GoldDivider extends StatelessWidget {
  const _GoldDivider();

  @override
  Widget build(BuildContext context) {
    final line = Container(width: 50, height: 1, color: _gold);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        line,
        const SizedBox(width: 10),
        Transform.rotate(
          angle: 0.785398,
          child: Container(width: 6, height: 6, color: _gold),
        ),
        const SizedBox(width: 10),
        line,
      ],
    );
  }
}

class _Terms extends StatelessWidget {
  const _Terms();

  @override
  Widget build(BuildContext context) {
    final ta = context.isTamil;
    final base = Fx.body(ta, fontSize: 12, height: 1.6, color: Colors.black54);
    final link = base.copyWith(
      color: _wine,
      decoration: TextDecoration.underline,
    );
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          TextSpan(text: '${context.tr('By continuing, you agree to our')}\n'),
          TextSpan(text: context.tr('Terms of Service'), style: link),
          TextSpan(text: ' ${context.tr('and')} '),
          TextSpan(text: context.tr('Privacy Policy'), style: link),
          TextSpan(text: ta ? ' ஏற்கிறீர்கள்.' : '.'),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}
