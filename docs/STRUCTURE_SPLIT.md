# ALBA 合约结构拆分指南（解决 `max code size exceeded`）

> 目标：在**不改变功能**的前提下，把超大的单体 `ALBA.sol` 拆成可部署到 Sepolia 的模块。

## 1. 拆分原则

- 保持外部行为不变（函数名、参数、事件、状态语义不变）。
- 把“重逻辑”移到模块合约，通过 `delegatecall` 复用主合约存储。
- 主合约只做：
  - 状态定义
  - 访问控制/入口分发
  - 关键一致性检查

## 2. 建议的模块边界

### A. `ALBAStorage.sol`
仅定义共享存储结构与 storage slot：
- `ALBAParam`
- `ALBAState`
- `PaymentChannel`
- `ChannelState`
- `OperationMode`
- `prover/verifier/totalSupply/fundsSettled/initBalEth`

### B. `ALBABridgeFacet.sol`
放桥接与争议路径：
- `setup`
- `submitProof`
- `optimisticSubmitProof`
- `dispute`
- `resolveValidDispute`
- `resolveInvalidDispute`
- `settle`

### C. `ALBAChannelFacet.sol`
放支付通道路径：
- `openChannel`
- `updateChannel`
- `closeChannel`
- `receive`（可保留在主合约，或放在 channel facet）

### D. `ALBA.sol`（主入口）
仅保留：
- 构造函数（初始化 `prover`/`verifier`）
- facet 地址配置
- fallback 分发（根据 selector delegatecall 到 bridge/channel facet）

## 3. 为什么用 delegatecall

- `delegatecall` 会在主合约上下文执行模块逻辑，
  所有状态仍写入主合约存储。
- 每个 facet 独立部署，绕开单合约 24KB runtime 限制。

## 4. 兼容性要求（保持功能不变）

1. 事件名称与参数不变。
2. 函数 selector 不变（接口不变）。
3. storage 布局严格固定（必须统一通过 `ALBAStorage` 读写）。
4. 旧测试用例无需改行为断言。

## 5. 最小改造步骤

1. 提取 storage：创建 `ALBAStorage.sol`。
2. 把 bridge 相关函数剪切到 `ALBABridgeFacet.sol`。
3. 把 channel 相关函数剪切到 `ALBAChannelFacet.sol`。
4. 在 `ALBA.sol` 增加 selector => facet 的路由表。
5. 回归测试：
   - `npx hardhat test`
   - `npm run sepolia:deploy`
   - `npm run sepolia:channel-demo`

## 6. 风险点

- **存储错位**：最常见、最危险。
- **msg.sender 语义变化**：delegatecall 下仍为外部调用者，通常符合预期。
- **内部函数可见性**：需要改为库函数或 facet 内部函数。

## 7. 渐进式落地建议

- 第一步：先只拆 `Bridge` 路径，保留 channel 在主合约。
- 第二步：再拆 `Channel` 路径。
- 第三步：如果还超限，再把重型解析逻辑进一步下沉到专用库/验证器。

---

如果你希望，我可以在下一次提交里直接给你一个“可编译的 skeleton 版本”：
- `ALBAStorage.sol`
- `ALBABridgeFacet.sol`
- `ALBAChannelFacet.sol`
- 只实现 selector 分发和 1~2 个函数的端到端路径，先跑通测试网部署。
