from datetime import datetime
import json
import asyncio
import os
from dotenv import load_dotenv

# ensures the system ignores global terminal exports 
# and strictly uses the variables defined in your .env file.
load_dotenv(override=True)

# 2. Binds key.json strictly to the directory where this script lives.
cred_path = os.environ.get("GOOGLE_APPLICATION_CREDENTIALS", "key.json")
if cred_path and not os.path.isabs(cred_path):
    script_dir = os.path.dirname(os.path.abspath(__file__))
    os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = os.path.join(script_dir, cred_path)

# Extract variables to explicitly pass to the model constructor
GCP_PROJECT = os.environ.get("GOOGLE_CLOUD_PROJECT", "chatboom-f9a38")
GCP_LOCATION = os.environ.get("GOOGLE_CLOUD_LOCATION", "us-central1")

from livekit.agents import (
    cli,
    Agent,
    AgentSession,
    JobContext,
    JobRequest,
    RunContext,
    function_tool,
    WorkerOptions,
    AutoSubscribe,
)
from livekit.plugins import google, silero
from livekit import rtc

async def entrypoint(ctx: JobContext):
    # Auto-subscribe to audio only
    await ctx.connect(auto_subscribe=AutoSubscribe.AUDIO_ONLY)
    print("Connected to LiveKit room.")

    call_active = asyncio.Event()
    session_ready = asyncio.Event()

    model = google.realtime.RealtimeModel(
        model="gemini-live-2.5-flash-native-audio",
        voice="Puck",
        temperature=0.8,
        vertexai=True,
        project=GCP_PROJECT,
        location=GCP_LOCATION,
    )

    @function_tool
    async def save_summary(context: RunContext, summary_text: str, note_type: str = "Other"):
        """ONLY use this tool when explicitly commanded by the SYSTEM. DO NOT use this tool during normal conversation."""
        print(f"Sending summary: {summary_text}")
        await asyncio.sleep(3.0)
        await ctx.room.local_participant.publish_data(f"SUMMARY:{summary_text}".encode("utf-8"))
        call_active.set()

    @function_tool
    async def show_ui_buttons(context: RunContext, options: list[str]) -> str:
        """Shows maximum 5 interactive short, actionable buttons. 
        CRITICAL: You must finish your spoken sentence completely BEFORE calling this tool. Do not call this tool while you are still speaking."""
        
        if isinstance(options, str):
            options = [opt.strip() for opt in options.split(",")]
        elif not isinstance(options, list):
            options = []

        options = options[:5]
        options_str = "|".join(options)
        print(f"Sending UI options: {options_str}")

        await asyncio.sleep(2.0)
        await ctx.room.local_participant.publish_data(f"[UI:{options_str}]".encode("utf-8"))
        
        return "Success"

    agent = Agent(
        instructions="Please wait. System initializing...",
        tools=[save_summary, show_ui_buttons],
    )

    vad = silero.VAD.load(min_speech_duration=0.1, min_silence_duration=0.6)

    active_session = AgentSession(
        llm=model,
        vad=vad,
    )

    def set_voice(voice: str) -> None:
        try:
            # Try the modern SDK approach
            model.update_options(voice=voice)
        except AttributeError:
            # Fallback to direct mutation for older SDK versions
            try:
                active_session._llm.voice = voice
            except Exception as e:
                print(f"Voice fallback update failed: {e}")
        except Exception as e:
            print(f"Voice update failed: {e}")

    @active_session.on("user_started_speaking")
    def on_user_started_speaking():
        asyncio.create_task(ctx.room.local_participant.publish_data(b"CLEAR_TEXT"))

    @ctx.room.on("disconnected")
    def on_disconnected(*args):
        print("Room disconnected.")
        call_active.set()

    @ctx.room.on("data_received")
    def on_data_received(data_packet: rtc.DataPacket):
        text_data = data_packet.data.decode("utf-8")

        if text_data.startswith("INIT:"):
            async def process_init():
                try:
                    await session_ready.wait()

                    payload = json.loads(text_data[5:])
                    owner_name = payload.get("ownerName", "User")
                    caller_name = payload.get("callerName", "The Caller")
                    agent_prompt = payload.get("agentPrompt", "I am currently unavailable.")
                    recent_context = payload.get("recentContext", "")
                    agent_gender = payload.get("agentGender", "Female")

                    selected_voice = "Aoede" if agent_gender == "Female" else "Puck"
                    set_voice(selected_voice)

                    current_time_string = datetime.now().strftime("%A, %B %d, %Y at %I:%M %p")

                    system_prompt = f"""You are the strictly bound AI answering assistant for {owner_name}.

CURRENT REAL-WORLD TIME:
- Today is: {current_time_string}

YOUR ONLY PURPOSE:
- Answer this call on behalf of {owner_name}
- Follow the current STATUS
- Use the CHAT CONTEXT when necessary. It contains recent messages from {owner_name} and {caller_name}.

STATUS:
- "{agent_prompt}"

CHAT CONTEXT:
- "{recent_context}"

STRICT RULES:
1. Start the call exactly like this: "Hello, I am {owner_name}'s AI assistant."
2. If asked anything outside the STATUS, say: "I don't know, but I can take a note for them."
3. If they ask for "someone" or mispronounce the name, they mean {owner_name}.
4. Never agree to meetings, promises, or commitments. Check always the CURRENT REAL-WORLD TIME, so you know the current day and time.
5. PROACTIVELY use the `show_ui_buttons` tool to offer choices if the STATUS implies options (like available times, dates, or any options in STATUS).
6. SEQUENCING: When using `show_ui_buttons`, you MUST FIRST speak to introduce the options, FINISH your spoken sentence completely, and ONLY THEN execute the tool. 
7. DO NOT use the `save_summary` tool just because the user clicked a button. You must verify you have ALL necessary information (e.g., if they pick a time, ask for the day) before concluding.
8. ONLY use the `save_summary` tool when the caller explicitly says goodbye or you have 100% completed the goal.
9. SUMMARY FORMATTING: When you use `save_summary`, you MUST write the `summary_text` addressing {owner_name} directly as "you", and the caller as "{caller_name}". Example format: "{caller_name} called you ({owner_name}) and set a meeting for ..."
"""

                    await agent.update_instructions(system_prompt)

                    await active_session.generate_reply(
                        instructions=f"Introduce yourself exactly as instructed and ask how you can help based on the Status: {agent_prompt}"
                    )

                except Exception as e:
                    print(f"INIT handling failed: {e}")

            asyncio.create_task(process_init())

        elif text_data == "END_CALL":
            async def process_end_call():
                try:
                    await agent.update_instructions(
                        "SYSTEM COMMAND: THE CALL HAS ENDED. "
                        "You are now a strict data-processor. "
                        "You MUST immediately use the `save_summary` tool. "
                        "Do not output spoken text. Do not say goodbye."
                    )

                    await active_session.generate_reply(
                        instructions="The caller has hung up. Execute the save_summary tool immediately. Remember to strictly use the caller and owner names in the summary."
                    )

                    await asyncio.sleep(5)
                    if not call_active.is_set():
                        await ctx.room.local_participant.publish_data(
                            b"SUMMARY:Call ended. Notes unavailable."
                        )
                        call_active.set()

                except Exception as e:
                    print(f"END_CALL handling failed: {e}")
                    call_active.set()

            asyncio.create_task(process_end_call())

        elif text_data.startswith("UI_SELECT:"):
            user_choice = text_data.split(":", 1)[1]

            async def process_ui_selection():
                try:
                    # Tell the AI exactly how to handle the button click
                    await active_session.generate_reply(
                        instructions=f"The caller just tapped a button on their screen and selected: {user_choice}. Acknowledge this choice. If you still need more information, ask for it now. DO NOT end the call yet."
                    )
                except Exception as e:
                    print(f"UI selection handling failed for '{user_choice}': {e}")

            asyncio.create_task(process_ui_selection())

    async def start_engine():
        await active_session.start(agent=agent, room=ctx.room)
        session_ready.set()
        print("AI engine ready.")

    asyncio.create_task(start_engine())

    await call_active.wait()


async def request_fnc(req: JobRequest) -> None:
    # Only accept calls meant for the Answering Machine
    if req.room.name.startswith("agent_"):
        await req.accept()
    else:
        await req.reject()

if __name__ == "__main__":
    cli.run_app(WorkerOptions(
        entrypoint_fnc=entrypoint, 
        request_fnc=request_fnc
    ))