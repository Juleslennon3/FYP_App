import base64
import logging
from datetime import datetime
from urllib.parse import unquote
from datetime import datetime, timedelta

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
from sqlalchemy.testing.pickleable import Parent
from werkzeug.security import generate_password_hash, check_password_hash
from flask_mysqldb import MySQL
from flask import Flask, request, jsonify
from flask_mysqldb import MySQL
from google.oauth2 import service_account
import google.auth.transport.requests

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
        redirect_uri = 'https://3efd-80-233-12-225.ngrok-free.app/fitbit_callback'
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
        redirect_uri = 'https://3efd-80-233-12-225.ngrok-free.app/fitbit_callback'
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
        redirect_uri = 'https://3efd-80-233-12-225.ngrok-free.app/fitbit_callback'

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
        fitbit_data = {}
        if headers:
            for key, url in urls.items():
                try:
                    fitbit_data[key] = fetch_with_retry(url, headers)
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


@app.route('/last_food_event/<int:child_id>', methods=['GET'])
def get_last_food_event(child_id):
    last_meal = CalendarEntry.query.filter_by(child_id=child_id, category="Food").order_by(CalendarEntry.start_time.desc()).first()

    if last_meal:
        last_meal_time = last_meal.start_time.strftime("%Y-%m-%d %H:%M:%S")
        return jsonify({
            "last_meal_time": last_meal_time,
            "warning": None  # No warning, as a meal was logged within 5 hours
        }), 200
    else:
        return jsonify({
            "last_meal_time": None,
            "warning": "No meals logged in the last 5 hours!"
        }), 200




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
    headers = {
        "Authorization": f"Bearer {get_access_token()}",
        "Content-Type": "application/json"
    }

    # Replace 'your-project-id' with your actual Firebase project ID
    PROJECT_ID = "cloud-messaging-bc6ad"

    url = f"https://fcm.googleapis.com/v1/projects/{PROJECT_ID}/messages:send"

    payload = {
        "message": {
            "token": fcm_token,
            "notification": {
                "title": title,
                "body": body
            }
        }
    }

    response = requests.post(url, headers=headers, json=payload)

    print(f"🔥 FCM Response Status: {response.status_code}")
    print(f"🔥 FCM Response Text: {response.text}")

    return response.json()

# ✅ Fetch Parent's FCM Token from Database
def get_parent_fcm_token(child_id):
    connection = get_db_connection()
    cursor = connection.cursor(dictionary=True)

    cursor.execute(
        "SELECT token FROM device_tokens WHERE parent_id = (SELECT guardian_id FROM child WHERE id = %s)",
        (child_id,)
    )
    result = cursor.fetchone()
    cursor.close()
    connection.close()

    return result["token"] if result else None  # ✅ Return valid token or None


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
            api_url = f"https://3efd-80-233-12-225.ngrok-free.app/fitbit_data/{child_id}"
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
            HEART_RATE_THRESHOLD = 20  # Adjust as needed

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
scheduler.add_job(check_heart_rate_and_notify, 'interval', minutes=1)
scheduler.start()



if __name__ == '__main__':
    app.run(debug=True, host="0.0.0.0")
