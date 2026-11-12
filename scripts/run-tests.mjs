import fs from 'node:fs';import {spawnSync} from 'node:child_process';
const files=fs.readdirSync(new URL('../tests/',import.meta.url)).filter(f=>/^tz001-.*\.test\.mjs$/.test(f)).sort();for(const f of files){const result=spawnSync(process.execPath,[new URL('../tests/'+f,import.meta.url).pathname],{stdio:'inherit'});if(result.status!==0)process.exit(result.status||1)}
