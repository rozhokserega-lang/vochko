// Minimal MCP stdio client for the built-in Roblox Studio MCP server.
// Usage: node roblox/tools/studio-mcp.cjs list
//        node roblox/tools/studio-mcp.cjs upload <studio_id> <url>...
// Speaks JSON-RPC 2.0 over stdin/stdout of /Applications/RobloxStudio.app/Contents/MacOS/StudioMCP.
const { spawn } = require('node:child_process');
const BIN = process.env.STUDIO_MCP_BIN || '/Applications/RobloxStudio.app/Contents/MacOS/StudioMCP';

const proc = spawn(BIN, [], { stdio: ['pipe', 'pipe', 'inherit'] });
setTimeout(() => { console.error('WATCHDOG-EXIT'); process.exit(3); }, 12000).unref();
if (process.env.MCP_DEBUG) console.error('spawned', BIN);
proc.on('error', (e) => { console.error('SPAWN ERROR', e.message); process.exit(1); });

const pending = new Map();
let nextId = 0;

proc.stdout.on('data', (chunk) => {
	if (process.env.MCP_DEBUG) console.error('RAW', JSON.stringify(chunk.toString()));
	// MCP servers may frame with SSE-style "data:" lines or raw JSON lines.
	for (const raw of chunk.toString().split('\n')) {
		const line = raw.trim();
		if (!line) continue;
		const jsonText = line.startsWith('data:') ? line.slice(5).trim() : line;
		let msg;
		try { msg = JSON.parse(jsonText); } catch { continue; }
		if (msg.id !== undefined && pending.has(msg.id)) {
			const { resolve, reject } = pending.get(msg.id);
			pending.delete(msg.id);
			if (msg.error) reject(new Error(JSON.stringify(msg.error)));
			else resolve(msg.result);
		}
	}
});

function call(method, params) {
	const id = ++nextId;
	return new Promise((resolve, reject) => {
		pending.set(id, { resolve, reject });
		const frame = JSON.stringify({ jsonrpc: '2.0', id, method, ...(params ? { params } : {}) }) + '\n';
		proc.stdin.write(frame);
		setTimeout(() => {
			if (pending.has(id)) {
				pending.delete(id);
				reject(new Error('timeout: ' + method));
			}
		}, 180000);
	});
}

function notify(method, params) {
	proc.stdin.write(JSON.stringify({ jsonrpc: '2.0', method, ...(params ? { params } : {}) }) + '\n');
}

(async () => {
	const [, , action, ...rest] = process.argv;
	const result = await call('initialize', {
		protocolVersion: '2024-11-05',
		capabilities: {},
		clientInfo: { name: 'vochko-tools', version: '1.0' },
	});
	notify('notifications/initialized');
	const serverName = result && result.serverInfo ? result.serverInfo.name : '?';
	if (action === 'list' || !action) {
		const tools = await call('tools/list', {});
		console.log('server:', serverName);
		console.log(tools.tools.map(t => t.name).join('\n'));
		return;
	}
	if (action === 'call') {
		const [tool, argsJson] = rest;
		const out = await call('tools/call', { name: tool, arguments: JSON.parse(argsJson || '{}') });
		console.log(JSON.stringify(out, null, 2));
		return;
	}
	if (action === 'upload') {
		const [studioId, ...urls] = rest;
		const out = await call('tools/call', {
			name: 'upload_image',
			arguments: { studio_id: studioId, imagePaths: urls },
		});
		console.log(JSON.stringify(out, null, 2));
		return;
	}
	console.error('unknown action: ' + action);
	process.exit(1);
})().catch(err => { console.error('MCP ERROR', err.message); process.exit(1); });
