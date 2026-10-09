import 'package:flutter/material.dart';

import '../core/l10n.dart';
import '../services/translation_controller.dart';
import '../models/profile.dart';

class ProfileAvatar extends StatelessWidget {
  final Profile profile;
  final double radius;
  const ProfileAvatar({super.key, required this.profile, this.radius = 32});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey.shade300,
      backgroundImage: profile.photoUrl.isNotEmpty
          ? NetworkImage(
              profile.photoUrl,
              webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
            )
          : null,
      onBackgroundImageError: profile.photoUrl.isNotEmpty ? (_, _) {} : null,
      child: profile.photoUrl.isEmpty ? Icon(Icons.person, size: radius) : null,
    );
  }
}

class ProfileCard extends StatelessWidget {
  final Profile profile;
  final VoidCallback onTap;
  const ProfileCard({super.key, required this.profile, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              ProfileAvatar(profile: profile, radius: 38),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tx(profile.name),
                      style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${profile.age} ${context.tr('yrs')}, ${profile.heightCm} ${context.tr('cm')} • ${context.tr(profile.maritalStatus)}',
                    ),
                    Text(
                      '${context.tr(profile.education)} • ${context.tx(profile.occupation)}',
                    ),
                    Text(
                      '${context.tx(profile.city)}, ${context.tr(profile.country)}',
                      style: text.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
