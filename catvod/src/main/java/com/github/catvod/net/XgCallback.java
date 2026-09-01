package com.github.catvod.net;

import java.io.IOException;

public interface XgCallback {

    void onFailure(XgCall call, IOException error);

    void onResponse(XgCall call, XgResponse response) throws IOException;
}
