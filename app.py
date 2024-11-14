from flask import Flask, request, jsonify
from flask_sqlalchemy import SQLAlchemy
from flask_migrate import Migrate
from werkzeug.security import generate_password_hash, check_password_hash
import requests
import base64

app = Flask(__name__)
app.config['SQLALCHEMY_DATABASE_URI'] = 'mysql+mysqlconnector://root:1FootballFan!!@localhost/FYP'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
db = SQLAlchemy(app)
migrate = Migrate(app, db)


class User(db.Model):
    __tablename__ = 'users'
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(80), nullable=False)
    email = db.Column(db.String(120), unique=True, nullable=False)
    password = db.Column(db.String(255), nullable=False)


class Child(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(80), nullable=False)
    age = db.Column(db.Integer, nullable=False)
    guardian_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    fitbit_access_token = db.Column(db.String(255), nullable=True)
    fitbit_refresh_token = db.Column(db.String(255), nullable=True)
    token_expires_in = db.Column(db.Integer, nullable=True)


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
        # Print the exception to console for debugging
        print(f"Error during registration: {e}")
        return jsonify({'message': 'Registration failed', 'error': str(e)}), 500


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
    data = request.get_json()
    name = data.get('name')
    age = data.get('age')
    guardian_id = data.get('guardian_id')  # Ensure the user's ID is passed here

    if not name or not age or not guardian_id:
        return jsonify({'message': 'Name, age, and guardian_id are required'}), 400

    try:
        new_child = Child(name=name, age=age, guardian_id=guardian_id)
        db.session.add(new_child)
        db.session.commit()
        return jsonify({'message': 'Child added successfully', 'child_id': new_child.id}), 201
    except Exception as e:
        print(f"Error during adding child: {e}")
        return jsonify({'message': 'Failed to add child', 'error': str(e)}), 500


@app.route('/view_children/<int:guardian_id>', methods=['GET'])
def view_children(guardian_id):
    children = Child.query.filter_by(guardian_id=guardian_id).all()
    if children:
        children_data = [{'id': child.id, 'name': child.name, 'age': child.age} for child in children]
        return jsonify(children_data), 200
    else:
        return jsonify({'message': 'No children found'}), 404


@app.route('/fitbit_callback', methods=['GET'])
def fitbit_callback():
    code = request.args.get('code')
    child_id = request.args.get('state')  # We use 'state' to get the child_id from the URL
    client_id = '23PVVG'
    client_secret = 'e87a3c8c746462bfff0c8dd8b5ccf675'
    redirect_uri = 'https://2927-37-228-233-126.ngrok-free.app/fitbit_callback'

    if not code:
        return jsonify({'message': 'Authorization code not found'}), 400

    # Exchange authorization code for tokens
    token_url = 'https://api.fitbit.com/oauth2/token'
    data = {
        'client_id': client_id,
        'grant_type': 'authorization_code',
        'redirect_uri': redirect_uri,
        'code': code,
    }
    headers = {
        'Authorization': 'Basic ' + base64.b64encode(f'{client_id}:{client_secret}'.encode()).decode(),
        'Content-Type': 'application/x-www-form-urlencoded',
    }

    response = requests.post(token_url, data=data, headers=headers)
    if response.status_code == 200:
        tokens = response.json()
        access_token = tokens['access_token']
        refresh_token = tokens['refresh_token']
        expires_in = tokens['expires_in']

        # Save tokens to the child profile in the database
        child = Child.query.get(child_id)
        if child:
            child.fitbit_access_token = access_token
            child.fitbit_refresh_token = refresh_token
            child.token_expires_in = expires_in
            db.session.commit()
            return jsonify({'message': 'Fitbit account linked successfully'}), 200
        else:
            return jsonify({'message': 'Child not found'}), 404
    else:
        return jsonify({'message': 'Failed to exchange code for token'}), 500


import requests

@app.route('/fitbit_data/<int:child_id>', methods=['GET'])
def get_fitbit_data(child_id):
    child = Child.query.get(child_id)
    if not child:
        return jsonify({'message': 'Child not found'}), 404

    # Check if the access token is present
    access_token = child.fitbit_access_token
    if not access_token:
        return jsonify({'message': 'Fitbit access token not available'}), 400

    # Make a request to the Fitbit API to get heart rate data (or any other data)
    headers = {
        'Authorization': f'Bearer {access_token}',
    }
    url = 'https://api.fitbit.com/1/user/-/activities/heart/date/today/1d.json'  # Example for heart rate data
    response = requests.get(url, headers=headers)

    if response.status_code == 200:
        # Return the Fitbit data in the response
        data = response.json()
        return jsonify(data), 200
    else:
        return jsonify({'message': 'Failed to fetch Fitbit data', 'error': response.text}), 500

@app.route('/refresh_fitbit_token/<int:child_id>', methods=['POST'])
def refresh_fitbit_token(child_id):
    child = Child.query.get(child_id)
    if not child or not child.fitbit_refresh_token:
        return jsonify({'message': 'Child or refresh token not found'}), 404

    refresh_token = child.fitbit_refresh_token
    client_id = '23PVVG'
    client_secret = 'e87a3c8c746462bfff0c8dd8b5ccf675'
    redirect_uri = 'https://2927-37-228-233-126.ngrok-free.app/fitbit_callback'

    # Prepare the request to refresh the token
    token_url = 'https://api.fitbit.com/oauth2/token'
    data = {
        'grant_type': 'refresh_token',
        'refresh_token': refresh_token,
        'client_id': client_id,
        'redirect_uri': redirect_uri
    }
    headers = {
        'Authorization': 'Basic ' + base64.b64encode(f'{client_id}:{client_secret}'.encode()).decode(),
        'Content-Type': 'application/x-www-form-urlencoded',
    }

    response = requests.post(token_url, data=data, headers=headers)

    if response.status_code == 200:
        tokens = response.json()
        new_access_token = tokens['access_token']
        expires_in = tokens['expires_in']

        # Update the access token and its expiry in the database
        child.fitbit_access_token = new_access_token
        child.token_expires_in = expires_in
        db.session.commit()

        return jsonify({'message': 'Fitbit token refreshed successfully'}), 200
    else:
        return jsonify({'message': 'Failed to refresh token', 'error': response.text}), 500


if __name__ == '__main__':
    app.run(debug=True, host="0.0.0.0")
