#!/usr/bin/env python3
"""Explicit per-agent cutover. No secret or credential is read from a repository."""
import argparse
import copy
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import stat
import subprocess
import sys
import tempfile
import tomllib


def write(path, data, mode=0o600):
    path=Path(path)
    if path.is_symlink():raise ValueError('refusing symlink output')
    path.parent.mkdir(parents=True,exist_ok=True,mode=0o700)
    fd,tmp=tempfile.mkstemp(prefix='.agent-git-',dir=path.parent)
    try:
        os.fchmod(fd,mode)
        with os.fdopen(fd,'w') as stream:stream.write(data);stream.flush();os.fsync(stream.fileno())
        os.replace(tmp,path)
    finally:
        if os.path.exists(tmp):os.unlink(tmp)


def checked(path):
    path=Path(path)
    if path.is_symlink():raise ValueError('refusing symlink input')
    return path.read_text() if path.exists() else ''


def public(value):
    parts=value.strip().split()
    if len(parts)<2 or parts[0] not in ('ssh-ed25519','ssh-rsa') or not re.fullmatch('[A-Za-z0-9+/=]+',parts[1]):
        raise ValueError('invalid public key')
    return ' '.join(parts[:2])


def program(name):
    path=shutil.which(name)
    if not path:raise ValueError('missing required program')
    return str(Path(path).resolve())


def read_pair(account,principal,vault,items):
    from_env=os.environ.get('OP_SERVICE_ACCOUNT_TOKEN')
    if not from_env:raise ValueError('designated service-account token required')
    ctx={k:v for k,v in os.environ.items() if not k.startswith('OP_')}
    ctx['OP_SERVICE_ACCOUNT_TOKEN']=from_env
    def op(*args):
        p=subprocess.run([program('op'),*args],env=ctx,capture_output=True,text=True,stdin=subprocess.DEVNULL,timeout=30)
        if p.returncode:raise ValueError('service-account read failed')
        return p.stdout
    identity=json.loads(op('whoami','--format=json'))
    if identity.get('user_type')!='SERVICE_ACCOUNT' or identity.get('account_uuid')!=account or identity.get('user_uuid')!=principal:
        raise ValueError('wrong service account')
    return [public(op('read',f'op://{vault}/{item}/public key')) for item in items]


def install(home,agent,account,principal,vault,items,keys,programs,refresh_tools=False):
    home=Path(home).resolve()
    root=home/('.'+agent)/'agent-git'
    for parent in (home/('.'+agent),root):
        if parent.is_symlink():raise ValueError('refusing symlink identity directory')
    if len(set(keys))!=2:raise ValueError('authentication and signing keys must differ')
    if agent=='codex':
        legacy=set()
        for name in ('claude-signing.pub','claude-auth.pub'):
            text=checked(home/'.claude'/name)
            if text:legacy.add(public(text))
        if legacy & set(keys):raise ValueError('Codex must not reuse the legacy Claude pair')
    other=home/('.'+('codex' if agent=='claude' else 'claude'))/'agent-git/identity.json'
    other_cfg=checked(other)
    if other_cfg:
        other_cfg=json.loads(other_cfg)
        if set(other_cfg['public_keys']) & set(keys):raise ValueError('another agent already uses one of these keys')
        if other_cfg['account_id']==account and (other_cfg['principal_id']==principal or other_cfg['vault_id']==vault):
            raise ValueError('agents require distinct service accounts and vaults')
    cfg=dict(schema=1,agent=agent,account_id=account,principal_id=principal,vault_id=vault,
             item_ids=items,public_keys=keys,programs=programs)
    # Avoid replacing a configured reader with a different one as an implicit update.
    existing=checked(root/'identity.json')
    if existing:
        prior=json.loads(existing)
        expected=dict(cfg)
        if refresh_tools:expected['programs']=prior.get('programs')
        if prior!=expected:raise ValueError('existing identity differs; review a separate rotation/cutover')
    invocation=shlex.quote(programs['python'])+' -I '+shlex.quote(str(root/'loader.py'))
    contents={
        'identity.json':json.dumps(cfg,indent=2,sort_keys=True)+'\n',
        'loader.py':Path(__file__).with_name('loader.py').read_text(),
        'signing.pub':keys[0]+'\n','auth.pub':keys[1]+'\n',
        'allowed_signers':'jodok@batlogg.com '+keys[0]+'\n',
        'gitconfig.xdg':'[include]\n\tpath = '+str(Path(os.environ.get('XDG_CONFIG_HOME',str(home/'.config')))/'git/config')+'\n',
        'sign':'#!/bin/sh\nexec '+invocation+' --sign "$@"\n',
        'transport':'#!/bin/sh\nexec '+invocation+' --transport "$@"\n',
        'ssh_config':'Host github.com\n  HostName github.com\n  User git\nHost *\n  IdentityAgent '+json.dumps(str(root/'run/agent.sock'),ensure_ascii=False)+'\n  IdentityFile '+json.dumps(str(root/'auth.pub'),ensure_ascii=False)+'\n  IdentitiesOnly yes\n',
    }
    for name,content in contents.items():write(root/name,content,0o700 if name in ('sign','transport') else 0o600)
    # Use Git's own serializer to avoid quoting path/config values by hand.
    fd,tmp=tempfile.mkstemp(prefix='.gitconfig-',dir=root);os.close(fd)
    try:
        values=[('include.path',str(root/'gitconfig.xdg')),('include.path',str(home/'.gitconfig')),
                ('user.name','Jodok Batlogg'),('user.email','jodok@batlogg.com'),('user.signingkey',str(root/'signing.pub')),
                ('gpg.format','ssh'),('gpg.ssh.program',shlex.quote(str(root/'sign'))),
                ('gpg.ssh.allowedSignersFile',str(root/'allowed_signers')),('commit.gpgsign','true'),
                ('core.sshCommand',shlex.quote(str(root/'transport'))),('core.askPass','/usr/bin/false'),
                ('credential.https://github.com.helper','')]
        values += [('url.git@github.com:.insteadOf',url) for url in ('https://github.com/','https://jodok@github.com/','http://github.com/','git://github.com/')]
        for name,value in values:
            subprocess.run([programs['git'],'config','--file',tmp,'--add',name,value],check=True,capture_output=True)
        write(root/'gitconfig',Path(tmp).read_text())
    finally:os.unlink(tmp)
    return root


