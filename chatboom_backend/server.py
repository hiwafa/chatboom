from flask import Flask, request, jsonify
from flask_cors import CORS 
from livekit import api
import os
from dotenv import load_dotenv
import firebase_admin
from firebase_admin import auth

load_dotenv()

if not firebase_admin._apps:
    firebase_admin.initialize_app()

app = Flask(__name__)

CORS(app)

@app.route('/getToken', methods=['POST'])
def get_token():
    # Firebase Authorization Header
    auth_header = request.headers.get('Authorization')
    if not auth_header or not auth_header.startswith('Bearer '):
        return jsonify({'error': 'Unauthorized: Missing or invalid token'}), 401
    
    id_token = auth_header.split('Bearer ')[1]
    
    try:
        # token verification
        decoded_token = auth.verify_id_token(id_token)
        verified_uid = decoded_token['uid']
    except Exception as e:
        return jsonify({'error': f'Invalid token: {e}'}), 401

    data = request.json
    
    # Matching the UID
    if data.get('currentUserId') != verified_uid:
        return jsonify({'error': 'Forbidden: UID mismatch'}), 403

    import time
    receiver_id = data.get('receiverId', 'unknown')
    current_user_id = data.get('currentUserId', 'unknown')
    
    # Route the room name based on who we are calling
    if receiver_id == 'copilot_agent':
        room_name = f"copilot_{current_user_id}_{int(time.time())}"
    else:
        # Caller's ID to guarantee unique rooms
        room_name = f"agent_{receiver_id}_caller_{current_user_id}_{int(time.time())}"
    
    # Generate a secure WebRTC entry ticket
    token = api.AccessToken(os.getenv('LIVEKIT_API_KEY'), os.getenv('LIVEKIT_API_SECRET')) \
        .with_identity(current_user_id) \
        .with_name("User") \
        .with_grants(api.VideoGrants(room_join=True, room=room_name))
        
    return jsonify({
        'token': token.to_jwt(), 
        'url': os.getenv('LIVEKIT_URL')
    })

if __name__ == '__main__':
    print("🚀 Server running on port 8080")
    # Tell Flask to accept external network connections
    app.run(host='0.0.0.0', port=8080)