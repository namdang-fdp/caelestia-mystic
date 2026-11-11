const {test} = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const path = require('node:path');
const logic = {};
vm.createContext(logic);
vm.runInContext(fs.readFileSync(path.join(__dirname, 'AudioLogic.js'), 'utf8').replace(/^\.pragma library\s*/, ''), logic);

test('a silent active stream never counts; short gaps hold, long silence expires', () => {
    assert.equal(logic.audibleUntil(0, 0, true, 10000), 0);
    const until = logic.audibleUntil(0, .01, true, 10000);
    assert.equal(until, 11200);
    assert.equal(logic.audibleUntil(until, 0, true, 10500), until);
    assert.equal(logic.audibleUntil(until, 0, true, 11300), 0);
    assert.equal(logic.audibleUntil(until, .01, false, 10100), 0);
    assert.equal(logic.audibleUntil(0, NaN, true, 10000), 0);
});

test('labels use media title and app, with a useful fallback for generic streams', () => {
    assert.equal(logic.streamLabel({'application.name': 'Zen', 'media.name': 'AudioStream'}), 'Zen');
    assert.equal(logic.streamLabel({'application.name': 'Zen', 'media.name': 'A video — YouTube'}), 'A video — YouTube · Zen');
    assert.equal(logic.streamLabel({'application.name': 'Music', 'media.title': 'Song'}), 'Song · Music');
    assert.equal(logic.streamLabel({'application.name': 'Zen', 'media.name': 'Zen'}), 'Zen');
});

test('MPRIS metadata is used only for a matching app with a real playing track', () => {
    const stream = {'application.name': 'Zen', 'application.process.binary': 'zen-bin'};
    assert.equal(logic.matchesPlayer({identity: 'Zen', trackTitle: 'Song', isPlaying: true}, stream), true);
    assert.equal(logic.matchesPlayer({identity: 'Zen', trackTitle: 'Song', isPlaying: false}, stream), false);
    assert.equal(logic.matchesPlayer({identity: 'Zen', trackTitle: '', isPlaying: true}, stream), false);
    assert.equal(logic.matchesPlayer({identity: 'Spotify', trackTitle: 'Song', isPlaying: true}, stream), false);
    assert.equal(logic.matchesPlayer({desktopEntry: 'zen', trackTitle: 'Song', isPlaying: true}, stream), true);
});

test('streams are keyed per app, not per node', () => {
    assert.equal(logic.streamKey({'application.process.id': 4242, 'application.name': 'Zen'}), '4242');
    assert.equal(logic.streamKey({'application.process.binary': 'spotify', 'application.name': 'Spotify'}), 'spotify');
    assert.equal(logic.streamKey({'application.name': 'Zen'}), 'Zen');
    assert.equal(logic.streamKey({}), '');
});

test('a stream that vanishes (browser seek) is carried across the gap, then expires', () => {
    const stream = {label: 'Zen', properties: {}};
    const first = logic.carryOver({}, [{key: 'zen', stream}], [], false, 10000);
    assert.deepEqual(first.streams, [stream]);
    const gap = logic.carryOver(first.held, [], [], false, 10400);
    assert.deepEqual(gap.streams, [stream]);
    assert.equal(gap.held.zen.until, 11500);
    const back = logic.carryOver(gap.held, [{key: 'zen', stream}], [], false, 10700);
    assert.deepEqual(back.streams, [stream]);
    assert.equal(back.held.zen.until, 12200);
    assert.deepEqual(logic.carryOver(gap.held, [], [], false, 11600).streams, []);
});

test('mute, zero volume and a silenced output clear a carried stream immediately', () => {
    const stream = {label: 'Zen', properties: {}};
    const held = logic.carryOver({}, [{key: 'zen', stream}], [], false, 10000).held;
    assert.deepEqual(logic.carryOver(held, [], ['zen'], false, 10100).streams, []);
    assert.deepEqual(logic.carryOver(held, [], [], true, 10100).streams, []);
    assert.deepEqual(logic.carryOver(held, [], ['other'], false, 10100).streams, [stream]);
});

test('a carried stream is not duplicated while its replacement is audible', () => {
    const old = {label: 'Zen', properties: {id: 1}};
    const fresh = {label: 'Zen', properties: {id: 2}};
    const held = logic.carryOver({}, [{key: 'zen', stream: old}], [], false, 10000).held;
    assert.deepEqual(logic.carryOver(held, [{key: 'zen', stream: fresh}], [], false, 10200).streams, [fresh]);
});
