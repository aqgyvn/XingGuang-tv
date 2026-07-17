package com.android.cast.dlna.dmr;

import android.os.Binder;

public class RendererServiceBinder extends Binder {

    private final DLNARendererService service;

    public RendererServiceBinder(DLNARendererService service) {
        this.service = service;
    }

    public DLNARendererService getService() {
        return service;
    }
}
