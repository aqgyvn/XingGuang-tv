package com.android.cast.dlna.dmc;

import androidx.annotation.NonNull;

public interface OnDeviceRegistryListener {

    default void onDeviceAdded(@NonNull org.fourthline.cling.model.meta.Device<?, ?, ?> device) {
    }

    default void onDeviceRemoved(@NonNull org.fourthline.cling.model.meta.Device<?, ?, ?> device) {
    }
}
