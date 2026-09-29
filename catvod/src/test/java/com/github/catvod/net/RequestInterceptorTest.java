package com.github.catvod.net;

import com.github.catvod.net.interceptor.RequestInterceptor;
import org.junit.Test;
import static org.junit.Assert.*;

public class RequestInterceptorTest {
    @Test public void encodedTokenIsNotDoubleEncodedAndStaysBeforeFragment() {
        RequestInterceptor interceptor = new RequestInterceptor();
        interceptor.intercept(new XgRequest.Builder().url("https://example.test/config?auth=a%2Bb%2Fc%3D").build());
        XgRequest request = new XgRequest.Builder().url("https://example.test/api?q=1#part").build();
        assertEquals("https://example.test/api?q=1&auth=a%2Bb%2Fc%3D#part", interceptor.intercept(request).url().toString());
        assertEquals("https://other.test/api", interceptor.intercept(new XgRequest.Builder().url("https://other.test/api").build()).url().toString());
        assertEquals("https://example.test/api?auth=new", interceptor.intercept(new XgRequest.Builder().url("https://example.test/api?auth=new").build()).url().toString());
    }
}
