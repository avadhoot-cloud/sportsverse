import google.generativeai as genai
from django.conf import settings

# This pulls the key from your settings.py
# Go to https://aistudio.google.com/ to get your free key
genai.configure(api_key="AIzaSyDbiN-A2MheTeOgJ0paJgr_mUMQjb_NR0Y")

def add_attendance(student_name):
    # Logic to update your Attendance model
    return f"Done! I've marked {student_name} as present."

def add_payment(student_name, amount):
    # Logic to update your Payment model
    return f"Got it. Recorded a payment of {amount} for {student_name}."

# Define the model with tools
model = genai.GenerativeModel(
    model_name='gemini-1.5-flash', # Use this exact string
    tools=[add_attendance, add_payment]
)
def process_bot_request(user_text):
    chat = model.start_chat(enable_automatic_function_calling=True)
    response = chat.send_message(user_text)
    return response.text