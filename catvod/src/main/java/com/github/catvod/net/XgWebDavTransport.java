package com.github.catvod.net;

import org.eclipse.jetty.client.Address;
import org.eclipse.jetty.client.HttpClient;
import org.eclipse.jetty.client.HttpExchange;
import org.eclipse.jetty.io.Buffer;
import org.eclipse.jetty.io.ByteArrayBuffer;
import org.eclipse.jetty.util.ssl.SslContextFactory;
import org.eclipse.jetty.util.thread.QueuedThreadPool;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.InterruptedIOException;
import java.net.InetSocketAddress;
import java.net.Proxy;
import java.net.SocketTimeoutException;
import java.security.NoSuchAlgorithmException;
import java.util.List;
import java.util.Map;
import java.util.zip.GZIPInputStream;

import javax.net.ssl.SSLEngine;
import javax.net.ssl.SSLContext;
import javax.net.ssl.SSLParameters;

/** Bounded PROPFIND execution using the protocol engine already shipped for casting. */
final class XgWebDavTransport {
    private static final int MAX_BODY_BYTES = 8 * 1024 * 1024;

    private XgWebDavTransport() {}

    static XgResponse execute(XgCall call) throws IOException {
        checkCanceled(call);
        XgRequest request = call.request();
        XgClient.Options options = call.client().options();
        if (options.sslSocketFactory != null || options.hostnameVerifier != null) {
            throw new IOException("WebDAV uses the platform certificate and hostname checks");
        }
        Exchange exchange = new Exchange();
        call.cancellation(exchange::cancel);
        try (ProtocolClient client = new ProtocolClient(request)) {
            int timeout = (int) Math.min(Integer.MAX_VALUE, Math.max(1, options.timeout));
            client.setConnectTimeout(timeout);
            client.setTimeout(timeout);
            client.setIdleTimeout(timeout);
            client.setMaxRetries(0);
            client.setMaxRedirects(0);
            configureProxy(client, request);
            exchange.setConfigureListeners(false);
            exchange.setTimeout(timeout);
            exchange.setURL(request.url().uri().toASCIIString());
            exchange.setMethod("PROPFIND");
            exchange.setVersion("HTTP/1.1");
            exchange.setRequestHeader("User-Agent", XgHttp.userAgent());
            for (Map.Entry<String, List<String>> entry : request.headers().toMultimap().entrySet()) {
                boolean first = true;
                for (String value : entry.getValue()) {
                    if (first) exchange.setRequestHeader(entry.getKey(), value);
                    else exchange.addRequestHeader(entry.getKey(), value);
                    first = false;
                }
            }
            if (request.body() != null) {
                exchange.setRequestContent(new ByteArrayBuffer(request.body().content()));
                if (request.headers().get("Content-Type") == null) {
                    exchange.setRequestContentType(request.body().contentType());
                }
            }
            client.start();
            checkCanceled(call);
            client.send(exchange);
            int status = exchange.waitForDone();
            checkCanceled(call);
            if (exchange.error != null) throw new IOException("WebDAV transport failed", exchange.error);
            if (status == HttpExchange.STATUS_EXPIRED) throw new SocketTimeoutException("WebDAV request timed out");
            if (status != HttpExchange.STATUS_COMPLETED) throw new IOException("WebDAV request ended with state " + status);
            XgHeaders headers = exchange.headers.build();
            byte[] bytes = exchange.content.toByteArray();
            InputStream stream = new ByteArrayInputStream(bytes);
            String encoding = headers.get("Content-Encoding");
            if ("gzip".equalsIgnoreCase(encoding)) stream = new GZIPInputStream(stream);
            else if (encoding != null && !encoding.isEmpty() && !"identity".equalsIgnoreCase(encoding)) {
                throw new IOException("Unsupported WebDAV content encoding: " + encoding);
            }
            Runnable close = () -> call.client().unregister(call);
            XgResponseBody body = new XgResponseBody(stream, encoding == null ? bytes.length : -1,
                    headers.get("Content-Type"), close);
            return new XgResponse(exchange.code, exchange.message, headers, body, request, close);
        } catch (InterruptedException e) {
            exchange.cancel();
            Thread.currentThread().interrupt();
            InterruptedIOException error = new InterruptedIOException("WebDAV request interrupted");
            error.initCause(e);
            throw error;
        } catch (IOException e) {
            throw e;
        } catch (Exception e) {
            throw new IOException("Starting WebDAV transport failed", e);
        } finally {
            call.cancellation(null);
        }
    }

