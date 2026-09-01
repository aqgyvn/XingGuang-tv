package com.github.catvod.net.interceptor;

import com.github.catvod.bean.Header;
import com.github.catvod.net.XgRequest;
import com.github.catvod.utils.Json;
import com.github.catvod.utils.Util;

import java.util.List;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CopyOnWriteArrayList;

public class ResponseInterceptor {

    private final List<Header> headers = new CopyOnWriteArrayList<>();
    private final ConcurrentHashMap<String, String> redirectMap = new ConcurrentHashMap<>();

    public void addAll(List<Header> items) {
        headers.addAll(items);
    }

    public void clear() {
        headers.clear();
        redirectMap.clear();
    }

    public XgRequest intercept(XgRequest request) {
        XgRequest.Builder builder = request.newBuilder();
        String host = request.url().host();
        for (Header item : headers) if (Util.containOrMatch(host, item.getHost())) Json.toMap(item.getHeader()).forEach(builder::header);
        return builder.build();
    }

    public void rememberRedirect(String location, String source) {
        if (location != null) redirectMap.put(location, source);
    }

    public String fallbackRedirect(String requestUrl) {
        return redirectMap.get(requestUrl);
    }
}
