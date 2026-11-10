"""Hermetic cloud-reader/agent contracts. SSH keys are disposable test fixtures."""
import copy
import importlib.util
import json
import os
from pathlib import Path
import shutil
import signal
import stat
import subprocess
import sys
import tempfile
import time
import tomllib
import unittest
from unittest.mock import patch

ROOT=Path(__file__).resolve().parents[1]
def module(name):
    spec=importlib.util.spec_from_file_location(name,ROOT/'agents/git'/str(name+'.py'))
    result=importlib.util.module_from_spec(spec);spec.loader.exec_module(result);return result
installer=module('install')
loader=module('loader')
A='a'*26;P='p'*26;V='v'*26;ITEMS=['s'*26,'k'*26];OTHER_ITEMS=['x'*26,'y'*26]


class Configuration(unittest.TestCase):
    def test_codex_preserves_unrelated_toml_and_changes_only_managed_values(self):
        text='''# user comment
model = "retained"
[shell_environment_policy.set]
EXISTING = "retained"
OP_SERVICE_ACCOUNT_TOKEN = "old_fixture"
[projects."/tmp/example"]
trust_level = "trusted"
'''
        values={'GIT_CONFIG_GLOBAL':'/home/test/.codex/agent-git/gitconfig','OP_SERVICE_ACCOUNT_TOKEN':'new_fixture'}
        result=installer.codex_settings(text,values)
        self.assertIn('# user comment',result)
        self.assertEqual(tomllib.loads(result)['projects'],tomllib.loads(text)['projects'])
        self.assertEqual(tomllib.loads(result)['shell_environment_policy']['set'],dict(EXISTING='retained',**values))
        self.assertEqual(installer.codex_settings(result,values),result)
        self.assertEqual(tomllib.loads(installer.codex_settings('model="retained"\n',values))['model'],'retained')

    def test_codex_refuses_invalid_inline_or_restrictive_config(self):
        for text in ('bad toml','[shell_environment_policy]\nset={A="retained"}',
                     '[shell_environment_policy.filters]\nPATH="include"',
                     '[shell_environment_policy]\ninclude_only=["PATH"]'):
            with self.assertRaises(Exception):installer.codex_settings(text,{'GIT_CONFIG_GLOBAL':'new'})

    def test_codex_appends_settings_after_valid_final_line_without_newline(self):
        values={'GIT_CONFIG_GLOBAL':'fixture','OP_SERVICE_ACCOUNT_TOKEN':'ops_fixture'}
        for text in ('[shell_environment_policy.set]\nEXISTING = "retained"',
                     '[shell_environment_policy.set]'):
            result=installer.codex_settings(text,values)
            expected=tomllib.loads(text)
            expected['shell_environment_policy']['set'].update(values)
            self.assertEqual(tomllib.loads(result),expected)
            self.assertEqual(installer.codex_settings(result,values),result)

    def test_write_is_private_atomic_and_refuses_symlinks(self):
        with tempfile.TemporaryDirectory() as folder:
            target=Path(folder)/'private/config'
            installer.write(target,'fixture')
            self.assertEqual(stat.S_IMODE(target.stat().st_mode),0o600)
            alias=Path(folder)/'alias';alias.symlink_to(target)
            with self.assertRaises(ValueError):installer.write(alias,'replacement')
            self.assertEqual(target.read_text(),'fixture')

    def test_no_operator_fallback_and_wrong_identity_rejected(self):
        def invoke(argv,**kwargs):
            self.assertEqual(kwargs['env'],{'OP_SERVICE_ACCOUNT_TOKEN':'ops_fixture'})
            return subprocess.CompletedProcess(argv,0,json.dumps(dict(account_uuid=A,user_uuid='wrong',user_type='SERVICE_ACCOUNT')),'')
        with patch.dict(os.environ,OP_SERVICE_ACCOUNT_TOKEN='ops_fixture',OP_SESSION_personal='forbidden',OP_CONNECT_HOST='forbidden',clear=True),patch.object(installer,'program',return_value='/fake/op'),patch.object(installer.subprocess,'run',side_effect=invoke):
            with self.assertRaisesRegex(ValueError,'wrong service account'):installer.read_pair(A,P,V,ITEMS)
        with patch.dict(os.environ,{},clear=True):
            with self.assertRaises(ValueError):installer.read_pair(A,P,V,ITEMS)


