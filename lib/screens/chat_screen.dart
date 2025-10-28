// import 'package:flutter/material.dart';
// import '../backend/walk_request_service.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
//
// class ChatScreen extends StatefulWidget {
//   final String walkId;
//   final String partnerId; // The ID of the person the Walker is chatting with (Wanderer)
//   // final String currentUserId = 'your_current_user_id'; // Passed in or fetched from Auth
//
//   ChatScreen({required this.walkId, required this.partnerId});
//
//   @override
//   State<ChatScreen> createState() => _ChatScreenState();
// }
//
// class _ChatScreenState extends State<ChatScreen> {
//   final WalkRequestService _walkService = WalkRequestService();
//   final TextEditingController _messageController = TextEditingController();
//   final ScrollController _scrollController = ScrollController();
//   final String currentUserId = 'your_current_user_id'; // TODO: Get actual user ID
//
//   void _sendMessage() {
//     if (_messageController.text.trim().isNotEmpty) {
//       _walkService.sendMessage(
//         walkId: widget.walkId,
//         senderId: currentUserId,
//         text: _messageController.text.trim(),
//       );
//       _messageController.clear();
//       // Scroll to bottom when a new message is sent
//       _scrollController.animateTo(
//         _scrollController.position.maxScrollExtent,
//         duration: const Duration(milliseconds: 300),
//         curve: Curves.easeOut,
//       );
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     // TODO: Fetch partner's name for the AppBar title
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Chat with Wanderer'),
//       ),
//       body: Column(
//         children: <Widget>[
//           Expanded(
//             child: StreamBuilder<List<Map<String, dynamic>>>(
//               stream: _walkService.getWalkMessages(widget.walkId),
//               builder: (context, snapshot) {
//                 if (snapshot.connectionState == ConnectionState.waiting) {
//                   return const Center(child: CircularProgressIndicator());
//                 }
//                 if (!snapshot.hasData || snapshot.data!.isEmpty) {
//                   return const Center(child: Text('Start the conversation!'));
//                 }
//
//                 WidgetsBinding.instance.addPostFrameCallback((_) {
//                   // Ensure we scroll to the bottom after the stream updates
//                   if (_scrollController.hasClients) {
//                     _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
//                   }
//                 });
//
//                 final messages = snapshot.data!;
//                 return ListView.builder(
//                   controller: _scrollController,
//                   padding: const EdgeInsets.all(10.0),
//                   itemCount: messages.length,
//                   itemBuilder: (context, index) {
//                     final message = messages[index];
//                     final bool isMe = message['senderId'] == currentUserId;
//
//                     return Align(
//                       alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
//                       child: Container(
//                         margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
//                         padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
//                         decoration: BoxDecoration(
//                           color: isMe ? Colors.blueAccent : Colors.grey[300],
//                           borderRadius: BorderRadius.circular(20),
//                         ),
//                         child: Text(
//                           message['text'] as String,
//                           style: TextStyle(color: isMe ? Colors.white : Colors.black),
//                         ),
//                       ),
//                     );
//                   },
//                 );
//               },
//             ),
//           ),
//           Padding(
//             padding: const EdgeInsets.all(8.0),
//             child: Row(
//               children: <Widget>[
//                 Expanded(
//                   child: TextField(
//                     controller: _messageController,
//                     decoration: InputDecoration(
//                       hintText: 'Type a message...',
//                       border: OutlineInputBorder(borderRadius: BorderRadius.circular(25)),
//                       contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
//                     ),
//                   ),
//                 ),
//                 IconButton(
//                   icon: const Icon(Icons.send, color: Colors.blue),
//                   onPressed: _sendMessage,
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }