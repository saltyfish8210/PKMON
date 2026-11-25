"""Local dev acceptance: Python 3 + curl; start server as in docs/api.md."""
import argparse
import datetime
import json
from pathlib import Path
import subprocess
import time
import uuid
from urllib.parse import urlsplit

parser = argparse.ArgumentParser()
parser.add_argument('--base', default='http://127.0.0.1:4191/api/v1')
parser.add_argument('--examples', type=Path)
args = parser.parse_args()
if urlsplit(args.base).hostname not in {'127.0.0.1', 'localhost', '::1'}:
    parser.error('Only a disposable local dev server is supported')
root = Path(__file__).resolve().parents[1]
catalog = json.loads((root / 'server/src/main/resources/catalog/stage4.json').read_text(encoding='utf8'))
answers = {item['questionId']: item['correctOptionId'] for item in catalog['questions']}
token = None
snapshots = {}

def uid():
    return str(uuid.uuid4())

def call(method, route, body=None, sample=None, expected=0):
    command = ['curl', '--silent', '--show-error', '--max-time', '20', '--noproxy', '*', '-X', method, args.base + route]
    if token:
        command += ['-H', 'Authorization: Bearer ' + token]
    if body is not None:
        command += ['-H', 'Content-Type: application/json', '--data-binary', '@-']
    raw = subprocess.run(command, input=json.dumps(body).encode() if body is not None else None,
                         stdout=subprocess.PIPE, check=True).stdout
    reply = json.loads(raw)
    if reply['code'] != expected:
        raise RuntimeError(f'{method} {route}: {reply}')
    if sample:
        snapshots[sample] = reply
    return reply['data']

def login(label, save=False):
    credentials = {'username': 'm06_' + uid()[:12].replace('-', '_'), 'password': uid()}
    call('POST', '/auth/register', dict(credentials, nickname=label), 'register' if save else None)
    return call('POST', '/auth/login', credentials, 'login' if save else None)['token']

def markers(lat=39.9042, radius=200, sample=None):
    return call('GET', f'/capture/nearby?lat={lat}&lng=116.4074&radius={radius}', sample=sample)['items']

def require(condition, label):
    if not condition:
        raise AssertionError(label)

other = login('对照账号')
token = login('接口验收', True)
owner = token
try:
    call('GET', '/users/me', sample='me')
    task = call('POST', '/study/tasks', dict(requestId=uid(), regionId='library_entrance', locationSource='SIMULATED'), 'tasks')
    path = '/study/tasks/' + task['taskId']
    call('GET', '/study/tasks/current', sample='current')
    for attempt in range(min(task['requiredSeconds'] + 15, 630)):
        sample = call('POST', path + '/samples', dict(sampleId=uid(), latitude=39.9042, longitude=116.4074,
                     accuracyMeters=8, sampledAt=datetime.datetime.now(datetime.timezone.utc).isoformat(),
                     coordinateSystem='GCJ02', source='SIMULATED'), 'samples')
        if sample.get('spawnId'):
            break
        time.sleep(1.05)
    spawn = sample['spawnId']
    nearby = markers(39.90455, sample='nearby')
    require(any(item['spawnId'] == spawn and 37 <= item['distanceMeters'] <= 41 for item in nearby), 'inside radius')
    require(not markers(39.9061) and markers(radius=0), 'outside 200m / exact center')
    token = other
    require(not markers(), 'owner isolation')
    token = owner
    seen = []
    for index in range(11):
        if index:
            spawn = call('POST', '/dev/spawns', dict(regionId='library_entrance', speciesId='study_spirit'))['spawnId']
        challenge = call('POST', '/capture/challenge', dict(spawnId=spawn), 'challenge' if not index else None)
        repeat = call('POST', '/capture/challenge', dict(spawnId=spawn))
        require(challenge == repeat and 'correctOptionId' not in challenge, 'stable challenge')
        question = challenge['questionId']
        require(question not in seen[-9:], 'duplicate question in rolling ten')
        seen.append(question)
        payload = dict(challengeId=challenge['challengeId'], requestId=uid(), optionId=answers[question])
        result = call('POST', '/capture/answer', payload, 'answer' if not index else None)
        require(result['result'] == 'CORRECT' and result == call('POST', '/capture/answer', payload), 'answer replay')
        if not index:
            call('POST', '/capture/status', {'challengeId':challenge['challengeId']}, 'status')
            require(not markers(), 'captured marker removed')
            summary = call('GET', '/collection/summary', sample='summary')
            dex = call('GET', '/collection/dex', sample='dex')
            bag = call('GET', '/collection/bag', sample='bag')
            require(summary['totalSpeciesCount'] == len(dex['entries']) == 8, 'catalog size')
            require(summary['collectedSpeciesCount'] == dex['collectedSpeciesCount'] == bag['speciesCount'] == 1, 'species count')
            require(sum(item['count'] for item in dex['entries']) == summary['captureCount'] == bag['totalCount'] == 1, 'capture total')
    call('POST', path + '/end', {'requestId':uid()}, 'end')
finally:
    for session in (other, owner):
        token = session
        call('POST', '/auth/logout', {}, 'logout' if session == owner else None)
call('GET', '/users/me', expected=40101)
if args.examples:
    args.examples.mkdir(exist_ok=True, parents=True)
    for name, example in snapshots.items():
        if name == 'login':
            example = dict(example, data=dict(example['data'], token='<REDACTED>'))
        (args.examples / (name+'.json')).write_text(json.dumps(example, ensure_ascii=False, indent=2) + '\n', encoding='utf8')
print(f'PASS: {len(snapshots)} endpoints; nearby bounds, ownership, captures, counters, 11 challenges and both logouts.')
