import 'package:flutter/material.dart';
import '../services/ai_service.dart';

class AIBotSheet extends StatefulWidget {
  const AIBotSheet({super.key});

  @override
  State<AIBotSheet> createState() => _AIBotSheetState();
}

class _AIBotSheetState extends State<AIBotSheet> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [];
  final AIService _aiService = AIService();
  bool _isTyping = false;

  void _sendQuery() async {
    if (_controller.text.isEmpty) return;
    String text = _controller.text;
    setState(() {
      _messages.add({"role": "user", "content": text});
      _isTyping = true;
    });
    _controller.clear();

    String response = await _aiService.getBotResponse(text);

    setState(() {
      _messages.add({"role": "bot", "content": response});
      _isTyping = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text("SportsVerse Assistant", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.teal[900])),
          const Divider(),
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (context, i) {
                bool isUser = _messages[i]['role'] == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.teal[100] : Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(_messages[i]['content']!),
                  ),
                );
              },
            ),
          ),
          if (_isTyping) const LinearProgressIndicator(),
          Row(
            children: [
              Expanded(child: TextField(controller: _controller, decoration: const InputDecoration(hintText: "Mark Rahul as present..."))),
              IconButton(onPressed: _sendQuery, icon: const Icon(Icons.send, color: Colors.teal)),
            ],
          )
        ],
      ),
    );
  }
}