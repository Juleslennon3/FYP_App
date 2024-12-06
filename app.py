from datetime import datetime, timedelta
import base64
import requests
from flask import Flask, request, jsonify
from urllib.parse import unquote
from flask_sqlalchemy import SQLAlchemy
from flask_migrate import Migrate
from werkzeug.security import generate_password_hash, check_password_hash

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
    fitbit_access_token = db.Column(db.String(255), nullable=True)
    fitbit_refresh_token = db.Column(db.String(255), nullable=True)
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

    def __init__(self, child_id, activity_name, start_time, end_time, activity_notes=None):
        self.child_id = child_id
        self.activity_name = activity_name
        self.start_time = start_time
        self.end_time = end_time
        self.activity_notes = activity_notes



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
        return jsonify({'message': 'User registered successfully'}), 201

    except Exception as e:
        print(f"Error during registration: {e}")
        return jsonify({'message': 'Registration failed', 'error': str(e)}), 500

# Login route
@app.route('/login', methods=['POST'])
def login():
    data = request.get_json()
    email = data.get('email')
    password = data.get('password')

    if not email or not password:
        return jsonify({'message': 'Email and password are required'}), 400

    user = User.query.filter_by(email=email).first()
    if user and check_password_hash(user.password, password):
        return jsonify({'message': 'Login successful', 'user_id': user.id}), 200
    else:
        return jsonify({'message': 'Invalid email or password'}), 401

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
        redirect_uri = 'https://a20b-37-228-210-166.ngrok-free.app/fitbit_callback'
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
        redirect_uri = 'https://a20b-37-228-210-166.ngrok-free.app/fitbit_callback'
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
        client_secret = 'e87a3c8c746462bfff0c8dd8b5ccf675'  # Replace with your secret
        redirect_uri = 'https://a20b-37-228-210-166.ngrok-free.app/fitbit_callback'

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
        if not child or not child.fitbit_access_token:
            return jsonify({'message': 'Child or access token not found'}), 404

        # Authorization headers for Fitbit API requests
        headers = {'Authorization': f'Bearer {child.fitbit_access_token}'}

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
        }

        # Fetch data from each URL and store in fitbit_data
        fitbit_data = {}
        for key, url in urls.items():
            try:
                fitbit_data[key] = fetch_with_retry(url, headers)
            except Exception as e:
                print(f"Error fetching {key}: {e}")  # Log errors for debugging
                fitbit_data[key] = None  # Set key to None if fetching fails

        # Check if any data was successfully fetched
        if not any(fitbit_data.values()):
            return jsonify({'message': 'No data available from Fitbit'}), 404

        # Save fetched data into the database
        try:
            new_fitbit_data = FitbitData(
                child_id=child_id,
                data=fitbit_data  # Store as JSON
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


@app.route('/calendar_entry', methods=['POST'])
def add_calendar_entry():
    try:
        data = request.get_json()

        # Extract data from the request
        child_id = data.get('child_id')  # Expect child_id from the frontend
        activity_name = data.get('activity_name')
        start_time = data.get('start_time')
        end_time = data.get('end_time')
        activity_notes = data.get('activity_notes', '')

        # Validate required fields
        if not child_id or not activity_name or not start_time or not end_time:
            return jsonify({'message': 'Missing required fields'}), 400

        # Check if child exists by ID
        child = Child.query.get(child_id)
        if not child:
            return jsonify({'message': 'Child not found'}), 404

        # Convert times from ISO format
        start_time = datetime.fromisoformat(start_time)
        end_time = datetime.fromisoformat(end_time)

        # Create a new calendar entry
        new_entry = CalendarEntry(
            child_id=child_id,
            activity_name=activity_name,
            start_time=start_time,
            end_time=end_time,
            activity_notes=activity_notes
        )

        db.session.add(new_entry)
        db.session.commit()

        return jsonify({'message': 'Activity added successfully', 'activity_id': new_entry.id}), 201

    except Exception as e:
        print(f"Error during adding activity: {e}")
        return jsonify({'message': 'Failed to add activity', 'error': str(e)}), 500

@app.route('/calendar_entries/<int:child_id>', methods=['GET'])
def get_calendar_entries(child_id):
    try:
        # Query calendar entries for the given child_id
        entries = CalendarEntry.query.filter_by(child_id=child_id).all()

        # Serialize the entries
        activities = [
            {
                'id': entry.id,
                'activity_name': entry.activity_name,
                'start_time': entry.start_time.isoformat(),
                'end_time': entry.end_time.isoformat(),
                'activity_notes': entry.activity_notes,
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
        entry = CalendarEntry.query.get(entry_id)

        if not entry:
            return jsonify({'message': 'Activity not found'}), 404

        data = request.get_json()
        entry.activity_name = data.get('activity_name', entry.activity_name)
        entry.start_time = datetime.fromisoformat(data.get('start_time', entry.start_time))
        entry.end_time = datetime.fromisoformat(data.get('end_time', entry.end_time))
        entry.activity_notes = data.get('activity_notes', entry.activity_notes)

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


if __name__ == '__main__':
    app.run(debug=True, host="0.0.0.0")
