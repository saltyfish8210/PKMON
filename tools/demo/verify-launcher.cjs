// Windows-only acceptance: occupied port, path with spaces, bundled runtime, own-process shutdown.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const net = require('node:net');
const os = require('node:os');
const { spawn } = require('node:child_process');

(async () => {
  const packageDir = path.resolve(process.argv[2]);
  const testDir = fs.mkdtempSync(path.join(os.tmpdir(), 'PKMon launch test '));
  const evidenceFile = process.env.PKMON_LAUNCHER_RESULT;
  for (const name of ['pkmon-demo.jar', 'launch.ps1']) {
    fs.copyFileSync(path.join(packageDir, name), path.join(testDir, name));
  }
  const occupied = net.createServer(socket => socket.end('occupied-by-test'));
  await new Promise(resolve => occupied.listen(0, '127.0.0.1', resolve));
  const blockedPort = occupied.address().port;
  let child, readyUrl, result;
  try {
    child = spawn('powershell.exe', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', path.join(testDir, 'launch.ps1'),
      '-Port', String(blockedPort), '-NoBrowser'], {
      windowsHide: true, env: { ...process.env, JAVA_HOME: path.join(packageDir, 'runtime') },
      stdio: ['pipe', 'pipe', 'pipe'],
    });
    let output = '';
    child.stderr.on('data', chunk => { output += chunk; });
    readyUrl = await new Promise((resolve, reject) => {
      const timer = setTimeout(() => reject(Error('Launcher timeout: ' + output)), 100000);
      child.stdout.on('data', chunk => {
        output += chunk;
        const ready = output.match(/PKMon is ready: (http:\/\/127\.0\.0\.1:\d+\/)/);
        if (ready) { clearTimeout(timer); resolve(ready[1]); }
      });
      child.once('exit', code => { clearTimeout(timer); reject(Error('Launcher exited ' + code + ': ' + output)); });
      child.once('error', e => { clearTimeout(timer); reject(e); });
    });
    assert.notEqual(Number(new URL(readyUrl).port), blockedPort);
    assert.ok(output.includes('Selecting a free port'));
    const response = await fetch(readyUrl);
    assert.equal(response.status, 200);
    assert.ok((await response.text()).includes('flutter_bootstrap.js'));
    const blockerStillAlive = await new Promise((resolve, reject) => {
      const socket = net.connect(blockedPort, '127.0.0.1');
      socket.once('data', data => { socket.destroy(); resolve(data.toString()); });
      socket.once('error', reject);
    });
    assert.equal(blockerStillAlive, 'occupied-by-test');
    await new Promise((resolve, reject) => {
      const timer = setTimeout(() => reject(Error('Launcher did not stop')), 15000);
      child.once('exit', code => { clearTimeout(timer); code === 0 ? resolve() : reject(Error('Exit ' + code)); });
      child.stdin.write('\n');
    });
    await assert.rejects(fetch(readyUrl));
    result = { passed: true, checkedAt: new Date().toISOString(), checks: [
      'launch from path with spaces using included Java runtime',
      'occupied port switches to free port without stopping existing listener',
      'embedded web assets respond successfully',
      'pressing Enter stops only the launched demo service',
    ] };
    console.log(JSON.stringify(result));
  } catch (error) {
    result = { passed: false, error: String(error) };
    console.error(String(error)); process.exitCode = 1;
    if (child && child.exitCode === null) child.stdin.write('\n');
  } finally {
    occupied.close();
    if (evidenceFile) fs.writeFileSync(evidenceFile, JSON.stringify(result, null, 2));
  }
})();
