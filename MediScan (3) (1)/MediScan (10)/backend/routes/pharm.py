from flask import Blueprint, jsonify

pharm_bp = Blueprint('pharm', __name__)

@pharm_bp.route('/test', methods=['GET'])
def test():
    return jsonify({'success': True, 'message': 'test works'}), 200

@pharm_bp.route('/ping', methods=['GET'])
def ping():
    return jsonify({'success': True, 'message': 'pong'}), 200

@pharm_bp.route('/check', methods=['GET'])
def check():
    return jsonify({'success': True, 'message': 'check works'}), 200