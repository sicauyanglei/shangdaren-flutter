<template>
    <view class="container">
        <web-view src="/hybrid/html/index.html" @message="handleMessage"></web-view>
    </view>
</template>

<script>
export default {
    data() {
        return {
            
        }
    },
    onLoad() {
        // 强制横屏
        // #ifdef APP-PLUS
        plus.screen.lockOrientation('landscape');
        plus.screen.lockOrientation('landscape-primary');
        // #endif
    },
    onUnload() {
        // 释放屏幕锁定
        // #ifdef APP-PLUS
        plus.screen.unlockOrientation();
        // #endif
    },
    methods: {
        handleMessage(e) {
            console.log('收到H5消息：', e.detail.data)
        }
    }
}
</script>

<style>
.container {
    width: 100%;
    height: 100%;
}
</style>