    private static void configureProxy(HttpClient client, XgRequest request) throws IOException {
        List<Proxy> proxies = XgHttp.selector().select(request.url().uri());
        Proxy proxy = proxies == null || proxies.isEmpty() ? Proxy.NO_PROXY : proxies.get(0);
        if (proxy.type() == Proxy.Type.DIRECT) return;
        if (proxy.type() != Proxy.Type.HTTP || !(proxy.address() instanceof InetSocketAddress address)) {
            throw new IOException("WebDAV requires a direct connection or an HTTP proxy");
        }
        client.setProxy(new Address(address.getHostString(), address.getPort()));
        XgRequest authenticated = XgHttp.authenticator().authenticate(request.url().uri(), proxy, request);
        if (authenticated != null) {
            String authorization = authenticated.headers().get("Proxy-Authorization");
            client.setProxyAuthentication(exchange -> exchange.setRequestHeader("Proxy-Authorization", authorization));
        }
    }

    private static void checkCanceled(XgCall call) throws IOException {
        if (Thread.currentThread().isInterrupted()) throw new InterruptedIOException("WebDAV request interrupted");
        if (call.isCanceled()) throw new IOException("Canceled");
    }

    private static final class ProtocolClient extends HttpClient implements AutoCloseable {
        ProtocolClient(XgRequest request) throws NoSuchAlgorithmException {
            super(new SslContextFactory(false) {
                @Override public SSLEngine newSslEngine(String ignoredHost, int ignoredPort) {
                    // Jetty 8 passes the connected IP; TLS must use the requested host for SNI and verification.
                    String host = request.url().host();
                    if (host.startsWith("[") && host.endsWith("]")) host = host.substring(1, host.length() - 1);
                    int port = request.url().uri().getPort();
                    return super.newSslEngine(host, port < 0 ? 443 : port);
                }

                @Override public SSLEngine newSslEngine() {
                    return newSslEngine(null, 0);
                }

                @Override public void customize(SSLEngine engine) {
                    super.customize(engine);
                    SSLParameters parameters = engine.getSSLParameters();
                    parameters.setEndpointIdentificationAlgorithm("HTTPS");
                    engine.setSSLParameters(parameters);
                }
            });
            getSslContextFactory().setSslContext(SSLContext.getDefault());
            QueuedThreadPool threads = new QueuedThreadPool();
            threads.setMinThreads(1);
            threads.setMaxThreads(8);
            threads.setDaemon(true);
            threads.setName("XgWebDav");
            threads.setMaxStopTimeMs(1000);
            setThreadPool(threads);
            setConnectorType(CONNECTOR_SELECT_CHANNEL);
            setMaxConnectionsPerAddress(1);
        }

        @Override public void close() throws IOException {
            boolean interrupted = Thread.interrupted();
            try {
                stop();
            } catch (Exception e) {
                throw new IOException("Stopping WebDAV transport failed", e);
            } finally {
                if (interrupted) Thread.currentThread().interrupt();
            }
        }
    }

    private static final class Exchange extends HttpExchange {
        final XgHeaders.Builder headers = new XgHeaders.Builder();
        final ByteArrayOutputStream content = new ByteArrayOutputStream();
        volatile Throwable error;
        int code;
        String message;

        @Override protected void onResponseStatus(Buffer version, int status, Buffer reason) {
            code = status;
            message = reason == null ? "" : reason.toString();
        }

        @Override protected void onResponseHeader(Buffer name, Buffer value) {
            headers.add(name.toString(), value.toString());
        }

        @Override protected void onResponseContent(Buffer buffer) throws IOException {
            if (buffer.length() > MAX_BODY_BYTES - content.size()) throw new IOException("WebDAV response exceeds size limit");
            content.write(buffer.asArray());
        }

        @Override protected synchronized void onConnectionFailed(Throwable cause) {
            if (error == null) error = cause;
            super.onConnectionFailed(cause);
        }

        @Override protected synchronized void onException(Throwable cause) {
            if (error == null) error = cause;
            super.onException(cause);
        }
    }
}
