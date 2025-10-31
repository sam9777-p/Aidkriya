// lib/screens/chat_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // [NEW]
import 'package:flutter/material.dart';

import '../backend/walk_request_service.dart';

class ChatScreen extends StatefulWidget {
  final String walkId;
  final String partnerName; // The display name of the chat partner
  final String
  partnerId; // The ID of the person the Walker is chatting with (Wanderer)

  // New constructor to take all required data
  const ChatScreen({
    super.key,
    required this.walkId,
    required this.partnerId,
    required this.partnerName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final WalkRequestService _walkService = WalkRequestService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  // Get current user ID once and store it
  final String currentUserId =
      FirebaseAuth.instance.currentUser?.uid ?? 'unknown';

  void _sendMessage() {
    if (_messageController.text.trim().isNotEmpty) {
      _walkService.sendMessage(
        walkId: widget.walkId,
        senderId: currentUserId,
        text: _messageController.text.trim(),
      );
      _messageController.clear();

      // Scroll to bottom when a new message is sent (delayed slightly for rendering)
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  // Helper function to handle auto-scrolling on initial load/updates
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFf5f5f5),
        title: Text('Chat with ${widget.partnerName}'), // Use partner name
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _walkService.getWalkMessages(widget.walkId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error loading messages: ${snapshot.error}'),
                  );
                }

                final messages = snapshot.data ?? [];

                if (messages.isEmpty) {
                  return const Center(child: Text('Start the conversation!'));
                }

                // Scroll to bottom after the messages are built
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => _scrollToBottom(),
                );

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(10.0),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final bool isMe = message['senderId'] == currentUserId;

                    return Align(
                      alignment: isMe
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                          vertical: 5,
                          horizontal: 8,
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 15,
                        ),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ), // Limit width
                        decoration: BoxDecoration(
                          color: isMe
                              ? const Color(0xFF6BCBA6)
                              : Colors.grey[300],
                          borderRadius: BorderRadius.circular(16).copyWith(
                            topRight: isMe
                                ? const Radius.circular(4)
                                : const Radius.circular(16),
                            topLeft: isMe
                                ? const Radius.circular(16)
                                : const Radius.circular(4),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              message['text'] as String,
                              style: TextStyle(
                                color: isMe ? Colors.white : Colors.black,
                              ),
                            ),
                            if (message['timestamp'] is Timestamp)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(
                                  // Format time as HH:MM
                                  (message['timestamp'] as Timestamp)
                                      .toDate()
                                      .toString()
                                      .substring(11, 16),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isMe
                                        ? Colors.white70
                                        : Colors.black54,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Input area
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  mini: true,
                  backgroundColor: const Color(0xFF6BCBA6),
                  onPressed: _sendMessage,
                  child: const Icon(Icons.send, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
