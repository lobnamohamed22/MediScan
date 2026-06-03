class ChatbotService {
  Future<String> sendMessage(String userMessage) async {
    try {
      // For now, simulate API response
      await Future.delayed(const Duration(seconds: 1));

      // This would be replaced with actual API call
      // final response = await http.post(
      //   Uri.parse(_apiUrl),
      //   headers: {'Content-Type': 'application/json'},
      //   body: json.encode({'message': userMessage}),
      // );

      // if (response.statusCode == 200) {
      //   final data = json.decode(response.body);
      //   return data['response'];
      // }

      // Simulated responses based on keywords
      return _generateSimulatedResponse(userMessage);
    } catch (e) {
      return 'Sorry, I encountered an error. Please try again later.';
    }
  }

  String _generateSimulatedResponse(String message) {
    message = message.toLowerCase();

    if (message.contains('hello') || message.contains('hi')) {
      return 'Hello! I\'m MediScan AI Assistant. How can I help you with your medications today?';
    }

    if (message.contains('panadol') || message.contains('paracetamol')) {
      return 'Panadol (Paracetamol) is a pain reliever and fever reducer.\n\nCommon dosage: 500mg every 4-6 hours\nMaximum daily dose: 4000mg\n\nSide effects: Rare but may include rash, nausea, or liver damage if overdosed.\n\nInteractions: May interact with blood thinners. Consult your doctor if taking Warfarin.';
    }

    if (message.contains('amoxicillin')) {
      return 'Amoxicillin is an antibiotic used to treat bacterial infections.\n\nCommon dosage: 250mg-500mg every 8 hours\n\nImportant: Complete the full course even if you feel better.\n\nSide effects: Diarrhea, nausea, rash. Stop if severe allergic reaction occurs.\n\nDo not take with alcohol.';
    }

    if (message.contains('interaction') &&
        message.contains('panadol') &&
        message.contains('amoxicillin')) {
      return 'Panadol and Amoxicillin can generally be taken together, but:\n\n1. Space them 2 hours apart\n2. Take with food to reduce stomach upset\n3. Monitor for increased side effects\n\nAlways consult your doctor for personalized advice.';
    }

    if (message.contains('storage') || message.contains('store')) {
      return 'General medication storage guidelines:\n\n• Store at room temperature (15-30°C)\n• Keep away from moisture and sunlight\n• Some medications need refrigeration (check label)\n• Keep out of reach of children\n• Store in original container';
    }

    if (message.contains('expired') || message.contains('expiry')) {
      return 'Never use expired medications! Expired drugs may:\n\n• Lose effectiveness\n• Become toxic\n• Cause unexpected side effects\n\nProperly dispose of expired medications at a pharmacy disposal program.';
    }

    if (message.contains('alternative') || message.contains('substitute')) {
      return 'I can suggest alternatives based on:\n\n1. Active ingredient equivalents\n2. Different brands with same effect\n3. Therapeutic alternatives\n\nPlease specify which medication you need alternatives for, and I\'ll provide safe options.';
    }

    if (message.contains('emergency') || message.contains('urgent')) {
      return 'For medical emergencies:\n\n🚨 Call emergency services immediately\n🏥 Go to nearest emergency room\n💊 Contact poison control if overdose suspected\n\nDo not wait for AI response in emergencies!';
    }

    return 'Thank you for your message. I can help with:\n\n• Medication information and side effects\n• Drug interactions\n• Dosage instructions\n• Storage guidelines\n• Alternative suggestions\n\nPlease provide more specific details about your query.';
  }

  Future<List<String>> getQuickQuestions() async {
    return [
      'What are the side effects of Panadol?',
      'Can I take Amoxicillin with food?',
      'How to store medications properly?',
      'What are alternatives to Ibuprofen?',
      'Emergency contact for overdose',
    ];
  }
}
