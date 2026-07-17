package com.android.cast.dlna.dmc.control;

import androidx.annotation.NonNull;

import org.fourthline.cling.support.lastchange.EventedValue;
import org.fourthline.cling.support.model.TransportState;

public interface OnDeviceControlListener {

    default void onConnected(@NonNull org.fourthline.cling.model.meta.Device<?, ?, ?> device) {
    }

    default void onDisconnected(@NonNull org.fourthline.cling.model.meta.Device<?, ?, ?> device) {
    }

    default void onAvTransportStateChanged(@NonNull TransportState state) {
    }

    default void onEventChanged(@NonNull EventedValue<?> event) {
    }

    default void onRendererVolumeChanged(int volume) {
    }

    default void onRendererVolumeMuteChanged(boolean mute) {
    }
}
