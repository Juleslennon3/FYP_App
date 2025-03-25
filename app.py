import base64
import logging
import os
from datetime import datetime
from urllib.parse import unquote
from datetime import datetime, timedelta
from flask_apscheduler import APScheduler
from datetime import datetime
import requests

import firebase_admin
import requests
import mysql.connector
from apscheduler.schedulers.background import BackgroundScheduler
from firebase_admin import credentials, messaging
from flask import Flask, request, jsonify
from flask_migrate import Migrate
from flask_sqlalchemy import SQLAlchemy
from google.auth.transport.requests import Request
from google.oauth2 import service_account
from mysql.connector import IntegrityError
from sqlalchemy import func
from sqlalchemy.testing.pickleable import Parent
from werkzeug.security import generate_password_hash, check_password_hash
from flask_mysqldb import MySQL
from flask import Flask, request, jsonify
from flask_mysqldb import MySQL
from google.oauth2 import service_account
import google.auth.transport.requests
from sqlalchemy.sql import text


if not firebase_admin._apps:
    cred = credentials.Certificate(r"C:\Users\jules\PycharmProjects\flaskFYP\serviceAccountKey.json")  # ✅ Ensure this file exists!
    firebase_admin.initialize_app(cred)
app = Flask(__name__)
app.config['SQLALCHEMY_DATABASE_URI'] = 'mysql+mysqlconnector://root:1FootballFan!!@localhost/FYP'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
db = SQLAlchemy(app)
migrate = Migrate(app, db)


# User model
class User(db.Model):
    __tablename__ = 'users'
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(80), nullable=False)
    email = db.Column(db.String(120), unique=True, nullable=False)
    password = db.Column(db.String(255), nullable=False)
    fcm_token = db.Column(db.String(255), nullable=True)

    # One-to-one relationship with the Child model
    child = db.relationship('Child', backref='guardian', uselist=False)


# Child model
class Child(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(80), nullable=False)
    age = db.Column(db.Integer, nullable=False)
    guardian_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    fitbit_access_token = db.Column(db.Text, nullable=True)
    fitbit_refresh_token = db.Column(db.Text, nullable=True)
    token_expires_in = db.Column(db.Integer, nullable=True)


