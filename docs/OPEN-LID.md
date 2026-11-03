# 开盖不休眠 / Open-lid keep awake

1.5 主界面底部提供独立的「开盖不休眠」开关。开启时，菜单栏精灵显示品牌蓝色。盖子打开时防止因闲置而自动休眠，屏幕仍按系统设置熄灭。

- 合盖或主动选择睡眠时暂停；开盖唤醒后恢复。
- 「本次合盖不休眠」仍单独控制。如果两个开关都开启，合盖模式结束后开盖模式仍可保持开启。
- 退出盖盖后关闭，再次启动默认关闭；低电量和高温保护同样适用。
- 这项功能无需安装免费兼容组件。完整合盖运行仍需该组件。

Version 1.5 provides an independent **Keep awake with lid open** switch at the bottom of the main panel. The guardian turns blue when enabled. It prevents idle system sleep while allowing the display to sleep normally.

- Pauses on lid close or manual sleep; resumes after reopening and wake.
- One-shot closed-lid sessions have their own switch. When both are enabled, ending a closed-lid session does not turn open-lid mode off.
- Quitting turns it off; relaunch starts with it off. Low-battery and thermal protection also apply.
- This mode requires no compatibility component. Full closed-lid operation still requires that separate component.

The request uses Apple's public idle-sleep API with a 30-second automatic release, renewed every 5 seconds. A frozen process cannot retain an unlimited sleep hold. No persistent power setting, display-sleep timer or screen-lock preference is changed.