def codex_settings(text,values):
    before=tomllib.loads(text)
    policy=before.get('shell_environment_policy',{})
    if policy.get('filters') or policy.get('include_only'):
        raise ValueError('review restrictive environment filters before activation')
    target=copy.deepcopy(before)
    target.setdefault('shell_environment_policy',{}).setdefault('set',{}).update(values)
    lines=text.splitlines(keepends=True)
    heads=[i for i,line in enumerate(lines) if re.fullmatch(r'\s*\[shell_environment_policy\.set\]\s*(?:#.*)?\n?',line)]
    if len(heads)>1:raise ValueError('ambiguous Codex environment table')
    if not heads:
        if before.get('shell_environment_policy',{}).get('set'):raise ValueError('unsupported inline Codex environment table')
        result=text.rstrip()+'\n\n[shell_environment_policy.set]\n'+''.join(k+' = '+json.dumps(v)+'\n' for k,v in values.items())
    else:
        start=heads[0]+1
        end=next((i for i in range(start,len(lines)) if lines[i].lstrip().startswith('[')),len(lines))
        pending=dict(values)
        for i in range(start,end):
            match=re.match(r'\s*([A-Za-z0-9_]+)\s*=',lines[i])
            if match and match[1] in pending:lines[i]=match[1]+' = '+json.dumps(pending.pop(match[1]))+'\n'
        if pending and end and not lines[end-1].endswith('\n'):lines[end-1]+='\n'
        lines[end:end]=[k+' = '+json.dumps(v)+'\n' for k,v in pending.items()]
        result=''.join(lines)
    if tomllib.loads(result)!=target:raise ValueError('Codex config changed outside managed values')
    return result


def activate(home,agent,root,token):
    home,root=Path(home),Path(root)
    cfg=json.loads(checked(root/'identity.json'))
    # Probe the designated identity before replacing a working provider config.
    if read_pair(cfg['account_id'],cfg['principal_id'],cfg['vault_id'],cfg['item_ids'])!=cfg['public_keys']:
        raise ValueError('remote public keys changed since installation')
    values={'GIT_CONFIG_GLOBAL':str(root/'gitconfig'),'OP_SERVICE_ACCOUNT_TOKEN':token}
    if agent=='codex':
        target=home/'.codex/config.toml'
        result=codex_settings(checked(target),values)
    else:
        target=home/'.claude/settings.json'
        data=json.loads(checked(target) or '{}')
        data.setdefault('env',{}).update(values)
        invocation=shlex.quote(cfg['programs']['python'])+' -I '+shlex.quote(str(root/'loader.py'))+' --load'
        old=checked(home/'.claude/settings-hook.installed').strip()
        entries=[]
        for entry in data.setdefault('hooks',{}).get('SessionStart',[]):
            saved=copy.deepcopy(entry)
            if any('claude-ssh-agent' in h.get('command','') and h.get('command')!=old for h in saved.get('hooks',[])):
                raise ValueError('review unmanaged legacy loader hook before activation')
            saved['hooks']=[h for h in saved.get('hooks',[]) if h.get('command') not in (invocation,old) or not h.get('command')]
            if saved['hooks']:entries.append(saved)
        entries.append({'hooks':[{'type':'command','command':invocation,'timeout':90,'statusMessage':'Loading the agent Git identity'}]})
        data['hooks']['SessionStart']=entries
        result=json.dumps(data,indent=2)+'\n'
    write(target,result)
    if agent=='claude':write(home/'.claude/settings-hook.installed',invocation+'\n')


def main():
    p=argparse.ArgumentParser()
    p.add_argument('--agent',choices=('claude','codex'),required=True)
    for name in ('account','principal','vault','signing-item','auth-item'):p.add_argument('--'+name,required=True)
    p.add_argument('--activate',action='store_true',help='Update only the agent Git environment after provisioning and verification')
    p.add_argument('--refresh-tools',action='store_true',help='Refresh executable paths while preserving the pinned reader and keys')
    a=p.parse_args()
    for value in (a.account,a.principal,a.vault,a.signing_item,a.auth_item):
        if not re.fullmatch('[A-Za-z0-9]{26}',value):raise ValueError('identity IDs required')
    items=[a.signing_item,a.auth_item]
    keys=read_pair(a.account,a.principal,a.vault,items)
    programs={name:program(name) for name in ('op','git','ssh','ssh-keygen','ssh-agent','ssh-add')}
    programs['python']=str(Path(sys.executable).resolve())
    root=install(Path.home(),a.agent,a.account,a.principal,a.vault,items,keys,programs,refresh_tools=a.refresh_tools)
    if a.activate:activate(Path.home(),a.agent,root,os.environ['OP_SERVICE_ACCOUNT_TOKEN'])
    print('Installed '+a.agent+' Git identity'+(' and activated its environment.' if a.activate else '; provider environment unchanged.'))


if __name__=='__main__':
    try:main()
    except Exception:
        print('Agent Git installation failed; verify the explicit identity and existing configuration.',file=sys.stderr)
        sys.exit(1)
