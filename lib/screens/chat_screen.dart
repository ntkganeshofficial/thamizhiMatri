import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/l10n.dart';
import '../services/translation_controller.dart';
import '../models/profile.dart';
import '../services/activity_controller.dart';
import '../services/profile_service.dart';
import '../widgets/profile_card.dart';

class ChatScreen extends StatefulWidget {
  final Profile other;
  const ChatScreen({super.key, required this.other});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  late final Stream<List<ChatMessage>> _messages;

  @override
  void initState() {
    super.initState();
    final me = context.read<ActivityController>().me;
    _messages = context.read<ProfileService>().watchMessages(
      me.uid,
      widget.other.uid,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final me = context.read<ActivityController>().me;
    final service = context.read<ProfileService>();
    final failMsg = context.trRead('Could not send message');
    final messenger = ScaffoldMessenger.of(context);
    // Firestore queues the write while offline, so do not wait for the server before clearing the box.
    _controller.clear();
    service.sendMessage(me.uid, widget.other.uid, text).catchError((Object e) {
      messenger.showSnackBar(SnackBar(content: Text('$failMsg: $e')));
    });
  }

  @override
  Widget build(BuildContext context) {
    final me = context.read<ActivityController>().me;
    final ta = context.isTamil;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ProfileAvatar(profile: widget.other, radius: 16),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                context.tx(widget.other.name),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: _messages,
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        '${context.tr('Error')}: ${snap.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final messages = snap.data!.reversed.toList();
                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                      context.tr('Say hello to start the conversation'),
                    ),
                  );
                }
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (_, i) {
                    final m = messages[i];
                    final mine = m.senderUid == me.uid;
                    return Align(
                      alignment: mine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        decoration: BoxDecoration(
                          color: mine ? AppColors.maroon : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: mine
                              ? null
                              : Border.all(
                                  color: AppColors.gold.withValues(alpha: 0.5),
                                ),
                        ),
                        child: Text(
                          m.text,
                          style: Fx.body(
                            ta,
                            fontSize: 15,
                            color: mine ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: context.tr('Type a message'),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.maroon,
                    ),
                    onPressed: _send,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
