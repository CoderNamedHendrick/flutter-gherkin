"""Protocol-level smoke client; discovers tool schemas, never edits host settings."""
import argparse
import asyncio
import json
import os

async def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--cwd', required=True)
    parser.add_argument('--backend', choices=['patrol', 'marionette'], required=True)
    parser.add_argument('--device')
    parser.add_argument('--uri')
    parser.add_argument('--test')
    parser.add_argument('command', nargs=argparse.REMAINDER)
    args = parser.parse_args()
    command = args.command[1:] if args.command[:1] == ['--'] else args.command
    env = dict(os.environ, PROJECT_ROOT=os.path.abspath(args.cwd), SHOW_TERMINAL='false')
    process = await asyncio.create_subprocess_exec(*command, cwd=args.cwd, env=env, stdin=asyncio.subprocess.PIPE, stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL)
    seq = 0
    async def rpc(method, params):
        nonlocal seq
        seq += 1
        process.stdin.write((json.dumps({'jsonrpc':'2.0','id':seq,'method':method,'params':params})+'\n').encode())
        await process.stdin.drain()
        while True:
            line = await asyncio.wait_for(process.stdout.readline(), timeout=600)
            if not line:
                raise RuntimeError('MCP server closed stdout')
            try:
                result = json.loads(line)
            except ValueError:
                continue
            if result.get('id') == seq:
                if 'error' in result:
                    raise RuntimeError(result['error'])
                return result['result']
    try:
        await rpc('initialize', {'protocolVersion':'2024-11-05','capabilities':{},'clientInfo':{'name':'gherkin-smoke','version':'1'}})
        process.stdin.write((json.dumps({'jsonrpc':'2.0','method':'notifications/initialized'})+'\n').encode())
        listing = await rpc('tools/list', {})
        print(json.dumps({'tools':listing['tools']}), flush=True)
        async def call(suffix, arguments):
            tool = next(t for t in listing['tools'] if t['name'].replace('-', '_').endswith(suffix))
            result = await rpc('tools/call', {'name':tool['name'],'arguments':arguments})
            print(json.dumps({'tool':tool['name'],'result':result}), flush=True)
            if result.get('isError'):
                raise RuntimeError('MCP tool reported failure')
            return result
        if args.backend == 'patrol' and args.test:
            try:
                run = await call('run', {'testFile':args.test,'device':args.device})
                status = await call('status', {})
                if run.get('structuredContent', {}).get('testState') != 'finishedPassed' or status.get('structuredContent', {}).get('testState') != 'finishedPassed':
                    raise RuntimeError('MCP did not confirm a passing test verdict')
            finally:
                await call('quit', {})
        elif args.backend == 'marionette' and args.uri:
            tool = next(t for t in listing['tools'] if t['name'].endswith('connect') and not t['name'].endswith('disconnect'))
            properties = tool['inputSchema']['properties']
            key = next(k for k in properties if 'uri' in k.lower())
            await rpc('tools/call', {'name':tool['name'],'arguments':{key:args.uri}})
            result = await call('get_interactive_elements', {})
            import re
            content = '\n'.join(c.get('text', '') for c in result.get('content', []))
            match = re.search(r'Found (\d+) interactive element', content)
            if not match or int(match.group(1)) == 0:
                raise RuntimeError('Marionette returned no verifiable interactive elements')
    finally:
        if process.returncode is None:
            process.terminate()
            try:
                await asyncio.wait_for(process.wait(), timeout=10)
            except asyncio.TimeoutError:
                process.kill()
                await process.wait()

if __name__ == '__main__':
    asyncio.run(main())