# FitbitData model to store the required Fitbit data
class FitbitData(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    child_id = db.Column(db.Integer, nullable=False)
    data = db.Column(db.JSON, nullable=False)  # JSON, not JSONB
    timestamp = db.Column(db.DateTime, default=datetime.utcnow)

    def __init__(self, child_id, data):
        self.child_id = child_id
        self.data = data

from flask_sqlalchemy import SQLAlchemy
from datetime import datetime



class StressEvent(db.Model):
    __tablename__ = 'stress_event'

    id = db.Column(db.Integer, primary_key=True)
    child_id = db.Column(db.Integer, db.ForeignKey('child.id'), nullable=False)
    trigger = db.Column(db.String(255))  # Optional: what triggered the stress
    timestamp = db.Column(db.DateTime, default=datetime.utcnow)

    interventions = db.relationship('Intervention', backref='stress_event', lazy=True)

    def to_dict(self):
        return {
            "id": self.id,
            "child_id": self.child_id,
            "trigger": self.trigger,
            "timestamp": self.timestamp.strftime("%Y-%m-%d %H:%M:%S"),
            "interventions": [i.to_dict() for i in self.interventions]
        }


class Intervention(db.Model):
    __tablename__ = 'intervention'

    id = db.Column(db.Integer, primary_key=True)
    stress_event_id = db.Column(db.Integer, db.ForeignKey('stress_event.id'), nullable=False)
    intervention_type = db.Column(db.String(100))
    description = db.Column(db.Text)
    resolved_at = db.Column(db.DateTime, default=datetime.utcnow)

    def to_dict(self):
        return {
            "id": self.id,
            "stress_event_id": self.stress_event_id,
            "intervention_type": self.intervention_type,
            "description": self.description,
            "resolved_at": self.resolved_at.strftime("%Y-%m-%d %H:%M:%S"),
        }


class CalendarEntry(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    child_id = db.Column(db.Integer, db.ForeignKey('child.id'), nullable=False)
    activity_name = db.Column(db.String(255), nullable=False)
    start_time = db.Column(db.DateTime, nullable=False)
    end_time = db.Column(db.DateTime, nullable=False)
    activity_notes = db.Column(db.String(255), nullable=True)
    category = db.Column(db.Enum('Activity', 'Food', 'Social', name='category_enum'), nullable=False,
                         default='Activity')

    def __init__(self, child_id, activity_name, start_time, end_time, activity_notes=None, category='Activity'):
        self.child_id = child_id
        self.activity_name = activity_name
        self.start_time = start_time
        self.end_time = end_time
        self.activity_notes = activity_notes
        self.category = category

class StressScoreLog(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    child_id = db.Column(db.Integer, db.ForeignKey('child.id'), nullable=False)
    stress_score = db.Column(db.Float, nullable=False)
    timestamp = db.Column(db.DateTime, default=datetime.utcnow)

    child = db.relationship("Child", backref=db.backref("stress_scores", lazy=True))

class DeviceToken(db.Model):
    __tablename__ = "device_tokens"

    id = db.Column(db.Integer, primary_key=True)
    parent_id = db.Column(db.String(255), nullable=False)
    token = db.Column(db.Text, unique=True, nullable=False)
    created_at = db.Column(db.TIMESTAMP, server_default=db.func.current_timestamp())



    with app.app_context():
        db.create_all()


@app.route('/favicon.ico')
def favicon():
    return '', 204  # Return a 204 No Content response


# Register route
@app.route('/register', methods=['POST'])
def register():
    try:
        data = request.get_json()
        name = data.get('name')
        email = data.get('email')
        password = data.get('password')

        if not name or not email or not password:
            return jsonify({'message': 'Name, email, and password are required'}), 400

        hashed_password = generate_password_hash(password)
        new_user = User(name=name, email=email, password=hashed_password)

        db.session.add(new_user)
        db.session.commit()

        return jsonify({
            'message': 'User registered successfully',
            'user_id': new_user.id  # Return the user ID for adding child data
        }), 201

    except Exception as e:
        print(f"Error during registration: {e}")
        return jsonify({'message': 'Registration failed', 'error': str(e)}), 500


# Login route
from werkzeug.security import check_password_hash

@app.route('/login', methods=['POST'])
def login():
    try:
        data = request.get_json()
        email = data.get('email')
        password = data.get('password')

        # ✅ Query users instead of Parent
        user = User.query.filter_by(email=email).first()

        if not user or not check_password_hash(user.password, password):
            return jsonify({'message': 'Invalid credentials'}), 401

        # ✅ Log the guardian ID before querying child
        guardian_id = user.id
        print(f"🔍 Guardian ID for user {email}: {guardian_id}")

        # ✅ Find a child where guardian_id matches the user's ID
        child = Child.query.filter_by(guardian_id=guardian_id).first()

        if not child:
            print(f"❌ No child found for guardian_id {guardian_id}")
            return jsonify({'message': 'No child linked to this account'}), 404

        # ✅ Get the FCM token for the parent (correctly using `users.id`)
        device_token = DeviceToken.query.filter_by(parent_id=user.id).first()

        return jsonify({
            'user_id': user.id,
            'guardian_id': user.id,  # ✅ Now properly linked
            'child_id': child.id,
            'token': device_token.token if device_token else None
        }), 200

    except Exception as e:
        print(f"❌ Error during login: {e}")
        return jsonify({'error': 'Internal Server Error'}), 500

# User email lookup route
@app.route('/user/email/<string:email>', methods=['GET'])
def get_user_by_email(email):
    user = User.query.filter_by(email=email).first()
    if user:
        return jsonify({
            'id': user.id,
            'name': user.name,
            'email': user.email
        }), 200
    else:
        return jsonify({'message': 'User not found'}), 404


@app.route('/profile', methods=['GET'])
def profile():
    user_id = request.args.get('user_id')
    print(f"Received user_id: {user_id}")

    if not user_id:
        print("No user ID provided")
        return jsonify({'message': 'User ID not provided'}), 400

    user = User.query.get(user_id)
    if not user:
        print(f"User with ID {user_id} not found")
        return jsonify({'message': 'User not found'}), 404

    print(f"User found: {user.name}, {user.email}")
    return jsonify({
        'name': user.name,
        'email': user.email,
    }), 200


@app.route('/add_child', methods=['POST'])
def add_child():
    try:
        data = request.get_json()
        guardian_id = data.get('guardian_id')  # Parent's user ID
        name = data.get('name')
        age = data.get('age')

        # Validate inputs
        if not guardian_id or not name or not age:
            return jsonify({'message': 'Guardian ID, name, and age are required'}), 400

        # Check if guardian exists
        guardian = User.query.get(guardian_id)
        if not guardian:
            return jsonify({'message': 'Guardian not found'}), 404

        # Add child to the database
        new_child = Child(
            name=name,
            age=age,
            guardian_id=guardian_id
        )
        db.session.add(new_child)
        db.session.commit()

        return jsonify({'message': 'Child added successfully', 'child_id': new_child.id}), 201

    except Exception as e:
        print(f"Error adding child: {e}")
        return jsonify({'message': 'Failed to add child', 'error': str(e)}), 500


# View child route
@app.route('/view_child/<guardian_id>', methods=['GET'])
def view_child(guardian_id):
    # Decode and sanitize the input
    clean_guardian_id = int(unquote(guardian_id).strip())
    print(f"Cleaned guardian_id: {clean_guardian_id}")

    # Query the database
    child = Child.query.filter_by(guardian_id=clean_guardian_id).first()
    if child:
        return jsonify({
            'id': child.id,
            'name': child.name,
            'age': child.age,
            'fitbit_access_token': child.fitbit_access_token,
            'fitbit_refresh_token': child.fitbit_refresh_token,
        }), 200
    else:
        return jsonify({'message': 'No child found for this guardian'}), 404


@app.route('/child/fitbit_status/<int:child_id>', methods=['GET'])
def get_fitbit_status(child_id):
    try:
        child = Child.query.get(child_id)
        if not child:
            return jsonify({'message': 'Child not found'}), 404

        # Check token status
        has_tokens = bool(child.fitbit_access_token and child.fitbit_refresh_token)
        return jsonify({'has_tokens': has_tokens}), 200

    except Exception as e:
        print(f"Error checking Fitbit status: {e}")
        return jsonify({'message': 'Failed to fetch status', 'error': str(e)}), 500


@app.route('/authenticate_fitbit/<int:child_id>', methods=['POST'])
def authenticate_fitbit(child_id):
    try:
        client_id = '23PVVG'
        redirect_uri = 'https://1a05-80-233-39-72.ngrok-free.app/fitbit_callback'
        scopes = (
            "activity heartrate sleep profile "
            "electrocardiogram irregular_rhythm_notifications "
            "cardio_fitness respiratory_rate temperature"
        )
        auth_url = (
            f"https://www.fitbit.com/oauth2/authorize?"
            f"response_type=code&client_id={client_id}&redirect_uri={redirect_uri}"
            f"&scope={scopes}&state={child_id}"
        )

        return jsonify({'auth_url': auth_url}), 200
    except Exception as e:
        print(f"Error in authenticate_fitbit: {e}")
        return jsonify({'message': 'Internal Server Error', 'error': str(e)}), 500


@app.route('/re_authorize_fitbit/<int:child_id>', methods=['POST'])
def re_authorize_fitbit(child_id):
    try:
        # Fetch child data
        child = Child.query.get(child_id)
        if not child:
            return jsonify({'message': 'Child not found'}), 404

        # Clear existing tokens
        child.fitbit_access_token = None
        child.fitbit_refresh_token = None
        db.session.commit()

        # Generate the Fitbit OAuth URL
        client_id = '23PVVG'
        redirect_uri = 'https://1a05-80-233-39-72.ngrok-free.app/fitbit_callback'
        scopes = 'activity heartrate sleep weight profile settings social location oxygen_saturation electrocardiogram irregular_rhythm_notifications cardio_fitness temperature respiratory_rate'  # Correct scopes
        auth_url = f"https://www.fitbit.com/oauth2/authorize?response_type=code&client_id={client_id}&redirect_uri={redirect_uri}&scope={scopes}&state={child_id}"

        # Debugging log
        print(f"Generated Fitbit Auth URL: {auth_url}")

        # Return response with the generated URL
        return jsonify({
            'message': 'Please re-authorize Fitbit',
            'auth_url': auth_url
        }), 200

    except Exception as e:
        # Log the error for debugging
        print(f"Error in re_authorize_fitbit: {e}")
        return jsonify({'message': 'Internal Server Error', 'error': str(e)}), 500


# Fitbit callback route
@app.route('/fitbit_callback', methods=['GET'])
def fitbit_callback():
    try:
        # Get the authorization code and state (child ID)
        code = request.args.get('code')
        state = request.args.get('state')  # This is the child_id

        if not code or not state:
            return jsonify({'message': 'Missing authorization code or state'}), 400

        # Exchange the authorization code for access/refresh tokens
        client_id = '23PVVG'
        client_secret = 'e87a3c8c746462bfff0c8dd8b5ccf675'
        redirect_uri = 'https://1a05-80-233-39-72.ngrok-free.app/fitbit_callback'

        token_url = 'https://api.fitbit.com/oauth2/token'
        headers = {
            'Authorization': 'Basic ' + base64.b64encode(f"{client_id}:{client_secret}".encode()).decode(),
            'Content-Type': 'application/x-www-form-urlencoded',
        }
        data = {
            'client_id': client_id,
            'grant_type': 'authorization_code',
            'redirect_uri': redirect_uri,
            'code': code,
        }

        response = requests.post(token_url, headers=headers, data=data)

        if response.status_code != 200:
            return jsonify({'message': 'Failed to exchange authorization code', 'error': response.json()}), 400

        # Parse the response
        tokens = response.json()
        access_token = tokens.get('access_token')
        refresh_token = tokens.get('refresh_token')

        # Save tokens to the database for the specific child
        child = Child.query.get(int(state))
        if not child:
            return jsonify({'message': 'Child not found'}), 404

        child.fitbit_access_token = access_token
        child.fitbit_refresh_token = refresh_token
        db.session.commit()

        return jsonify({'message': 'Fitbit authorization successful', 'tokens': tokens}), 200

    except Exception as e:
        print(f"Error in fitbit_callback: {e}")
        return jsonify({'message': 'Internal Server Error', 'error': str(e)}), 500


import time


def fetch_with_retry(url, headers, retries=3):
    for attempt in range(retries):
        response = requests.get(url, headers=headers)
        if response.status_code == 200:
            return response.json()
        elif response.status_code == 429:  # Too many requests
            time.sleep(2 ** attempt)  # Exponential backoff
        else:
            print(f"Failed to fetch data from {url}. Status Code: {response.status_code}")
            return None
    return None


@app.route('/fitbit_data/<int:child_id>', methods=['GET'])
def get_fitbit_data(child_id):
    try:
        # Fetch the child and their access token
        child = Child.query.get(child_id)
        if not child:
            return jsonify({'message': 'Child not found'}), 404

        # Authorization headers for Fitbit API requests
        headers = {'Authorization': f'Bearer {child.fitbit_access_token}'} if child.fitbit_access_token else None

        # Get today's date in the required format
        today = datetime.now().strftime('%Y-%m-%d')

        # Define URLs for Fitbit endpoints
        urls = {
            'sleep': f'https://api.fitbit.com/1.2/user/-/sleep/date/{today}.json',
            'activity': f'https://api.fitbit.com/1/user/-/activities/date/{today}.json',
            'heart_rate': f'https://api.fitbit.com/1/user/-/activities/heart/date/{today}/1d.json',
            'respiratory_rate': f'https://api.fitbit.com/1/user/-/spo2/date/{today}/all.json',
            'temperature': f'https://api.fitbit.com/1/user/-/temperature/skin/date/{today}/all.json',
            'profile': 'https://api.fitbit.com/1/user/-/profile.json',
            # Add intraday heart rate data endpoint
            'heart_rate_intraday': f'https://api.fitbit.com/1/user/-/activities/heart/date/{today}/1d/1min.json',
        }

        # Fetch live data from Fitbit
        # Fetch live data from Fitbit
        fitbit_data = {}
        if headers:
            for key, url in urls.items():
                try:
                    response = fetch_with_retry(url, headers)

                    # If response is a tuple (response, status_code), extract response
                    if isinstance(response, tuple):
                        response, status_code = response  # Unpack tuple

                    fitbit_data[key] = response.json()  # Convert to JSON

                except Exception as e:
                    print(f"Error fetching {key}: {e}")
                    fitbit_data[key] = None  # Set key to None if fetching fails

        # Check if live data is unavailable
        if not any(fitbit_data.values()):
            print("Live Fitbit data unavailable, falling back to database.")
            most_recent_data = FitbitData.query.filter_by(child_id=child_id).order_by(
                FitbitData.timestamp.desc()).first()
            if most_recent_data:
                fitbit_data = most_recent_data.data
                return jsonify({
                    'message': 'Fallback to the most recent Fitbit data',
                    'data': fitbit_data,
                }), 200
            else:
                return jsonify({'message': 'No data available from Fitbit or database'}), 404

        # Save the live data into the database
        try:
            new_fitbit_data = FitbitData(
                child_id=child_id,
                data=fitbit_data,  # Store as JSON
            )
            db.session.add(new_fitbit_data)
            db.session.commit()
            print(f"Data successfully saved to the database for child_id: {child_id}")
        except Exception as db_error:
            print(f"Error saving data to the database: {db_error}")
            return jsonify({'message': 'Error saving data to the database'}), 500

        # Return the fetched data
        return jsonify({
            'message': 'Fitbit data fetched successfully',
            'data': fitbit_data,
        }), 200

    except Exception as e:
        # Handle unexpected errors
        print(f"Error in get_fitbit_data: {e}")
        return jsonify({'message': str(e)}), 500


@app.route('/sleep_alert/<int:child_id>', methods=['GET'])
def sleep_alert(child_id):
    try:
        # Fetch the latest Fitbit data for the child
        fitbit_data_entry = FitbitData.query.filter_by(child_id=child_id).order_by(FitbitData.timestamp.desc()).first()

        if not fitbit_data_entry:
            return jsonify({'message': 'No Fitbit data found for the child'}), 404

        # Extract sleep data
        fitbit_data = fitbit_data_entry.data
        sleep_data = fitbit_data.get('sleep')

        if not sleep_data or not sleep_data.get('sleep'):
            return jsonify({'message': 'No sleep data found'}), 404

        # Extract totalMinutesAsleep and efficiency from the sleep data
        total_minutes_asleep = sleep_data['summary'].get('totalMinutesAsleep', 0)
        efficiency = sleep_data['sleep'][0].get('efficiency', 0)

        # Determine sleep quality based on the parameters
        if total_minutes_asleep >= 420 and efficiency >= 85:
            sleep_quality = 'Good'
            alert_message = 'Good: Your child had a restful night\'s sleep!'
        elif total_minutes_asleep >= 300 and efficiency >= 70:
            sleep_quality = 'Average'
            alert_message = 'Average: Your child had an okay sleep, but could be improved.'
        else:
            sleep_quality = 'Poor'
            alert_message = 'Poor: WARNING: Child sleep quality was low. Consider improving their sleep habits.'

        return jsonify({
            'sleep_quality': sleep_quality,
            'total_minutes_asleep': total_minutes_asleep,
            'efficiency': efficiency,
            'alert': alert_message
        }), 200

    except Exception as e:
        # Handle unexpected errors
        print(f"Error in sleep_alert: {e}")
        return jsonify({'message': 'An error occurred while processing the sleep alert'}), 500


@app.route('/calendar_entry', methods=['POST'])
def add_calendar_entry():
    try:
        data = request.get_json()

        # Extract and validate data
        child_id = data.get('child_id')
        activity_name = data.get('activity_name')
        start_time = data.get('start_time')
        end_time = data.get('end_time')
        activity_notes = data.get('activity_notes', '')
        category = data.get('category', 'Activity').title()  # Normalize input

        # Log received data
        logging.info(f"Data received: {data}")
        logging.info(f"Category being used: {category}")

        # Validate required fields
        if not child_id:
            return jsonify({'message': 'Missing child_id'}), 400
        if not activity_name:
            return jsonify({'message': 'Missing activity_name'}), 400
        if not start_time:
            return jsonify({'message': 'Missing start_time'}), 400
        if not end_time:
            return jsonify({'message': 'Missing end_time'}), 400
        if category not in ['Activity', 'Food', 'Social']:
            return jsonify({'message': 'Invalid category value'}), 400

        # Check if child exists
        child = Child.query.get(child_id)
        if not child:
            return jsonify({'message': 'Child not found'}), 404

        # Validate time format
        try:
            start_time = datetime.fromisoformat(start_time)
            end_time = datetime.fromisoformat(end_time)
        except ValueError:
            return jsonify({'message': 'Invalid date format for start_time or end_time'}), 400

        if start_time >= end_time:
            return jsonify({'message': 'start_time must be before end_time'}), 400

        # Create a new calendar entry
        new_entry = CalendarEntry(
            child_id=child_id,
            activity_name=activity_name,
            start_time=start_time,
            end_time=end_time,
            activity_notes=activity_notes,
            category=category
        )

        db.session.add(new_entry)
        db.session.commit()

        return jsonify({'message': 'Activity added successfully', 'activity_id': new_entry.id}), 201

    except Exception as e:
        logging.error(f"Error during adding activity: {e}")
        return jsonify({'message': 'Failed to add activity', 'error': str(e)}), 500


@app.route('/calendar_entries/<int:child_id>', methods=['GET'])
def get_calendar_entries(child_id):
    try:
        # Query calendar entries for the given child_id
        entries = CalendarEntry.query.filter_by(child_id=child_id).all()

        # Serialize the entries with the category field
        activities = [
            {
                'id': entry.id,
                'activity_name': entry.activity_name,
                'start_time': entry.start_time.isoformat(),
                'end_time': entry.end_time.isoformat(),
                'activity_notes': entry.activity_notes,
                'category': entry.category,  # Include the category field
            }
            for entry in entries
        ]

        return jsonify({'activities': activities}), 200
    except Exception as e:
        print(f"Error fetching activities: {e}")
        return jsonify({'message': 'Failed to fetch activities', 'error': str(e)}), 500


@app.route('/calendar_entry/<int:entry_id>', methods=['PUT'])
def update_calendar_entry(entry_id):
    try:
        # Fetch the calendar entry by ID
        entry = CalendarEntry.query.get(entry_id)

        if not entry:
            return jsonify({'message': 'Activity not found'}), 404

        # Get the updated data from the request
        data = request.get_json()
        entry.activity_name = data.get('activity_name', entry.activity_name)
        entry.start_time = datetime.fromisoformat(data.get('start_time', entry.start_time.isoformat()))
        entry.end_time = datetime.fromisoformat(data.get('end_time', entry.end_time.isoformat()))
        entry.activity_notes = data.get('activity_notes', entry.activity_notes)
        entry.category = data.get('category', entry.category)  # Update the category field

        # Commit the changes to the database
        db.session.commit()
        return jsonify({'message': 'Activity updated successfully'}), 200

    except Exception as e:
        print(f"Error updating activity: {e}")
        return jsonify({'message': 'Failed to update activity', 'error': str(e)}), 500


@app.route('/calendar_entry/<int:event_id>', methods=['DELETE'])
def delete_calendar_entry(event_id):
    try:
        # Fetch the calendar entry by ID
        calendar_entry = CalendarEntry.query.get(event_id)

        if not calendar_entry:
            return jsonify({'message': 'Event not found'}), 404

        # Delete the calendar entry
        db.session.delete(calendar_entry)
        db.session.commit()

        return jsonify({'message': 'Event deleted successfully'}), 200

    except Exception as e:
        print(f"Error deleting event: {e}")
        return jsonify({'message': 'Failed to delete event', 'error': str(e)}), 500


@app.route('/fitbit_heart_rate_zones/<int:child_id>', methods=['GET'])
def fitbit_heart_rate_zones(child_id):
    try:
        # Fetch heart rate zones from Fitbit or database
        today = datetime.now().strftime('%Y-%m-%d')
        child = Child.query.get(child_id)
        if not child:
            return jsonify({'message': 'Child not found'}), 404

        # Fetch heart rate zones
        fitbit_data = FitbitData.query.filter_by(child_id=child_id).order_by(FitbitData.timestamp.desc()).first()
        hr_data = fitbit_data.data.get('heart_rate', {}).get('activities-heart', []) if fitbit_data else []

        if not hr_data:
            return jsonify({'message': 'No heart rate data available from Fitbit or database'}), 404

        # Fetch calendar events for the same day
        events = CalendarEntry.query.filter(
            CalendarEntry.child_id == child_id,
            db.func.date(CalendarEntry.start_time) == today
        ).all()

        event_data = [
            {
                'activity_name': event.activity_name,
                'start_time': event.start_time.strftime('%H:%M'),
                'end_time': event.end_time.strftime('%H:%M'),
                'activity_notes': event.activity_notes,
            }
            for event in events
        ]

        # Return data
        return jsonify({
            'message': 'Heart Rate Zones and Calendar Events fetched successfully',
            'heart_rate_zones': hr_data,
            'calendar_events': event_data,
        }), 200

    except Exception as e:
        print(f"Error in fitbit_heart_rate_zones: {e}")
        return jsonify({'message': 'Internal Server Error', 'error': str(e)}), 500


@app.route('/fitbit_location/<int:child_id>', methods=['GET'])
def fitbit_location(child_id):
    try:
        # Fetch the child and their access token
        child = Child.query.get(child_id)
        if not child:
            return jsonify({'message': 'Child not found'}), 404

        # Authorization headers
        headers = {'Authorization': f'Bearer {child.fitbit_access_token}'}

        # Fetch activity data
        today = datetime.now().strftime('%Y-%m-%d')  # Today's date
        activity_url = f"https://api.fitbit.com/1/user/-/activities/date/{today}.json"
        response = requests.get(activity_url, headers=headers)

        if response.status_code != 200:
            return jsonify({'message': 'Failed to fetch activities', 'error': response.json()}), response.status_code

        activities = response.json().get('activities', [])

        # Extract GPS data if available
        locations = []
        for activity in activities:
            if 'tcxLink' in activity:  # TCX file contains detailed location data
                locations.append({
                    'name': activity.get('name', 'Unknown Activity'),
                    'start_time': activity.get('startTime'),
                    'duration': activity.get('duration'),
                    'calories': activity.get('calories'),
                    'tcx_link': activity['tcxLink'],  # Link to detailed GPS data
                })

        if not locations:
            return jsonify({'message': 'No location data available for today', 'activities': activities}), 200

        return jsonify({'message': 'Location data fetched successfully', 'locations': locations}), 200

    except Exception as e:
        print(f"Error in fitbit_location: {e}")
        return jsonify({'message': 'Internal Server Error', 'error': str(e)}), 500


@app.route('/generate_graph_data/<int:child_id>', methods=['GET'])
def generate_graph_data(child_id):
    try:
        # Fetch the child object from the database
        child = Child.query.get(child_id)
        if not child:
            return jsonify({'error': 'Child not found'}), 404

        # Get the Fitbit access token
        fitbit_access_token = child.fitbit_access_token
        if not fitbit_access_token:
            return jsonify({'error': 'No Fitbit access token found for this child'}), 400

        # Fetch calendar events for the child
        calendar_events = CalendarEntry.query.filter_by(child_id=child_id).all()
        event_data = [
            {
                'activity_name': event.activity_name,
                'start_time': event.start_time.isoformat(),
                'end_time': event.end_time.isoformat(),
                'activity_notes': event.activity_notes,
            }
            for event in calendar_events
        ]

        # Fitbit API request for intraday heart rate data
        today = datetime.now().strftime('%Y-%m-%d')
        fitbit_url = f'https://api.fitbit.com/1/user/-/activities/heart/date/{today}/1d/1min.json'
        headers = {'Authorization': f'Bearer {fitbit_access_token}'}
        response = requests.get(fitbit_url, headers=headers)

        # Handle API errors

        if response.status_code != 200:
            return jsonify({'error': 'Failed to fetch heart rate data from Fitbit'}), response.status_code

        heart_rate_data = response.json()
        intraday_data = heart_rate_data.get('activities-heart-intraday', {}).get('dataset', [])

        # Process graph data
        graph_data = process_graph_data(intraday_data, event_data)

        return jsonify(graph_data), 200

    except Exception as e:
        print(f"Error in generate_graph_data: {e}")
        return jsonify({'error': 'Internal Server Error'}), 500


def process_graph_data(intraday_data, calendar_events):
    graph_data = {'timestamps': [], 'heartRates': [], 'eventMarkers': []}

    for point in intraday_data:
        # Extract time and heart rate value
        timestamp = datetime.strptime(point['time'], '%H:%M:%S').time()
        graph_data['timestamps'].append(point['time'])
        graph_data['heartRates'].append(point['value'])

        # Check if this timestamp falls within any calendar event
        event_marker = None
        for event in calendar_events:
            event_start = datetime.fromisoformat(event['start_time']).time()
            event_end = datetime.fromisoformat(event['end_time']).time()
            if event_start <= timestamp <= event_end:
                event_marker = event['activity_name']
                break

        graph_data['eventMarkers'].append(event_marker)

    return graph_data


@app.route('/get_last_meal/<int:child_id>', methods=['GET'])
def get_last_meal(child_id):
    try:
        # Query for the latest 'Food' category event for the given child_id
        last_meal = CalendarEntry.query.filter_by(child_id=child_id, category='Food') \
            .order_by(CalendarEntry.start_time.desc()).first()

        if last_meal:
            now = datetime.now()
            last_meal_time = last_meal.start_time
            hours_since_last_meal = (now - last_meal_time).total_seconds() // 3600
            return jsonify({"time_since_last_meal": int(hours_since_last_meal)})
        else:
            return jsonify({"time_since_last_meal": None})  # No meal found
    except Exception as e:
        return jsonify({"error": str(e)}), 500




FIREBASE_SERVER_KEY = "46449a307bf47e14fa6785cf37f6e3128a127505"
FIREBASE_FCM_URL = "https://fcm.googleapis.com/v1/projects/cloud-messaging-bc6ad/messages:send"

import json
import requests
import mysql.connector
import atexit
from flask import Flask, jsonify, request
from google.auth.transport.requests import Request
from google.oauth2 import service_account
from apscheduler.schedulers.background import BackgroundScheduler



FIREBASE_FCM_URL = "https://fcm.googleapis.com/v1/projects/cloud-messaging-bc6ad/messages:send"


def get_db_connection():
    return mysql.connector.connect(
        host="localhost",
        user="root",
        password="1FootballFan!!",
        database="FYP"
    )


# ✅ Fetch OAuth Token for Firebase Cloud Messaging
def get_access_token():
    SCOPES = ["https://www.googleapis.com/auth/firebase.messaging"]
    SERVICE_ACCOUNT_FILE = "C:/Users/jules/PycharmProjects/flaskFYP/serviceAccountKey.json"  # ✅ Make sure the path is correct

    credentials = service_account.Credentials.from_service_account_file(
        SERVICE_ACCOUNT_FILE, scopes=SCOPES
    )

    request = google.auth.transport.requests.Request()
    credentials.refresh(request)  # Refresh the token

    return credentials.token  # ✅ Return the OAuth2 token

# ✅ Send Firebase Cloud Notification
def send_fcm_notification(fcm_token, title, body):
    access_token = get_access_token()  # Get valid OAuth token

    headers = {
        "Authorization": f"Bearer {access_token}",
        "Content-Type": "application/json",
    }

    PROJECT_ID = "cloud-messaging-bc6ad"  # 🔁 Replace with your real Firebase project ID
    url = f"https://fcm.googleapis.com/v1/projects/{PROJECT_ID}/messages:send"

    payload = {
        "message": {
            "token": fcm_token,
            "notification": {
                "title": title,
                "body": body
            },
            "android": {
                "priority": "high"
            }
        }
    }

    print("📡 Sending notification with payload:")
    print(json.dumps(payload, indent=2))

    response = requests.post(url, headers=headers, json=payload)

    print(f"🔥 FCM Response Status: {response.status_code}")
    print(f"🔥 FCM Response Text: {response.text}")

    return response.json()


# ✅ Fetch Resting Heart Rate from Fitbit API
def fetch_resting_hr(child_id, access_token):
    response = requests.get(f"https://api.fitbit.com/1/user/{child_id}/activities/heart/date/today.json",
                            headers={"Authorization": f"Bearer {access_token}"})
    if response.status_code == 200:
        data = response.json()
        return data["activities-heart"][0]["value"].get("restingHeartRate", None)
    return None


# ✅ Fetch Latest Heart Rate from Fitbit API
def fetch_intraday_heart_rate(child_id, access_token):
    response = requests.get(f"https://api.fitbit.com/1/user/{child_id}/activities/heart/date/today/1d/1min.json",
                            headers={"Authorization": f"Bearer {access_token}"})
    if response.status_code == 200:
        dataset = response.json()["activities-heart-intraday"].get("dataset", [])
        return dataset[-1]["value"] if dataset else None
    return None


# ✅ Check Heart Rate & Trigger Notification if Needed
def check_heart_rate(child_id, access_token):
    resting_hr = fetch_resting_hr(child_id, access_token)
    latest_hr = fetch_intraday_heart_rate(child_id, access_token)

    if resting_hr and latest_hr:
        threshold = resting_hr * 2
        if latest_hr >= threshold:
            fcm_token = get_parent_fcm_token(child_id)
            if fcm_token:
                send_fcm_notification(fcm_token, "🚨 High Heart Rate Alert",
                                      f"Your child's heart rate is {latest_hr} BPM! 🚑")
                return {"message": "High heart rate detected, notification sent!"}
    return {"message": "Heart rate normal."}


# ✅ Check All Children & Their Heart Rates
def check_all_children():
    connection = get_db_connection()
    cursor = connection.cursor(dictionary=True)

    cursor.execute("SELECT id, fitbit_access_token FROM child WHERE fitbit_access_token IS NOT NULL")
    children = cursor.fetchall()

    for child in children:
        check_heart_rate(child["id"], child["fitbit_access_token"])

    cursor.close()
    connection.close()


@app.route("/check_all_children", methods=["POST"])
def check_all_children_api():
    check_all_children()
    return jsonify({"message": "Checked heart rates for all children"}), 200


# ✅ Register FCM Token
@app.route('/register_token', methods=['POST'])
def register_token():
    try:
        data = request.json
        parent_id = data.get("parent_id")
        new_token = data.get("token")

        if not parent_id or not new_token:
            return jsonify({"error": "Missing parent_id or token"}), 400

        # 🔍 Check if the parent has an existing token
        existing_token_entry = DeviceToken.query.filter_by(parent_id=parent_id).first()

        if existing_token_entry:
            if existing_token_entry.token == new_token:
                # ✅ Token is already up to date, no need to update
                print("🔄 FCM Token is already up to date, no changes made.")
                return jsonify({"message": "Token already up to date"}), 200
            else:
                # 🗑️ Delete the old token and insert the new one
                print(f"🗑️ Deleting old FCM Token: {existing_token_entry.token}")
                db.session.delete(existing_token_entry)
                db.session.commit()

        # ✅ Save the new token
        new_device_token = DeviceToken(parent_id=parent_id, token=new_token)
        db.session.add(new_device_token)
        db.session.commit()

        print(f"✅ New FCM Token saved: {new_token}")
        return jsonify({"message": "FCM Token updated successfully"}), 201

    except Exception as e:
        print(f"❌ Error updating FCM token: {e}")
        return jsonify({"error": str(e)}), 500

# ✅ Send Notification Manually
@app.route('/send_notification', methods=['POST'])
def send_notification():
    data = request.get_json()
    parent_id = data.get("parent_id")
    message = data.get("message")

    if not parent_id or not message:
        return jsonify({"error": "Missing parent_id or message"}), 400

    try:
        # ✅ Fetch tokens from database
        tokens = db.session.execute(
            db.select(DeviceToken.token).where(DeviceToken.parent_id == parent_id)
        ).scalars().all()

        if not tokens:
            return jsonify({"error": "No registered devices for this parent"}), 404

        print(f"📌 Tokens from DB: {tokens}")

        # ✅ Set up Firebase headers
        headers = {
            'Authorization': 'key=YOUR_SERVER_KEY',  # 🔥 Replace with your actual Firebase server key
            'Content-Type': 'application/json',
        }

        # ✅ Construct payload
        payload = {
            "registration_ids": tokens,  # List of device tokens
            "notification": {
                "title": "Alert!",
                "body": message,
                "sound": "default"
            },
        }

        # ✅ Send request to FCM
        response = requests.post("https://fcm.googleapis.com/fcm/send",
                                 headers=headers, json=payload)

        print(f"🔥 FCM Response Status: {response.status_code}")
        print(f"🔥 FCM Response Text: {response.text}")  # 🔥 Print raw response

        # ✅ Handle Firebase response
        if response.status_code == 200:
            return jsonify({"message": "Notification sent successfully", "response": response.json()}), 200
        else:
            return jsonify({"error": "Failed to send notification", "details": response.text}), 500

    except Exception as e:
        return jsonify({"error": str(e)}), 500

def check_heart_rate_and_notify():
    """
    Fetches the latest heart rate from Fitbit and sends a notification if it's too high
    for the child of the currently logged-in parent.
    """
    try:
        with app.app_context():  # Ensure SQLAlchemy session works inside the function
            # ✅ Get the most recent parent_id from the device_tokens table
            latest_device_token = DeviceToken.query.order_by(DeviceToken.created_at.desc()).first()

            if not latest_device_token:
                print("❌ No logged-in parent found with a device token.")
                return

            parent_id = latest_device_token.parent_id

            # ✅ Find the child associated with this parent
            child = Child.query.filter_by(guardian_id=parent_id).first()

            if not child:
                print(f"❌ No child found for parent {parent_id}.")
                return

            child_id = child.id

            # ✅ Fetch the latest Fitbit heart rate data for this child
            api_url = f"https://1a05-80-233-39-72.ngrok-free.app/fitbit_data/{child_id}"
            response = requests.get(api_url)
            data = response.json()

            # ✅ Extract latest heart rate
            heart_rate_data = data.get('data', {}).get('heart_rate_intraday', {}).get('activities-heart-intraday', {}).get('dataset', [])

            if not heart_rate_data:
                print(f"⚠️ No heart rate data available for child {child_id}.")
                return

            latest_heart_rate = heart_rate_data[-1]['value']
            print(f"🔥 Latest Heart Rate for Child {child_id}: {latest_heart_rate} BPM")

            # ✅ Define a high heart rate threshold
            HEART_RATE_THRESHOLD = 100  # Adjust as needed

            if latest_heart_rate >= HEART_RATE_THRESHOLD:
                print(f"🚨 High heart rate detected: {latest_heart_rate} BPM! Sending alert...")

                # ✅ Get the FCM token for the parent
                device_token = DeviceToken.query.filter_by(parent_id=child.guardian_id).first()

                if device_token:
                    fcm_token = device_token.token
                    send_fcm_notification(fcm_token, "🚨 High Heart Rate Alert!", f"Heart rate is {latest_heart_rate} BPM. Please check on your child.")
                else:
                    print("❌ No FCM token found for parent. Cannot send notification.")

    except Exception as e:
        print(f"❌ Error checking heart rate: {e}")

scheduler = BackgroundScheduler()
scheduler.add_job(check_heart_rate_and_notify, 'interval', minutes=500)
scheduler.start()


def get_meal_counts(child_id):
    today = datetime.today().date()
    last_7_days = [(today - timedelta(days=i)) for i in range(6, -1, -1)]

    print(f"🔍 Today: {today}")
    print(f"🔍 Last 7 days range: {last_7_days[0]} to {last_7_days[-1]}")

    # ✅ Query meal data (meals per day + timestamps for calculating gaps)
    meals = (
        db.session.query(
            func.date(CalendarEntry.start_time).label("meal_date"),
            func.count().label("meal_count"),
            func.group_concat(text("UNIX_TIMESTAMP(start_time) ORDER BY start_time")).label("timestamps")  # Collect timestamps for gap calculation
        )
        .filter(CalendarEntry.category == 'Food')
        .filter(CalendarEntry.child_id == child_id)
        .filter(CalendarEntry.start_time >= last_7_days[0])
        .filter(CalendarEntry.start_time <= last_7_days[-1] + timedelta(days=1))  # Ensure today is included
        .group_by(func.date(CalendarEntry.start_time))
        .all()
    )

    print(f"🟠 Raw meal data from DB: {meals}")

    # ✅ Initialize dictionary with all 7 days set to 0 meals and gaps
    meal_data = {day.strftime('%Y-%m-%d'): {"meal_count": 0, "meal_gap": 0} for day in last_7_days}

    # ✅ Update dictionary with actual data from SQL
    for meal in meals:
        meal_date_str = meal.meal_date.strftime('%Y-%m-%d')
        timestamps = meal.timestamps.split(',') if meal.timestamps else []

        meal_data[meal_date_str]["meal_count"] = meal.meal_count

        # ✅ Calculate meal gap (difference in hours between meals on the same day)
        if len(timestamps) > 1:
            timestamps = sorted([datetime.fromtimestamp(int(ts)) for ts in timestamps])
            gaps = [(timestamps[i] - timestamps[i - 1]).total_seconds() / 3600 for i in range(1, len(timestamps))]
            meal_data[meal_date_str]["meal_gap"] = max(gaps)  # Store the longest gap of the day
        else:
            meal_data[meal_date_str]["meal_gap"] = 0  # No gap if only one meal

    # ✅ Convert dates into readable format (e.g., "Today", "1st Mar")
    def format_date(date):
        if date == today:
            return "Today"
        return date.strftime('%-d %b') if os.name != 'nt' else date.strftime('%#d %b')

    date_labels = [format_date(day) for day in last_7_days]

    # ✅ Return updated data with meal counts and meal gaps
    return jsonify({
        "dates": date_labels,
        "meal_counts": [meal_data.get(day.strftime('%Y-%m-%d'), {"meal_count": 0})["meal_count"] for day in
                        last_7_days],
        "meal_gaps": [meal_data.get(day.strftime('%Y-%m-%d'), {"meal_gap": 0})["meal_gap"] for day in last_7_days]
    })


@app.route('/getMealData/<int:child_id>', methods=['GET'])
def get_meal_data(child_id):
    # 🔹 Fetch meal data from function
    result = get_meal_counts(child_id).json  # ✅ Extract JSON from Response object

    print("🟢 Final JSON Response:", result)  # ✅ Just print the dictionary, no json.dumps()

    return jsonify(result)  # ✅ Return JSON response properly


def fetch_with_retry(url, headers, max_retries=3):
    """Fetch data from Fitbit API with retry logic."""
    for attempt in range(max_retries):
        response = requests.get(url, headers=headers)

        if response.status_code == 200:
            return response  # ✅ Correct: Returning the full response object

        elif response.status_code == 429:
            wait_time = int(response.headers.get("Retry-After", 10))  # Default wait: 10s
            print(f"⚠️ Rate limited. Retrying in {wait_time} seconds...")
            time.sleep(wait_time)

        else:
            print(f"❌ Error {response.status_code}: {response.text}")

    return None  # ✅ Returns None only if all retries fail


@app.route('/get_weekly_sleep/<int:child_id>', methods=['GET'])
def get_weekly_sleep(child_id):
    try:
        # Fetch the child and their access token
        child = Child.query.get(child_id)
        if not child:
            return jsonify({'message': 'Child not found'}), 404

        if not child.fitbit_access_token:
            return jsonify({'message': 'No Fitbit access token found'}), 400

        headers = {'Authorization': f'Bearer {child.fitbit_access_token}'}

        # Generate the last 7 days’ dates
        past_week_dates = [(datetime.now() - timedelta(days=i)).strftime('%Y-%m-%d') for i in range(7)]
        sleep_data = []

        # Query Fitbit API for each date
        for date in past_week_dates:
            sleep_url = f'https://api.fitbit.com/1.2/user/-/sleep/date/{date}.json'
            response = requests.get(sleep_url, headers=headers)

            if response.status_code == 200:
                sleep_response = response.json()

                if 'sleep' in sleep_response and sleep_response['sleep']:
                    # Get the main sleep session
                    main_sleep = max(sleep_response['sleep'], key=lambda x: x.get('minutesAsleep', 0))
                    sleep_data.append({
                        "dateOfSleep": main_sleep.get("dateOfSleep", date),
                        "minutesAsleep": main_sleep.get("minutesAsleep", 0)
                    })
                else:
                    sleep_data.append({"dateOfSleep": date, "minutesAsleep": 0})

            else:
                print(f"⚠️ Failed to fetch sleep data for {date}: {response.status_code}")
                sleep_data.append({"dateOfSleep": date, "minutesAsleep": 0})  # If Fitbit API fails, default to 0

        return jsonify({
            'message': 'Weekly sleep data fetched successfully',
            'data': sleep_data,
        }), 200

    except Exception as e:
        print(f"❌ Error in get_weekly_sleep: {e}")
        return jsonify({'message': str(e)}), 500


@app.route('/get_intraday_heart_rate/<int:child_id>/<date>', methods=['GET'])
def get_intraday_heart_rate(child_id, date):
    try:
        # Fetch child data
        child = Child.query.get(child_id)
        if not child:
            return jsonify({'message': 'Child not found'}), 404

        headers = {'Authorization': f'Bearer {child.fitbit_access_token}'} if child.fitbit_access_token else None

        # ✅ Correct Fitbit API URL
        fitbit_url = f'https://api.fitbit.com/1/user/-/activities/heart/date/{date}/1d/1min.json'

        # ✅ Fetch Data (Make sure fetch_with_retry() returns a valid response!)
        response = fetch_with_retry(fitbit_url, headers)

        if response is None:
            print("❌ Failed to fetch intraday heart rate data from Fitbit. Trying database...")

            # 🔥 Fallback: Get latest stored Fitbit data
            most_recent_data = FitbitData.query.filter_by(child_id=child_id).order_by(
                FitbitData.timestamp.desc()).first()

            if most_recent_data:
                fitbit_data = most_recent_data.data
                if 'heart_rate_intraday' in fitbit_data:
                    return jsonify({
                        'message': 'Using fallback intraday heart rate data',
                        'data': fitbit_data['heart_rate_intraday']
                    }), 200
                else:
                    return jsonify({'message': 'No heart rate data in database'}), 404
            else:
                return jsonify({'message': 'No data available in database'}), 404

        # ✅ Convert response to JSON properly
        heart_rate_data = response.json()

        # ✅ Store the data into the database
        try:
            new_fitbit_data = FitbitData(
                child_id=child_id,
                data={'heart_rate_intraday': heart_rate_data}  # Storing only heart rate
            )
            db.session.add(new_fitbit_data)
            db.session.commit()
            print(f"✅ Intraday heart rate data saved for child_id: {child_id}")
        except Exception as db_error:
            print(f"❌ Error saving data to the database: {db_error}")
            return jsonify({'message': 'Error saving data to database'}), 500

        return jsonify({
            'message': 'Intraday heart rate data fetched successfully',
            'data': heart_rate_data
        }), 200

    except Exception as e:
        print(f"❌ Error in get_intraday_heart_rate: {e}")
        return jsonify({'message': str(e)}), 500

@app.route("/log_stress_score/<int:child_id>", methods=["POST"])
def log_stress_score(child_id):
    data = request.json
    stress_score = data.get("stress_score")

    if stress_score is None:
        return jsonify({"error": "Missing stress score"}), 400

    new_entry = StressScoreLog(child_id=child_id, stress_score=stress_score)
    db.session.add(new_entry)
    db.session.commit()

    return jsonify({"message": "Stress score logged successfully"})
@app.route("/get_stress_scores/<int:child_id>", methods=["GET"])
def get_stress_scores(child_id):
    scores = StressScoreLog.query.filter_by(child_id=child_id).order_by(StressScoreLog.timestamp.asc()).all()

    stress_data = [
        {"timestamp": score.timestamp.strftime("%Y-%m-%d %H:%M:%S"), "stress_score": score.stress_score}
        for score in scores
    ]

    return jsonify({"data": stress_data, "message": "Stress scores fetched successfully"})

@app.route('/save_stress_score', methods=['POST'])
def save_stress_score():
    try:
        data = request.json
        child_id = data.get('child_id')
        stress_score = data.get('stress_score')
        timestamp = datetime.now()

        new_entry = StressScoreLog(
            child_id=child_id,
            stress_score=stress_score,
            timestamp=timestamp
        )

        db.session.add(new_entry)
        db.session.commit()

        return jsonify({"message": "Stress score logged successfully"}), 200
    except Exception as e:
        return jsonify({"error":
                            str(e)}), 500


@app.route('/log_stress_event', methods=['POST'])
def log_stress_event():
    data = request.json
    child_id = data.get('child_id')
    trigger = data.get('trigger', '')  # Optional context

    if not child_id:
        return jsonify({"error": "child_id is required"}), 400

    new_event = StressEvent(
        child_id=child_id,
        trigger=trigger,
        timestamp=datetime.utcnow()
    )
    db.session.add(new_event)
    db.session.commit()

    return jsonify({"message": "Stress event logged", "event_id": new_event.id}), 200


@app.route('/log_intervention/<int:event_id>', methods=['POST'])
def log_intervention(event_id):
    data = request.json
    intervention_type = data.get('intervention_type')
    description = data.get('description', '')

    if not intervention_type:
        return jsonify({"error": "intervention_type is required"}), 400

    intervention = Intervention(
        stress_event_id=event_id,
        intervention_type=intervention_type,
        description=description,
        resolved_at=datetime.utcnow()
    )
    db.session.add(intervention)

    # Optionally mark the stress event as resolved
    event = StressEvent.query.get(event_id)
    if event:
        event.resolved = True

    db.session.commit()

    return jsonify({"message": "Intervention logged"}), 200


@app.route('/stress_events/<int:child_id>', methods=['GET'])
def get_stress_events(child_id):
    # Get the date parameter from the request
    date_param = request.args.get('date')

    if date_param:
        try:
            # Convert date_param to a valid datetime object (00:00:00 time)
            selected_date = datetime.strptime(date_param, "%Y-%m-%d").date()

            # Filter stress events to include only those matching the selected date
            events = StressEvent.query.filter(
                StressEvent.child_id == child_id,
                db.func.date(StressEvent.timestamp) == selected_date
            ).order_by(StressEvent.timestamp.desc()).all()
        except ValueError:
            return jsonify({"error": "Invalid date format, expected YYYY-MM-DD"}), 400
    else:
        # If no date is provided, return all events (fallback)
        events = StressEvent.query.filter_by(child_id=child_id).order_by(StressEvent.timestamp.desc()).all()

    return jsonify({
        "data": [e.to_dict() for e in events],
        "message": "Stress events retrieved successfully"
    })

STRESS_THRESHOLD = 10


@app.route('/calculate_and_store_stress/<int:child_id>', methods=['POST'])
def calculate_and_store_stress(child_id):
    try:
        # 🌙 Fetch Fitbit data
        fitbit_response = requests.get(f"http://localhost:5000/fitbit_data/{child_id}")
        if fitbit_response.status_code != 200:
            return jsonify({"error": "Failed to fetch Fitbit data"}), 500

        fitbit_data = fitbit_response.json().get('data', {})

        # 💤 Sleep data
        sleep_list = fitbit_data.get('sleep', {}).get('sleep', [])
        main_sleep = next((s for s in sleep_list if s.get('isMainSleep')), {})
        total_sleep = main_sleep.get('minutesAsleep', 0) / 60
        deep_sleep = main_sleep.get('levels', {}).get('summary', {}).get('deep', {}).get('minutes', 0) / 60
        efficiency = main_sleep.get('efficiency', 0)

        # ❤️ Latest Heart Rate
        heart_data = fitbit_data.get('heart_rate_intraday', {}).get('activities-heart-intraday', {}).get('dataset', [])
        latest_heart_rate = heart_data[-1]['value'] if heart_data else 70

        # 🍽️ Meal data
        meal_response = requests.get(f"http://localhost:5000/get_last_meal/{child_id}")
        meal_data = meal_response.json()
        time_since_last_meal = meal_data.get('time_since_last_meal', 24)

        # ✅ Score Calculations (Match Flutter)
        def calculate_sleep_score(total, deep, eff):
            score = (total / 8) * 50
            score += (deep / 2) * 25
            score += (eff / 100) * 25
            return max(0, min(score, 100))

        def calculate_heart_score(hr):
            if hr < 60: return 25
            if hr < 100: return 12.5
            return 0

        def calculate_meal_score(hours):
            return max(0, min(25 - (hours / 24) * 25, 25))

        sleep_score = calculate_sleep_score(total_sleep, deep_sleep, efficiency)
        heart_score = calculate_heart_score(latest_heart_rate)
        meal_score = calculate_meal_score(time_since_last_meal)

        original_score = (sleep_score * 0.5) + (heart_score * 0.25) + (meal_score * 0.25)
        overall_stress = 100 - original_score

        # ✅ Store in DB
        new_log = StressScoreLog(
            child_id=child_id,
            stress_score=overall_stress,
            timestamp=datetime.now()
        )
        db.session.add(new_log)
        db.session.commit()

        # 🚨 Send Notification if Needed
        if overall_stress >= STRESS_THRESHOLD:
            parent_token = get_parent_fcm_token(child_id)
            if parent_token:
                send_fcm_notification(
                    fcm_token=parent_token,
                    title="⚠️ High Stress Alert!",
                    body=f"Your child's stress level is high ({overall_stress:.1f}). Check the app for details."
                )

            # 📌 Log as Stress Event
            new_event = StressEvent(
                child_id=child_id,
                trigger="Auto-detected spike",
                timestamp=datetime.utcnow()
            )
            db.session.add(new_event)
            db.session.commit()

        return jsonify({
            "child_id": child_id,
            "stress_score": overall_stress,
            "message": "Stress calculated, stored, and notification sent if necessary."
        }), 200

    except Exception as e:
        print(f"❌ Error calculating or storing stress: {e}")
        return jsonify({"error": str(e)}), 500

# Helper function to send notifications with FCM
def send_fcm_message(token, title, body):
    message = messaging.Message(
        notification=messaging.Notification(title=title, body=body),
        token=token,
    )

    response = messaging.send(message)
    print(f"✅ Successfully sent notification: {response}")



def scheduled_stress_calculation():
    child_id = 1  # Update if needed
    print(f"⏳ Running scheduled stress calculation for child {child_id} at {datetime.now()}")

    try:
        response = requests.post(f"http://localhost:5000/calculate_and_store_stress/{child_id}")
        print(f"✅ Stress Calculation Response: {response.status_code} - {response.json()}")
    except Exception as e:
        print(f"❌ Error in scheduled stress calculation: {e}")


scheduler = APScheduler()

scheduler.add_job(
    id="calculate_stress_job",
    func=scheduled_stress_calculation,
    trigger="interval",
    minutes=10  # Change to your preferred interval
)

@app.route('/list_jobs', methods=['GET'])
def list_jobs():
    return jsonify([{"id": job.id, "next_run": str(job.next_run_time)} for job in scheduler.get_jobs()])


scheduler.init_app(app)
scheduler.start()


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)

