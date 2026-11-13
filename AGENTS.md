# KStep 项目交接

本项目是女团舞蹈教学视频 App。使用原生 SwiftUI，最低 iOS 17，工程与共享 Scheme 均为 `KStep`。本文件记录 2026-11-13 的交付和用户确认的约定。后续状态以本项目的代码、配置和新验证记录为准。

## 业务与测试约定

- 业务沿用 Clipo。首页保留课程链接和短码输入，通过 `search-check` 进入可纵向切换的全屏播放器。游客登录、推荐、收藏、离线播放、编辑导出、额度、开屏与激励广告、订阅和恢复购买继续走原有路径。订阅与媒体导出保留服务端权益校验。
- 当前连接测试 API `https://devapi.io-jp.com`。`getV2.name` 为 `KStep`，取自 `KSTEP_RELEASE_NAME`。KStep 的 Bundle ID 为 `com.kstepstudio.eightcount`，游客登录 `source` 和业务 `packageName` 同源。
- 广告使用 Clipo 的 Google 官方演示 App ID 和开屏、激励广告位。官网、用户协议、隐私政策使用 HTTPS 占位链接。测试商品为月付 `coins_1.99` USD 9.99、年付 `conis_4.99` USD 99.99。会员页展示 StoreKit 返回的本地化价格和账期。
- 播放联调用 Clipo 的原测试短码，在首页手动输入。短码和广告配置见工具包的 [Clipo 基线](/Users/chengdupengyuyan/.codex/skills/toolkit/references/clipo-baseline.md) 第 1、5 节。Clipo 源工程位于 `/Users/chengdupengyuyan/Fun/Clipo`。
- 用户确认本项目测试通过后，再收集正式 API 域名、广告 App ID 和广告位、官网、用户协议和隐私政策。切换时核对 `com.kstepstudio.eightcount` 的后台登记和签名、`getV2.name` 对应的 `KStep` 配置，以及正式月年商品与后台订单映射。

## 本项目的原创界面

- 首页是可操作的八拍练习台，选择八拍与速度后，排练日志使用该设置。课程合集横向浏览。主题练习按唱段、八拍、速度和镜像设置记录动作与复盘结果。记录模型在 `KStep/Core/DancePracticeJournal.swift`。
- 保留五个目的地，练习排在推荐流前。
- **资料库**。四块排练分类按钮显示本机数量，收藏用竖向课程缩略图。收藏、离线、导入、导出四类及原有操作均保留。实现见 `KStep/Features/LibraryView.swift`。
- **Plus 会员页**。原创排练照配并排套餐卡，大字号可纵排。订阅用亮粉按钮，恢复用独立描边按钮。从「我」页及原有额度或导出入口打开。实现见 `KStep/Features/MembershipView.swift`，主图在该 target 的 `Assets.xcassets/Illustrations/PlusArtwork.imageset`。
- 后续 UI 工作按全局 UI 技能约定使用 `ui-design-reference`、`ui-taste` 和适用的原创素材工作流。iOS 适配按 Duo 约定，保留当前 SwiftUI 和各主题的交互设计。

## 交付时的验证状态

- 已静态核对新版首页、导航、主题入口和课程返回路径。此前核对过资料库与会员页的语法和接线。
- 待运行验证的事项包括编译、模拟器和真机显示、Duo 布局、测试后台返回、短码播放、广告以及 Apple Sandbox 购买与恢复。按用户约定，默认只做静态核对，编译和测试在用户明确要求时执行。
