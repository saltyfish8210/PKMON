# 答题捕获主链测试脚本
$base = "http://127.0.0.1:4180"
Write-Host "=== 开始答题捕获主流程测试 ===" -ForegroundColor Cyan

# 1. 建会话与探索
$s = Invoke-RestMethod -Method Post -Uri "$base/api/v1/demo/sessions" -ContentType "application/json" -Body "{}"
$h = @{ "X-Demo-Session" = $s.data.sessionId }
$explore = Invoke-RestMethod -Method Post -Uri "$base/api/v1/demo/explore" -Headers $h -ContentType "application/json" -Body "{}"

# 2. 获取题目（注意路径带有 /demo）
$q = Invoke-RestMethod -Method Post -Uri "$base/api/v1/demo/capture/challenge" -Headers $h -ContentType "application/json" -Body '{"spawnId":"library-001"}'

# 3. 提交正确答案
$a = Invoke-RestMethod -Method Post -Uri "$base/api/v1/demo/capture/answer" -Headers $h -ContentType "application/json" -Body (@{ challengeId = $q.data.challengeId; optionId = "A" } | ConvertTo-Json)

# 4. 查询最终状态并断言
$state = (Invoke-RestMethod -Uri "$base/api/v1/demo/state" -Headers $h).data
if ($state.captured -eq $true -and $state.count -eq 1) {
    Write-Host "=== [测试通过] 答题捕获主链完整跑通！ ===" -ForegroundColor Green
    exit 0
} else {
    Write-Host "=== [测试失败] 状态断言不匹配。 ===" -ForegroundColor Red
    exit 1
}