// Run against the actual packaged JAR. Requires Playwright and Chrome/Chromium.
// PKMON_DEMO_JAR, JAVA_HOME, CHROME_PATH, PKMON_EVIDENCE_DIR may be supplied.
const { chromium } = require('playwright');
const { spawn } = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const { randomBytes, randomUUID, createHash } = require('node:crypto');
const assert = require('node:assert/strict');

(async () => {
  const jar = path.resolve(process.env.PKMON_DEMO_JAR || 'pkmon-demo.jar');
  const evidence = path.resolve(process.env.PKMON_EVIDENCE_DIR || fs.mkdtempSync(path.join(os.tmpdir(), 'pkmon-evidence-')));
  fs.mkdirSync(evidence, { recursive: true });
  const dataDir = fs.mkdtempSync(path.join(os.tmpdir(), 'pkmon-demo-test-'));
  const java = process.env.JAVA_HOME ? path.join(process.env.JAVA_HOME, 'bin', process.platform === 'win32' ? 'java.exe' : 'java') : 'java';
  const password = randomBytes(18).toString('hex');
  const username = 'demo_' + randomBytes(4).toString('hex');
  const checks = [];
  const blockedExternal = new Set();
  const unexpectedErrors = [];
  let server, browser, page, context, token, port, launchCount = 0;
  const ok = (name) => { checks.push(name); console.log('PASS ' + name); };
  const start = async () => {
    const label = ++launchCount;
    server = spawn(java, ['-jar', jar, '--server.address=127.0.0.1', '--server.port=0',
      '--spring.profiles.active=dev', '--pkmon.capture.dev-user-header=false',
      '--pkmon.capture.dev-spawn-enabled=true', '--pkmon.study.rules.required-seconds=4',
      '--pkmon.study.rules.cooldown-seconds=0', '--spring.datasource.url=jdbc:h2:file:' + path.join(dataDir, 'db').replaceAll('\\', '/') + ';WRITE_DELAY=0'],
    { windowsHide: true, stdio: ['ignore', 'pipe', 'pipe'], cwd: dataDir });
    let output = '';
    return await new Promise((resolve, reject) => {
      const timer = setTimeout(() => reject(Error('Server startup timeout')), 60000);
      server.stdout.on('data', chunk => {
        output += chunk;
        fs.appendFileSync(path.join(evidence, `server-${label}.log`), chunk);
        const match = output.match(/Tomcat started on port (\d+)/);
        if (match) { clearTimeout(timer); port = Number(match[1]); resolve(port); }
      });
      server.stderr.on('data', chunk => fs.appendFileSync(path.join(evidence, `server-${label}.log`), chunk));
      server.once('error', error => { clearTimeout(timer); reject(error); });
      server.once('exit', code => { clearTimeout(timer); reject(Error('Server exited: ' + code)); });
    });
  };
  const stop = async () => {
    if (!server || server.exitCode !== null) return;
    const child = server;
    await new Promise(resolve => { child.once('exit', resolve); child.kill(); });
    server = null;
  };
  const api = async (method, endpoint, body, bearer = token, expectedStatus = 200) => {
    const response = await context.request.fetch(`http://127.0.0.1:${port}/api/v1${endpoint}`, {
      method, headers: bearer ? { Authorization: 'Bearer ' + bearer } : {}, data: body,
    });
    assert.equal(response.status(), expectedStatus, endpoint + ' HTTP status');
    const payload = await response.json();
    if (expectedStatus === 200) assert.equal(payload.code, 0, endpoint + ' code');
    return payload;
  };
  const click = name => page.getByRole('button', { name, exact: true }).click();
  const field = async (name, value) => {
    await page.getByRole('textbox', { name, exact: true }).click();
    await page.keyboard.press('Control+A');
    await page.keyboard.insertText(value);
  };
  const shot = async name => { await page.screenshot({ path: path.join(evidence, name + '.png'), fullPage: true }); };
  const back = () => page.getByRole('button', { name: /^(Back|返回)$/ }).click();
  const login = async () => {
    await field('用户名', username); await field('密码', password); await click('登录');
    await page.getByRole('button', { name: '进入自习任务', exact: true }).waitFor();
  };
  let success = false;
  try {
    await start();
    browser = await chromium.launch({ executablePath: process.env.CHROME_PATH || undefined,
      headless: true, args: ['--enable-unsafe-swiftshader'] });
    context = await browser.newContext({ viewport: { width: 1080, height: 960 },
      recordVideo: { dir: path.join(evidence, 'video'), size: { width: 1080, height: 960 } } });
    await context.route('**/*', route => {
      const url = new URL(route.request().url());
      if (['127.0.0.1', 'localhost'].includes(url.hostname) || ['data:', 'blob:'].includes(url.protocol)) return route.continue();
      blockedExternal.add(url.origin); return route.abort();
    });
    page = await context.newPage();
    page.setDefaultTimeout(15000);
    page.on('pageerror', e => unexpectedErrors.push(String(e)));
    const receipts = [];
    const guestCalls = [];
    let answerRequest;
    page.on('request', request => {
      const endpoint = new URL(request.url()).pathname;
      if (endpoint.includes('/api/v1/demo/')) guestCalls.push(endpoint);
      if (endpoint === '/api/v1/capture/answer') {
        const body = request.postDataJSON();
        if (body.optionId === 'A') answerRequest = body;
      }
    });
    page.on('response', async response => {
      const endpoint = new URL(response.url()).pathname;
      if (!endpoint.startsWith('/api/v1/')) return;
      try {
        const payload = await response.json();
        if (endpoint === '/api/v1/auth/login') token = payload.data.token;
        if (!endpoint.startsWith('/api/v1/auth/')) receipts.push({ endpoint, data: payload.data, code: payload.code });
      } catch { /* non-JSON failed connection is reported by the UI */ }
    });
    await page.goto(`http://127.0.0.1:${port}/`);
    await page.getByText('登录 PKMon', { exact: true }).waitFor();
    await shot('01-login');
    await click('注册新账号'); await field('用户名', username); await field('昵称', '展示同学');
    await field('密码', password); await click('创建账号');
    await page.getByText('注册成功，请登录', { exact: true }).waitFor();
    await click('登录');
    await page.getByText('已收集 0 / 1 种 · 累计捕获 0 次', { exact: true }).waitFor();
    await shot('02-home'); ok('register/login and account-owned empty collection');
    await click('进入自习任务'); await click('使用模拟位置开始');
    await page.getByText('状态　驻留中', { exact: true }).waitFor({ timeout: 20000 });
    await shot('03-study');
    await page.getByRole('button', { name: '前往答题', exact: true }).waitFor({ timeout: 35000 });
    await shot('04-encounter'); await click('前往答题');
    await page.getByRole('button', { name: /^B\s/ }).click();
    await page.getByText('这次没有答对，可以再试一次。', { exact: true }).waitFor();
    await shot('05-retry');
    await page.getByRole('button', { name: /^A\s/ }).click();
    await page.getByText('成为伙伴了！', { exact: true }).waitFor();
    await shot('06-captured');
    const triggered = receipts.find(r => r.data?.status === 'TRIGGERED');
    const challenge = receipts.find(r => r.endpoint.endsWith('/capture/challenge'));
    assert.ok(triggered?.data.spawnId);
    assert.equal(triggered.data.spawnId, challenge?.data.spawnId);
    assert.equal(challenge.data.sourceType, 'DEV_SIMULATED');
    assert.ok(!JSON.stringify(challenge.data).includes('correctOptionId'));
    ok('study dwell -> same encounter -> wrong retry -> correct capture; simulation labelled');
    await click('查看收藏'); await page.getByText('累计捕获 1 次', { exact: true }).waitFor();
    await shot('07-collection'); await back(); await click('返回自习');
    await click('结束任务'); await page.getByText('状态　已结束', { exact: true }).waitFor();
    await back(); await page.getByText('已收集 1 / 1 种 · 累计捕获 1 次', { exact: true }).waitFor();
    await shot('08-home-updated');
    assert.deepEqual(guestCalls, []); ok('collection navigation, task end, homepage refresh; no guest demo APIs');
    assert.ok(token); assert.ok(answerRequest);
    const replay = await api('POST', '/capture/answer', answerRequest);
    const replayAgain = await api('POST', '/capture/answer', answerRequest);
    assert.equal(replay.data.captureRecordId, replayAgain.data.captureRecordId);
    const conflict = await api('POST', '/capture/answer', { ...answerRequest, optionId: 'B' }, token, 409);
    assert.equal(conflict.code, 40902);
    assert.equal((await api('GET', '/collection/summary')).data.captureCount, 1);
    ok('replayed answer returns one record; conflicting request rejected');
    await api('GET', '/collection/summary', undefined, null, 401);
    await api('GET', '/collection/summary', undefined, 'invalid-token', 401);
    const second = 'other_' + randomBytes(4).toString('hex');
    await api('POST', '/auth/register', { username: second, nickname: '隔离账号', password }, null);
    const secondToken = (await api('POST', '/auth/login', { username: second, password }, null)).data.token;
    assert.equal((await api('GET', '/collection/summary', undefined, secondToken)).data.captureCount, 0);
    await api('GET', '/capture/challenges/' + answerRequest.challengeId, undefined, secondToken, 404);
    ok('anonymous/invalid sessions rejected; another account cannot read capture');
    const startRequest = { regionId: 'library_entrance', requestId: randomUUID(), locationSource: 'SIMULATED' };
    const pending = (await api('POST', '/study/tasks', startRequest)).data;
    assert.equal((await api('POST', '/study/tasks', startRequest)).data.taskId, pending.taskId);
    const oldToken = token;
    await stop(); await start();
    await api('GET', '/users/me', undefined, oldToken);
    assert.equal((await api('GET', '/study/tasks/current', undefined, oldToken)).data.task.taskId, pending.taskId);
    assert.equal((await api('GET', '/collection/summary', undefined, oldToken)).data.captureCount, 1);
    assert.equal((await api('POST', '/capture/answer', answerRequest, oldToken)).data.captureRecordId, replay.data.captureRecordId);
    ok('file database restart preserves account/session, active task, collection and answer replay');
    await page.goto(`http://127.0.0.1:${port}/`); await login();
    await page.getByText('已收集 1 / 1 种 · 累计捕获 1 次', { exact: true }).waitFor();
    await shot('09-after-restart'); await click('进入自习任务');
    await page.getByText('状态　等待进入区域', { exact: true }).waitFor();
    await click('结束任务'); await page.getByText('状态　已结束', { exact: true }).waitFor(); await back();
    // A failed network request must lead to an actionable error, then recover.
    const summaryRoute = '**/api/v1/collection/summary';
    await page.route(summaryRoute, route => route.abort());
    await click('刷新收藏'); await page.getByRole('button', { name: '重试', exact: true }).waitFor();
    await page.unroute(summaryRoute); await click('重试');
    await page.getByText('已收集 1 / 1 种 · 累计捕获 1 次', { exact: true }).waitFor();
    await click('退出登录'); await page.getByText('登录 PKMon', { exact: true }).waitFor();
    await api('GET', '/users/me', undefined, token, 401);
    await login();
    await api('POST', '/auth/logout', {});
    await click('刷新收藏'); await page.getByText('登录 PKMon', { exact: true }).waitFor();
    ok('network retry, logout and revoked-session return to login');
    assert.deepEqual(unexpectedErrors, []);
    assert.deepEqual([...blockedExternal], [], 'Classroom UI must not need fallback glyph downloads');
    ok('entire browser flow works with external network blocked; no uncaught browser error');
    success = true;
  } catch (error) {
    console.error(String(error).replaceAll(password, '[redacted]'));
    if (page) {
      await shot('failure').catch(() => {});
      const tree = await page.locator('body').ariaSnapshot().catch(() => '');
      console.error(tree.replaceAll(password, '[redacted]').slice(0,5000));
    }
    process.exitCode = 1;
  } finally {
    const video = page?.video();
    await context?.close();
    if (video) await video.saveAs(path.join(evidence, 'browser-flow.webm')).catch(() => {});
    await browser?.close(); await stop();
    fs.writeFileSync(path.join(evidence, 'verification.json'), JSON.stringify({
      passed: success, verifiedAt: new Date().toISOString(), jarSha256: createHash('sha256').update(fs.readFileSync(jar)).digest('hex'),
      checks, externalNetworkDisabled: true, blockedExternal: [...blockedExternal], browserErrors: unexpectedErrors,
      scope: 'Windows Chrome / Flutter Web + Spring Boot + JDBC file database; simulated position; Android not tested',
    }, null, 2));
  }
})();
