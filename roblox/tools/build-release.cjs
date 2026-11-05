// Run from any directory: node /path/to/vochko/roblox/tools/build-release.cjs
const fs=require('node:fs');
const path=require('node:path');
const crypto=require('node:crypto');
const {spawnSync}=require('node:child_process');
const root=path.resolve(__dirname,'../..');
const output='roblox/releases/VochkoPrototype.rbxl';
fs.mkdirSync(path.join(root,'roblox/releases'),{recursive:true});
const result=spawnSync('rojo',['build','roblox/default.project.json','-o',output],{cwd:root,stdio:'inherit'});
if(result.error)throw result.error;
if(result.status!==0)process.exit(result.status||1);
const paths=[output,'roblox/default.project.json','roblox/assets/cards-atlas.png','roblox/assets/opponents.png','roblox/assets/loadout/loadout-atlas-v1.png',
 'roblox/assets/models/TavernTable.rbxmx','roblox/assets/models/tavern-table.glb','roblox/assets/models/source-tripo-meshopt.glb',
 ...fs.readdirSync(path.join(root,'roblox/src')).filter(x=>x.endsWith('.luau')).map(x=>'roblox/src/'+x),
 ...fs.readdirSync(path.join(root,'assets/tarot')).filter(x=>x.endsWith('.webp')).map(x=>'assets/tarot/'+x)];
const files=paths.sort().map(file=>{const data=fs.readFileSync(path.join(root,file));return {path:file,bytes:data.length,sha256:crypto.createHash('sha256').update(data).digest('hex')};});
const refs=[...new Set((fs.readFileSync(path.join(root,'roblox/src/Assets.luau'),'utf8')+fs.readFileSync(path.join(root,'roblox/assets/models/TavernTable.rbxmx'),'utf8')).match(/rbxassetid:\/\/\d+/g))].sort();
fs.writeFileSync(path.join(root,'roblox/releases/manifest.json'),JSON.stringify({format:1,place:output,
 note:'Source GLBs contain embedded geometry and PBR textures. The place loads published Roblox assets by ID; use the same Roblox account or grant access/reimport for a different owner.',
 robloxAssets:refs,files},null,2)+'\n');
console.log(`Saved ${files.length} files and ${refs.length} Roblox asset references in manifest.json`);
