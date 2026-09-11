package com.github.catvod.net.spider;

import java.io.IOException;

public interface XgCall {
    XgResponse execute() throws IOException;
    XgRequest request();
    void cancel();
}
