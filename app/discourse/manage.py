#!/usr/bin/env python3
"""Build the official Discourse image; resolve dotenv with Compose, never a shell."""
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import subprocess
import sys
import tempfile

HERE = Path(__file__).resolve().parent
COMPOSE = ['docker', 'compose', '--env-file', str(HERE / '.env'),
           '-f', str(HERE / 'docker-compose.yml')]
SOURCE = 'https://github.com/discourse/discourse_docker.git'
GENERATED_IMAGE = 'local_discourse/discourse:latest'


def capture(args):
    return subprocess.check_output(args, cwd=HERE, text=True, stderr=subprocess.PIPE).strip()


def resolve():
    app = json.loads(capture(COMPOSE + ['config', '--format', 'json']))['services']['discourse']
    labels = app['labels']
    data = Path(labels['io.pigsty.discourse.data'])
    # The classic Launcher splits host mount paths in shell arguments.
    if (not re.fullmatch(r'/[A-Za-z0-9_./-]+', str(data)) or '..' in data.parts
            or len(data.parts) < 4 or data.is_symlink()):
        raise ValueError('DISCOURSE_DATA must be a dedicated absolute directory without shell characters or symlinks')
    if data.resolve() != data:
        raise ValueError('DISCOURSE_DATA must not traverse symlinks')
    ref = labels['io.pigsty.discourse.docker-ref']
    if not re.fullmatch(r'[0-9a-f]{40}', ref):
        raise ValueError('DISCOURSE_DOCKER_REF must be a full reviewed commit SHA')
    version = labels['io.pigsty.discourse.version']
    if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_./-]*', version):
        raise ValueError('DISCOURSE_VERSION must be a Git ref without shell characters')
    memory = labels['io.pigsty.discourse.redis-memory']
    if not re.fullmatch(r'[1-9][0-9]*(mb|gb)', memory.lower()):
        raise ValueError('REDIS_MAX_MEMORY must be a positive value such as 512mb')
    # Compose escapes literal dollars again when exporting a reusable config.
    # Launcher takes actual environment values, not Compose interpolation text.
    env = app['environment'] = {k: str(v).replace('$$', '$')
                                for k, v in app['environment'].items()}
    if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9.-]*', env['DISCOURSE_HOSTNAME']):
        raise ValueError('DISCOURSE_HOSTNAME must be a DNS name, without a URL or port')
    if env['DISCOURSE_DB_HOST'] in ['localhost', '127.0.0.1', '::1']:
        raise ValueError('PG_HOST must be reachable from the container bridge; localhost points into the container')
    if any('\n' in str(v) or '\r' in str(v) for v in env.values()):
        raise ValueError('Application environment values must not contain newlines')
    return app, data, ref, version, memory.lower()


def definition(app, data, version, memory):
    directives = ['bind 127.0.0.1', 'protected-mode yes', f'maxmemory {memory}',
                  'maxmemory-policy noeviction', 'appendonly yes', 'appendfsync everysec']
    return {
        'templates': ['templates/redis.template.yml', 'templates/web.template.yml',
                      'templates/web.ratelimited.template.yml', 'templates/web.socketed.template.yml'],
        'params': {'version': version},
        'env': app['environment'],
        'volumes': [{'volume': {'host': str(data / 'shared'), 'guest': '/shared'}},
                    {'volume': {'host': str(data / 'shared/log/var-log'), 'guest': '/var/log'}}],
        'hooks': {'after_redis': [{'exec': {'cmd': "printf '%s\\n' " +
                   ' '.join(shlex.quote(d) for d in directives) + ' >> /etc/redis/redis.conf'}}]},
    }


def write_private(path, contents):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix='.discourse-', dir=path.parent)
    try:
        with os.fdopen(fd, 'w') as f:
            f.write(contents)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def fingerprint(app):
    return hashlib.sha256(json.dumps(app, sort_keys=True).encode()).hexdigest()


def current_image_id(image):
    try:
        return capture(['docker', 'image', 'inspect', '--format', '{{.Id}}', image])
    except subprocess.CalledProcessError:
        return None


def built(app, data):
    receipt = data / '.build.json'
    if not receipt.exists():
        return False
    state = json.loads(receipt.read_text())
    return (state.get('config') == fingerprint(app)
            and state.get('image') == current_image_id(app['image']))


def checkout(data, ref):
    repo = data / 'launcher'
    new_checkout = not repo.exists()
    if new_checkout:
        subprocess.run(['git', 'clone', '--filter=blob:none', '--no-checkout', SOURCE, str(repo)], check=True)
    if capture(['git', '-C', str(repo), 'remote', 'get-url', 'origin']) != SOURCE:
        raise ValueError('launcher checkout has a different origin; refusing to replace it')
    if not new_checkout and capture(['git', '-C', str(repo), 'status', '--porcelain', '--untracked-files=no']):
        raise ValueError('launcher checkout has local changes; preserve/review them before building')
    subprocess.run(['git', '-C', str(repo), 'fetch', '--depth=1', 'origin', ref], check=True)
    subprocess.run(['git', '-C', str(repo), 'checkout', '--detach', ref], check=True)
    return repo


