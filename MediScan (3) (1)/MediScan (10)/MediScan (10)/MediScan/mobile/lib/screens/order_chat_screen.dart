import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class OrderChatScreen extends StatefulWidget {
  final String orderId;
  final String driverName;

  const OrderChatScreen({
    super.key,
    required this.orderId,
    required this.driverName,
  });

  @override
  State<OrderChatScreen> createState() => _OrderChatScreenState();
}

class _OrderChatScreenState extends State<OrderChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<dynamic> _messages = [];
  bool _isLoading = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetchMessages();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      _fetchMessages(isBackground: true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchMessages({bool isBackground = false}) async {
    final res = await ApiService.getOrderChat(widget.orderId);
    if (mounted && res['success'] == true) {
      final newMessages = res['data'] as List<dynamic>;
      
      bool isDifferent = _messages.length != newMessages.length;
      if (!isDifferent && _messages.isNotEmpty && newMessages.isNotEmpty) {
        isDifferent = _messages.last['message'] != newMessages.last['message'] ||
                      _messages.last['sender_role'] != newMessages.last['sender_role'];
      }

      if (!isDifferent) {
        if (!isBackground && _isLoading) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      setState(() {
        _messages = newMessages;
        if (!isBackground) _isLoading = false;
      });

      _scrollToBottom();
    } else if (mounted && !isBackground) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();

    // Optimistic UI update
    final tempMsg = {
      'message': text,
      'sender_role': 'user', // Temporary role
      'created_at': DateTime.now().toIso8601String(),
    };

    setState(() {
      _messages.add(tempMsg);
    });
    _scrollToBottom();

    final res = await ApiService.sendOrderMessage(widget.orderId, text);

    if (mounted) {
      if (res['success'] != true) {
        setState(() {
          _messages.removeWhere((m) => m['message'] == text && m['sender_role'] == 'user');
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Failed to send message')),
        );
        _messageController.text = text;
      } else {
        // Fetch to get exact DB timestamp/ID
        _fetchMessages(isBackground: true);
        
        // Proactive fast-polling loop for instant under 1-second responses
        Future.delayed(const Duration(milliseconds: 500), () => _fetchMessages(isBackground: true));
        Future.delayed(const Duration(milliseconds: 1000), () => _fetchMessages(isBackground: true));
        Future.delayed(const Duration(milliseconds: 1800), () => _fetchMessages(isBackground: true));
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const CircleAvatar(
              backgroundColor: Colors.white,
              radius: 18,
              child: Icon(Icons.delivery_dining, color: Colors.blue, size: 24),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.driverName,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Text(
                    "Delivery Driver",
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.normal,
                        color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(
                        child: Text(
                          "No messages yet.\nStart the conversation!",
                          textAlign: TextAlign.center,
                          style:
                              TextStyle(color: Colors.grey[500], fontSize: 16),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final isDriver = msg['sender_role'] == 'delivery';
                          return _buildMessageBubble(msg['message'], isDriver);
                        },
                      ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(String text, bool isDriver) {
    return Align(
      alignment: isDriver ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isDriver ? Colors.grey[200] : Colors.blue,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isDriver ? 0 : 16),
            bottomRight: Radius.circular(isDriver ? 16 : 0),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isDriver ? Colors.black87 : Colors.white,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _messageController,
                  decoration: const InputDecoration(
                    hintText: "Type a message...",
                    border: InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: const BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white),
                onPressed: _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
