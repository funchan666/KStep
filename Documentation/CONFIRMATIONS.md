# KStep 接入记录

测试配置和正式切换条件见 [KStep README](../README.md)。使用 Xcode 27.1 的 iOS 27.1 SDK 查看 Duo 相关布局，应用最低支持 iOS 17。

KStep 的课程内容由测试后台返回，舞蹈指南和练习日志使用本地资源。`getV2.name` 使用 `KStep`。登录 `source` 和业务 `packageName` 跟随 `Config/KStep.xcconfig` 的实际 Bundle ID。

本次核对覆盖源码、配置和资源引用。短码播放、广告曝光、Apple Sandbox 支付与恢复、Duo 内外屏和折叠姿态待实际验证。