def scrub(line, env):
    # Launcher and pups can echo configuration; never log private values.
    secrets = [v for k, v in env.items() if v and any(s in k for s in ['PASSWORD', 'SECRET', 'KEY'])]
    variants = set()
    for secret in secrets:
        variants.update([secret, shlex.quote(secret), json.dumps(secret)[1:-1]])
    for value in sorted(variants, key=len, reverse=True):
        line = line.replace(value, '<redacted>')
    return line


def build(app, data, ref, version, memory):
    env = app['environment']
    if env['DISCOURSE_SKIP_EMAIL_SETUP'] != '1' and env['DISCOURSE_SMTP_ADDRESS'] in ['', 'smtp.example.com']:
        raise ValueError('configure SMTP before building; DISCOURSE_SKIP_EMAIL_SETUP=1 is for isolated tests only')
    repo = checkout(data, ref)
    config = definition(app, data, version, memory)
    write_private(repo / 'containers/discourse.yml', json.dumps(config, indent=2) + '\n')
    (data / 'shared/log/var-log').mkdir(parents=True, exist_ok=True)
    # bootstrap starts Redis against the shared volume. Stop the sole old app
    # first. A manually started Launcher instance must be stopped by its owner.
    subprocess.run(COMPOSE + ['stop', 'discourse'], check=True)
    status = capture(['docker', 'ps', '--filter', 'name=^/discourse$', '--format', '{{.Names}}'])
    if status:
        raise ValueError('discourse is still running; stop it before bootstrap to protect Redis data')
    print('Building Discourse with the classic Launcher; existing data is retained.', flush=True)
    process = subprocess.Popen([str(repo / 'launcher'), 'bootstrap', 'discourse'], cwd=repo,
                               stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    for line in process.stdout:
        print(scrub(line, env), end='', flush=True)
    if process.wait():
        raise ValueError('Discourse bootstrap failed; the previous application remains stopped')
    if app['image'] != GENERATED_IMAGE:
        subprocess.run(['docker', 'tag', GENERATED_IMAGE, app['image']], check=True)
    record_build(app, data, ref, version)


def record_build(app, data, ref, version):
    state = {'config': fingerprint(app), 'image': current_image_id(app['image']),
             'launcher': ref, 'version': version}
    if not state['image']:
        raise ValueError('Launcher completed without creating the application image')
    state['commit'] = capture(['docker', 'run', '--rm', '--user', 'discourse', '--entrypoint', 'git',
                              app['image'], '-C', '/var/www/discourse', 'rev-parse', 'HEAD'])
    write_private(data / '.build.json', json.dumps(state, indent=2) + '\n')


def save(app):
    archive = Path('/tmp/docker/discourse.tgz')
    archive.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix='.discourse-', dir=archive.parent)
    try:
        with os.fdopen(fd, 'wb') as output:
            producer = subprocess.Popen(['docker', 'save', app['image']], stdout=subprocess.PIPE)
            compressor = subprocess.run(['gzip', '-c'], stdin=producer.stdout, stdout=output)
            producer.stdout.close()
            if producer.wait() or compressor.returncode:
                raise ValueError('image export failed')
        os.replace(temporary, archive)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)
    print(f'Private image saved to {archive}; shared data and PostgreSQL are not included.')


def main():
    action = sys.argv[1] if len(sys.argv) == 2 else ''
    if action not in ['config', 'view', 'build', 'up', 'rebuild', 'start', 'save']:
        raise ValueError('usage: manage.py config|view|build|up|rebuild|start|save')
    app, data, ref, version, memory = resolve()
    if action == 'view':
        scheme = 'https' if app['environment']['DISCOURSE_FORCE_HTTPS'] == 'true' else 'http'
        print(f"visit {scheme}://{app['environment']['DISCOURSE_HOSTNAME']}")
        print(f'Pigsty Nginx upstream: unix:{data}/shared/nginx.http.sock')
        return
    if action == 'config':
        config = definition(app, data, version, memory)
        config['env'] = {k: ('<redacted>' if any(s in k for s in ['PASSWORD', 'SECRET', 'KEY']) else v)
                         for k, v in config['env'].items()}
        print(json.dumps(config, indent=2))
        return
    data.mkdir(parents=True, exist_ok=True)
    # Serialize builds and app startup even when Make is run with -j.
    with (data / '.build.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        if action == 'save':
            save(app)
        elif action in ['build', 'rebuild'] or (action == 'up' and not built(app, data)):
            build(app, data, ref, version, memory)
        elif action == 'start' and not built(app, data):
            raise ValueError('configuration/image differs from the build; run make up or make rebuild')
        if action in ['up', 'rebuild', 'start']:
            subprocess.run(COMPOSE + ['up', '-d', '--wait', '--wait-timeout', '300', 'discourse'], check=True)


if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError, subprocess.CalledProcessError, json.JSONDecodeError) as error:
        # Compose's stderr can contain resolved credentials; do not echo it.
        print('ERROR: ' + str(error), file=sys.stderr)
        sys.exit(1)
