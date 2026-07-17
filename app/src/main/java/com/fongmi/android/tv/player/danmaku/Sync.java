package com.fongmi.android.tv.player.danmaku;

import com.fongmi.android.tv.player.Players;

public class Sync {

    private final Players player;

    public Sync(Players player) {
        this.player = player;
    }

    public long getUptimeMillis() {
        return player.getPosition();
    }

    public int getSyncState() {
        return player.isPlaying() ? 1 : 2;
    }

    public long getThresholdTimeMills() {
        return 1000L;
    }

    public boolean isSyncPlayingState() {
        return true;
    }
}
