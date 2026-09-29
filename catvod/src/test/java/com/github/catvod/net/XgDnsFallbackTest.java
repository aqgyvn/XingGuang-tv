package com.github.catvod.net;

import com.github.catvod.bean.Doh;
import org.junit.Test;
import java.io.IOException;
import java.net.InetAddress;
import java.net.UnknownHostException;
import java.util.List;
import static org.junit.Assert.*;

public class XgDnsFallbackTest {
    private static class Resolver extends XgDns {
        boolean malformed;
        boolean empty;
        boolean failSystem;
        int systemCalls;
        Resolver() { setDoh(new Doh() { @Override public String getUrl() { return "https://dns.test"; } }); }
        @Override protected List<InetAddress> lookupDoh(Doh doh, String hostname) throws IOException {
            if (empty) return List.of();
            if (malformed) throw new IllegalStateException("malformed DNS JSON");
            throw new IOException("DNS endpoint unavailable");
        }
        @Override protected List<InetAddress> systemLookup(String hostname) throws IOException {
            systemCalls++;
            if (failSystem) throw new UnknownHostException(hostname);
            return List.of(InetAddress.getByAddress(new byte[]{127,0,0,1}));
        }
    }
    @Test public void networkFailureFallsBack() throws Exception {
        Resolver dns = new Resolver();
        assertEquals(1, dns.lookup("source.test").size());
        assertEquals(1, dns.systemCalls);
    }
    @Test public void malformedAndEmptyDnsFallBack() throws Exception {
        Resolver dns = new Resolver();
        dns.malformed = true;
        assertEquals(1, dns.lookup("source.test").size());
        dns.empty = true;
        assertEquals(1, dns.lookup("source.test").size());
    }
    @Test public void bothFailuresKeepCause() {
        Resolver dns = new Resolver();
        dns.failSystem = true;
        assertEquals(1, assertThrows(UnknownHostException.class, () -> dns.lookup("source.test")).getSuppressed().length);
    }
}
