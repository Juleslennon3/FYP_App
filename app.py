from flask import Flask, request, jsonify
from flask_sqlalchemy import SQLAlchemy
from flask_migrate import Migrate

app = Flask(__name__)

app.config['SQLALCHEMY_DATABASE_URI'] = 'mysql+mysqlconnector://root:1FootballFan!!@localhost/FYP'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

db = SQLAlchemy(app)
migrate = Migrate(app, db)

# Define the User model
class User(db.Model):
    __tablename__ = 'users'
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(80), nullable=False)
    email = db.Column(db.String(120), unique=True, nullable=False)
    password = db.Column(db.String(120), nullable=False)

    def __repr__(self):
        return f'<User {self.name}>'

# Define the Child model
class Child(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(80), nullable=False)
    age = db.Column(db.Integer, nullable=False)
    guardian_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)

    def __repr__(self):
        return f'<Child {self.name}>'

@app.route('/register', methods=['POST'])
def register():
    data = request.get_json()
    name = data['name']
    email = data['email']
    password = data['password']

    # Check if user already exists
    existing_user = User.query.filter_by(email=email).first()
    if existing_user:
        return jsonify({'message': 'User already exists'}), 400

    # Create a new user
    new_user = User(name=name, email=email, password=password)
    db.session.add(new_user)
    db.session.commit()

    return jsonify({'message': 'User registered successfully'}), 200

@app.route('/login', methods=['POST'])
def login():
    data = request.get_json()
    email = data['email']
    password = data['password']

    # Check if user exists and the password matches
    user = User.query.filter_by(email=email, password=password).first()
    if user:
        return jsonify({'message': 'Login successful'}), 200
    else:
        return jsonify({'message': 'Invalid credentials'}), 401

@app.route('/add_child', methods=['POST'])
def add_child():
    data = request.get_json()
    name = data['name']
    age = data['age']
    guardian_id = data['guardian_id']

    new_child = Child(name=name, age=age, guardian_id=guardian_id)
    db.session.add(new_child)
    db.session.commit()

    return jsonify({'message': 'Child added successfully'}), 200

@app.route('/view_children/<int:guardian_id>', methods=['GET'])
def view_children(guardian_id):
    children = Child.query.filter_by(guardian_id=guardian_id).all()
    children_list = [{'id': child.id, 'name': child.name, 'age': child.age} for child in children]
    return jsonify(children_list), 200

@app.route('/update_child/<int:child_id>', methods=['PUT'])
def update_child(child_id):
    data = request.get_json()
    child = Child.query.get(child_id)

    if not child:
        return jsonify({'message': 'Child not found'}), 404

    child.name = data.get('name', child.name)
    child.age = data.get('age', child.age)
    db.session.commit()

    return jsonify({'message': 'Child updated successfully'}), 200

if __name__ == '__main__':
    app.run(debug=True, host="0.0.0.0")  # Allows connections from other devices on the network
