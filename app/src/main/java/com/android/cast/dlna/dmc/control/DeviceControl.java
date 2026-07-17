package com.android.cast.dlna.dmc.control;

import kotlin.Unit;

public class DeviceControl {

    private final OnDeviceControlListener listener;
    private final org.fourthline.cling.model.meta.Device<?, ?, ?> device;

    public DeviceControl(OnDeviceControlListener listener, org.fourthline.cling.model.meta.Device<?, ?, ?> device) {
        this.listener = listener;
        this.device = device;
        if (listener != null && device != null) listener.onConnected(device);
    }

    public void setAVTransportURI(String url, String name, ServiceActionCallback<Unit> callback) {
        if (callback != null) callback.onFailure("DLNA library unavailable");
    }

    public void seek(long position, ServiceActionCallback<Unit> callback) {
        if (callback != null) callback.onSuccess(Unit.INSTANCE);
    }

    public void play(String speed, ServiceActionCallback<Unit> callback) {
        if (callback != null) callback.onSuccess(Unit.INSTANCE);
    }

    public void disconnect() {
        if (listener != null && device != null) listener.onDisconnected(device);
    }
}
