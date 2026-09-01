package com.github.catvod.net;

import android.net.Uri;

import com.github.catvod.bean.Proxy;
import com.github.catvod.utils.Util;
import com.google.common.net.HttpHeaders;

import java.net.InetSocketAddress;
import java.net.ProxySelector;
import java.net.URI;
import java.util.List;
import java.util.concurrent.CopyOnWriteArrayList;

public class XgAuthenticator {

    private final List<Proxy> proxy = new CopyOnWriteArrayList<>();

    public void addAll(List<Proxy> items) {
        proxy.addAll(items);
    }

    public void clear() {
        proxy.clear();
    }

    XgRequest authenticate(URI uri, java.net.Proxy selected, XgRequest request) {
        if (request.headers().get(HttpHeaders.PROXY_AUTHORIZATION) != null) return null;
        if (!(selected.address() instanceof InetSocketAddress address)) return null;
        String requestHost = uri.getHost();
        String proxyHost = address.getHostString();
        for (Proxy item : proxy) for (String host : item.getHosts()) if (Util.containOrMatch(requestHost, host)) {
            for (String url : item.getUrls()) if (url.contains(proxyHost)) {
                String userInfo = Uri.parse(url).getUserInfo();
                if (userInfo != null) return request.newBuilder().header(HttpHeaders.PROXY_AUTHORIZATION, Util.basic(userInfo)).build();
            }
        }
        return null;
    }
}
