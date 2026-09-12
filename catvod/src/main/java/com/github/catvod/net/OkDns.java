package com.github.catvod.net;

import java.io.IOException;
import java.net.InetAddress;
import java.net.UnknownHostException;
import java.util.List;

/** Original public DNS ABI, sharing the current hosts/DoH configuration. */
public class OkDns extends XgDns implements okhttp3.Dns {
    @Override
    public List<InetAddress> lookup(String hostname) throws UnknownHostException {
        try {
            return super.lookup(hostname);
        } catch (UnknownHostException error) {
            throw error;
        } catch (IOException error) {
            UnknownHostException failure = new UnknownHostException(hostname);
            failure.initCause(error);
            throw failure;
        }
    }
}
