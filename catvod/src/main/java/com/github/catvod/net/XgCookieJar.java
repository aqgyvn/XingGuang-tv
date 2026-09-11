package com.github.catvod.net;

import java.util.Collections;
import java.util.List;

public interface XgCookieJar {
    XgCookieJar NO_COOKIES = new XgCookieJar() {
        public List<XgCookie> loadForRequest(XgUrl url) { return Collections.emptyList(); }
        public void saveFromResponse(XgUrl url, List<XgCookie> cookies) {}
    };

    List<XgCookie> loadForRequest(XgUrl url);
    void saveFromResponse(XgUrl url, List<XgCookie> cookies);
}