class RealAgents(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory(prefix='git-readers-',dir='/tmp')
        self.base=Path(self.tmp.name);self.home=self.base/'home';self.home.mkdir()
        self.keys=[];self.private={}
        for index,item in enumerate(ITEMS+OTHER_ITEMS):
            path=self.base/str(index)
            subprocess.run(['ssh-keygen','-q','-t','ed25519','-N','','-f',str(path)],check=True)
            self.keys.append(installer.public(path.with_suffix('.pub').read_text()))
            self.private[item]=str(path)
        self.op=self.base/'op'
        self.op.write_text('''#!/usr/bin/env python3
import json,os,sys
from pathlib import Path
if os.environ.get('OP_SERVICE_ACCOUNT_TOKEN')!='ops_fixture' or any(k.startswith('OP_SESSION_') for k in os.environ):
 print('SECRET_CANARY',file=sys.stderr);sys.exit(1)
if sys.argv[1]=='whoami':print(json.dumps(dict(account_uuid='''+repr(A)+''',user_uuid='''+repr(P)+''',user_type='SERVICE_ACCOUNT')))
elif sys.argv[1]=='read':
 item=sys.argv[2].split('/')[3]
 path=Path('''+repr(self.private)+'''[item])
 if '/public key' in sys.argv[2]:print(path.with_suffix('.pub').read_text(),end='')
 else:print(path.read_text(),end='')
else:sys.exit(1)
''')
        self.op.chmod(0o700)
        self.programs={name:shutil.which(name) for name in ('git','ssh','ssh-keygen','ssh-agent','ssh-add')}
        self.programs.update(op=str(self.op),python=sys.executable)
        self.env=patch.dict(os.environ,OP_SERVICE_ACCOUNT_TOKEN='ops_fixture',OP_SESSION_unattended='forbidden',OP_CONNECT_HOST='forbidden',OP_ACCOUNT='forbidden')
        self.env.start()
        self.roots=[]

    def tearDown(self):
        for root in self.roots:
            pid=root/'run/agent.pid'
            if pid.exists():
                try:os.kill(int(pid.read_text()),signal.SIGTERM)
                except ProcessLookupError:pass
        self.env.stop();self.tmp.cleanup()

    def install(self,agent='codex'):
        chosen=0 if agent=='codex' else 2
        root=installer.install(self.home,agent,A,P if agent=='codex' else 'q'*26,V if agent=='codex' else 'w'*26,(ITEMS+OTHER_ITEMS)[chosen:chosen+2],self.keys[chosen:chosen+2],self.programs)
        if root not in self.roots:self.roots.append(root)
        return root

    def test_distinct_identity_files_idempotence_and_no_implicit_rebinding(self):
        root=self.install();first={p.name:p.read_bytes() for p in root.iterdir() if p.is_file()}
        self.install();self.assertEqual(first,{p.name:p.read_bytes() for p in root.iterdir() if p.is_file()})
        with self.assertRaises(ValueError):installer.install(self.home,'codex',A,'z'*26,V,ITEMS,self.keys[:2],self.programs)
        with self.assertRaisesRegex(ValueError,'another agent'):
            installer.install(self.home,'claude',A,P,V,ITEMS,self.keys[:2],self.programs)
        with self.assertRaisesRegex(ValueError,'distinct service'):
            installer.install(self.home,'claude',A,P,V,OTHER_ITEMS,self.keys[2:],self.programs)
        other=self.install('claude')
        self.assertNotEqual(root,other)
        self.assertIn(str(other/'run/agent.sock'),(other/'ssh_config').read_text())
        for secret in self.private.values():self.assertFalse(any(Path(secret).read_bytes() in p.read_bytes() for p in root.iterdir() if p.is_file()))

    def test_cold_load_and_signed_commit_with_own_socket(self):
        root=self.install()
        cfg,env=loader.ensure(root)
        self.assertTrue(loader.holds(cfg,env))
        first_pid=(root/'run/agent.pid').read_text()
        loader.ensure(root)
        self.assertEqual((root/'run/agent.pid').read_text(),first_pid)
        repo=self.base/'repo';repo.mkdir()
        subprocess.run(['git','init','-q'],cwd=repo,check=True)
        ctx=dict(os.environ,GIT_CONFIG_GLOBAL=str(root/'gitconfig'))
        subprocess.run(['git','commit','-q','--allow-empty','-m','test: disposable signing fixture'],cwd=repo,env=ctx,check=True,capture_output=True)
        verified=subprocess.run(['git','verify-commit','HEAD'],cwd=repo,env=ctx,capture_output=True)
        self.assertEqual(verified.returncode,0)
        os.kill(int((root/'run/agent.pid').read_text()),signal.SIGTERM)
        for _ in range(100):
            if not (root/'run/agent.sock').exists():break
            time.sleep(0.01)
        ctx.pop('OP_SERVICE_ACCOUNT_TOKEN',None)
        verified=subprocess.run(['git','verify-commit','HEAD'],cwd=repo,env=ctx,capture_output=True)
        self.assertEqual(verified.returncode,0,verified.stderr)
        self.assertFalse((root/'run/agent.sock').exists())

    def test_explicit_tool_refresh_preserves_identity_and_rejects_rebinding(self):
        root=self.install()
        changed=dict(self.programs,op='/updated/op')
        before=json.loads((root/'identity.json').read_text())
        with self.assertRaises(ValueError):
            installer.install(self.home,'codex',A,P,V,ITEMS,self.keys[:2],changed)
        installer.install(self.home,'codex',A,P,V,ITEMS,self.keys[:2],changed,refresh_tools=True)
        expected=dict(before,programs=changed)
        self.assertEqual(json.loads((root/'identity.json').read_text()),expected)
        with self.assertRaises(ValueError):
            installer.install(self.home,'codex',A,'z'*26,V,ITEMS,self.keys[:2],changed,refresh_tools=True)

    def test_legacy_claude_pair_cannot_be_reused_by_codex(self):
        legacy=self.home/'.claude';legacy.mkdir()
        (legacy/'claude-signing.pub').write_text(self.keys[0]+'\n')
        (legacy/'claude-auth.pub').write_text(self.keys[1]+'\n')
        with self.assertRaisesRegex(ValueError,'legacy Claude'):
            self.install()
        root=installer.install(self.home,'codex',A,P,V,OTHER_ITEMS,self.keys[2:],self.programs)
        self.roots.append(root)
        # Claude is allowed to preserve its own registered pair.
        own=installer.install(self.home,'claude',A,'q'*26,'w'*26,ITEMS,self.keys[:2],self.programs)
        self.roots.append(own)

    def test_cold_invalid_token_fails_without_socket_or_secret_logs(self):
        root=self.install()
        ctx=dict(os.environ,OP_SERVICE_ACCOUNT_TOKEN='invalid_fixture')
        p=subprocess.run([sys.executable,'-I',str(root/'loader.py'),'--load'],env=ctx,capture_output=True,text=True)
        self.assertNotEqual(p.returncode,0)
        self.assertFalse((root/'run/agent.sock').exists())
        self.assertNotIn('SECRET_CANARY',p.stdout+p.stderr)

    def test_refuses_foreign_non_socket_and_preserves_it(self):
        root=self.install();(root/'run').mkdir(mode=0o700)
        precious=root/'run/agent.sock';precious.write_text('retained')
        with self.assertRaises(loader.IdentityError):loader.ensure(root)
        self.assertEqual(precious.read_text(),'retained')

    def test_activation_preserves_provider_values_and_replaces_only_owned_hook(self):
        root=self.install('claude')
        target=self.home/'.claude/settings.json'
        installer.write(self.home/'.claude/settings-hook.installed','legacy-hook\n')
        fixture={'theme':'retained','env':{'EXISTING':'retained'},'hooks':{'SessionStart':[{'matcher':'startup','hooks':[{'type':'command','command':'legacy-hook'},{'type':'command','command':'user-hook'}]}]}}
        target.write_text(json.dumps(fixture))
        with patch.object(installer,'read_pair',return_value=self.keys[2:]):installer.activate(self.home,'claude',root,'ops_fixture')
        after=json.loads(target.read_text())
        self.assertEqual(after['theme'],'retained');self.assertEqual(after['env']['EXISTING'],'retained')
        self.assertEqual(after['hooks']['SessionStart'][0],{'matcher':'startup','hooks':[{'type':'command','command':'user-hook'}]})
        self.assertEqual(len(after['hooks']['SessionStart']),2)
        self.assertEqual(stat.S_IMODE(target.stat().st_mode),0o600)
        with patch.object(installer,'read_pair',return_value=self.keys[2:]):installer.activate(self.home,'claude',root,'ops_fixture')
        self.assertEqual(json.loads(target.read_text()),after)

    def test_activation_refuses_remote_key_change_before_touching_config(self):
        root=self.install()
        target=self.home/'.codex/config.toml';target.write_text('model="retained"\n')
        before=target.read_bytes()
        with patch.object(installer,'read_pair',return_value=self.keys[::-1]):
            with self.assertRaises(ValueError):installer.activate(self.home,'codex',root,'ops_fixture')
        self.assertEqual(before,target.read_bytes())


if __name__=='__main__':unittest.main()
