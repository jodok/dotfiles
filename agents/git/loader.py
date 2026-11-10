#!/usr/bin/env python3
"""Load exactly one agent's approved Git pair using its designated service account."""
import errno
import fcntl
import json
import os
from pathlib import Path
import signal
import re
import socket
import stat
import subprocess
import sys
import time


class IdentityError(Exception):
    pass


def command(argv, env, data=None, timeout=30):
    p=subprocess.run(argv,input=data,env=env,stdin=subprocess.DEVNULL if data is None else None,
                     capture_output=True,timeout=timeout)
    if p.returncode:raise IdentityError('identity operation failed')
    return p.stdout


def environment(token, sock):
    result={k:v for k,v in os.environ.items() if not k.startswith(('OP_', 'SSH_','PYTHON'))}
    result.update(OP_SERVICE_ACCOUNT_TOKEN=token,SSH_AUTH_SOCK=str(sock),PATH='/usr/bin:/bin:/usr/sbin:/sbin')
    return result


def holds(cfg, env):
    try:
        keys=command([cfg['programs']['ssh-add'],'-L'],env).decode().splitlines()
        return {' '.join(k.split()[:2]) for k in keys}==set(cfg['public_keys'])
    except Exception:return False


def ensure(root):
    root=Path(root).resolve()
    cfg=json.loads((root/'identity.json').read_text())
    sock=root/'run/agent.sock'
    token=os.environ.get('OP_SERVICE_ACCOUNT_TOKEN')
    if not token:raise IdentityError('designated service account required')
    env=environment(token,sock)
    if holds(cfg,env):return cfg,env
    sock.parent.mkdir(mode=0o700,exist_ok=True)
    if stat.S_IMODE(sock.parent.stat().st_mode)!=0o700:raise IdentityError('unsafe agent directory')
    with (sock.parent/'agent.lock').open('a') as lock:
        os.chmod(lock.name,0o600)
        deadline=time.monotonic()+20
        while True:
            try:fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB);break
            except BlockingIOError:
                if time.monotonic()>=deadline:raise IdentityError('agent load busy')
                time.sleep(0.05)
        if holds(cfg,env):return cfg,env
        op=cfg['programs']['op']
        identity=json.loads(command([op,'whoami','--format=json'],env))
        if (identity.get('user_type')!='SERVICE_ACCOUNT' or identity.get('account_uuid')!=cfg['account_id']
                or identity.get('user_uuid')!=cfg['principal_id']):
            raise IdentityError('wrong service account')
        # Fetch both keys before changing a socket. No operator-session fallback.
        private=[]
        for item in cfg['item_ids']:
            uri=f"op://{cfg['vault_id']}/{item}/private key?ssh-format=openssh"
            private.append(command([op,'read',uri],env).rstrip()+b'\n')
        if sock.exists() or sock.is_symlink():
            if sock.is_symlink() or not stat.S_ISSOCK(sock.stat().st_mode):
                raise IdentityError('refusing non-socket agent path')
            probe=socket.socket(socket.AF_UNIX,socket.SOCK_STREAM)
            try:
                probe.connect(str(sock))
            except OSError as error:
                if error.errno not in (errno.ECONNREFUSED,errno.ENOENT):raise
                sock.unlink(missing_ok=True)
            else:raise IdentityError('existing agent holds unexpected keys')
            finally:probe.close()
        agent_env=dict(env)
        agent_env.pop('OP_SERVICE_ACCOUNT_TOKEN',None)
        started=command([cfg['programs']['ssh-agent'],'-s','-a',str(sock)],agent_env).decode()
        pid_match=re.search(r'^SSH_AGENT_PID=([0-9]+);',started,re.M)
        if not pid_match:raise IdentityError('agent returned no process identity')
        pid=int(pid_match[1])
        try:
            for _ in range(60):
                if sock.exists():break
                time.sleep(0.05)
            else:raise IdentityError('agent start timed out')
            for key in private:command([cfg['programs']['ssh-add'],'-'],agent_env,key)
            if not holds(cfg,agent_env):raise IdentityError('loaded keys differ from approved public keys')
            (sock.parent/'agent.pid').write_text(str(pid)+'\n')
            os.chmod(sock.parent/'agent.pid',0o600)
        except BaseException:
            try:os.kill(pid,signal.SIGTERM)
            except ProcessLookupError:pass
            raise
    return cfg,env


def main():
    cfg,env=ensure(Path(__file__).resolve().parent)
    env.pop('OP_SERVICE_ACCOUNT_TOKEN',None)
    mode=sys.argv[1:2]
    if mode==['--load'] and len(sys.argv)==2:return 0
    if mode==['--sign']:
        os.execve(cfg['programs']['ssh-keygen'],[cfg['programs']['ssh-keygen'],*sys.argv[2:]],env)
    if mode==['--transport']:
        ssh=cfg['programs']['ssh']
        os.execve(ssh,[ssh,'-F',str(Path(__file__).resolve().parent/'ssh_config'),*sys.argv[2:]],env)
    raise IdentityError('unsupported agent operation')


if __name__=='__main__':
    try:sys.exit(main())
    except Exception:
        print('Agent Git identity unavailable; verify its service account and installed public keys.',file=sys.stderr)
        sys.exit(1)
