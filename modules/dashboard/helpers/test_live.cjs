const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const path=require('node:path');
const c={};vm.createContext(c);
vm.runInContext(fs.readFileSync(path.join(__dirname,'LiveLogic.js'),'utf8').replace(/^\.pragma library\s*/,''),c);
test('network changes announce only real outages and recoveries',()=>{
 assert.equal(c.networkChange('full','none'),'offline');
 assert.equal(c.networkChange('full','limited'),'limited');
 assert.equal(c.networkChange('none','full'),'online');
 assert.equal(c.networkChange('limited','full'),'online');
 assert.equal(c.networkChange('unknown','full'),'');
 assert.equal(c.networkChange('full','unknown'),'');
 assert.equal(c.networkChange('portal','none'),'');
 assert.equal(c.networkChange('full','full'),'');
});
test('partial and hidden downloads are not announced',()=>{
 assert.equal(c.downloadName('report.pdf'),'report.pdf');
 for (const n of ['a.part','b.CRDOWNLOAD','.hidden','c.tmp','','x/y.txt']) assert.equal(c.downloadName(n),'');
});
test('bursts are rate limited',()=>{
 assert.equal(c.allowEvent(undefined,1000,2000),true);
 assert.equal(c.allowEvent(1000,2500,2000),false);
 assert.equal(c.allowEvent(1000,3000,2000),true);
});
test('recording streams exclude the shell and internal captures',()=>{
 assert.equal(c.isAppRecording({'media.class':'Stream/Input/Audio','application.name':'Firefox'}),true);
 assert.equal(c.isAppRecording({'media.class':'Stream/Input/Audio','application.name':'Quickshell Peak Detect','stream.capture.sink':'true'}),false);
 assert.equal(c.isAppRecording({'media.class':'Stream/Input/Audio/Internal'}),false);
 assert.equal(c.isAppRecording({'media.class':'Stream/Output/Audio','application.name':'mpv'}),false);
 assert.equal(c.isAppRecording(null),false);
 assert.equal(c.isCameraStream({'media.class':'Stream/Input/Video'}),true);
 assert.equal(c.isCameraStream({'media.class':'Stream/Input/Audio'}),false);
});
test('caps lock state from LED brightness',()=>{
 assert.equal(c.capsOn(['0','0']),false);assert.equal(c.capsOn(['0','1']),true);assert.equal(c.capsOn([]),false);
 assert.equal(c.capsText(true),'Caps Lock on');
});

test('feedback icons have their own colours with a safe default',()=>{
 assert.equal(c.iconTint('wifi_off'),'red');assert.equal(c.iconTint('wifi'),'green');assert.equal(c.iconTint('download_done'),'blue');
 assert.equal(c.iconTint('something_new'),'blue');
});
