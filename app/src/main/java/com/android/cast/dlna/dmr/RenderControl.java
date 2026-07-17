package com.android.cast.dlna.dmr;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

public interface RenderControl {

    @NonNull
    RenderState getState();

    long getCurrentPosition();

    long getDuration();

    void seek(long time);

    void pause();

    void play(@Nullable Double speed);

    void stop();
}
