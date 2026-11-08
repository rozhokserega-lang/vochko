// Push current repo script sources into the live Studio Edit datamodel via Studio MCP.
// Usage: node roblox/tools/studio-push.cjs <studio_id> [name1 name2 ...]   (default: all)
const { spawn } = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');
const BIN = process.env.STUDIO_MCP_BIN || '/Applications/RobloxStudio.app/Contents/MacOS/StudioMCP';
const root = path.resolve(__dirname, '..');

// src file -> container; instance name = key
const FILES = {
	ReplicatedStorage: { Assets: 'src/Assets.luau', Loadout: 'src/Loadout.luau', Inventory: 'src/Inventory.luau',
		HUDControls: 'src/HUDControls.luau', HeadLook: 'src/HeadLook.luau', TableScene: 'src/TableScene.luau',
		CameraControls: 'src/CameraControls.luau', CardImpact: 'src/CardImpact.luau', Tarot: 'src/Tarot.luau',
		RaceTarot: 'src/RaceTarot.luau', RaceUI: 'src/RaceUI.luau', SoundKit: 'src/SoundKit.luau' },
	ServerStorage: { Config: 'src/Config.luau', Seating: 'src/Seating.luau', NetworkDuel: 'src/NetworkDuel.luau',
		Battle: 'src/Battle.luau', Duel: 'src/Duel.luau', SharedDuel: 'src/SharedDuel.luau',
		RaceBot: 'src/RaceBot.luau', RoomBuilder: 'src/RoomBuilder.luau' },
	ServerScriptService: { VochkoPrototypeServer: 'src/Server.server.luau' },
	StarterPlayerScripts: { VochkoPrototypeClient: 'src/Client.client.luau' },
};

const proc = spawn(BIN, [], { stdio: ['pipe', 'pipe', 'inherit'] });
setTimeout(() => { console.error('WATCHDOG-EXIT'); process.exit(3); }, 120000).unref();
const pending = new Map(); let nextId = 0;
proc.stdout.on('data', (chunk) => {
	for (const raw of chunk.toString().split('\n')) {
		const line = raw.trim(); if (!line) continue;
		let msg; try { msg = JSON.parse(line); } catch { continue; }
		if (msg.id !== undefined && pending.has(msg.id)) {
			const { resolve, reject } = pending.get(msg.id); pending.delete(msg.id);
			msg.error ? reject(new Error(JSON.stringify(msg.error))) : resolve(msg.result);
		}
	}
});
function call(method, params) {
	const id = ++nextId;
	return new Promise((resolve, reject) => {
		pending.set(id, { resolve, reject });
		proc.stdin.write(JSON.stringify({ jsonrpc: '2.0', id, method, ...(params ? { params } : {}) }) + '\n');
	});
}
(async () => {
	const [, , studioId, ...only] = process.argv;
	await call('initialize', { protocolVersion: '2024-11-05', capabilities: {}, clientInfo: { name: 'vochko-push', version: '1.0' } });
	proc.stdin.write(JSON.stringify({ jsonrpc: '2.0', method: 'notifications/initialized' }) + '\n');
	const results = [];
	for (const [container, files] of Object.entries(FILES)) {
		for (const [name, srcRel] of Object.entries(files)) {
			if (only.length && !only.includes(name)) continue;
			if (!fs.existsSync(path.join(root, srcRel))) { results.push({ name, error: 'missing ' + srcRel }); continue; }
			let src = fs.readFileSync(path.join(root, srcRel), 'utf8');
			if (src.includes(']==]')) { results.push({ name, error: 'source contains ]==]' }); continue; }
			const node = container === 'ServerStorage'
				? `game.ServerStorage.VochkoPrototype.${name}`
				: container === 'ReplicatedStorage'
					? `game.ReplicatedStorage.VochkoPrototype.${name}`
					: container === 'ServerScriptService'
						? `game.ServerScriptService.${name}`
						: `game.StarterPlayer.StarterPlayerScripts.${name}`;
			const code = `local ok,err=pcall(function() ${node}.Source=[==[${src}]==] return true end) if ok then return "set" else return "ERR:"..tostring(err) end`;
			const out = await call('tools/call', { name: 'execute_luau', arguments: { studio_id: studioId, datamodel_type: 'Edit', code } });
			const text = out && out.content && out.content[0] && out.content[0].text || '';
			results.push({ name, result: text.slice(0, 200) });
		}
	}
	console.log(JSON.stringify(results, null, 2));
	process.exit(0);
})().catch(err => { console.error('PUSH ERROR', err.message); process.exit(1); });
