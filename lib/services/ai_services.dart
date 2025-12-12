/* lib/services/ai_services.dart */
// Flutter-side AIService - talks to the backend above. Replace BACKEND_URL with your server address if not using env.
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ConversationContext {
  final String conversationId;
  final List<Map<String,String>> history;
  ConversationContext({required this.conversationId, this.history = const []});
}

class AIService {
  AIService._private();
  static final AIService instance = AIService._private();

  // Update if your backend runs on a different origin
  final String backend = const String.fromEnvironment('AI_BACKEND_URL', defaultValue: 'http://localhost:3000');

  Future<String> sendMessage(String message, ConversationContext ctx) async {
    final url = Uri.parse('$backend/api/chat');
    final body = {'message': message, 'context': ctx.history, 'conversationId': ctx.conversationId};
    final resp = await http.post(url, body: jsonEncode(body), headers: {'Content-Type':'application/json'});
    if (resp.statusCode == 200) {
      final j = jsonDecode(resp.body);
      return j['reply'] ?? j['text'] ?? '';
    }
    throw Exception('Chat error ${resp.statusCode}');
  }

  Future<List<dynamic>> generateQuiz(String syllabus, {int count = 10, String difficulty = 'medium'}) async {
    final url = Uri.parse('$backend/api/quiz/generate');
    final body = {'syllabusText': syllabus, 'count': count, 'difficulty': difficulty};
    final resp = await http.post(url, body: jsonEncode(body), headers: {'Content-Type':'application/json'});
    if (resp.statusCode == 200) {
      final j = jsonDecode(resp.body);
      if (j['ok'] == true) return j['quiz'] as List<dynamic>;
      throw Exception('Quiz error: ${j['error'] ?? 'unknown'}');
    }
    throw Exception('Quiz HTTP error ${resp.statusCode}');
  }

  Future<bool> uploadEmbedding(String id, List<double> vector, Map<String,dynamic> metadata) async {
    final url = Uri.parse('$backend/api/embeddings/upsert');
    final resp = await http.post(url, body: jsonEncode({'id': id, 'vector': vector, 'metadata': metadata}), headers: {'Content-Type':'application/json'});
    return resp.statusCode == 200;
  }

  Future<List<dynamic>> searchEmbeddings(List<double> qVector, {int topK=5}) async {
    final url = Uri.parse('$backend/api/embeddings/search');
    final resp = await http.post(url, body: jsonEncode({'qVector': qVector, 'topK': topK}), headers: {'Content-Type':'application/json'});
    if (resp.statusCode == 200) return jsonDecode(resp.body) as List<dynamic>;
    return [];
  }

  Future<String> uploadImageForOCR(Uint8List bytes) async {
    final url = Uri.parse('$backend/api/ocr');
    final req = http.MultipartRequest('POST', url);
    req.files.add(http.MultipartFile.fromBytes('file', bytes, filename: 'scan.jpg'));
    final streamed = await req.send();
    final resp = await http.Response.fromStream(streamed);
    if (resp.statusCode == 200) {
      final j = jsonDecode(resp.body);
      return j['text'] ?? '';
    }
    throw Exception('OCR failed ${resp.statusCode}');
  }
}
