import requests

text = 'Hello, how are you today? This is a test.'

r = requests.post('http://0.0.0.0:8443/predictions/bert', data = text.encode(encoding='utf-8'), headers={'Content-Type': 'application/json"'})
response = r.json()
print(response)
