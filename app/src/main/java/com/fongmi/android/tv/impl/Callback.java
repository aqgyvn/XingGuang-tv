package com.fongmi.android.tv.impl;

import androidx.annotation.NonNull;

import com.github.catvod.net.XgCall;
import com.github.catvod.net.XgCallback;
import com.github.catvod.net.XgResponse;

import java.io.IOException;

public class Callback implements XgCallback {

    public void success() {
    }

    public void success(String result) {
    }

    public void error() {
    }

    public void start() {
    }

    public void error(String msg) {
    }

    @Override
    public void onFailure(XgCall call, IOException e) {
    }

    @Override
    public void onResponse(XgCall call, XgResponse response) throws IOException {
    }
}
