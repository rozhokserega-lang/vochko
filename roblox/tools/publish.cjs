// Публикация локального релиза в облачное место Roblox через Open Cloud.
// Использование:
//   ROBLOX_API_KEY=ключ node roblox/tools/publish.cjs 1234567890 9876543210
//   (первое число — universeId, второе — placeId)
// Или запустить без чисел утилита-подсказка. Ключ также можно передать ключом --key=...
const fs=require('node:fs');
const path=require('node:path');
const https=require('node:https');

const file=path.join(__dirname,'../releases/VochkoPrototype.rbxl');
const args=process.argv.slice(2);
let key=process.env.ROBLOX_API_KEY||'';
const flag=args.find(a=>a.startsWith('--key='));
if(flag)key=flag.slice(6);
const positional=args.filter(a=>!/^-/.test(a));
const [universe,place]=positional.map(Number);

if(!key||!universe||!place){
 console.log('Утилита публикует roblox/releases/VochkoPrototype.rbxl в Open Cloud.');
 console.log('Формат: ROBLOX_API_KEY=... node tools/publish.cjs <universeId> <placeId>');
 console.log('Ключ нужен со скоупами места публикации (publish/write). universeId смотрят в адресе Creator Dashboard.');
 process.exit(1);
}

const body=fs.readFileSync(file);
console.log(`Публикую ${path} (${body.length} байт) во вселенную ${universe} / место ${place}...`);

const req=https.request({
 method:'POST',
 host:'apis.roblox.com',
 path:`/cloud/v2/universes/${universe}/places/${place}/versions`,
 headers:{'x-api-key':key,'Content-Type':'application/octet-stream','Content-Length':body.length},
},res=>{
 let text='';
 res.on('data',c=>text+=c);
 res.on('end',()=>{
  if(res.statusCode>=200&&res.statusCode<300){
   console.log('Готово. Ответ сервера:',text);
  }else{
   console.error(`Ошибка ${res.statusCode}:`,text);
   process.exit(res.statusCode===401||res.statusCode===403?2:1);
  }
 });
});
req.on('error',e=>{console.error('Сетевая ошибка:',e.message);process.exit(1)});
req.end(body);
