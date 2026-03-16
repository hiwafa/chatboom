import json
from livekit.agents import function_tool, RunContext
from livekit import rtc

# STUDY MODE SYSTEM PROMPT
def get_study_prompt(user_name: str, current_topic: str = "Main Menu", saved_topics: list = []):
    topics_str = ", ".join(saved_topics) if saved_topics else "None yet."
    
    return f"""You are an expert AI Tutor for the user: {user_name}.
You are currently in STUDY MODE. 
Currently Active Deck: {current_topic} (If this says 'Main Menu', the user is looking at their list of decks and has not opened one yet).

THE USER'S SAVED DECKS: {topics_str}

STRICT RULES FOR CREATING CARDS:
1. NEVER use the `generate_flashcards` tool if the Currently Active Deck is 'Main Menu'. You must open a topic first.
2. If the user asks to create cards, FIRST check their SAVED DECKS.
   - If a saved deck matches (or is very similar to) their request, STOP and ASK: "You already have a '[Deck Name]' deck. Should I add these cards to it, or create a new one?"
   - If they say "Add to it", use the `open_or_create_topic` tool to open that exact deck, and THEN use the `generate_flashcards` tool.
   - If they say "Create a new one" (or if no similar deck exists), use `open_or_create_topic` with their new category name, and THEN use `generate_flashcards`.

GENERAL RULES:
3. You are a teacher. Be encouraging, clear, concise, and speak naturally in the user's preferred language.
4. STRICT PACING (CRITICAL): You must ONLY review ONE card at a time. 
   - First, read the FRONT of the card to the user, then STOP speaking and WAIT for them to guess the answer.
   - NEVER use the `flip_card` tool until the user makes a guess or explicitly asks for the answer.
   - After flipping and reading the back, STOP speaking and WAIT for the user to say "next" or "go back" before using the `next_card` or `prev_card` tool.
   - NEVER call `next_card`, `prev_card`, or `flip_card` multiple times in a single turn.
   - NEVER go to specific card.

5. If the user says "I'm done" or "Exit study mode", use the `exit_study_mode` tool.
6. FOCUS LIMITATION: You do not have the tools to open chats, read notes, or check the calendar while in Study Mode. If the user explicitly requests to do one of those things, you MUST use the `exit_study_mode` tool first to return to your general assistant mode, and tell the user you are switching gears to help them with that.
"""

# STUDY MODE TOOLS 
def get_study_tools(room: rtc.Room):
    
    @function_tool
    async def open_or_create_topic(context: RunContext, topic_name: str):
        """
        Use this to open an existing study deck or create a new one. Pass the exact name of the topic.
        CRITICAL RULE: If the user asks to "open", "read", "review", or "explain" an EXISTING deck, ONLY use this tool. DO NOT use the `generate_flashcards` tool unless they explicitly ask you to "create", "make", or "add" NEW cards.
        """
        print(f"Study Command: Open/Create Topic -> {topic_name}")
        payload = json.dumps({"command": "study_start_topic", "topic": topic_name})
        await room.local_participant.publish_data(payload.encode("utf-8"))
        return f"Successfully opened {topic_name}. You are now looking at card 1. Wait for the user's instructions."

    @function_tool
    async def generate_flashcards(context: RunContext, topic: str, count: int, front_label: str, back_label: str, cards_json_string: str):
        """
        Use this to generate educational flashcards. 
        You MUST provide the cards as a STRICTLY VALID JSON string.
        The JSON MUST exactly match this array of objects format:
        [
          {
            "front": {
              "word": "Main term, concept, or story title",
              "sentence": "Example sentence or detailed description"
            },
            "back": {
              "first_meaning": "Primary translation or main answer",
              "first_sentence_meaning": "Translation of the sentence or further context",
              "second_meaning": "Secondary translation/language (if applicable)",
              "second_sentence_meaning": "Secondary sentence translation (if applicable)"
            }
          }
        ]
        CRITICAL RULES:
        1. Never deviate from this exact schema. Do not use markdown blocks.
        2. If a field is not applicable (e.g., it's a story, or only 1 language was requested), you MUST use an empty string "" for that field. Do not write "none" or "not provided".
        3. MAX CARD LIMIT: You must NEVER generate more than 10 cards in a single request to maintain fast performance. If the user asks for more than 10 (e.g., 50), generate exactly 10, and politely tell the user out loud: "I generated the first 10 cards for you. Let me know when you are ready for the next batch!"
        4. TEXT LENGTH LIMIT: Flashcard screens have limited physical space. If the user asks for a story or long explanation, keep the `front.sentence` field strictly under 5 sentences. This is CRITICAL if the user asks for multiple translations, as each additional language takes up more screen space. Do not write massive paragraphs.
        """
        print(f"Study Command: Generate {count} cards for {topic}")

        try:
            parsed_cards = json.loads(cards_json_string)
        except json.JSONDecodeError as e:
            print(f"⚠️ JSON Typo caught: {e}")
            return "Error: You made a syntax typo in the JSON string (missing quotes or brackets). Please fix the JSON formatting and call this tool again."
        
        payload = json.dumps({
            "command": "study_generate_cards", 
            "topic": topic,
            "frontLabel": front_label,
            "backLabel": back_label,
            "cards": parsed_cards
        })
        await room.local_participant.publish_data(payload.encode("utf-8"))
        return "Flashcards generated and sent to the screen. Ask the user if they are ready to start reviewing."

    @function_tool
    async def flip_card(context: RunContext):
        """Use this to flip the current flashcard to reveal the answer on the user's screen."""
        print("Study Command: Flip Card")
        payload = json.dumps({"command": "study_flip_card"})
        await room.local_participant.publish_data(payload.encode("utf-8"))
        return "Card flipped."

    @function_tool
    async def next_card(context: RunContext):
        """Use this to move to the next flashcard in the deck."""
        print("Study Command: Next Card")
        payload = json.dumps({"command": "study_next_card"})
        await room.local_participant.publish_data(payload.encode("utf-8"))
        return "Moved to the next card. Read the front of it to the user."
    
    @function_tool
    async def prev_card(context: RunContext):
        """Use this to move backward to the previous flashcard in the deck."""
        print("Study Command: Prev Card")
        payload = json.dumps({"command": "study_prev_card"})
        await room.local_participant.publish_data(payload.encode("utf-8"))
        return "Moved to the previous card. Read the front of it to the user."

    @function_tool
    async def exit_study_mode(context: RunContext):
        """Use this when the user wants to stop studying and return to the normal app."""
        print("Study Command: Exit Study Mode")
        payload = json.dumps({"command": "exit_study_mode"})
        await room.local_participant.publish_data(payload.encode("utf-8"))
        return "Exiting study mode. Say goodbye to the student."

    return [open_or_create_topic, generate_flashcards, flip_card, next_card, prev_card, exit_study_mode]