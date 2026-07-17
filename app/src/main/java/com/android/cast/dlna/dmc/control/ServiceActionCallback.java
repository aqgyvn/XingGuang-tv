package com.android.cast.dlna.dmc.control;

import androidx.annotation.NonNull;

public interface ServiceActionCallback<T> {

    default void onSuccess(T value) {
    }

    default void onFailure(@NonNull String message) {
    }
}
