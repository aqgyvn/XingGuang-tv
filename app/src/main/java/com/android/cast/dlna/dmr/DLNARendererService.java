package com.android.cast.dlna.dmr;

import android.app.Service;
import android.content.Intent;
import android.os.IBinder;

import androidx.annotation.Nullable;

public class DLNARendererService extends Service {

    private RenderControl control;

    @Nullable
    @Override
    public IBinder onBind(Intent intent) {
        return new RendererServiceBinder(this);
    }

    public void bindRealPlayer(RenderControl control) {
        this.control = control;
    }

    public void notifyAvTransportLastChange(RenderState state) {
    }

    public RenderControl getControl() {
        return control;
    }
}
