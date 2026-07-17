package com.android.cast.dlna.dmc;

import android.content.Context;

import androidx.annotation.Nullable;

import com.android.cast.dlna.dmc.control.DeviceControl;
import com.android.cast.dlna.dmc.control.OnDeviceControlListener;

public enum DLNACastManager {
    INSTANCE;

    public void bindCastService(Context context) {
    }

    public void unbindCastService(Context context) {
    }

    public void registerDeviceListener(OnDeviceRegistryListener listener) {
    }

    public void unregisterListener(Object listener) {
    }

    public void search(@Nullable Object filter) {
    }

    public DeviceControl connectDevice(org.fourthline.cling.model.meta.Device<?, ?, ?> device, OnDeviceControlListener listener) {
        return new DeviceControl(listener, device);
    }

    public void disconnectDevice(org.fourthline.cling.model.meta.Device<?, ?, ?> device) {
    }
}
