package com.github.catvod.net.spider;

import java.net.InetAddress;
import java.net.UnknownHostException;
import java.util.List;

public interface XgDns {
    XgDns SYSTEM = hostname -> List.of(InetAddress.getAllByName(hostname));
    List<InetAddress> lookup(String hostname) throws UnknownHostException;

    static XgDns safeDns() {
        return hostname -> {
            try {
                return com.github.catvod.net.XgHttp.dns().lookup(hostname);
            } catch (java.io.IOException e) {
                UnknownHostException error = new UnknownHostException(hostname);
                error.initCause(e);
                throw error;
            }
        };
    }
}
